import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

import '../../../config/app_config.dart';
import '../../../core/storage/secure_storage.dart';
import '../../settings/presentation/providers/settings_provider.dart';
import 'plugin_theme_utils.dart';

/// 插件 Tab 页面（Web 平台实现）
/// 使用 iframe 嵌入插件页面，体验与原生 WebView 一致
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

class _PluginTabPageState extends ConsumerState<PluginTabPage> {
  static final _registeredTypes = <String>{};
  static final _activeStates = <String, _PluginTabPageState>{};

  late final String _viewType;
  web.HTMLIFrameElement? _iframe;
  String? _lastTheme;

  String _buildPluginUrl(String theme) {
    final baseUrl =
        '${AppConfig.baseUrl}${AppConfig.basePath}/api/v1/jsplugin/${widget.entryPath}';
    final token = SecureStorageService.cachedAccessToken ?? '';
    final params = <String>['embed', 'theme=$theme'];
    if (token.isNotEmpty) params.add('access_token=$token');
    return '$baseUrl?${params.join('&')}';
  }

  void _sendThemeToPlugin(String theme) {
    final iframe = _iframe;
    if (iframe == null) return;
    final contentWindow = iframe.contentWindow;
    if (contentWindow == null) return;
    final msg = {'type': 'songloft-theme', 'theme': theme}.jsify();
    contentWindow.postMessage(msg, '*'.toJS);
  }

  @override
  void initState() {
    super.initState();
    _viewType = 'plugin-tab-${widget.entryPath}';
    _activeStates[widget.entryPath] = this;

    if (!_registeredTypes.contains(_viewType)) {
      _registeredTypes.add(_viewType);
      final entryPath = widget.entryPath;
      ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
        final state = _activeStates[entryPath]!;
        final theme = state._lastTheme ?? 'light';
        final iframe = web.HTMLIFrameElement()
          ..src = state._buildPluginUrl(theme)
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%';
        state._iframe = iframe;
        return iframe;
      });
    }
  }

  @override
  void dispose() {
    if (_activeStates[widget.entryPath] == this) {
      _activeStates.remove(widget.entryPath);
    }
    _iframe?.src = 'about:blank';
    _iframe = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final brightness = MediaQuery.of(context).platformBrightness;
    final theme = resolveEffectiveTheme(themeMode, brightness);

    if (_lastTheme == null) {
      _lastTheme = theme;
    } else if (_lastTheme != theme) {
      _lastTheme = theme;
      _sendThemeToPlugin(theme);
    }

    return HtmlElementView(viewType: _viewType);
  }
}
