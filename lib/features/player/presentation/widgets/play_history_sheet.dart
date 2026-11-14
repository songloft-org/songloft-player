import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/utils/responsive_snackbar.dart';
import '../../../../shared/widgets/browse_card.dart' show BrowseCardAction;
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../../shared/widgets/song_tile.dart';
import '../../domain/play_history_entry.dart';
import '../../domain/playback_context.dart';
import '../providers/play_history_provider.dart';
import '../providers/player_provider.dart';
import 'playlist_resume_card.dart';

/// 播放历史面板：展示某个播放上下文（歌单 / 歌手 / 专辑 / 其余分面维度）内
/// 最近播放过的歌曲，点任一首从该首接着往下播。
class PlayHistorySheet extends ConsumerWidget {
  final PlaybackContext playbackContext;
  final String title;

  const PlayHistorySheet({
    super.key,
    required this.playbackContext,
    required this.title,
  });

  static Future<void> show(
    BuildContext context, {
    required PlaybackContext playbackContext,
    required String title,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) =>
              PlayHistorySheet(playbackContext: playbackContext, title: title),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final historyAsync = ref.watch(playHistoryProvider(playbackContext));

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              _buildDragHandle(colorScheme),
              _buildHeader(context, ref, historyAsync.value ?? const []),
              if (playbackContext.playlistId != null)
                PlaylistResumeCard(
                  id: playbackContext.playlistId!,
                  audiobook: false,
                ),
              const Divider(height: 1),
              Expanded(
                child: historyAsync.when(
                  loading:
                      () => const Center(child: CircularProgressIndicator()),
                  error: (_, _) => _buildError(context, ref),
                  data:
                      (entries) =>
                          entries.isEmpty
                              ? _buildEmpty(context)
                              : _buildList(
                                context,
                                ref,
                                entries,
                                scrollController,
                              ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

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

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    List<PlayHistoryEntry> entries,
  ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (entries.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: l10n.playHistoryClear,
              onPressed: () => _confirmClear(context, ref),
            ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: l10n.playerClose,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_rounded,
              size: 56,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(l10n.playHistoryEmpty, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(
              l10n.playHistoryEmptyHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(l10n.commonLoadFailed),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed:
                () => ref.invalidate(playHistoryProvider(playbackContext)),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l10n.commonRetry),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<PlayHistoryEntry> entries,
    ScrollController scrollController,
  ) {
    final currentSongId = ref.watch(
      playerStateProvider.select((s) => s.currentSong?.id),
    );
    final l10n = AppLocalizations.of(context);

    return ListView.builder(
      controller: scrollController,
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return SongTile(
          key: ValueKey('history_${entry.song.id}_${entry.song.type}'),
          song: entry.song,
          isCurrentSong: currentSongId == entry.song.id,
          subtitleSuffix: _formatPlayedAt(entry.playedAt),
          onTap: () => _playFrom(context, ref, entry),
          menuActions: [
            BrowseCardAction(
              value: 'delete_entry',
              icon: Icons.delete_outline_rounded,
              label: l10n.playHistoryDeleteEntry,
              destructive: true,
              onTap: () => _deleteEntry(context, ref, entry),
            ),
          ],
        );
      },
    );
  }

  /// 播放时间用绝对时间显示（相对时间需要一堆带复数的 l10n key，收益不匹配）。
  String _formatPlayedAt(DateTime playedAt) {
    return DateFormat('MM-dd HH:mm').format(playedAt.toLocal());
  }

  /// 从该条历史起播：先以这一首出声，队列随后在后台补齐成环形旋转。
  void _playFrom(BuildContext context, WidgetRef ref, PlayHistoryEntry entry) {
    ref
        .read(playerStateProvider.notifier)
        .playFromHistory(context: playbackContext, song: entry.song);
    Navigator.of(context).pop();
  }

  Future<void> _deleteEntry(
    BuildContext context,
    WidgetRef ref,
    PlayHistoryEntry entry,
  ) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref
          .read(playHistoryApiProvider)
          .deleteEntry(playbackContext, entry.song.id);
      // 面板可能在请求途中被关掉：此时 ref 已失效，刷新已无意义，
      // 继续调用会抛异常并被下面的 catch 误报成「删除失败」。
      if (!context.mounted) return;
      ref.invalidate(playHistoryProvider(playbackContext));
    } catch (e) {
      if (context.mounted) {
        ResponsiveSnackBar.showError(
          context,
          message: l10n.playHistoryOperationFailed,
        );
      }
    }
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await ConfirmDialog.show(
      context,
      title: l10n.playHistoryClear,
      content: l10n.playHistoryClearConfirm,
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) return;

    try {
      await ref.read(playHistoryApiProvider).clearHistory(playbackContext);
      if (!context.mounted) return;
      ref.invalidate(playHistoryProvider(playbackContext));
      ResponsiveSnackBar.showSuccess(context, message: l10n.playHistoryCleared);
    } catch (e) {
      if (context.mounted) {
        ResponsiveSnackBar.showError(
          context,
          message: l10n.playHistoryOperationFailed,
        );
      }
    }
  }
}
