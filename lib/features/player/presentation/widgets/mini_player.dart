import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/responsive.dart';
import '../../../../core/utils/url_helper.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/scrolling_text.dart';

import '../../domain/mini_player_controls.dart';
import '../../domain/player_state.dart';
import '../providers/mini_player_controls_provider.dart';
import '../providers/player_provider.dart';
import '../../../dlna/presentation/providers/dlna_provider.dart';
import '../utils/full_player_route.dart';
import 'play_controls.dart';
import 'popup_controls.dart';
import 'progress_bar.dart';

/// 播放模式按钮所需的最小屏幕宽度。低于此值时即使偏好选了 prevNextMode 也降级成
/// prevNext：四个按钮约占 148dp，标题列在更窄的屏上只剩不到 120dp，已无可读性。
const double _kPlayModeMinWidth = 340;

/// 移动端迷你播放器（底部小条）
class MiniPlayer extends ConsumerWidget {
  final VoidCallback? onTap; // 点击展开全屏

  const MiniPlayer({super.key, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerStateProvider);
    final notifier = ref.read(playerStateProvider.notifier);
    final controls = ref.watch(miniPlayerControlsProvider);
    final theme = Theme.of(context);

    // 无歌曲时不显示
    if (!state.hasSong) {
      debugPrint('[Player] MiniPlayer: no song, hiding');
      return const SizedBox.shrink();
    }

    final song = state.currentSong!;
    final ext = theme.extension<SongloftThemeExtension>();
    final useCapsule = ext?.navigationStyle == 'capsule';

    if (useCapsule) {
      return _buildCapsule(context, ref, theme, ext, song, state, notifier);
    }

    // Standard mode: 2px progress + 64px body = 66px
    return SizedBox(
      height: 66,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 2,
            child: PlayerProgressBar(
              position: state.currentTime,
              duration: state.duration,
              onSeek: notifier.seek,
              mini: true,
            ),
          ),
          Material(
            color: ext?.glassFill ?? theme.colorScheme.surface,
            elevation: 0,
            child: Semantics(
              label: AppLocalizations.of(context).playerExpandPlayer,
              button: true,
              child: InkWell(
                onTap: onTap ?? () {
                  debugPrint('[Player] MiniPlayer tapped, opening full player');
                  openFullPlayer(context);
                },
                child: SizedBox(
                  height: 64,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        _buildCover(context, song.coverUrl),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ScrollingText(
                                text: song.title,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  if (ref.watch(dlnaStateProvider.select((s) => s.isCasting)))
                                    Padding(
                                      padding: const EdgeInsets.only(right: 4),
                                      child: Icon(Icons.cast_connected, size: 12, color: theme.colorScheme.primary),
                                    ),
                                  Expanded(
                                    child: Text(
                                      song.artist ?? AppLocalizations.of(context).playerUnknownArtist,
                                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        _buildActions(context, state, notifier, controls),
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

  /// Lynx 风格胶囊迷你播放器：pill 全圆角 + 3px 进度条 + 48px 行 + 圆形播放按钮
  Widget _buildCapsule(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    SongloftThemeExtension? ext,
    dynamic song,
    PlayerState state,
    PlayerNotifier notifier,
  ) {
    const capsuleHeight = 51.0; // 3px progress + 48px row
    const rowHeight = 48.0;
    final radius = BorderRadius.circular(capsuleHeight / 2);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Container(
        height: capsuleHeight,
        decoration: BoxDecoration(
          color: ext?.glassFill ?? theme.colorScheme.surfaceContainer,
          borderRadius: radius,
          border: Border.all(
            color: ext?.glassBorder ?? theme.colorScheme.outlineVariant,
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap ?? () => openFullPlayer(context),
            child: Column(
              children: [
                // 3px 进度条
                SizedBox(
                  height: 3,
                  child: PlayerProgressBar(
                    position: state.currentTime,
                    duration: state.duration,
                    onSeek: notifier.seek,
                    mini: true,
                  ),
                ),
                // 48px 内容行
                SizedBox(
                  height: rowHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        // 36px 封面
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: theme.colorScheme.surfaceContainerHighest,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: song.coverUrl != null && (song.coverUrl as String).isNotEmpty
                              ? Image.network(
                                  UrlHelper.buildCoverUrl(song.coverUrl, width: 108),
                                  fit: BoxFit.cover,
                                  cacheWidth: 108,
                                  errorBuilder: (_, _, _) => Icon(
                                    Icons.music_note_rounded,
                                    size: 18,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                )
                              : Icon(
                                  Icons.music_note_rounded,
                                  size: 18,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                        ),
                        const SizedBox(width: 12),
                        // 标题 + 艺术家
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                song.title as String,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (song.artist != null) ...[
                                const SizedBox(height: 1),
                                Text(
                                  song.artist as String,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 圆形播放按钮（primary 填充）
                        GestureDetector(
                          onTap: notifier.togglePlay,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.colorScheme.primary,
                            ),
                            child: Icon(
                              state.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 20,
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 右侧控制按钮区（songloft-org/songloft-player#25）。
  ///
  /// 保持单行 64px 主体不变，靠紧凑命中框（36x40，而非 IconButton 默认的 48）从标题列
  /// 借最少的宽度：三键约 116dp、四键约 148dp。标题在唯一的 Expanded 里，固定宽度总和
  /// 远小于视口，不会 RenderFlex 溢出，只会更早省略。
  Widget _buildActions(
    BuildContext context,
    PlayerState state,
    PlayerNotifier notifier,
    MiniPlayerControls controls,
  ) {
    final playButton = CompactPlayButton(
      isPlaying: state.isPlaying,
      isBuffering: state.showBufferingIndicator,
      onPlay: notifier.togglePlay,
      onPause: notifier.togglePlay,
      size: 44,
    );

    if (!controls.hasPrevNext) return playButton;

    final l10n = AppLocalizations.of(context);
    final showPlayMode =
        controls.hasPlayMode && context.screenWidth >= _kPlayModeMinWidth;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showPlayMode)
          PopupPlayModeControl(
            playMode: state.playMode,
            onPlayModeChanged: notifier.setPlayMode,
          ),
        _buildSkipButton(
          context,
          icon: Icons.skip_previous_rounded,
          tooltip: l10n.playerPrevious,
          onPressed: state.hasPrev ? notifier.playPrev : null,
        ),
        playButton,
        _buildSkipButton(
          context,
          icon: Icons.skip_next_rounded,
          tooltip: l10n.playerNext,
          onPressed: state.hasNext ? notifier.playNext : null,
        ),
      ],
    );
  }

  Widget _buildSkipButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    final theme = Theme.of(context);

    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 36, height: 40),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        foregroundColor: theme.colorScheme.onSurface,
        disabledForegroundColor: theme.colorScheme.onSurface.withValues(
          alpha: 0.38,
        ),
      ),
    );
  }

  Widget _buildCover(BuildContext context, String? coverUrl) {
    final theme = Theme.of(context);
    // 48px 显示尺寸，按 3x DPR 给 144px 缩略图。弱网/NAS 拥堵时全尺寸封面（3~4MB）
    // 下载会阻塞主线程触发 ANR（songloft-org/songloft-player#39）。
    const decodeWidth = 144;

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
                  UrlHelper.buildCoverUrl(coverUrl, width: decodeWidth),
                  fit: BoxFit.cover,
                  cacheWidth: decodeWidth,
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
