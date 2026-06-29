import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_config.dart';
import '../../../core/storage/secure_storage.dart';
import '../../settings/presentation/providers/settings_provider.dart';
import 'plugin_theme_utils.dart';

/// 插件 Tab 页面（原生平台实现）
/// 在 Shell 内嵌入 WebView 展示插件页面，底部导航栏保持可见
class PluginTabPage extends ConsumerStatefulWidget {
  final String entryPath;
  final bool isActive;

  const PluginTabPage({
    super.key,
    required this.entryPath,
    this.isActive = true,
  });

  @override
  ConsumerState<PluginTabPage> createState() => _PluginTabPageState();
}

class _PluginTabPageState extends ConsumerState<PluginTabPage>
    with WidgetsBindingObserver {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  bool _pageReady = false;
  String? _errorMessage;
  String? _lastTheme;
  bool _windowVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant PluginTabPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive && !widget.isActive) {
      // 原生 WebView 即使被 Offstage 隐藏仍可在系统层面持有键盘焦点，
      // 释放焦点以防止抢夺 Flutter 输入法上下文
      _webViewController?.clearFocus();
    }
  }

  @override
  void dispose() {
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

  String _buildPluginUrl(String theme) =>
      '${AppConfig.baseUrl}${AppConfig.basePath}/api/v1/jsplugin/${widget.entryPath}?embed&theme=$theme';

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
      source:
          "window.postMessage({type:'songloft-theme',theme:'$theme'},'*')",
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

    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          if (_errorMessage != null)
            _buildErrorView(colorScheme)
          else
            _buildWebView(theme),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Widget _buildWebView(String theme) {
    final tokenScript = _buildTokenInjectionScript();

    return Offstage(
      offstage: !_windowVisible,
      child: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(_buildPluginUrl(theme))),
        initialUserScripts: tokenScript.isNotEmpty
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
            setState(() {
              _isLoading = true;
              _errorMessage = null;
            });
          }
        },
        onLoadStop: (controller, url) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _pageReady = true;
            });
          }
        },
        onReceivedError: (controller, request, error) {
          if (request.isForMainFrame ?? false) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _errorMessage = error.description;
              });
            }
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
            },
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
