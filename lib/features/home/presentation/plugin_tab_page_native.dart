import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../config/app_config.dart';
import '../../../core/storage/secure_storage.dart';

/// 插件 Tab 页面（原生平台实现）
/// 在 Shell 内嵌入 WebView 展示插件页面，底部导航栏保持可见
class PluginTabPage extends StatefulWidget {
  final String entryPath;

  const PluginTabPage({super.key, required this.entryPath});

  @override
  State<PluginTabPage> createState() => _PluginTabPageState();
}

class _PluginTabPageState extends State<PluginTabPage> {
  bool _isLoading = true;
  String? _errorMessage;

  String get _pluginUrl =>
      '${AppConfig.baseUrl}${AppConfig.basePath}/api/v1/jsplugin/${widget.entryPath}?embed';

  String _buildTokenInjectionScript() {
    final token = SecureStorageService.cachedAccessToken ?? '';
    if (token.isEmpty) return '';
    final escapedToken = token
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('"', '\\"');
    return "localStorage.setItem('songloft-auth', JSON.stringify({accessToken: '$escapedToken'}));";
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          if (_errorMessage != null)
            _buildErrorView(colorScheme)
          else
            _buildWebView(),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Widget _buildWebView() {
    final tokenScript = _buildTokenInjectionScript();

    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(_pluginUrl)),
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
          setState(() => _isLoading = false);
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
