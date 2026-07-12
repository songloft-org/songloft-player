import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/url_helper.dart';
import '../../../../shared/models/song.dart';
import '../../../../shared/utils/responsive_snackbar.dart';
import '../providers/player_provider.dart';

/// 桌面端播放队列侧边栏
/// 作为布局的一部分常驻显示在主内容区右侧
class PlaylistDrawer extends ConsumerWidget {
  const PlaylistDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerStateProvider);
    final notifier = ref.read(playerStateProvider.notifier);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          left: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: Column(
        children: [
          // 标题栏
          _buildHeader(context, state, notifier, theme, colorScheme),
          const Divider(height: 1),
          // 歌曲列表
          Expanded(
            child:
                state.playlist.isEmpty
                    ? _buildEmptyState(context, colorScheme, theme)
                    : _buildQueueList(context, ref, state, notifier),
          ),
        ],
      ),
    );
  }

  /// 构建标题栏
  Widget _buildHeader(
    BuildContext context,
    dynamic state,
    PlayerNotifier notifier,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // 标题和歌曲数量
          Text(
            '播放队列',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${state.playlist.length}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const Spacer(),
          // 清空按钮
          if (state.playlist.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              tooltip: '清空播放列表',
              visualDensity: VisualDensity.compact,
              onPressed: () => _showClearConfirmation(context, notifier),
            ),
          // 关闭按钮
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            tooltip: '关闭',
            visualDensity: VisualDensity.compact,
            onPressed: notifier.closePlaylistDrawer,
          ),
        ],
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(
    BuildContext context,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.queue_music_rounded,
            size: 48,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            '播放队列为空',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '添加歌曲开始播放',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建播放队列列表
  Widget _buildQueueList(
    BuildContext context,
    WidgetRef ref,
    dynamic state,
    PlayerNotifier notifier,
  ) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: state.playlist.length,
      onReorder: notifier.reorderPlaylist,
      buildDefaultDragHandles: false,
      itemBuilder: (context, index) {
        final song = state.playlist[index];
        final isCurrentSong = index == state.currentIndex;
        final isPlaying = isCurrentSong && state.isPlaying;

        return _DrawerSongItem(
          key: ValueKey('drawer_${song.id}_${song.type}_$index'),
          song: song,
          index: index,
          isCurrentSong: isCurrentSong,
          isPlaying: isPlaying,
          onTap: () => notifier.playPlaylist(state.playlist, startIndex: index),
          onRemove: () => _removeSong(context, notifier, index, song),
        );
      },
    );
  }

  /// 移除歌曲
  void _removeSong(
    BuildContext context,
    PlayerNotifier notifier,
    int index,
    Song song,
  ) {
    notifier.removeFromPlaylist(index);
    ResponsiveSnackBar.show(
      context,
      message: '已移除「${song.title}」',
      duration: const Duration(seconds: 2),
    );
  }

  /// 显示清空确认对话框
  void _showClearConfirmation(BuildContext context, PlayerNotifier notifier) {
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('清空播放队列'),
            content: const Text('确定要清空播放队列吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  notifier.clearPlaylist();
                  Navigator.pop(dialogContext);
                },
                child: const Text('清空'),
              ),
            ],
          ),
    );
  }
}

/// 侧边栏歌曲项
class _DrawerSongItem extends StatelessWidget {
  final Song song;
  final int index;
  final bool isCurrentSong;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _DrawerSongItem({
    super.key,
    required this.song,
    required this.index,
    required this.isCurrentSong,
    required this.isPlaying,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final coverUrl = song.coverUrl;

    return Dismissible(
      key: ValueKey('dismiss_drawer_${song.id}_${song.type}_$index'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        color: colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: Icon(
          Icons.delete_rounded,
          color: colorScheme.onErrorContainer,
          size: 18,
        ),
      ),
      child: Material(
        color:
            isCurrentSong
                ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                // 拖拽手柄
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.drag_handle_rounded,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                // 封面
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: colorScheme.surfaceContainerHighest,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      if (coverUrl != null && coverUrl.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: UrlHelper.buildCoverUrl(coverUrl),
                          fit: BoxFit.cover,
                          width: 36,
                          height: 36,
                          placeholder:
                              (_, _) => _buildCoverPlaceholder(colorScheme),
                          errorWidget:
                              (_, _, _) => _buildCoverPlaceholder(colorScheme),
                        )
                      else
                        _buildCoverPlaceholder(colorScheme),
                      // 正在播放指示器
                      if (isPlaying)
                        Container(
                          color: Colors.black54,
                          child: Center(
                            child: Icon(
                              Icons.equalizer_rounded,
                              size: 18,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 歌曲信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        song.title,
                        style: textTheme.bodySmall?.copyWith(
                          fontWeight:
                              isCurrentSong
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                          color:
                              isCurrentSong
                                  ? colorScheme.primary
                                  : colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        song.artist ?? '未知艺术家',
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // 时长
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    Formatters.formatDuration(song.duration),
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                // 删除按钮
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close_rounded),
                  iconSize: 16,
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    foregroundColor: colorScheme.onSurfaceVariant,
                    minimumSize: const Size(28, 28),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoverPlaceholder(ColorScheme colorScheme) {
    return Center(
      child: Icon(
        Icons.music_note_rounded,
        size: 18,
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
      ),
    );
  }
}
