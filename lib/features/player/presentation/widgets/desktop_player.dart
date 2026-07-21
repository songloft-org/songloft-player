import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/url_helper.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/favorite_button.dart';
import '../../domain/player_state.dart';
import '../providers/player_provider.dart';
import 'desktop_full_player.dart';
import 'play_controls.dart';
import 'progress_bar.dart';
import 'audio_track_control.dart';
import 'equalizer_panel.dart';
import 'popup_controls.dart';
import 'volume_control.dart';
import '../../../dlna/presentation/widgets/cast_button.dart';

/// 桌面端底部播放器栏
class DesktopPlayer extends ConsumerWidget {
  const DesktopPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerStateProvider);
    final notifier = ref.read(playerStateProvider.notifier);
    final theme = Theme.of(context);

    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: Column(
        children: [
          // 顶部进度条（可点击）
          ClickableProgressBar(
            position: state.currentTime,
            duration: state.duration,
            onSeek: notifier.seek,
            height: 4,
          ),
          // 主内容
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // 左侧：歌曲信息
                  Expanded(flex: 3, child: _buildSongInfo(context, state)),
                  // 中间：播放控制
                  Expanded(
                    flex: 4,
                    child: _buildPlayControls(context, state, notifier),
                  ),
                  // 右侧：工具栏
                  Expanded(
                    flex: 3,
                    child: _buildToolbar(context, state, notifier),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSongInfo(BuildContext context, PlayerState state) {
    final theme = Theme.of(context);

    if (!state.hasSong) {
      return Row(
        children: [
          // 空封面
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: theme.colorScheme.surfaceContainerHighest,
            ),
            child: Icon(
              Icons.music_note_rounded,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            AppLocalizations.of(context).playerNoContent,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ],
      );
    }

    final song = state.currentSong!;
    final coverUrl = song.coverUrl;

    return Row(
      children: [
        // 可点击区域（封面+标题）
        Expanded(
          child: Semantics(
            button: true,
            label: AppLocalizations.of(context).playerOpenFullPlayer,
            child: GestureDetector(
              onTap: () => DesktopFullPlayer.show(context),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  // 封面
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: theme.colorScheme.surfaceContainerHighest,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child:
                        coverUrl != null
                            ? ExcludeSemantics(
                              child: Image.network(
                                UrlHelper.buildCoverUrl(coverUrl),
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (_, _, _) => Icon(
                                      Icons.music_note_rounded,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            )
                            : Icon(
                              Icons.music_note_rounded,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                  ),
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
                        const SizedBox(height: 4),
                        Text(
                          song.artist ??
                              AppLocalizations.of(context).playerUnknownArtist,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // 收藏按钮
        FavoriteButton(songId: song.id, songType: song.type, size: 20),
      ],
    );
  }

  Widget _buildPlayControls(
    BuildContext context,
    PlayerState state,
    PlayerNotifier notifier,
  ) {
    final theme = Theme.of(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 控制按钮
        PlayControls(
          isPlaying: state.isPlaying,
          hasPrev: state.hasPrev,
          hasNext: state.hasNext,
          isBuffering: state.isBuffering,
          onPlay: notifier.togglePlay,
          onPause: notifier.togglePlay,
          onPrev: notifier.playPrev,
          onNext: notifier.playNext,
          size: 40,
        ),
        const SizedBox(height: 4),
        // 时间显示
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              Formatters.formatDuration(state.currentTime.inSeconds.toDouble()),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              ' / ',
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
      ],
    );
  }

  Widget _buildToolbar(
    BuildContext context,
    PlayerState state,
    PlayerNotifier notifier,
  ) {
    final theme = Theme.of(context);

    final volume = ResponsiveVolumeControl(
      volume: state.volume,
      onVolumeChanged: notifier.setVolume,
    );

    // 音量之后的次要操作按钮
    final actions = <Widget>[
      // 均衡器（依赖 libmpv，Web 无 libmpv 不生效，故 Web 隐藏）
      if (!kIsWeb)
        IconButton(
          onPressed: () => showEqualizerSheet(context),
          icon: const Icon(Icons.equalizer_rounded, size: 20),
          tooltip: AppLocalizations.of(context).playerEqualizer,
          visualDensity: VisualDensity.compact,
        ),
      // 投屏
      const CastButton(iconSize: 20, visualDensity: VisualDensity.compact),
      // 音轨切换（多音频轨时显示，单轨自动隐藏）；本行兄弟均为 compact，故显式对齐
      const AudioTrackControl(visualDensity: VisualDensity.compact),
      // 睡眠定时
      _buildSleepTimerButton(context, state, notifier, theme),
      // 歌词按钮
      _buildLyricsButton(context, state, theme),
      // 播放列表
      IconButton(
        onPressed: notifier.togglePlaylistDrawer,
        icon: Icon(
          Icons.queue_music_rounded,
          size: 20,
          color: state.showPlaylistDrawer ? theme.colorScheme.primary : null,
        ),
        tooltip: AppLocalizations.of(context).playerPlaylist,
        visualDensity: VisualDensity.compact,
      ),
    ];

    // 窗口较窄（如平板布局 / 缩小的桌面窗口）时，固定尺寸的按钮会超出
    // Expanded(flex:3) 分配的宽度导致 RenderFlex 溢出。这里按可用宽度分档：
    // - 空间充足：内联音量滑块 + 全部按钮（原布局）
    // - 空间紧张：整体等比缩小并让音量退化为弹出图标，保证任意宽度都不溢出
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 300) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPlayModeButton(context, state, notifier, theme),
              Flexible(child: volume),
              ...actions,
            ],
          );
        }
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPlayModeButton(context, state, notifier, theme),
              // 无界约束下 ResponsiveVolumeControl 自动退化为弹出图标
              volume,
              ...actions,
            ],
          ),
        );
      },
    );
  }

  /// 构建播放模式按钮（使用自定义弹出层）
  Widget _buildPlayModeButton(
    BuildContext context,
    PlayerState state,
    PlayerNotifier notifier,
    ThemeData theme,
  ) {
    return PopupPlayModeControl(
      playMode: state.playMode,
      onPlayModeChanged: notifier.setPlayMode,
    );
  }

  /// 构建睡眠定时按钮（使用自定义弹出层）
  Widget _buildSleepTimerButton(
    BuildContext context,
    PlayerState state,
    PlayerNotifier notifier,
    ThemeData theme,
  ) {
    return PopupSleepTimerControl(
      status: state.sleepTimer,
      isLive: state.currentSong?.isLive ?? false,
      onSetDuration: notifier.setSleepTimerByDuration,
      onSetAfterSongs: notifier.setSleepTimerAfterSongs,
      onCancel: notifier.cancelSleepTimer,
    );
  }

  /// 构建歌词按钮
  Widget _buildLyricsButton(
    BuildContext context,
    PlayerState state,
    ThemeData theme,
  ) {
    final hasSong = state.hasSong;
    final hasLyrics = hasSong && state.currentSong?.lyricUrl != null;

    return IconButton(
      onPressed: hasSong ? () => DesktopFullPlayer.show(context) : null,
      icon: Icon(
        Icons.lyrics_rounded,
        size: 20,
        color:
            hasLyrics
                ? null
                : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
      ),
      tooltip: AppLocalizations.of(context).playerLyrics,
      visualDensity: VisualDensity.compact,
    );
  }
}
