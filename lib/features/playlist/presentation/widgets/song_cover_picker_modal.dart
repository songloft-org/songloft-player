import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/url_helper.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/models/song.dart';
import '../providers/playlist_provider.dart';

/// 从歌单内歌曲中选择封面的弹窗组件
class SongCoverPickerModal extends ConsumerWidget {
  final int playlistId;

  const SongCoverPickerModal({super.key, required this.playlistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(playlistSongsProvider(playlistId));
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // 拖拽指示器
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withAlpha(100),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // 标题栏
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  l10n.playlistPickCoverTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: l10n.playlistClose,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // 歌曲封面网格
          Expanded(
            child: songsAsync.when(
              data: (state) {
                // 过滤有封面的歌曲
                final songsWithCover =
                    state.items.where((song) {
                      return song.coverUrl != null && song.coverUrl!.isNotEmpty;
                    }).toList();

                if (songsWithCover.isEmpty && !state.hasMore) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_not_supported_outlined,
                          size: 64,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.playlistNoCoveredSongs,
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  );
                }

                return NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.axis != Axis.vertical) {
                      return false;
                    }
                    if (notification.metrics.pixels >=
                        notification.metrics.maxScrollExtent - 200.0) {
                      ref
                          .read(playlistSongsProvider(playlistId).notifier)
                          .loadMore();
                    }
                    return false;
                  },
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.8,
                              ),
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final song = songsWithCover[index];
                            return _CoverGridItem(
                              song: song,
                              onTap: () {
                                Navigator.of(
                                  context,
                                ).pop({
                                  'songId': song.id,
                                  'coverUrl': song.coverUrl,
                                });
                              },
                            );
                          }, childCount: songsWithCover.length),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _buildLoadMoreFooter(
                          context,
                          ref,
                          state,
                          songsWithCover.isEmpty,
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (error, _) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.commonLoadFailed,
                          style: TextStyle(color: colorScheme.error),
                        ),
                      ],
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  /// 底部加载更多指示器
  Widget _buildLoadMoreFooter(
    BuildContext context,
    WidgetRef ref,
    PaginatedSongsState state,
    bool noCoverYet,
  ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (state.loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: TextButton.icon(
            onPressed:
                () =>
                    ref
                        .read(playlistSongsProvider(playlistId).notifier)
                        .loadMore(),
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(l10n.playlistLoadRetry),
          ),
        ),
      );
    }
    if (state.hasMore) {
      // 当前页全是无封面歌曲时，给一个"继续加载"提示
      if (noCoverYet) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: TextButton.icon(
              onPressed:
                  () =>
                      ref
                          .read(playlistSongsProvider(playlistId).notifier)
                          .loadMore(),
              icon: const Icon(Icons.expand_more, size: 16),
              label: Text(l10n.playlistNoCoverLoadMore),
            ),
          ),
        );
      }
      return const SizedBox(height: 8);
    }
    if (state.items.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            l10n.playlistAllLoadedSimple,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

/// 封面网格项
class _CoverGridItem extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;

  const _CoverGridItem({required this.song, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final coverUrl = song.coverUrl;

    return Semantics(
      button: true,
      label: AppLocalizations.of(context).playlistSelectThisCover,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 封面图片
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child:
                    coverUrl != null
                        ? ExcludeSemantics(
                          child: CachedNetworkImage(
                            imageUrl: UrlHelper.buildCoverUrl(coverUrl),
                            fit: BoxFit.cover,
                            placeholder:
                                (context, url) => Container(
                                  color: colorScheme.surfaceContainerHighest,
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                            errorWidget:
                                (context, url, error) => Container(
                                  color: colorScheme.surfaceContainerHighest,
                                  child: Icon(
                                    Icons.music_note,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                          ),
                        )
                        : Container(
                          color: colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.music_note,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
              ),
            ),
            const SizedBox(height: 4),
            // 歌曲标题
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// 显示歌曲封面选择弹窗的便捷方法
///
/// 返回选中的封面信息 Map，包含 'songId'(int) 和 'coverUrl'(String?)，取消返回 null
Future<Map<String, dynamic>?> showSongCoverPicker(
  BuildContext context,
  int playlistId,
) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => SongCoverPickerModal(playlistId: playlistId),
  );
}
