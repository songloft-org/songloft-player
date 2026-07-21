import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/url_helper.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/favorite_button.dart';
import '../../domain/player_state.dart';
import '../providers/player_provider.dart';
import '../utils/full_player_route.dart';
import 'audio_track_control.dart';
import 'play_controls.dart';
import 'progress_bar.dart';
import 'video_stage.dart';
import 'video_subtitle_overlay.dart';
import 'volume_control.dart';

/// 超宽屏（车机模式，isAuto）右侧常驻「正在播放」面板。
///
/// 超宽屏纵向空间稀缺、横向富余，底部播放器条会吃掉宝贵的高度，因此这里改用
/// 右侧竖排面板：封面 + 标题/艺术家 + 进度 + 控制 + 音量。内容用
/// SingleChildScrollView 包裹，保证在极扁的车机屏上也不会溢出
/// (songloft-org/songloft-player 超宽屏播放器缺失修复)。
class AutoSidePlayer extends ConsumerWidget {
  const AutoSidePlayer({super.key});

  /// 面板宽度：超宽屏横向富余，320 既容得下控件也不喧宾夺主
  static const double panelWidth = 320;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerStateProvider);
    final notifier = ref.read(playerStateProvider.notifier);
    final theme = Theme.of(context);

    return Container(
      width: panelWidth,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          left: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child:
                state.hasSong
                    ? _buildContent(context, state, notifier, theme)
                    : _buildEmpty(context, theme),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.music_note_rounded,
          size: 48,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
        ),
        const SizedBox(height: 12),
        Text(
          AppLocalizations.of(context).playerNoContent,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context,
    PlayerState state,
    PlayerNotifier notifier,
    ThemeData theme,
  ) {
    final song = state.currentSong!;
    final coverUrl = song.coverUrl;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 封面（点击打开全屏播放器：左封面右歌词）
        Semantics(
          button: true,
          label: AppLocalizations.of(context).playerOpenFullPlayer,
          child: GestureDetector(
            onTap: () => openFullPlayer(context),
            behavior: HitTestBehavior.opaque,
            child: AspectRatio(
              // 视频用 16:9,音频用方形封面
              aspectRatio: song.isVideo ? 16 / 9 : 1,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 280),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: song.isVideo
                      ? Colors.black
                      : theme.colorScheme.surfaceContainerHighest,
                ),
                clipBehavior: Clip.antiAlias,
                // 视频歌曲在支持的桌面平台渲染画面，否则回退封面/占位图；
                // 视频叠加字幕(点击封面进入全屏视频界面看完整控制层)
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    VideoStage(
                      song: song,
                      borderRadius: BorderRadius.circular(12),
                      fallback:
                          coverUrl != null && coverUrl.isNotEmpty
                              ? Image.network(
                                UrlHelper.buildCoverUrl(coverUrl),
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (_, _, _) => Icon(
                                      Icons.music_note_rounded,
                                      size: 48,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                              )
                              : Icon(
                                Icons.music_note_rounded,
                                size: 48,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                    ),
                    if (song.isVideo)
                      const Positioned(
                        left: 8,
                        right: 8,
                        bottom: 8,
                        child: IgnorePointer(
                          child: VideoSubtitleOverlay(fontSize: 14),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // 标题 + 收藏
        Row(
          children: [
            Expanded(
              child: Text(
                song.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            FavoriteButton(songId: song.id, songType: song.type, size: 22),
          ],
        ),
        const SizedBox(height: 4),
        // 艺术家
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            song.artist ?? AppLocalizations.of(context).playerUnknownArtist,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 16),
        // 进度条
        PlayerProgressBar(
          position: state.currentTime,
          duration: state.duration,
          onSeek: notifier.seek,
        ),
        const SizedBox(height: 4),
        // 时间
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              Formatters.formatDuration(state.currentTime.inSeconds.toDouble()),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              Formatters.formatDuration(state.duration.inSeconds.toDouble()),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 播放控制
        PlayControls(
          isPlaying: state.isPlaying,
          hasPrev: state.hasPrev,
          hasNext: state.hasNext,
          isBuffering: state.isBuffering,
          onPlay: notifier.togglePlay,
          onPause: notifier.togglePlay,
          onPrev: notifier.playPrev,
          onNext: notifier.playNext,
          size: 52,
        ),
        const SizedBox(height: 12),
        // 音量
        VolumeControl(
          volume: state.volume,
          onVolumeChanged: notifier.setVolume,
          sliderWidth: 160,
        ),
        // 音轨切换（多音频轨时显示，单轨自动隐藏）
        const AudioTrackControl(),
      ],
    );
  }
}
