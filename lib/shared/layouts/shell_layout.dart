import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/responsive.dart';
import '../../core/utils/platform_utils.dart';
import '../../features/home/presentation/plugin_tab_page.dart';
import '../../features/jsplugin/presentation/providers/jsplugin_provider.dart';
import '../../features/library/presentation/providers/favorite_provider.dart';
import '../../features/player/domain/player_state.dart';
import '../../features/player/presentation/providers/player_provider.dart';
import '../../features/player/presentation/widgets/desktop_player.dart';
import '../../features/player/presentation/widgets/mini_player.dart';
import '../../features/player/presentation/widgets/player_shortcut_scope.dart';
import '../../features/player/presentation/widgets/playlist_drawer.dart';
import '../../features/player/presentation/widgets/tv_player.dart';
import '../../features/settings/data/settings_api.dart';
import '../../features/settings/presentation/providers/settings_provider.dart';
import '../../l10n/app_localizations.dart';
import '../utils/responsive_snackbar.dart';
import 'active_destinations.dart';
import 'adaptive_scaffold.dart';

/// ShellRoute 的布局组件
/// 整合 AdaptiveScaffold 和路由导航
class ShellLayout extends ConsumerStatefulWidget {
  final Widget child;

  const ShellLayout({super.key, required this.child});

  @override
  ConsumerState<ShellLayout> createState() => _ShellLayoutState();
}

class _ShellLayoutState extends ConsumerState<ShellLayout> {
  final _visitedPluginTabs = <String>{};

  /// 每个保活插件 Tab 的稳定 GlobalKey（按 entryPath 缓存）。
  /// Web 端插件页嵌在 HtmlElementView 的 iframe 里，其 platform view 的 viewId
  /// 一旦销毁重建，浏览器会重新拉取整张插件入口页（表现为页面反复重载/抖动，
  /// songloft-org/songloft#278）。用 GlobalKey 作 key 可让承载 iframe 的
  /// PluginTabPage 元素在 Stack 内被重排/换父时**被移动而非 dispose+重建**，
  /// 从而保住 viewId、不触发 iframe 重载。
  final _pluginTabKeys = <String, GlobalKey>{};

  GlobalKey _pluginTabKey(String entryPath) =>
      _pluginTabKeys.putIfAbsent(entryPath, GlobalKey.new);

  /// 稳定 GlobalKey：跨响应式断点重建布局时，让 body 子树（含插件 WebView 原生表面）
  /// 被 reparent 而非 dispose+重建，避免拖窗跨断点导致 InAppWebView reload
  /// （songloft-org/songloft-player#20）
  final _bodyKey = GlobalKey();

  /// 根据当前路由路径计算导航索引
  int _getCurrentIndex(String location, ActiveDestinations activeDest) {
    // 精确匹配
    if (activeDest.routeToIndex.containsKey(location)) {
      return activeDest.routeToIndex[location]!;
    }

    // 前缀匹配（处理子路由情况，如 /playlists/:id）
    if (location.startsWith('/playlists')) {
      final idx = activeDest.routeToIndex['/playlists'];
      if (idx != null) return idx;
    }

    // 曲库子路由（如 /library/categories...）归属「曲库」
    if (location.startsWith('/library')) {
      final idx = activeDest.routeToIndex['/library'];
      if (idx != null) return idx;
    }

    // 插件 Tab 前缀匹配（/plugin-tab/xxx）
    if (location.startsWith('/plugin-tab/')) {
      final idx = activeDest.routeToIndex[location];
      if (idx != null) return idx;
    }

    // 设置子路由匹配（如 /settings/tab-config）
    if (location.startsWith('/settings')) {
      final idx = activeDest.routeToIndex['/settings'];
      if (idx != null) return idx;
    }

    // 默认返回首页索引
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final tabConfigAsync = ref.watch(tabConfigProvider);
    final tabConfig = tabConfigAsync.value ?? TabConfig.defaultConfig();
    final plugins = ref.watch(jsPluginsProvider).value ?? [];
    final activeDest = ActiveDestinations.compute(
      tabConfig,
      plugins,
      AppLocalizations.of(context),
    );

    // 获取当前路由位置
    final location = GoRouterState.of(context).uri.path;
    final currentIndex = _getCurrentIndex(location, activeDest);

    // 确保收藏系统被初始化（FavoriteNotifier.build 中自动调度）
    ref.watch(favoriteProvider);

    // 监听播放器错误状态
    ref.listen<PlayerState>(playerStateProvider, (prev, next) {
      if (next.errorMessage != null &&
          next.errorMessage != prev?.errorMessage) {
        ResponsiveSnackBar.showError(context, message: next.errorMessage!);
      }
    });

    // 监听播放队列侧边栏状态（仅桌面/平板端有效）
    final showPlaylistDrawer = ref.watch(
      playerStateProvider.select((s) => s.showPlaylistDrawer),
    );

    final isPluginTab = location.startsWith('/plugin-tab/');
    final isSettings = location.startsWith('/settings');

    final currentEntryPath =
        isPluginTab ? location.replaceFirst('/plugin-tab/', '') : null;

    // 构建 body：
    // - Web + 移动端（Android/iOS）：插件 tab 通过 Offstage 持久化保活。
    //   Web 避免 CanvasKit 反复销毁/重建 iframe 触发渲染器段错误（见 32d8924）
    //   及 iframe 反复重载抖动（#278）；移动端避免 flutter_inappwebview 的 WebView
    //   被销毁后再次打开时黑屏/底部导航栏消失（songloft-org/songloft#273 后续）。
    //   plugin_tab_page_native 本就按 isActive 做保活设计（切走 clearFocus）。
    // - 桌面端（Windows/macOS/Linux）：只渲染当前激活的插件 tab，切走即销毁。
    //   其 flutter_inappwebview 是独立原生表面（尤其 Windows WebView2），Offstage
    //   无法隐藏，保活会在切到其他页面后残留灰块（songloft-org/songloft#246）。
    final isNativeDesktop =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux);
    Widget body;
    if (!isNativeDesktop) {
      // 追踪已访问的插件 tab（首次访问时创建，之后通过 Offstage 保持存活）
      if (currentEntryPath != null) {
        _visitedPluginTabs.add(currentEntryPath);
      }

      // 清理已从配置中移除的插件 tab。**只按 tabConfig（稳定）裁剪，不依赖会
      // 短暂加载/刷新的 jsPluginsProvider**——否则 plugins 快照瞬时为空
      // （首次加载 / 依赖重启 / 插件更新触发 ref.invalidate）会误删激活 tab，
      // 下一帧再加回，导致 PluginTabPage 元素 dispose+重建、iframe 反复重载
      // （页面抖动，songloft-org/songloft#278）。且仅在 tabConfig 确有数据时
      // 裁剪，避免 config 加载中回落到默认空配置误删。
      if (tabConfigAsync.hasValue) {
        final configuredPaths =
            tabConfig.pluginTabs
                .map((pt) => pt.entryPath)
                .where((p) => p.isNotEmpty)
                .toSet();
        // 保留仍在配置内的、以及当前正在浏览的插件（防御 config 与路由的竞态）
        if (currentEntryPath != null) configuredPaths.add(currentEntryPath);
        _visitedPluginTabs.retainAll(configuredPaths);
        _pluginTabKeys.removeWhere((ep, _) => !_visitedPluginTabs.contains(ep));
      }

      if (_visitedPluginTabs.isEmpty) {
        body = widget.child;
      } else {
        body = Stack(
          children: [
            Offstage(offstage: isPluginTab, child: widget.child),
            for (final ep in _visitedPluginTabs)
              Offstage(
                // GlobalKey 挂在 PluginTabPage 上，使其在 Stack 内被重排/换父时
                // 被移动而非重建，保住底层 WebView / iframe 的 platform view
                // viewId 不被销毁重建（Web 避免 iframe 反复重载抖动 #278，
                // 移动端避免 WebView 重建黑屏 #273 后续）。
                key: ValueKey('plugin-offstage-$ep'),
                offstage: currentEntryPath != ep,
                child: PluginTabPage(
                  key: _pluginTabKey(ep),
                  entryPath: ep,
                  isActive: currentEntryPath == ep,
                ),
              ),
          ],
        );
      }
    } else if (currentEntryPath != null) {
      // 插件 Tab 仍只渲染当前激活的 WebView（切走即销毁，规避 #246 的 WebView2
      // 残留灰块）。但必须用 Offstage 保活 widget.child（shell 子 Navigator）：
      // 若把它整个丢弃，子 Navigator 不挂载、其 NavigatorState 为 null，
      // go_router 的 _findCurrentNavigators() 会在 `navigatorKey.currentState!`
      // 强制解包处抛异常，导致系统返回键分发中断、插件 Tab 页退不出
      // （songloft-org/songloft#273）。此处 child 渲染的是 /plugin-tab 的
      // SizedBox.shrink 占位，不含 WebView，Offstage 保活无灰块副作用。
      body = Stack(
        children: [
          Offstage(offstage: true, child: widget.child),
          PluginTabPage(
            key: ValueKey('plugin-active-$currentEntryPath'),
            entryPath: currentEntryPath,
            isActive: true,
          ),
        ],
      );
    } else {
      body = widget.child;
    }

    final scaffold = AdaptiveScaffold(
      body: KeyedSubtree(key: _bodyKey, child: body),
      currentIndex: currentIndex,
      destinations: activeDest.destinations,
      onDestinationSelected: (index) {
        if (index >= 0 && index < activeDest.indexToRoute.length) {
          context.go(activeDest.indexToRoute[index]);
        }
      },
      bottomPlayer:
          (isPluginTab || isSettings) ? null : _buildBottomPlayer(context),
      playlistDrawer: showPlaylistDrawer ? const PlaylistDrawer() : null,
    );

    // 桌面端挂载全局播放快捷键监听；移动/Web/TV 不包裹（零开销、零行为变化）
    if (!PlatformUtils.isDesktop) return scaffold;
    return PlayerShortcutScope(child: scaffold);
  }

  /// 根据屏幕类型构建底部播放器
  Widget _buildBottomPlayer(BuildContext context) {
    final screenType = context.screenType;
    switch (screenType) {
      case ScreenType.mobile:
        return const MiniPlayer();
      case ScreenType.tablet:
      case ScreenType.desktop:
        return const DesktopPlayer();
      case ScreenType.auto_:
        // 车机模式使用 MiniPlayer（屏幕纵向空间有限）
        return const MiniPlayer();
      case ScreenType.tv:
        // 仅在 Android TV 等真正的 TV 平台使用 TvMiniPlayer
        // 桌面/Web 大屏使用 DesktopPlayer 以保留完整工具栏
        if (defaultTargetPlatform == TargetPlatform.android) {
          return const TvMiniPlayer();
        }
        return const DesktopPlayer();
    }
  }
}
