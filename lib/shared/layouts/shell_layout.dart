import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/responsive.dart';
import '../../features/home/presentation/plugin_tab_page.dart';
import '../../features/library/presentation/providers/favorite_provider.dart';
import '../../features/player/domain/player_state.dart';
import '../../features/player/presentation/providers/player_provider.dart';
import '../../features/player/presentation/widgets/desktop_player.dart';
import '../../features/player/presentation/widgets/mini_player.dart';
import '../../features/player/presentation/widgets/playlist_drawer.dart';
import '../../features/player/presentation/widgets/tv_player.dart';
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
    final activeDest = ref.watch(activeDestinationsProvider);

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

    // 追踪已访问的插件 tab（首次访问时创建，之后通过 Offstage 保持存活）
    final currentEntryPath =
        isPluginTab ? location.replaceFirst('/plugin-tab/', '') : null;
    if (currentEntryPath != null) {
      _visitedPluginTabs.add(currentEntryPath);
    }

    // 清理已移除/禁用的插件
    final validPaths = activeDest.indexToRoute
        .where((r) => r.startsWith('/plugin-tab/'))
        .map((r) => r.replaceFirst('/plugin-tab/', ''))
        .toSet();
    _visitedPluginTabs.retainAll(validPaths);

    // 构建 body：插件 tab 通过 Offstage 持久化，避免 iframe 反复销毁/重建
    Widget body;
    if (_visitedPluginTabs.isEmpty) {
      body = widget.child;
    } else {
      body = Stack(
        children: [
          Offstage(
            offstage: isPluginTab,
            child: widget.child,
          ),
          for (final ep in _visitedPluginTabs)
            Offstage(
              offstage: currentEntryPath != ep,
              child: PluginTabPage(
                key: ValueKey('plugin-keep-$ep'),
                entryPath: ep,
              ),
            ),
        ],
      );
    }

    return AdaptiveScaffold(
      body: body,
      currentIndex: currentIndex,
      destinations: activeDest.destinations,
      onDestinationSelected: (index) {
        if (index >= 0 && index < activeDest.indexToRoute.length) {
          context.go(activeDest.indexToRoute[index]);
        }
      },
      bottomPlayer: (isPluginTab || isSettings) ? null : _buildBottomPlayer(context),
      playlistDrawer: showPlaylistDrawer ? const PlaylistDrawer() : null,
    );
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
