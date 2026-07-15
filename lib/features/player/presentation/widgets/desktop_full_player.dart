import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/responsive.dart';
import '../../../../core/utils/color_extraction.dart';
import '../../../../core/utils/url_helper.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/favorite_button.dart';
import '../../domain/player_state.dart';
import '../providers/player_provider.dart';
import '../queue_page.dart';
import 'lyrics_view.dart';
import 'play_controls.dart';
import 'popup_controls.dart';
import 'progress_bar.dart';
import '../utils/player_song_actions.dart';
import 'vinyl_ring.dart';
import 'video_stage.dart';
import '../../../dlna/presentation/widgets/cast_button.dart';
import 'volume_control.dart';

/// Desktop/Tablet 全屏播放器（左右分栏布局）
class DesktopFullPlayer extends ConsumerStatefulWidget {
  const DesktopFullPlayer({super.key});

  /// 显示全屏播放器
  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder:
            (context, animation, secondaryAnimation) =>
                const DesktopFullPlayer(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // 从下往上滑入动画
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  ConsumerState<DesktopFullPlayer> createState() => _DesktopFullPlayerState();
}

class _DesktopFullPlayerState extends ConsumerState<DesktopFullPlayer>
    with SingleTickerProviderStateMixin {
  /// 唱片环旋转动画控制器
  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 28),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerStateProvider);
    final notifier = ref.read(playerStateProvider.notifier);
    final theme = Theme.of(context);
    final isDesktop = context.isDesktop;

    // 播放列表被清空时，自动关闭全屏播放器
    ref.listen<PlayerState>(playerStateProvider, (previous, next) {
      if (previous?.hasSong == true && !next.hasSong) {
        debugPrint(
          '[Player] DesktopFullPlayer: playlist cleared, closing player',
        );
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      }
      // 控制唱片环旋转动画
      if (next.isPlaying && !_rotationController.isAnimating) {
        _rotationController.repeat();
      } else if (!next.isPlaying && _rotationController.isAnimating) {
        _rotationController.stop();
      }
    });

    // 初始播放状态动画
    if (state.isPlaying && !_rotationController.isAnimating) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && state.isPlaying && !_rotationController.isAnimating) {
          _rotationController.repeat();
        }
      });
    }

    if (!state.hasSong) {
      debugPrint('[Player] DesktopFullPlayer: no song, hiding');
      return const SizedBox.shrink();
    }

    final song = state.currentSong!;
    final coverUrl = song.coverUrl;

    final paletteAsync = ref.watch(playerBackgroundPaletteProvider(song));
    final palette = paletteAsync.value;

    final horizontalPadding = isDesktop ? 48.0 : 24.0;
    final coverSize = isDesktop ? 300.0 : 220.0;

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
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                children: [
                  // 顶部栏
                  _buildTopBar(context, notifier),
                  const SizedBox(height: 16),
                  // 左右分栏主体
                  Expanded(
                    child: Row(
                      children: [
                        // 左侧：封面 + 歌曲信息
                        Expanded(
                          flex: 4,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              // 超宽屏又矮时（车机模式）纵向空间不足，按左栏实际可用
                              // 高度动态收缩封面：为标题+艺术家+间距预留 ~100px、
                              // 唱片环上下各 8px 预留 16px，其余留给封面，避免
                              // 固定 coverSize 撑破 Column 造成底部溢出。
                              final budget = constraints.maxHeight - 100 - 16;
                              final maxCover = budget < 140.0 ? 140.0 : budget;
                              final effectiveCover =
                                  coverSize > maxCover ? maxCover : coverSize;
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // 视频歌曲渲染画面，否则封面带唱片环旋转（视频不可用时也回退到此）
                                    VideoStage(
                                      song: song,
                                      width: effectiveCover,
                                      height: effectiveCover,
                                      fallback: VinylRing(
                                        rotationAnimation: _rotationController,
                                        child: _buildCover(
                                          context,
                                          coverUrl,
                                          effectiveCover,
                                          palette: palette,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                // 歌曲标题
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                  ),
                                  child: Text(
                                    song.title,
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // 艺术家名
                                Text(
                                  song.artist ??
                                      AppLocalizations.of(
                                        context,
                                      ).playerUnknownArtist,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        // 右侧：歌词
                        Expanded(
                          flex: 5,
                          child: LyricsView(
                            currentPosition: state.currentTime,
                            onSeek: notifier.seek,
                            song: song,
                            editable: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 进度条
                  PlayerProgressBar(
                    position: state.currentTime,
                    duration: state.duration,
                    onSeek: notifier.seek,
                  ),
                  const SizedBox(height: 12),
                  // 主控制按钮
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
                    showGlow: true,
                  ),
                  const SizedBox(height: 12),
                  // 底部工具栏
                  _buildBottomBar(context, state, notifier),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 顶部栏：返回按钮 + "正在播放" + 右侧占位
  Widget _buildTopBar(BuildContext context, PlayerNotifier notifier) {
    const topBarColor = Colors.white;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 返回按钮
        IconButton(
          onPressed: () {
            notifier.closeFullPlayer();
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          iconSize: 32,
          color: topBarColor,
          tooltip: AppLocalizations.of(context).playerCollapse,
        ),
        // 中间标题
        Text(
          AppLocalizations.of(context).playerNowPlaying,
          style: TextStyle(
            color: topBarColor.withValues(alpha: 0.9),
            fontSize: 14,
          ),
        ),
        // 更多操作
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
          onSelected: (value) {
            if (value == 'delete') {
              deleteCurrentSongFromPlayer(context, ref);
            }
          },
          itemBuilder: (context) {
            final colorScheme = Theme.of(context).colorScheme;
            return [
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
    );
  }

  /// 封面构建
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

  /// 底部工具栏
  Widget _buildBottomBar(
    BuildContext context,
    PlayerState state,
    PlayerNotifier notifier,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        // 收藏
        SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: FavoriteButton(songId: state.currentSong!.id, songType: state.currentSong!.type, size: 24),
          ),
        ),
        // 播放模式
        SizedBox(
          width: 48,
          height: 48,
          child: PopupPlayModeControl(
            playMode: state.playMode,
            onPlayModeChanged: notifier.setPlayMode,
          ),
        ),
        // 投屏
        const SizedBox(
          width: 48,
          height: 48,
          child: CastButton(iconSize: 24),
        ),
        // 音量
        SizedBox(
          width: 48,
          height: 48,
          child: PopupVolumeControl(
            volume: state.volume,
            onVolumeChanged: notifier.setVolume,
          ),
        ),
        // 睡眠定时
        SizedBox(
          width: 48,
          height: 48,
          child: PopupSleepTimerControl(
            status: state.sleepTimer,
            isLive: state.currentSong?.isLive ?? false,
            onSetDuration: notifier.setSleepTimerByDuration,
            onSetAfterSongs: notifier.setSleepTimerAfterSongs,
            onCancel: notifier.cancelSleepTimer,
          ),
        ),
        // 播放队列
        SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            onPressed: () {
              QueueBottomSheet.show(context);
            },
            icon: const Icon(Icons.queue_music_rounded),
            tooltip: AppLocalizations.of(context).playerQueueTitle,
          ),
        ),
      ],
    );
  }
}
