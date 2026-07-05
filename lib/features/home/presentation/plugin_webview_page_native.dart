import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/storage/secure_storage.dart';
import '../../settings/presentation/providers/settings_provider.dart';
import 'plugin_theme_utils.dart';

/// 插件 WebView 页面（原生平台实现）
/// 在应用内加载插件 HTML 页面，通过 JS 注入传递 JWT token
class PluginWebViewPage extends ConsumerStatefulWidget {
  final String pluginUrl;
  final String pluginName;

  const PluginWebViewPage({
    super.key,
    required this.pluginUrl,
    required this.pluginName,
  });

  @override
  ConsumerState<PluginWebViewPage> createState() => _PluginWebViewPageState();
}

class _PluginWebViewPageState extends ConsumerState<PluginWebViewPage>
    with WidgetsBindingObserver {
  static const Duration _pageLoadTimeout = Duration(seconds: 20);

  InAppWebViewController? _webViewController;
  Timer? _loadTimer;
  bool _isLoading = true;
  bool _pageReady = false;
  String? _errorMessage;
  String? _lastTheme;
  bool _windowVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startLoadTimer();
  }

  @override
  void dispose() {
    _loadTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final visible = state != AppLifecycleState.hidden;
    if (_windowVisible != visible) {
      setState(() => _windowVisible = visible);
    }
  }

  String _buildPluginUrl(String theme) {
    final token = SecureStorageService.cachedAccessToken ?? '';
    final uri = Uri.parse(widget.pluginUrl);
    final query = Map<String, String>.from(uri.queryParameters)
      ..['theme'] = theme;
    if (token.isNotEmpty) {
      query['access_token'] = token;
    }
    return uri.replace(queryParameters: query).toString();
  }

  void _startLoadTimer() {
    _loadTimer?.cancel();
    _loadTimer = Timer(_pageLoadTimeout, () {
      if (!mounted || !_isLoading) return;
      setState(() {
        _isLoading = false;
        _errorMessage = '页面加载超时，请检查插件是否可用或网络连接';
      });
    });
  }

  void _finishLoading() {
    _loadTimer?.cancel();
    _loadTimer = null;
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _pageReady = true;
      _errorMessage = null;
    });
  }

  void _finishLoadingWithError(String message) {
    _loadTimer?.cancel();
    _loadTimer = null;
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _pageReady = false;
      _errorMessage = message;
    });
  }

  String _buildTokenInjectionScript() {
    final token = SecureStorageService.cachedAccessToken ?? '';
    if (token.isEmpty) return '';
    final escapedToken = token
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('"', '\\"');
    return "localStorage.setItem('songloft-auth', JSON.stringify({accessToken: '$escapedToken'}));";
  }

  void _sendThemeToPlugin(String theme) {
    _webViewController?.evaluateJavascript(
      source: "window.postMessage({type:'songloft-theme',theme:'$theme'},'*')",
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final themeMode = ref.watch(themeModeProvider);
    final brightness = MediaQuery.of(context).platformBrightness;
    final theme = resolveEffectiveTheme(themeMode, brightness);

    if (_lastTheme == null) {
      _lastTheme = theme;
    } else if (_lastTheme != theme) {
      _lastTheme = theme;
      if (_pageReady) _sendThemeToPlugin(theme);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final controller = _webViewController;
        if (controller != null && await controller.canGoBack()) {
          await controller.goBack();
        } else if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.pluginName),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final controller = _webViewController;
              if (controller != null && await controller.canGoBack()) {
                await controller.goBack();
              } else if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: '关闭',
              onPressed: () => Navigator.of(context).pop(),
            ),
            IconButton(
              icon: const Icon(Icons.open_in_browser),
              tooltip: '在浏览器中打开',
              onPressed: () {
                final token = SecureStorageService.cachedAccessToken ?? '';
                final separator = widget.pluginUrl.contains('?') ? '&' : '?';
                var url = widget.pluginUrl;
                final params = <String>['theme=$theme'];
                if (token.isNotEmpty) params.add('access_token=$token');
                url = '$url$separator${params.join('&')}';
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              },
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Stack(
            children: [
              if (_errorMessage != null)
                _buildErrorView(colorScheme)
              else
                _buildWebView(theme),
              if (_isLoading) const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebView(String theme) {
    final tokenScript = _buildTokenInjectionScript();

    return Offstage(
      offstage: !_windowVisible,
      child: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(_buildPluginUrl(theme))),
        initialUserScripts:
            tokenScript.isNotEmpty
                ? UnmodifiableListView([
                  UserScript(
                    source: tokenScript,
                    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                  ),
                ])
                : null,
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          allowFileAccessFromFileURLs: true,
          allowUniversalAccessFromFileURLs: true,
          supportZoom: false,
        ),
        onWebViewCreated: (controller) {
          _webViewController = controller;
        },
        onLoadStart: (controller, url) {
          if (mounted) {
            _startLoadTimer();
            setState(() {
              _isLoading = true;
              _pageReady = false;
              _errorMessage = null;
            });
          }
        },
        onLoadStop: (controller, url) {
          _finishLoading();
        },
        onReceivedError: (controller, request, error) {
          if (request.isForMainFrame ?? false) {
            _finishLoadingWithError(error.description);
          }
        },
        onReceivedHttpError: (controller, request, errorResponse) {
          if (request.isForMainFrame ?? false) {
            final status = errorResponse.statusCode;
            final reason = errorResponse.reasonPhrase;
            final detail = reason == null || reason.isEmpty ? '' : ' $reason';
            _finishLoadingWithError('页面加载失败: HTTP $status$detail');
          }
        },
      ),
    );
  }

  Widget _buildErrorView(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: colorScheme.error),
          const SizedBox(height: 16),
          Text('页面加载失败', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage ?? '未知错误',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              setState(() {
                _errorMessage = null;
                _isLoading = true;
              });
              _startLoadTimer();
              _webViewController?.reload();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
