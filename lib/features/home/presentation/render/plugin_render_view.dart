import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/utils/window_visibility.dart';
import '../../../../l10n/app_localizations.dart';
import 'plugin_render_controller.dart';
import 'plugin_render_surface_webf.dart';
import 'plugin_render_surface_webview.dart';

/// 插件页渲染层的**引擎无关**外壳（songloft-org/songloft#341）。
///
/// 负责所有与「用哪个引擎渲染」无关的事：加载态、20s 超时、错误 UI 与重试、
/// 窗口可见性处理。真正的渲染面由 `PluginRenderSurface*` 提供。
///
/// 抽出它同时消掉了 `plugin_tab_page_native` 与 `plugin_webview_page_native`
/// 里两份逐字重复的超时 / 错误视图 / token 注入 / 重建计数逻辑。
///
/// 刻意是纯 `StatefulWidget`、不读任何 provider：用哪个引擎由宿主解析后经
/// [engine] 传入（见 `pluginRenderEngineForProvider`）。需要 provider 的是各引擎
/// 的渲染面自己（如 WebF 面要读播放器状态），它们各自持有 `ref`。
class PluginRenderView extends StatefulWidget {
  /// 已经拼好的完整插件页 URL（含 theme / access_token / embed）。
  final String url;

  /// 当前生效主题（`light` / `dark`）。
  final String theme;

  /// 用哪个引擎渲染。由宿主按插件声明解析后传入
  /// （`pluginRenderEngineForProvider`），本 widget 不自己去读任何偏好。
  ///
  /// 宿主必须在**引擎确定之后**才挂载本 widget，否则会先起一个引擎再换成另一个，
  /// 整页加载两次。
  final PluginRenderEngine engine;

  /// 见 `PluginRenderSurfaceWebView.useHybridComposition`。
  final bool useHybridComposition;

  /// 渲染面就绪时回调，宿主用它做返回键处理与焦点释放。
  ///
  /// 注意会被多次调用：重试或窗口重新可见都会重建渲染面，宿主应覆盖旧引用。
  final void Function(PluginRenderController controller) onControllerReady;

  const PluginRenderView({
    super.key,
    required this.url,
    required this.theme,
    required this.engine,
    required this.onControllerReady,
    this.useHybridComposition = true,
  });

  @override
  State<PluginRenderView> createState() => _PluginRenderViewState();
}

class _PluginRenderViewState extends State<PluginRenderView>
    with WidgetsBindingObserver {
  static const Duration _pageLoadTimeout = Duration(seconds: 20);

  Timer? _loadTimer;
  bool _isLoading = true;
  String? _errorMessage;

  /// 应用是否处于可见状态（`AppLifecycleState.hidden` 时为 false）。
  bool _appVisible = true;

  /// 窗口是否可见（最小化 / 隐藏到托盘时为 false）。
  ///
  /// 仅 Windows 会翻转（`WindowTrayManager` 只在 Windows setup），其余平台恒 true。
  bool _hwndVisible = windowVisibleNotifier.value;

  /// 重建计数：作为渲染面的 `ValueKey`，递增即重建整个渲染面。
  ///
  /// 不用 `controller.reload()`：Windows 上 WebView 实例创建失败时
  /// `onWebViewCreated` 不触发、controller 恒为 null，reload 是 no-op，
  /// 必须换 key 重建才能重新走环境创建（songloft-org/songloft#271）。
  int _reloadSeq = 0;

  /// 是否需要为独立原生表面做「移出 widget 树以销毁」的处理（#293）。
  bool get _needsHwndUnmount => widget.engine.usesPlatformView;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    windowVisibleNotifier.addListener(_onWindowVisibilityChanged);
    _startLoadTimer();
  }

  @override
  void didUpdateWidget(covariant PluginRenderView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.engine != widget.engine) {
      // 换引擎等于换渲染面：复位加载态，否则会卡在上一引擎遗留的错误/完成态。
      // （正常不该发生 —— 宿主等引擎确定后才挂载本 widget；这里只是自愈兜底。）
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      _startLoadTimer();
    }
  }

  @override
  void dispose() {
    _loadTimer?.cancel();
    windowVisibleNotifier.removeListener(_onWindowVisibilityChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final visible = state != AppLifecycleState.hidden;
    if (_appVisible != visible) {
      setState(() => _appVisible = visible);
    }
  }

  /// 窗口可见性变化（Windows 最小化 / 托盘）。
  ///
  /// 不可见时下一帧把渲染面移出 widget 树以销毁 WebView2 HWND（仅原生 platform
  /// view 才需要，见 [_needsHwndUnmount]）；恢复可见时换 key 重建并重新计时。
  ///
  /// 重建动作刻意收窄到 `_needsHwndUnmount`：WebF 是普通 Flutter RenderObject，
  /// 最小化时从未被移出树（`surfaceMounted` 恒 true），恢复时若也 `_reloadSeq++`
  /// 会连带销毁进程内缓存的 controller，整页重载、丢失页面 JS 状态（列表滚动位置、
  /// 筛选项等回到第一屏）—— songloft-org/songloft#438。原生 WebView2 才真的在
  /// 最小化时销毁过 HWND，恢复时必须换 key 重建以重新创建原生表面。
  void _onWindowVisibilityChanged() {
    final visible = windowVisibleNotifier.value;
    if (!mounted || _hwndVisible == visible) return;
    setState(() {
      _hwndVisible = visible;
      if (visible && _needsHwndUnmount) {
        _isLoading = true;
        _errorMessage = null;
        _reloadSeq++;
        _startLoadTimer();
      }
    });
  }

  void _startLoadTimer() {
    _loadTimer?.cancel();
    _loadTimer = Timer(_pageLoadTimeout, () {
      if (!mounted || !_isLoading) return;
      setState(() {
        _isLoading = false;
        _errorMessage = AppLocalizations.of(context).homePluginLoadTimeout;
      });
    });
  }

  void _onLoadStart() {
    if (!mounted) return;
    _startLoadTimer();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
  }

  void _onLoadStop() {
    _loadTimer?.cancel();
    _loadTimer = null;
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _errorMessage = null;
    });
  }

  void _onError(String message) {
    _loadTimer?.cancel();
    _loadTimer = null;
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _errorMessage = message;
    });
  }

  void _retry() {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
      _reloadSeq++;
    });
    _startLoadTimer();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // 刻意不叫 mounted：那会遮蔽 State.mounted。
    final surfaceMounted = !_needsHwndUnmount || _hwndVisible;

    return Stack(
      children: [
        if (_errorMessage != null)
          _buildErrorView(colorScheme)
        else if (surfaceMounted)
          // SizedBox.expand 把渲染面收成 tight 约束：Stack 默认给非定位子节点
          // loose 约束（min 0 / max=栈尺寸），WebF 在 loose 宽度下按内容收缩，
          // 插件页里 flex:1 的布局会解析出无界宽度，触发 WebF flex 的
          // `Infinity or NaN toInt` 崩溃（miot 设置页因含 <select>/<input> 内嵌
          // Flutter widget 最先炸）。收成 tight 后 WebF 根拿到确定宽度即可。
          // songloft-org/songloft#341
          Offstage(
            offstage: !_appVisible,
            child: SizedBox.expand(child: _buildSurface()),
          )
        else
          // 窗口不可见：不挂载渲染面，销毁原生 HWND（#293）。
          const SizedBox.expand(),
        if (_isLoading && surfaceMounted)
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  Widget _buildSurface() {
    switch (widget.engine) {
      case PluginRenderEngine.webView:
        return PluginRenderSurfaceWebView(
          key: ValueKey(_reloadSeq),
          url: widget.url,
          theme: widget.theme,
          useHybridComposition: widget.useHybridComposition,
          onLoadStart: _onLoadStart,
          onLoadStop: _onLoadStop,
          onError: _onError,
          onControllerReady: widget.onControllerReady,
        );
      case PluginRenderEngine.webF:
        return PluginRenderSurfaceWebF(
          key: ValueKey(_reloadSeq),
          url: widget.url,
          theme: widget.theme,
          onLoadStart: _onLoadStart,
          onLoadStop: _onLoadStop,
          onError: _onError,
          onControllerReady: widget.onControllerReady,
        );
    }
  }

  Widget _buildErrorView(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: colorScheme.error),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).homePluginLoadFailed,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage ??
                  AppLocalizations.of(context).homePluginUnknownError,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _retry,
            icon: const Icon(Icons.refresh),
            label: Text(AppLocalizations.of(context).commonRetry),
          ),
        ],
      ),
    );
  }
}
