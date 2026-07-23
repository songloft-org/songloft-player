import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/utils/color_extraction.dart';
import '../../../../core/utils/url_helper.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/favorite_button.dart';
import '../../domain/player_state.dart';
import '../providers/player_provider.dart';
import '../queue_page.dart';
import '../providers/audio_track_provider.dart';
import 'audio_track_control.dart';
import 'lyrics_view.dart';
import 'play_controls.dart';
import 'popup_controls.dart';
import '../../../dlna/presentation/widgets/cast_button.dart';
import 'progress_bar.dart';
import 'equalizer_panel.dart';
import '../utils/full_player_route.dart';
import '../utils/player_song_actions.dart';
import 'video_player_surface.dart';
import 'video_stage.dart';
import 'vinyl_ring.dart';
import 'volume_control.dart';

/// 移动端全屏播放器
class MobilePlayer extends ConsumerStatefulWidget {
  /// 初始展示的 PageView 页（0: 封面，1: 歌词）。
  /// 「打开后自动进入歌词」会传 1 直接落在歌词页。
  final int initialPage;

  const MobilePlayer({super.key, this.initialPage = 0});

  @override
  ConsumerState<MobilePlayer> createState() => _MobilePlayerState();
}

class _MobilePlayerState extends ConsumerState<MobilePlayer>
    with SingleTickerProviderStateMixin, FullPlayerAutoExit {
  /// PageView 控制器
  late final PageController _pageController;

  /// 当前页面索引（0: 封面, 1: 歌词）
  late int _currentPage;

  /// 唱片环旋转动画控制器
  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: widget.initialPage);
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 28),
    );
    // Web 冷加载 /player 但无队列可恢复时，短暂等待异步恢复；仍无歌曲则退出。
    scheduleFullPlayerAutoExit();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerStateProvider);
    final notifier = ref.read(playerStateProvider.notifier);
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    // 播放列表被清空时，自动关闭全屏播放器并返回上一页
    // 同时控制封面脉冲动画
    ref.listen<PlayerState>(playerStateProvider, (previous, next) {
      if (previous?.hasSong == true && !next.hasSong) {
        debugPrint('[Player] MobilePlayer: playlist cleared, closing player');
        dismissFullPlayer(context, ref);
      }
      // 异步恢复出歌曲后，取消冷加载兜底退出
      if (next.hasSong) cancelFullPlayerAutoExit();
      // 控制唱片环旋转动画
      if (next.isPlaying && !_rotationController.isAnimating) {
        _rotationController.repeat();
      } else if (!next.isPlaying && _rotationController.isAnimating) {
        _rotationController.stop();
      }
    });

    // 初始播放状态动画（listen 只响应变化，初始状态需要手动处理）
    if (state.isPlaying && !_rotationController.isAnimating) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && state.isPlaying && !_rotationController.isAnimating) {
          _rotationController.repeat();
        }
      });
    }

    if (!state.hasSong) {
      debugPrint('[Player] MobilePlayer: no song, hiding');
      return const SizedBox.shrink();
    }

    final song = state.currentSong!;

    // 视频/MV:切到视频播放器界面(画面铺满 + 叠加控制层 + 字幕),
    // 不走下面的封面/歌词音乐布局。
    if (song.isVideo) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: VideoPlayerSurface(song: song),
      );
    }

    final coverUrl = song.coverUrl;

    final paletteAsync = ref.watch(playerBackgroundPaletteProvider(song));
    final palette = paletteAsync.value;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          // 背景模糊封面 / 无封面时的动态渐变
          if (coverUrl != null)
            Positioned.fill(
              child: ExcludeSemantics(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
                  child: Image.network(
                    UrlHelper.buildCoverUrl(coverUrl),
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, _, _) => Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                        ),
                  ),
                ),
              ),
            )
          else if (palette != null)
            Positioned.fill(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topLeft,
                    radius: 1.5,
                    colors: [
                      palette.dominantColor.withValues(alpha: 0.6),
                      palette.darkMutedColor ?? palette.dominantColor,
                    ],
                  ),
                ),
              ),
            ),
          // 径向环境光晕
          if (palette != null)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.6, -0.5),
                      radius: 1.2,
                      colors: [
                        (palette.vibrantColor ?? palette.dominantColor)
                            .withValues(alpha: 0.22),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // 背景遮罩 - 动态取色渐变
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    (palette?.darkMutedColor ?? theme.colorScheme.surface)
                        .withValues(alpha: 0.7),
                    theme.colorScheme.surface.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
          ),
          // 顶部渐变遮罩 — 保证顶部按钮在任何封面色下可见
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 100,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.35),
                      Colors.black.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 主内容
          SafeArea(
            child: Column(
              children: [
                // 顶部工具栏
                _buildTopBar(context, notifier, state),
                const SizedBox(height: 16),
                // 封面/歌词 PageView
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      Expanded(
                        child: PageView(
                          controller: _pageController,
                          onPageChanged: (index) {
                            setState(() {
                              _currentPage = index;
                            });
                          },
                          children: [
                            // 页面1：视频歌曲渲染画面（支持的平台），否则封面（带唱片环旋转）
                            Center(
                              child: VideoStage(
                                song: song,
                                width: size.width * 0.75,
                                height: size.width * 0.75,
                                fallback: VinylRing(
                                  rotationAnimation: _rotationController,
                                  child: _buildCover(
                                    context,
                                    coverUrl,
                                    size.width * 0.75,
                                    palette: palette,
                                  ),
                                ),
                              ),
                            ),
                            // 页面2：歌词
                            LyricsView(
                              currentPosition: state.currentTime,
                              onSeek: notifier.seek,
                              song: song,
                              editable: true,
                            ),
                          ],
                        ),
                      ),
                      // 页面指示器
                      const SizedBox(height: 12),
                      _buildPageIndicator(theme),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // 歌曲信息
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                  ),
                  child: Column(
                    children: [
                      Text(
                        song.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        song.artist ??
                            AppLocalizations.of(context).playerUnknownArtist,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // 进度条
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: PlayerProgressBar(
                    position: state.currentTime,
                    duration: state.duration,
                    onSeek: notifier.seek,
                  ),
                ),
                const SizedBox(height: 16),
                // 主控制行（播放模式 + 上一首/播放/下一首 + 收藏）
                _buildControlsRow(context, state, notifier),
                const SizedBox(height: 20),
                // 工具行（投屏 + 音量 + 队列 + 更多）
                _buildToolBar(context, state, notifier),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建页面指示器（小圆点）
  Widget _buildPageIndicator(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(2, (index) {
        final isActive = index == _currentPage;
        return Container(
          width: isActive ? 8 : 6,
          height: isActive ? 8 : 6,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                isActive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
        );
      }),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    PlayerNotifier notifier,
    PlayerState state,
  ) {
    final song = state.currentSong;
    const topBarColor = Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 返回按钮
          IconButton(
            onPressed: () => dismissFullPlayer(context, ref),
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            iconSize: 32,
            color: topBarColor,
            tooltip: AppLocalizations.of(context).playerCollapse,
          ),
          // 歌曲信息（专辑名）
          if (song?.album != null && song!.album!.isNotEmpty)
            Expanded(
              child: Text(
                song.album!,
                style: TextStyle(
                  color: topBarColor.withValues(alpha: 0.9),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            )
          else
            const Spacer(),
          // 更多操作
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_horiz_rounded,
              color: state.sleepTimer != null
                  ? Theme.of(context).colorScheme.primary
                  : topBarColor,
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
                    isLive: state.currentSong?.isLive ?? false,
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
                      title: Text(AppLocalizations.of(context).playerEqualizer),
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
                      title: Text(AppLocalizations.of(context).playerAudioTrack),
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
                      hasTimer
                          ? AppLocalizations.of(context).playerSleepTimerOn
                          : AppLocalizations.of(context).playerSleepTimer,
                    ),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(
                      Icons.delete_outline,
                      color: colorScheme.error,
                    ),
                    title: Text(
                      AppLocalizations.of(context).playerDeleteCurrentSong,
                      style: TextStyle(color: colorScheme.error),
                    ),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ];
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCover(
    BuildContext context,
    String? coverUrl,
    double size, {
    CoverPalette? palette,
  }) {
    final theme = Theme.of(context);

    final glowColor = palette?.vibrantColor ?? palette?.dominantColor;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: AppRadius.xlAll,
        color: theme.colorScheme.surfaceContainerHighest,
        boxShadow: glowColor != null
            ? AppEffects.primaryGlow(glowColor)
            : AppEffects.softGlow(theme.colorScheme.onSurface),
      ),
      clipBehavior: Clip.antiAlias,
      child:
          coverUrl != null
              ? ExcludeSemantics(
                child: Image.network(
                  UrlHelper.buildCoverUrl(coverUrl),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _buildPlaceholder(theme, size),
                ),
              )
              : _buildPlaceholder(theme, size),
    );
  }

  Widget _buildPlaceholder(ThemeData theme, double size) {
    return Icon(
      Icons.music_note_rounded,
      size: size * 0.4,
      color: theme.colorScheme.onSurfaceVariant,
    );
  }

  /// Spotify 风格控制行：[播放模式] [上一首] [播放/暂停] [下一首] [收藏]
  Widget _buildControlsRow(
    BuildContext context,
    PlayerState state,
    PlayerNotifier notifier,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 播放模式
          SizedBox(
            width: 48,
            height: 48,
            child: PopupPlayModeControl(
              playMode: state.playMode,
              onPlayModeChanged: notifier.setPlayMode,
            ),
          ),
          const SizedBox(width: 8),
          // 主控制按钮
          PlayControls(
            isPlaying: state.isPlaying,
            hasPrev: state.hasPrev,
            hasNext: state.hasNext,
            isBuffering: state.showBufferingIndicator,
            onPlay: notifier.togglePlay,
            onPause: notifier.togglePlay,
            onPrev: notifier.playPrev,
            onNext: notifier.playNext,
            size: 76,
            showGlow: true,
            useRoundedRect: true,
          ),
          const SizedBox(width: 8),
          // 收藏
          SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: FavoriteButton(
                songId: state.currentSong!.id,
                songType: state.currentSong!.type,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Spotify 风格工具行：[投屏] [音量] [队列]（Web 无投屏时仅 [音量] [队列]）
  Widget _buildToolBar(
    BuildContext context,
    PlayerState state,
    PlayerNotifier notifier,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (!kIsWeb)
            const CastButton(iconSize: 20),
          PopupVolumeControl(
            volume: state.volume,
            onVolumeChanged: notifier.setVolume,
          ),
          IconButton(
            onPressed: () => QueueBottomSheet.show(context),
            icon: const Icon(Icons.queue_music_rounded, size: 20),
            tooltip: AppLocalizations.of(context).playerQueueTitle,
          ),
        ],
      ),
    );
  }
}
