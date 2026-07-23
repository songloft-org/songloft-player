import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/utils/url_helper.dart';
import '../../../../l10n/app_localizations.dart';

import '../providers/player_provider.dart';
import '../../../dlna/presentation/providers/dlna_provider.dart';
import '../utils/full_player_route.dart';
import 'play_controls.dart';
import 'progress_bar.dart';

/// 移动端迷你播放器（底部小条）
class MiniPlayer extends ConsumerWidget {
  final VoidCallback? onTap; // 点击展开全屏

  const MiniPlayer({super.key, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerStateProvider);
    final notifier = ref.read(playerStateProvider.notifier);
    final theme = Theme.of(context);

    // 无歌曲时不显示
    if (!state.hasSong) {
      debugPrint('[Player] MiniPlayer: no song, hiding');
      return const SizedBox.shrink();
    }

    final song = state.currentSong!;

    // 固定高度: 进度条 2px + 主体 64px = 66px
    return SizedBox(
      height: 66,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 迷你进度条（高度精确控制为 2px）
          SizedBox(
            height: 2,
            child: PlayerProgressBar(
              position: state.currentTime,
              duration: state.duration,
              onSeek: notifier.seek,
              mini: true,
            ),
          ),
          // 主体内容（高度 64px）
          Material(
            color: theme.colorScheme.surface,
            elevation: 2,
            child: Semantics(
            label: AppLocalizations.of(context).playerExpandPlayer,
            button: true,
            child: InkWell(
              onTap:
                  onTap ??
                  () {
                    debugPrint(
                      '[Player] MiniPlayer tapped, opening full player',
                    );
                    openFullPlayer(context);
                  },
              child: SizedBox(
                height: 64,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      // 封面
                      _buildCover(context, song.coverUrl),
                      const SizedBox(width: 12),
                      // 标题和艺术家
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                if (ref.watch(dlnaStateProvider.select((s) => s.isCasting)))
                                  Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: Icon(
                                      Icons.cast_connected,
                                      size: 12,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                Expanded(
                                  child: Text(
                                    song.artist ??
                                        AppLocalizations.of(
                                          context,
                                        ).playerUnknownArtist,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // 播放/暂停按钮
                      CompactPlayButton(
                        isPlaying: state.isPlaying,
                        isBuffering: state.showBufferingIndicator,
                        onPlay: notifier.togglePlay,
                        onPause: notifier.togglePlay,
                        size: 44,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCover(BuildContext context, String? coverUrl) {
    final theme = Theme.of(context);

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: AppRadius.mdAll,
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      clipBehavior: Clip.antiAlias,
      child:
          coverUrl != null && coverUrl.isNotEmpty
              ? ExcludeSemantics(
                child: Image.network(
                  UrlHelper.buildCoverUrl(coverUrl),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _buildPlaceholder(theme),
                ),
              )
              : _buildPlaceholder(theme),
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Icon(
      Icons.music_note_rounded,
      size: 24,
      color: theme.colorScheme.onSurfaceVariant,
    );
  }
}
