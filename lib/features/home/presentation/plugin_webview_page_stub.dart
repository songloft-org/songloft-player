import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web/web.dart' as web;

import '../../../core/a11y/web_semantics_controller.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../l10n/app_localizations.dart';
import '../../player/domain/player_state.dart';
import '../../player/presentation/providers/player_provider.dart';
import '../../settings/presentation/providers/settings_provider.dart';
import 'plugin_host_dispatch.dart';
import 'plugin_iframe_diagnostics.dart';
import 'plugin_theme_utils.dart';

/// JS `Object.is` —— 用于精确比较两个 JS 对象引用（判断消息是否来自本 iframe）。
@JS('Object.is')
external bool _objectIs(JSAny? a, JSAny? b);

/// 插件 WebView 页面（Web 平台实现）
/// 使用 iframe 在应用内内嵌插件页面，体验与原生 WebView 一致（不再跳浏览器新标签）。
/// 通过 postMessage 双向桥接：主题下发（宿主→iframe）+ 客户端 SDK 调用（iframe→宿主）。
///
/// 此文件不引入 flutter_inappwebview，确保 Web 构建不包含该包。
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

class _PluginWebViewPageState extends ConsumerState<PluginWebViewPage> {
  static final _registeredTypes = <String>{};
  static final _activeStates = <String, _PluginWebViewPageState>{};

  late final String _viewType;
  late final String _stateKey;
  web.HTMLIFrameElement? _iframe;
  String? _lastTheme;

  // 客户端 SDK 桥接（iframe ↔ 宿主）
  StreamSubscription<web.MessageEvent>? _msgSub;
  PluginHostDispatcher? _dispatcher;
  String? _lastPushedStateSig;

  PluginHostDispatcher get _hostDispatcher =>
      _dispatcher ??= PluginHostDispatcher(ref, platformName: 'web');

  /// 在传入的裸 url 上追加 theme + access_token（不带 embed，插件保留自身工具栏）。
  String _buildPluginUrl(String theme) {
    final token = SecureStorageService.cachedAccessToken ?? '';
    final uri = Uri.parse(widget.pluginUrl);
    final query = Map<String, String>.from(uri.queryParameters)
      ..['theme'] = theme;
    if (token.isNotEmpty) query['access_token'] = token;
    return uri.replace(queryParameters: query).toString();
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
    _stateKey = widget.pluginUrl;
    _viewType = 'plugin-webview-${widget.pluginUrl.hashCode}';
    _activeStates[_stateKey] = this;

    // 全屏插件 iframe 页展示期间暂停常驻语义树，避免残留语义节点遮挡 iframe
    // （songloft-org/songloft#295）。此路由为独立全屏路由，随页面挂载/销毁精确对应
    // 展示/离开。非 Web 平台为 no-op。
    WebSemanticsController.instance.suspendForPlugin();

    // 监听来自本 iframe 的客户端 SDK 调用（songloft-host-call）。
    _msgSub = web.window.onMessage.listen(_onWindowMessage);

    if (!_registeredTypes.contains(_viewType)) {
      _registeredTypes.add(_viewType);
      final stateKey = _stateKey;
      ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
        final state = _activeStates[stateKey]!;
        final theme = state._lastTheme ?? 'light';
        final iframe = web.HTMLIFrameElement()
          ..src = state._buildPluginUrl(theme)
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%';
        state._iframe = iframe;
        // #278 抖动诊断（仅 flutter.web_debug_console=true 时生效，生产零副作用）
        attachPluginIframeDiagnostics(
          iframe,
          'webview:${widget.pluginUrl.hashCode}',
          viewId,
        );
        return iframe;
      });
    }
  }

  @override
  void dispose() {
    if (_activeStates[_stateKey] == this) {
      _activeStates.remove(_stateKey);
    }
    _msgSub?.cancel();
    _iframe?.src = 'about:blank';
    _iframe = null;
    // 离开全屏插件页：恢复常驻语义树。
    WebSemanticsController.instance.resume();
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

  /// 在浏览器新标签打开（逃生入口，对齐原生的「在浏览器中打开」）。
  void _openInNewTab() {
    final theme = _lastTheme ?? 'light';
    launchUrl(
      Uri.parse(_buildPluginUrl(theme)),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pluginName),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: l10n.homePluginOpenInBrowser,
            onPressed: _openInNewTab,
          ),
        ],
      ),
      body: HtmlElementView(viewType: _viewType),
    );
  }
}
