import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/platform_utils.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/models/song.dart';
import '../../../../shared/widgets/favorite_button.dart';
import '../../../dlna/presentation/widgets/cast_button.dart';
import '../../domain/player_state.dart';
import '../providers/player_provider.dart';
import '../queue_page.dart';
import '../providers/audio_track_provider.dart';
import '../utils/player_song_actions.dart';
import 'audio_track_control.dart';
import 'equalizer_panel.dart';
import 'play_controls.dart';
import 'popup_controls.dart';
import 'progress_bar.dart';
import 'video_fullscreen_page.dart';
import 'video_stage.dart';
import 'video_subtitle_overlay.dart';
import 'volume_control.dart';

/// 视频/MV 播放器界面组合(移动端 & 桌面端复用)。
///
/// 与音乐界面(封面/唱片环 + 歌词页)不同,这里是**视频播放器**式布局:画面铺满黑底,
/// 点击画面唤出/隐藏控制层(播放中约 3.5s 无操作自动隐藏),歌词以字幕形式叠加
/// (见 [VideoSubtitleOverlay]),移动端提供横屏全屏入口。
///
/// 复用现有控制部件([PlayControls] / [PlayerProgressBar] / [PopupPlayModeControl] 等),
/// 视频画面复用 [VideoStage](media_kit / web `<video>`,与音频同源)。
class VideoPlayerSurface extends ConsumerStatefulWidget {
  const VideoPlayerSurface({
    super.key,
    required this.song,
    this.isFullscreen = false,
  });

  final Song song;

  /// 是否处于横屏全屏态(由 [VideoFullscreenPage] 托管)。影响返回/全屏按钮语义与字幕字号。
  final bool isFullscreen;

  @override
  ConsumerState<VideoPlayerSurface> createState() => _VideoPlayerSurfaceState();
}

class _VideoPlayerSurfaceState extends ConsumerState<VideoPlayerSurface> {
  bool _controlsVisible = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 3500), () {
      if (!mounted) return;
      if (ref.read(playerStateProvider).isPlaying) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _pokeControls() {
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) {
      _scheduleHide();
    } else {
      _hideTimer?.cancel();
    }
  }

  void _onBack() {
    if (!widget.isFullscreen) {
      ref.read(playerStateProvider.notifier).closeFullPlayer();
    }
    Navigator.of(context).maybePop();
  }

  void _onFullscreenToggle() {
    if (widget.isFullscreen) {
      Navigator.of(context).maybePop();
    } else {
      VideoFullscreenPage.show(context, widget.song);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerStateProvider);
    final notifier = ref.read(playerStateProvider.notifier);

    // 暂停时常驻控制层;恢复播放后重新计时隐藏。
    ref.listen<bool>(playerStateProvider.select((s) => s.isPlaying), (_, playing) {
      if (!playing) {
        _hideTimer?.cancel();
        if (!_controlsVisible) setState(() => _controlsVisible = true);
      } else {
        _scheduleHide();
      }
    });

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 视频画面铺满(BoxFit.contain,letterbox 黑底);控制器未就绪时回退黑屏。
          Positioned.fill(
            child: VideoStage(
              song: widget.song,
              borderRadius: BorderRadius.zero,
              fallback: const ColoredBox(color: Colors.black),
            ),
          ),
          // 点击空白区域切换控制层显隐(位于控制层之下,按钮优先接收点击)。
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleControls,
            ),
          ),
          // 字幕:随控制层显示上移让位,避免与底部控制条重叠。
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            left: 24,
            right: 24,
            bottom: _controlsVisible ? 140 : 40,
            child: IgnorePointer(
              child: VideoSubtitleOverlay(
                fontSize: widget.isFullscreen ? 26 : 20,
              ),
            ),
          ),
          // 控制层(顶栏 + 底部控制),隐藏时不接收指针。
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_controlsVisible,
              child: AnimatedOpacity(
                opacity: _controlsVisible ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: Listener(
                  // 控制层内任意操作重置自动隐藏计时。
                  onPointerDown: (_) => _pokeControls(),
                  child: _buildControlsOverlay(context, state, notifier),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsOverlay(
    BuildContext context,
    PlayerState state,
    PlayerNotifier notifier,
  ) {
    final base = Theme.of(context);
    // 控制层永远浮在黑底视频上,强制浅色前景保证任意主题下可读。
    final overlayTheme = base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        onSurface: Colors.white,
        onSurfaceVariant: Colors.white70,
      ),
    );

    return Theme(
      data: overlayTheme,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 顶部渐变遮罩
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 120,
            child: _ScrimGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter),
          ),
          // 底部渐变遮罩
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 200,
            child: _ScrimGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(context, state, notifier, base),
                const Spacer(),
                _buildBottomControls(context, state, notifier),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    PlayerState state,
    PlayerNotifier notifier,
    ThemeData baseTheme,
  ) {
    final l10n = AppLocalizations.of(context);
    final song = widget.song;
    final subtitleOn = ref.watch(subtitleEnabledProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: _onBack,
            icon: Icon(
              widget.isFullscreen
                  ? Icons.arrow_back_rounded
                  : Icons.keyboard_arrow_down_rounded,
            ),
            iconSize: 30,
            color: Colors.white,
            tooltip: l10n.playerCollapse,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  song.artist ?? l10n.playerUnknownArtist,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // 字幕开关
          IconButton(
            onPressed: () {
              ref.read(subtitleEnabledProvider.notifier).toggle();
              _pokeControls();
            },
            icon: Icon(
              subtitleOn ? Icons.subtitles_rounded : Icons.subtitles_off_rounded,
            ),
            color: subtitleOn ? Theme.of(context).colorScheme.primary : Colors.white,
            tooltip: subtitleOn ? l10n.playerSubtitleOff : l10n.playerSubtitleOn,
          ),
          // 全屏(仅移动端)
          if (PlatformUtils.isMobile)
            IconButton(
              onPressed: _onFullscreenToggle,
              icon: Icon(
                widget.isFullscreen
                    ? Icons.fullscreen_exit_rounded
                    : Icons.fullscreen_rounded,
              ),
              color: Colors.white,
              tooltip: widget.isFullscreen
                  ? l10n.playerExitFullscreen
                  : l10n.playerEnterFullscreen,
            ),
          // 更多(弹出菜单用回原始主题,避免继承黑底浅色前景导致菜单文字看不清)
          Theme(
            data: baseTheme,
            child: PopupMenuButton<String>(
            icon: Icon(
              Icons.more_horiz_rounded,
              color: state.sleepTimer != null
                  ? baseTheme.colorScheme.primary
                  : Colors.white,
            ),
            onSelected: (value) {
              switch (value) {
                case 'equalizer':
                  showEqualizerSheet(context);
                case 'audio_track':
                  showAudioTrackSheet(context, ref);
                case 'sleep_timer':
                  SleepTimerSheet.show(
                    context,
                    status: state.sleepTimer,
                    isLive: widget.song.isLive,
                    onSetDuration: notifier.setSleepTimerByDuration,
                    onSetAfterSongs: notifier.setSleepTimerAfterSongs,
                    onCancel: notifier.cancelSleepTimer,
                  );
                case 'delete':
                  deleteCurrentSongFromPlayer(context, ref);
              }
            },
            itemBuilder: (context) {
              final colorScheme = Theme.of(context).colorScheme;
              final hasTimer = state.sleepTimer != null;
              return [
                // 均衡器依赖 libmpv，Web 无 libmpv 不生效，故 Web 隐藏
                if (!kIsWeb)
                  PopupMenuItem(
                    value: 'equalizer',
                    child: ListTile(
                      leading: const Icon(Icons.equalizer_rounded),
                      title: Text(l10n.playerEqualizer),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                // 音轨切换：多音轨时才显示（与均衡器同为次要功能，统一收进菜单）
                if (ref.read(audioTrackProvider).hasMultiple)
                  PopupMenuItem(
                    value: 'audio_track',
                    child: ListTile(
                      leading: const Icon(Icons.multitrack_audio_rounded),
                      title: Text(l10n.playerAudioTrack),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                PopupMenuItem(
                  value: 'sleep_timer',
                  child: ListTile(
                    leading: Icon(
                      Icons.bedtime_outlined,
                      color: hasTimer ? colorScheme.primary : null,
                    ),
                    title: Text(
                      hasTimer ? l10n.playerSleepTimerOn : l10n.playerSleepTimer,
                    ),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline, color: colorScheme.error),
                    title: Text(
                      l10n.playerDeleteCurrentSong,
                      style: TextStyle(color: colorScheme.error),
                    ),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ];
            },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(
    BuildContext context,
    PlayerState state,
    PlayerNotifier notifier,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 进度条(白色轨道,在黑底上更醒目)
          PlayerProgressBar(
            position: state.currentTime,
            duration: state.duration,
            onSeek: notifier.seek,
            activeColor: Colors.white,
            inactiveColor: Colors.white24,
          ),
          const SizedBox(height: 4),
          // 主控制行
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: PopupPlayModeControl(
                  playMode: state.playMode,
                  onPlayModeChanged: notifier.setPlayMode,
                ),
              ),
              PlayControls(
                isPlaying: state.isPlaying,
                hasPrev: state.hasPrev,
                hasNext: state.hasNext,
                isBuffering: state.isBuffering,
                onPlay: notifier.togglePlay,
                onPause: notifier.togglePlay,
                onPrev: notifier.playPrev,
                onNext: notifier.playNext,
                size: 60,
                showGlow: true,
                useRoundedRect: true,
              ),
              SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: FavoriteButton(
                    songId: widget.song.id,
                    songType: widget.song.type,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // 工具行(投屏 / 音量 / 队列)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!kIsWeb) const CastButton(iconSize: 20),
              const SizedBox(width: 8),
              PopupVolumeControl(
                volume: state.volume,
                onVolumeChanged: notifier.setVolume,
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => QueueBottomSheet.show(context),
                icon: const Icon(Icons.queue_music_rounded, size: 20),
                color: Colors.white,
                tooltip: AppLocalizations.of(context).playerQueueTitle,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 顶/底部渐变遮罩,提升控制层在明亮画面上的可读性。
class _ScrimGradient extends StatelessWidget {
  const _ScrimGradient({required this.begin, required this.end});

  final Alignment begin;
  final Alignment end;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: begin,
            end: end,
            colors: [
              Colors.black.withValues(alpha: 0.6),
              Colors.black.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }
}
