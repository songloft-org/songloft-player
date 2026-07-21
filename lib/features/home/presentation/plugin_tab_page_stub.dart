import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

import '../../../config/app_config.dart';
import '../../../core/storage/secure_storage.dart';
import '../../player/domain/player_state.dart';
import '../../player/presentation/providers/player_provider.dart';
import '../../settings/presentation/providers/settings_provider.dart';
import 'plugin_host_dispatch.dart';
import 'plugin_iframe_diagnostics.dart';
import 'plugin_theme_utils.dart';

/// JS `Object.is` —— 用于精确比较两个 JS 对象引用（判断消息是否来自本 iframe）。
@JS('Object.is')
external bool _objectIs(JSAny? a, JSAny? b);

/// 插件 Tab 页面（Web 平台实现）
/// 使用 iframe 嵌入插件页面，体验与原生 WebView 一致。
/// 通过 postMessage 双向桥接：主题下发（宿主→iframe）+ 客户端 SDK 调用（iframe→宿主）。
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

  // 客户端 SDK 桥接（iframe ↔ 宿主）
  StreamSubscription<web.MessageEvent>? _msgSub;
  PluginHostDispatcher? _dispatcher;
  String? _lastPushedStateSig;

  PluginHostDispatcher get _hostDispatcher =>
      _dispatcher ??= PluginHostDispatcher(ref, platformName: 'web');

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

    // 监听来自本 iframe 的客户端 SDK 调用（songloft-host-call）。
    _msgSub = web.window.onMessage.listen(_onWindowMessage);

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
        // #278 抖动诊断（仅 flutter.web_debug_console=true 时生效，生产零副作用）
        attachPluginIframeDiagnostics(iframe, 'tab:$entryPath', viewId);
        return iframe;
      });
    }
  }

  @override
  void dispose() {
    if (_activeStates[widget.entryPath] == this) {
      _activeStates.remove(widget.entryPath);
    }
    _msgSub?.cancel();
    _iframe?.src = 'about:blank';
    _iframe = null;
    super.dispose();
  }

  /// 处理来自插件 iframe 的客户端 SDK 调用。
  void _onWindowMessage(web.MessageEvent event) {
    final iframe = _iframe;
    if (iframe == null) return;
    // 安全：仅接受来自本 iframe 的消息，避免其它窗口/frame 伪造。
    final source = event.source;
    if (source == null ||
        !_objectIs(source as JSAny?, iframe.contentWindow as JSAny?)) {
      return;
    }
    final dartData = event.data?.dartify();
    if (dartData is! Map) return;
    if (dartData['type'] != 'songloft-host-call') return;

    final req = Map<String, dynamic>.from(dartData);
    final id = req['id'];
    _hostDispatcher.handleCall(req).then((result) {
      final contentWindow = _iframe?.contentWindow;
      if (contentWindow == null) return;
      final reply = <String, dynamic>{
        'type': 'songloft-host-reply',
        'id': id,
        ...result,
      };
      contentWindow.postMessage(reply.jsify(), '*'.toJS);
    });
  }

  /// 播放状态变更 → 推送给 iframe（节流，仅关键字段变化时推）。
  void _pushPlayerState(PlayerState state) {
    final sig = _hostDispatcher.stateSignature(state);
    if (sig == _lastPushedStateSig) return;
    _lastPushedStateSig = sig;
    final contentWindow = _iframe?.contentWindow;
    if (contentWindow == null) return;
    final msg = {
      'type': 'songloft-player-state',
      'state': _hostDispatcher.stateToJson(state),
    }.jsify();
    contentWindow.postMessage(msg, '*'.toJS);
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final brightness = MediaQuery.of(context).platformBrightness;
    final theme = resolveEffectiveTheme(themeMode, brightness);

    ref.listen<PlayerState>(playerStateProvider, (prev, next) {
      _pushPlayerState(next);
    });

    if (_lastTheme == null) {
      _lastTheme = theme;
    } else if (_lastTheme != theme) {
      _lastTheme = theme;
      _sendThemeToPlugin(theme);
    }

    return HtmlElementView(viewType: _viewType);
  }
}
