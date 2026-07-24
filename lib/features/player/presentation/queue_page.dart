import '../../../shared/widgets/network_cover_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/url_helper.dart';
import '../../../core/utils/web_image_tuning.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/song.dart';
import '../../../shared/utils/responsive_snackbar.dart';
import '../domain/player_state.dart';
import 'providers/player_provider.dart';
import 'widgets/queue_auto_scroll.dart';

/// 播放队列底部弹窗
/// 以浮层形式展示当前播放队列中的所有歌曲
class QueueBottomSheet extends ConsumerStatefulWidget {
  const QueueBottomSheet({super.key});

  /// 显示播放队列底部弹窗
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const QueueBottomSheet(),
    );
  }

  @override
  ConsumerState<QueueBottomSheet> createState() => _QueueBottomSheetState();
}

class _QueueBottomSheetState extends ConsumerState<QueueBottomSheet>
    with QueueAutoScrollMixin {
  /// 队列项固定高度：封面 48 + 上下 padding 各 8 = 64。
  @override
  double get queueItemExtent => 64;

  /// DraggableScrollableSheet 提供的滚动控制器（切歌跟随时复用）。
  ScrollController? _sheetController;

  /// 打开弹窗后是否已完成初次定位（仅定位一次）。
  bool _didInitialJump = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerStateProvider);
    final notifier = ref.read(playerStateProvider.notifier);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 播放列表变空时（逐个删除到最后一首），自动关闭队列弹窗
    ref.listen<PlayerState>(playerStateProvider, (previous, next) {
      if (previous != null &&
          previous.playlist.isNotEmpty &&
          next.playlist.isEmpty) {
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      }
    });

    // 方案 B：自动切歌时，仅当当前项滚出可视区才平滑跟随
    ref.listen(playerStateProvider.select((s) => s.currentIndex), (_, next) {
      final controller = _sheetController;
      if (controller != null) followQueueIfOffscreen(controller, next);
    });

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        _sheetController = scrollController;
        // 首次构建后定位到当前播放项（仅一次）
        if (!_didInitialJump) {
          _didInitialJump = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            jumpQueueToCurrent(
              scrollController,
              ref.read(playerStateProvider).currentIndex,
            );
          });
        }
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // 拖拽指示条
              _buildDragHandle(colorScheme),
              // 标题栏
              _buildHeader(context, state, notifier, theme, colorScheme),
              const Divider(height: 1),
              // 歌曲列表
              Expanded(
                child:
                    state.playlist.isEmpty
                        ? _buildEmptyState(context, colorScheme, theme)
                        : _buildQueueList(
                          context,
                          ref,
                          state,
                          notifier,
                          scrollController,
                        ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建拖拽指示条
  Widget _buildDragHandle(ColorScheme colorScheme) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12, bottom: 8),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(2),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          const SizedBox(width: 8),
          // 标题和歌曲数量
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.of(context).playerQueueTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${state.playlist.length}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          // 清空按钮
          if (state.playlist.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: AppLocalizations.of(context).playerClearPlaylist,
              onPressed: () => _showClearConfirmation(context, notifier),
            ),
          // 关闭按钮
          IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: AppLocalizations.of(context).playerClose,
            onPressed: () => Navigator.of(context).pop(),
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
            size: 64,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).playerQueueEmpty,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).playerQueueEmptyHint,
            style: theme.textTheme.bodyMedium?.copyWith(
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
    ScrollController scrollController,
  ) {
    return ReorderableListView.builder(
      scrollController: scrollController,
      // Web 端收紧离屏预解码范围，降低队列封面 GPU 纹理累积（原生端为 null 保持默认）。
      scrollCacheExtent: webListCacheExtent,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      itemCount: state.playlist.length,
      onReorderItem: notifier.moveInPlaylist,
      buildDefaultDragHandles: false,
      itemBuilder: (context, index) {
        final song = state.playlist[index];
        final isCurrentSong = index == state.currentIndex;
        final isPlaying = isCurrentSong && state.isPlaying;

        return _QueueSongItem(
          key: ValueKey('${song.id}_${song.type}_$index'),
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
      message: AppLocalizations.of(context).playerRemovedSong(song.title),
      duration: const Duration(seconds: 2),
    );
  }

  /// 显示清空确认对话框
  void _showClearConfirmation(BuildContext context, PlayerNotifier notifier) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(l10n.playerClearQueueTitle),
            content: Text(l10n.playerClearQueueConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () {
                  notifier.clearPlaylist();
                  Navigator.pop(dialogContext); // 关闭确认对话框，队列弹窗由 ref.listen 自动关闭
                },
                child: Text(l10n.playerClear),
              ),
            ],
          ),
    );
  }
}

/// 播放队列歌曲项
class _QueueSongItem extends StatelessWidget {
  final Song song;
  final int index;
  final bool isCurrentSong;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _QueueSongItem({
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
      key: ValueKey('dismiss_${song.id}_${song.type}_$index'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        color: colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete_rounded, color: colorScheme.onErrorContainer),
      ),
      child: Material(
        color:
            isCurrentSong
                ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                // 拖拽手柄
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.drag_handle_rounded,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                // 封面
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: colorScheme.surfaceContainerHighest,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      if (coverUrl != null)
                        ExcludeSemantics(
                          child: NetworkCoverImage(
                            imageUrl: UrlHelper.buildCoverUrl(coverUrl),
                            fit: BoxFit.cover,
                            width: 48,
                            height: 48,
                            // 48px 封面无需按默认 400px 解码：Web 端收紧到显示尺寸，
                            // 大幅降低整队列的 GPU 纹理体积（原生端保持 400 不变）。
                            decodeWidth: smallCoverDecodeWidth(
                              48,
                              MediaQuery.of(context).devicePixelRatio,
                            ),
                            placeholder:
                                (_, _) => _buildCoverPlaceholder(colorScheme),
                            errorWidget:
                                (_, _, _) => _buildCoverPlaceholder(colorScheme),
                          ),
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
                              size: 24,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // 歌曲信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        song.title,
                        style: textTheme.bodyMedium?.copyWith(
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
                      const SizedBox(height: 4),
                      Text(
                        song.artist ??
                            AppLocalizations.of(context).playerUnknownArtist,
                        style: textTheme.bodySmall?.copyWith(
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
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    Formatters.formatDuration(song.duration),
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                // 删除按钮
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close_rounded),
                  iconSize: 20,
                  tooltip: AppLocalizations.of(context).playerRemoveFromQueue,
                  style: IconButton.styleFrom(
                    foregroundColor: colorScheme.onSurfaceVariant,
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
        size: 24,
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
      ),
    );
  }
}
