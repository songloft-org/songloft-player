import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/tv_theme.dart';
import '../../../core/utils/url_helper.dart';
import '../../../shared/widgets/tv_focusable.dart';
import '../../player/presentation/providers/player_provider.dart';
import '../../playlist/domain/playlist.dart';
import '../../playlist/presentation/providers/playlist_provider.dart';

/// TV 首页
///
/// 专为大屏 TV 设计的首页布局，支持 D-Pad 焦点导航。
/// 包含：Hero 区域 + 快捷导航 + 歌单网格。
class TvHomePage extends ConsumerWidget {
  const TvHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(playlistListProvider(null));
    final normalPlaylistsAsync = ref.watch(playlistListProvider('normal'));
    final radioPlaylistsAsync = ref.watch(playlistListProvider('radio'));

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: playlistsAsync.when(
          data:
              (state) => _TvHomeContent(
                playlists: state.items,
                normalCount: normalPlaylistsAsync.value?.totalCount ?? 0,
                radioCount: radioPlaylistsAsync.value?.totalCount ?? 0,
              ),
          loading: () => const _TvLoadingContent(),
          error:
              (error, _) => _TvErrorContent(
                error: error.toString(),
                onRetry: () => ref.invalidate(playlistListProvider(null)),
              ),
        ),
      ),
    );
  }
}

/// TV 首页主内容
class _TvHomeContent extends ConsumerWidget {
  final List<Playlist> playlists;
  final int normalCount;
  final int radioCount;

  const _TvHomeContent({
    required this.playlists,
    required this.normalCount,
    required this.radioCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final currentPlaylistId = ref.watch(sourcePlaylistIdProvider);
    final isPlaying = ref.watch(isPlayingProvider);

    final normalPlaylists = playlists.where((p) => p.type == 'normal').toList();
    final radioPlaylists = playlists.where((p) => p.type == 'radio').toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1920),
        child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TvTheme.contentPadding,
        vertical: TvTheme.spacingLarge,
      ),
      child: CustomScrollView(
        slivers: [
          // 顶部问候 + 时间
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: TvTheme.spacingLarge),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Songloft',
                        style: textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getGreeting(),
                        style: textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // 统计信息
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: TvTheme.spacingLarge,
                      vertical: TvTheme.spacingMedium,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(TvTheme.cardRadius),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.queue_music_rounded,
                          color: colorScheme.primary,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '$normalCount 歌单',
                          style: TvTheme.bodyStyle(context),
                        ),
                        const SizedBox(width: TvTheme.spacingLarge),
                        Icon(
                          Icons.radio_rounded,
                          color: colorScheme.secondary,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '$radioCount 电台',
                          style: TvTheme.bodyStyle(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 快捷导航
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: TvTheme.spacingLarge),
              child: SizedBox(
                height: 120,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _TvQuickNavCard(
                      title: '本地音乐',
                      icon: Icons.library_music_rounded,
                      autofocus: playlists.isEmpty,
                      onSelect: () => context.go(AppRoutes.library),
                    ),
                    const SizedBox(width: TvTheme.spacingMedium),
                    _TvQuickNavCard(
                      title: '播放列表',
                      icon: Icons.queue_music_rounded,
                      onSelect: () => context.go(AppRoutes.playlists),
                    ),
                    const SizedBox(width: TvTheme.spacingMedium),
                    _TvQuickNavCard(
                      title: '设置',
                      icon: Icons.settings_rounded,
                      onSelect: () => context.go(AppRoutes.settings),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 我的歌单区域
          if (normalPlaylists.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(
                  bottom: TvTheme.spacingMedium,
                ),
                child: Text(
                  '我的歌单',
                  style: TvTheme.titleStyle(context),
                ),
              ),
            ),
            SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: TvTheme.gridColumns,
                mainAxisSpacing: TvTheme.gridSpacing,
                crossAxisSpacing: TvTheme.gridSpacing,
                childAspectRatio: 0.85,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final playlist = normalPlaylists[index];
                  final isCurrent = playlist.id == currentPlaylistId;
                  return _TvPlaylistCard(
                    playlist: playlist,
                    isCurrent: isCurrent,
                    isPlaying: isPlaying && isCurrent,
                    autofocus: playlists.isNotEmpty && index == 0,
                    onSelect: () => context.push('/playlists/${playlist.id}'),
                  );
                },
                childCount: normalPlaylists.length > 8
                    ? 8
                    : normalPlaylists.length,
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: TvTheme.spacingXLarge),
            ),
          ],

          // 电台歌单区域
          if (radioPlaylists.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(
                  bottom: TvTheme.spacingMedium,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.radio_rounded,
                      color: colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '我的电台',
                      style: TvTheme.titleStyle(context),
                    ),
                  ],
                ),
              ),
            ),
            SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: TvTheme.gridColumns,
                mainAxisSpacing: TvTheme.gridSpacing,
                crossAxisSpacing: TvTheme.gridSpacing,
                childAspectRatio: 0.85,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final playlist = radioPlaylists[index];
                  final isCurrent = playlist.id == currentPlaylistId;
                  return _TvPlaylistCard(
                    playlist: playlist,
                    isCurrent: isCurrent,
                    isPlaying: isPlaying && isCurrent,
                    onSelect: () => context.push('/playlists/${playlist.id}'),
                  );
                },
                childCount: radioPlaylists.length > 8
                    ? 8
                    : radioPlaylists.length,
              ),
            ),
          ],

          // 空状态
          if (playlists.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.library_music_outlined,
                      size: 80,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                    const SizedBox(height: TvTheme.spacingLarge),
                    Text(
                      '暂无歌单',
                      style: TvTheme.titleStyle(context),
                    ),
                    const SizedBox(height: TvTheme.spacingSmall),
                    Text(
                      '使用快捷导航浏览本地音乐',
                      style: TvTheme.captionStyle(context),
                    ),
                  ],
                ),
              ),
            ),

          // 底部间距
          const SliverToBoxAdapter(
            child: SizedBox(height: TvTheme.spacingXLarge),
          ),
        ],
      ),
    ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) {
      return '夜深了，听点音乐吧';
    } else if (hour < 12) {
      return '早上好';
    } else if (hour < 14) {
      return '中午好';
    } else if (hour < 18) {
      return '下午好';
    } else {
      return '晚上好';
    }
  }
}

/// TV 快捷导航卡片
class _TvQuickNavCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback? onSelect;
  final bool autofocus;

  const _TvQuickNavCard({
    required this.title,
    required this.icon,
    this.onSelect,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TvFocusable(
      autofocus: autofocus,
      onSelect: onSelect,
      borderRadius: TvTheme.cardRadius,
      child: Container(
        width: 200,
        height: 120,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(TvTheme.cardRadius),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              style: TvTheme.bodyStyle(context).copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// TV 歌单卡片
class _TvPlaylistCard extends StatelessWidget {
  final Playlist playlist;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback? onSelect;
  final bool autofocus;

  const _TvPlaylistCard({
    required this.playlist,
    this.isCurrent = false,
    this.isPlaying = false,
    this.onSelect,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return TvFocusable(
      autofocus: autofocus,
      onSelect: onSelect,
      borderRadius: TvTheme.cardRadius,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(TvTheme.cardRadius),
          border:
              isCurrent
                  ? Border.all(color: colorScheme.primary, width: 3)
                  : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildCover(colorScheme),
                  if (isPlaying)
                    Container(
                      color: Colors.black54,
                      child: Center(
                        child: Icon(
                          Icons.equalizer_rounded,
                          size: 48,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // 信息
            Padding(
              padding: const EdgeInsets.all(TvTheme.spacingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.name,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color:
                          isCurrent
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${playlist.songCount} 首歌曲',
                    style: TvTheme.captionStyle(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCover(ColorScheme colorScheme) {
    final coverUrl = playlist.coverImageUrl;
    if (coverUrl != null && coverUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: UrlHelper.buildCoverUrl(coverUrl),
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildPlaceholder(colorScheme),
        errorWidget: (context, url, error) => _buildPlaceholder(colorScheme),
      );
    }
    return _buildPlaceholder(colorScheme);
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          playlist.type == 'radio'
              ? Icons.radio_rounded
              : Icons.queue_music_rounded,
          size: 56,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

/// TV 加载中
class _TvLoadingContent extends StatelessWidget {
  const _TvLoadingContent();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}

/// TV 错误内容
class _TvErrorContent extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _TvErrorContent({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: colorScheme.error,
          ),
          const SizedBox(height: TvTheme.spacingLarge),
          Text(
            '加载失败',
            style: TvTheme.titleStyle(context),
          ),
          const SizedBox(height: TvTheme.spacingSmall),
          Text(
            error,
            style: TvTheme.captionStyle(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: TvTheme.spacingLarge),
          TvButton(
            label: '重试',
            icon: Icons.refresh,
            autofocus: true,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
