import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/tv_theme.dart';
import '../../../../core/utils/color_extraction.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/url_helper.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../l10n/l10n_holder.dart';
import '../../../../shared/models/song.dart';
import '../../../../shared/widgets/tv_focusable.dart';
import '../../domain/player_state.dart';
import '../providers/audio_track_provider.dart';
import '../providers/player_provider.dart';
import 'audio_track_control.dart';
import 'lyrics_view.dart';
import 'video_stage.dart';
import 'video_subtitle_overlay.dart';

/// TV 全屏播放器界面
///
/// 专为 TV 端设计的播放器，特性：
/// - 左右分栏：左侧封面+歌曲信息，右侧歌词
/// - 大尺寸封面图（360x360）
/// - 大号字体（标题 24sp，艺术家 20sp）
/// - 加粗进度条
/// - 大按钮（最小 80x80），支持 D-Pad 焦点导航
/// - 渐变背景
class TvPlayer extends ConsumerStatefulWidget {
  const TvPlayer({super.key});

  /// 显示 TV 全屏播放器（歌词界面）。返回按钮内部已处理 closeFullPlayer + maybePop。
  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder:
            (context, animation, secondaryAnimation) => const TvPlayer(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  ConsumerState<TvPlayer> createState() => _TvPlayerState();
}

class _TvPlayerState extends ConsumerState<TvPlayer> {
  final _playlistButtonFocusNode = FocusNode();

  @override
  void dispose() {
    _playlistButtonFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerStateProvider);
    final notifier = ref.read(playerStateProvider.notifier);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 获取封面 URL 和动态调色板
    String? coverUrl;
    CoverPalette? palette;
    if (state.hasSong) {
      coverUrl = state.currentSong!.coverUrl;
      palette =
          ref.watch(playerBackgroundPaletteProvider(state.currentSong!)).value;
    }
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          // 渐变背景
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              (palette?.darkMutedColor ?? colorScheme.primaryContainer)
                  .withValues(alpha: 0.4),
              colorScheme.surface,
              colorScheme.surface,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: FocusTraversalGroup(
            child: Column(
              children: [
                // 顶部工具栏
                _buildTopBar(context, notifier),
                // 主内容：视频铺满画面(16:9 + 字幕),或音频的封面/歌词分栏
                Expanded(
                  child: (state.currentSong?.isVideo ?? false)
                      ? _buildVideoArea(context, state.currentSong!)
                      : Row(
                          children: [
                            // 左侧：封面 + 歌曲信息
                            Expanded(
                              flex: 4,
                              child: Center(
                                child: SingleChildScrollView(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _buildCoverArt(
                                        context,
                                        coverUrl,
                                        state.currentSong,
                                      ),
                                      const SizedBox(
                                        height: TvTheme.spacingLarge,
                                      ),
                                      _buildSongInfo(context, state),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // 右侧：歌词
                            Expanded(
                              flex: 5,
                              child: _buildLyricsArea(context, state, notifier),
                            ),
                          ],
                        ),
                ),
                // 进度条
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TvTheme.contentPadding,
                  ),
                  child: _TvFocusableProgressBar(
                    state: state,
                    notifier: notifier,
                  ),
                ),
                const SizedBox(height: TvTheme.spacingMedium),
                // 播放控制 + 附加控制（合并为一行）
                _buildControlsRow(context, state, notifier),
                const SizedBox(height: TvTheme.spacingMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 顶部工具栏
  Widget _buildTopBar(BuildContext context, PlayerNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TvTheme.contentPadding,
        vertical: TvTheme.spacingMedium,
      ),
      child: Row(
        children: [
          // 返回按钮（带标签）
          _TvPlayerControlButton(
            icon: Icons.arrow_back_rounded,
            label: AppLocalizations.of(context).playerBack,
            onPressed: () {
              notifier.closeFullPlayer();
              Navigator.of(context).maybePop();
            },
            size: 56,
            iconSize: 28,
          ),
          const Spacer(),
          // 正在播放标题
          Text(
            AppLocalizations.of(context).playerNowPlaying,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: TvTheme.fontSizeBody,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          // 占位，保持居中
          const SizedBox(width: 56),
        ],
      ),
    );
  }

  /// 视频/MV 画面区(TV):16:9 铺满 + 字幕叠加。进度条/控制行沿用下方 TV 焦点控件。
  Widget _buildVideoArea(BuildContext context, Song song) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: TvTheme.contentPadding),
      child: Center(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: DecoratedBox(
            decoration: const BoxDecoration(color: Colors.black),
            child: Stack(
              fit: StackFit.expand,
              children: [
                VideoStage(
                  song: song,
                  borderRadius: BorderRadius.zero,
                  fallback: const ColoredBox(color: Colors.black),
                ),
                const Positioned(
                  left: 24,
                  right: 24,
                  bottom: 16,
                  child: IgnorePointer(
                    child: VideoSubtitleOverlay(fontSize: 24),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 封面图
  Widget _buildCoverArt(BuildContext context, String? coverUrl, Song? song) {
    final theme = Theme.of(context);

    final cover =
        coverUrl != null
            ? ExcludeSemantics(
              child: Image.network(
                UrlHelper.buildCoverUrl(coverUrl),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _buildPlaceholderIcon(context),
              ),
            )
            : _buildPlaceholderIcon(context);

    return Container(
      width: 360,
      height: 360,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TvTheme.cardRadius),
        color: theme.colorScheme.surfaceContainerHighest,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      // 视频歌曲在支持的桌面平台渲染画面，否则回退封面/占位图
      child:
          song != null
              ? VideoStage(
                song: song,
                borderRadius: BorderRadius.circular(TvTheme.cardRadius),
                fallback: cover,
              )
              : cover,
    );
  }

  Widget _buildPlaceholderIcon(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Icon(
        Icons.music_note_rounded,
        size: 100,
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
      ),
    );
  }

  /// 歌曲信息
  Widget _buildSongInfo(BuildContext context, PlayerState state) {
    final theme = Theme.of(context);

    if (!state.hasSong) {
      return Text(
        AppLocalizations.of(context).playerNoContent,
        style: TvTheme.titleStyle(context).copyWith(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      );
    }

    final song = state.currentSong!;

    return Column(
      children: [
        // 标题
        Text(
          song.title,
          style: TvTheme.titleStyle(context),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: TvTheme.spacingSmall),
        // 艺术家
        Text(
          song.artist ?? AppLocalizations.of(context).playerUnknownArtist,
          style: TvTheme.captionStyle(context),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// 歌词区域
  Widget _buildLyricsArea(
    BuildContext context,
    PlayerState state,
    PlayerNotifier notifier,
  ) {
    if (!state.hasSong) {
      return const SizedBox.shrink();
    }
    final song = state.currentSong!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: LyricsView(
        currentPosition: state.currentTime,
        onSeek: notifier.seek,
        song: song,
        editable: true,
      ),
    );
  }

  /// 播放控制 + 附加控制合并为一行
  Widget _buildControlsRow(
    BuildContext context,
    PlayerState state,
    PlayerNotifier notifier,
  ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: TvTheme.contentPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 播放模式
          Builder(
            builder:
                (buttonContext) => _TvPlayerControlButton(
                  icon: _getPlayModeIcon(state.playMode),
                  label: AppLocalizations.of(context).playerPlayMode,
                  onPressed:
                      () => _showPlayModeOverlay(
                        buttonContext,
                        notifier,
                        state,
                        theme,
                      ),
                  size: 64,
                  iconSize: 28,
                  iconColor:
                      state.playMode != PlayMode.order
                          ? theme.colorScheme.primary
                          : null,
                ),
          ),
          const SizedBox(width: TvTheme.spacingMedium),
          // 音量减
          _TvPlayerControlButton(
            icon: Icons.volume_down_rounded,
            label: AppLocalizations.of(context).playerVolumeDown,
            onPressed: () {
              final newVolume = (state.volume - 10).clamp(0.0, 100.0);
              notifier.setVolume(newVolume);
            },
            size: 64,
            iconSize: 28,
          ),
          const SizedBox(width: TvTheme.spacingSmall),
          // 音量显示
          SizedBox(
            width: 60,
            child: Text(
              '${state.volume.round()}%',
              style: TvTheme.bodyStyle(context),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: TvTheme.spacingSmall),
          // 音量加
          _TvPlayerControlButton(
            icon: Icons.volume_up_rounded,
            label: AppLocalizations.of(context).playerVolumeUp,
            onPressed: () {
              final newVolume = (state.volume + 10).clamp(0.0, 100.0);
              notifier.setVolume(newVolume);
            },
            size: 64,
            iconSize: 28,
          ),
          const SizedBox(width: TvTheme.spacingLarge),
          // 上一首
          _TvPlayerControlButton(
            icon: Icons.skip_previous_rounded,
            label: AppLocalizations.of(context).playerPrevious,
            onPressed: state.hasPrev ? notifier.playPrev : null,
            size: TvTheme.minButtonSize,
            iconSize: 40,
            autofocus: true,
          ),
          const SizedBox(width: TvTheme.spacingMedium),
          // 播放/暂停（主按钮）
          _buildPlayPauseButton(context, state, notifier),
          const SizedBox(width: TvTheme.spacingMedium),
          // 下一首
          _TvPlayerControlButton(
            icon: Icons.skip_next_rounded,
            label: AppLocalizations.of(context).playerNext,
            onPressed: state.hasNext ? notifier.playNext : null,
            size: TvTheme.minButtonSize,
            iconSize: 40,
          ),
          const SizedBox(width: TvTheme.spacingLarge),
          // 播放列表
          _TvPlayerControlButton(
            icon: Icons.queue_music_rounded,
            label: AppLocalizations.of(context).playerPlaylist,
            focusNode: _playlistButtonFocusNode,
            onPressed: () {
              final wasOpen = state.showPlaylistDrawer;
              notifier.togglePlaylistDrawer();
              if (wasOpen) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _playlistButtonFocusNode.requestFocus();
                });
              }
            },
            size: 64,
            iconSize: 28,
            iconColor:
                state.showPlaylistDrawer ? theme.colorScheme.primary : null,
          ),
          // 音轨切换（多音频轨时显示，如原唱/伴奏；单轨自动隐藏）
          if (ref.watch(audioTrackProvider).hasMultiple) ...[
            const SizedBox(width: TvTheme.spacingLarge),
            _TvPlayerControlButton(
              icon: Icons.multitrack_audio_rounded,
              label: AppLocalizations.of(context).playerAudioTrack,
              onPressed: () => showAudioTrackSheet(context, ref),
              size: 64,
              iconSize: 28,
              iconColor: theme.colorScheme.primary,
            ),
          ],
        ],
      ),
    );
  }

  /// 播放/暂停按钮
  Widget _buildPlayPauseButton(
    BuildContext context,
    PlayerState state,
    PlayerNotifier notifier,
  ) {
    final theme = Theme.of(context);

    if (state.isBuffering) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.of(context).playerBuffering,
            style: TextStyle(
              fontSize: TvTheme.fontSizeCaption,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      );
    }

    return _TvPlayPauseButton(
      isPlaying: state.isPlaying,
      onPressed: notifier.togglePlay,
    );
  }

  IconData _getPlayModeIcon(PlayMode mode) {
    switch (mode) {
      case PlayMode.order:
        return Icons.format_list_numbered_rounded;
      case PlayMode.loop:
        return Icons.repeat_rounded;
      case PlayMode.single:
        return Icons.repeat_one_rounded;
      case PlayMode.random:
        return Icons.shuffle_rounded;
      case PlayMode.singlePlay:
        return Icons.looks_one_outlined;
    }
  }

  String _getPlayModeTooltip(PlayMode mode) {
    switch (mode) {
      case PlayMode.order:
        return l10n.playerModeOrder;
      case PlayMode.loop:
        return l10n.playerModeLoop;
      case PlayMode.single:
        return l10n.playerModeSingle;
      case PlayMode.random:
        return l10n.playerModeRandom;
      case PlayMode.singlePlay:
        return l10n.playerModeSinglePlay;
    }
  }

  /// 显示播放模式弹出层（使用自定义 Overlay）
  void _showPlayModeOverlay(
    BuildContext context,
    PlayerNotifier notifier,
    PlayerState state,
    ThemeData theme,
  ) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = button.localToGlobal(Offset.zero, ancestor: overlay);
    final size = button.size;

    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder:
          (context) => _TvPlayModeOverlayPanel(
            playMode: state.playMode,
            onPlayModeChanged: (mode) {
              notifier.setPlayMode(mode);
              overlayEntry.remove();
            },
            onDismiss: () => overlayEntry.remove(),
            anchorPosition: position,
            anchorSize: size,
            getIcon: _getPlayModeIcon,
            getTooltip: _getPlayModeTooltip,
          ),
    );

    Overlay.of(context).insert(overlayEntry);
  }
}

/// TV 播放器控制按钮（带焦点标签）
class _TvPlayerControlButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool autofocus;
  final FocusNode? focusNode;
  final double size;
  final double iconSize;
  final Color? iconColor;

  const _TvPlayerControlButton({
    required this.icon,
    required this.label,
    this.onPressed,
    this.autofocus = false,
    this.focusNode,
    this.size = TvTheme.minButtonSize,
    this.iconSize = 32,
    this.iconColor,
  });

  @override
  State<_TvPlayerControlButton> createState() => _TvPlayerControlButtonState();
}

class _TvPlayerControlButtonState extends State<_TvPlayerControlButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 圆形发光容器 + TvIconButton
        AnimatedContainer(
          duration: TvTheme.focusAnimationDuration,
          curve: TvTheme.focusAnimationCurve,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow:
                _isFocused
                    ? [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: TvTheme.focusShadowBlurRadius,
                        spreadRadius: TvTheme.focusGlowSpreadRadius,
                      ),
                    ]
                    : null,
          ),
          child: TvIconButton(
            icon: widget.icon,
            onPressed: widget.onPressed,
            autofocus: widget.autofocus,
            focusNode: widget.focusNode,
            size: widget.size,
            iconSize: widget.iconSize,
            enabled: widget.onPressed != null,
            iconColor: widget.iconColor,
            onFocusChange: (hasFocus) {
              setState(() {
                _isFocused = hasFocus;
              });
            },
          ),
        ),
        const SizedBox(height: 6),
        // 焦点时淡入的标签
        AnimatedOpacity(
          opacity: _isFocused ? 1.0 : 0.0,
          duration: TvTheme.focusAnimationDuration,
          curve: TvTheme.focusAnimationCurve,
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: TvTheme.fontSizeCaption,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );
  }
}

/// TV 播放/暂停主按钮（增强焦点效果）
class _TvPlayPauseButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onPressed;

  const _TvPlayPauseButton({required this.isPlaying, required this.onPressed});

  @override
  State<_TvPlayPauseButton> createState() => _TvPlayPauseButtonState();
}

class _TvPlayPauseButtonState extends State<_TvPlayPauseButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: TvTheme.focusAnimationDuration,
          curve: TvTheme.focusAnimationCurve,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow:
                _isFocused
                    ? [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.5),
                        blurRadius: 30,
                        spreadRadius: 8,
                      ),
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                    : null,
          ),
          child: TvFocusable(
            onSelect: widget.onPressed,
            autofocus: true,
            borderRadius: 50,
            focusedScale: TvTheme.focusedScaleLarge,
            onFocusChange: (hasFocus) {
              setState(() {
                _isFocused = hasFocus;
              });
            },
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                size: 56,
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        // 焦点时淡入的标签
        AnimatedOpacity(
          opacity: _isFocused ? 1.0 : 0.0,
          duration: TvTheme.focusAnimationDuration,
          curve: TvTheme.focusAnimationCurve,
          child: Text(
            widget.isPlaying
                ? AppLocalizations.of(context).playerPause
                : AppLocalizations.of(context).playerPlay,
            style: TextStyle(
              fontSize: TvTheme.fontSizeCaption,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );
  }
}

/// TV 可聚焦进度条（支持左右快进/快退）
class _TvFocusableProgressBar extends StatefulWidget {
  final PlayerState state;
  final PlayerNotifier notifier;

  const _TvFocusableProgressBar({required this.state, required this.notifier});

  @override
  State<_TvFocusableProgressBar> createState() =>
      _TvFocusableProgressBarState();
}

class _TvFocusableProgressBarState extends State<_TvFocusableProgressBar> {
  bool _isFocused = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      // 快退 10 秒
      final newPosition = Duration(
        milliseconds: (widget.state.currentTime.inMilliseconds - 10000).clamp(
          0,
          widget.state.duration.inMilliseconds,
        ),
      );
      widget.notifier.seek(newPosition);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      // 快进 10 秒
      final newPosition = Duration(
        milliseconds: (widget.state.currentTime.inMilliseconds + 10000).clamp(
          0,
          widget.state.duration.inMilliseconds,
        ),
      );
      widget.notifier.seek(newPosition);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = widget.state;

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      onFocusChange: (hasFocus) {
        setState(() {
          _isFocused = hasFocus;
        });
      },
      child: Semantics(
        slider: true,
        label: AppLocalizations.of(context).playerProgress,
        child: GestureDetector(
          onTap: () => _focusNode.requestFocus(),
          child: AnimatedContainer(
          duration: TvTheme.focusAnimationDuration,
          curve: TvTheme.focusAnimationCurve,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  _isFocused ? theme.colorScheme.primary : Colors.transparent,
              width: 2,
            ),
            boxShadow:
                _isFocused
                    ? [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                    : null,
          ),
          child: Column(
            children: [
              // 焦点时显示快进/快退提示
              AnimatedOpacity(
                opacity: _isFocused ? 1.0 : 0.0,
                duration: TvTheme.focusAnimationDuration,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    AppLocalizations.of(context).playerSeekHint,
                    style: TextStyle(
                      fontSize: TvTheme.fontSizeCaption,
                      color: theme.colorScheme.primary.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ),
              // 进度滑块
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: _isFocused ? 8 : 6,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 10,
                    pressedElevation: 6,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 20,
                  ),
                  activeTrackColor: theme.colorScheme.primary,
                  inactiveTrackColor: theme.colorScheme.surfaceContainerHighest,
                  thumbColor: theme.colorScheme.primary,
                  overlayColor: theme.colorScheme.primary.withValues(
                    alpha: 0.2,
                  ),
                ),
                child: Slider(
                  value: state.progress,
                  onChanged: (value) {
                    final newPosition = Duration(
                      milliseconds:
                          (value * state.duration.inMilliseconds).round(),
                    );
                    widget.notifier.seek(newPosition);
                  },
                  semanticFormatterCallback: (value) {
                    final pos = Duration(
                      milliseconds: (value * state.duration.inMilliseconds).round(),
                    );
                    return '${Formatters.formatDuration(pos.inSeconds.toDouble())} / ${Formatters.formatDuration(state.duration.inSeconds.toDouble())}';
                  },
                ),
              ),
              const SizedBox(height: TvTheme.spacingSmall),
              // 时间显示
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      Formatters.formatDuration(
                        state.currentTime.inSeconds.toDouble(),
                      ),
                      style: TvTheme.captionStyle(context).copyWith(
                        fontWeight:
                            _isFocused ? FontWeight.w600 : FontWeight.normal,
                        color: _isFocused ? theme.colorScheme.primary : null,
                      ),
                    ),
                    Text(
                      Formatters.formatDuration(
                        state.duration.inSeconds.toDouble(),
                      ),
                      style: TvTheme.captionStyle(context).copyWith(
                        fontWeight:
                            _isFocused ? FontWeight.w600 : FontWeight.normal,
                        color: _isFocused ? theme.colorScheme.primary : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

/// TV 端播放模式弹出面板
/// 使用自定义 Overlay 实现，与音量控制弹出层定位方式一致
class _TvPlayModeOverlayPanel extends StatelessWidget {
  final PlayMode playMode;
  final ValueChanged<PlayMode> onPlayModeChanged;
  final VoidCallback onDismiss;
  final Offset anchorPosition;
  final Size anchorSize;
  final IconData Function(PlayMode) getIcon;
  final String Function(PlayMode) getTooltip;

  const _TvPlayModeOverlayPanel({
    required this.playMode,
    required this.onPlayModeChanged,
    required this.onDismiss,
    required this.anchorPosition,
    required this.anchorSize,
    required this.getIcon,
    required this.getTooltip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;

    // TV 端面板尺寸
    const itemHeight = 56.0;
    const panelWidth = 200.0;
    const iconSize = 24.0;
    const fontSize = 16.0;

    final panelHeight = PlayMode.values.length * itemHeight + 16;

    // 计算面板位置（居中对齐按钮）
    double left = anchorPosition.dx + anchorSize.width / 2 - panelWidth / 2;
    // 确保不超出屏幕
    if (left < 16) left = 16;
    if (left + panelWidth > screenSize.width - 16) {
      left = screenSize.width - panelWidth - 16;
    }

    // 面板从按钮上方弹出
    double top = anchorPosition.dy - panelHeight - 8;

    // 如果面板会超出屏幕可见区域，显示在按钮下方
    final safeAreaTop = MediaQuery.of(context).padding.top;
    if (top < safeAreaTop + 16) {
      top = anchorPosition.dy + anchorSize.height + 8;
    }

    return Stack(
      children: [
        // 透明背景层，点击关闭
        Positioned.fill(
          child: Semantics(
            label: AppLocalizations.of(context).playerClose,
            child: GestureDetector(
              onTap: onDismiss,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
        // 播放模式面板
        Positioned(
          left: left,
          top: top,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: theme.colorScheme.surfaceContainerHigh,
            child: Container(
              width: panelWidth,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: FocusTraversalGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final mode in PlayMode.values)
                      Builder(
                        builder:
                            (itemContext) => TvFocusable(
                              onSelect: () => onPlayModeChanged(mode),
                              borderRadius: 8,
                              child: Container(
                                width: double.infinity,
                                height: itemHeight,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      getIcon(mode),
                                      size: iconSize,
                                      color:
                                          playMode == mode
                                              ? theme.colorScheme.primary
                                              : theme.colorScheme.onSurface,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      getTooltip(mode),
                                      style: TextStyle(
                                        fontSize: fontSize,
                                        color:
                                            playMode == mode
                                                ? theme.colorScheme.primary
                                                : theme.colorScheme.onSurface,
                                        fontWeight:
                                            playMode == mode
                                                ? FontWeight.w500
                                                : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// TV 迷你播放器（用于底部显示）
///
/// 专为 TV 端设计的迷你播放器，显示在底部
class TvMiniPlayer extends ConsumerWidget {
  const TvMiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerStateProvider);
    final notifier = ref.read(playerStateProvider.notifier);
    final theme = Theme.of(context);

    if (!state.hasSong) {
      return const SizedBox.shrink();
    }

    final song = state.currentSong!;
    final coverUrl = song.coverUrl;

    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TvTheme.contentPadding,
          vertical: TvTheme.spacingSmall,
        ),
        child: FocusTraversalGroup(
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
                          ),
                        )
                        : Icon(
                          Icons.music_note_rounded,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
              ),
              const SizedBox(width: TvTheme.spacingMedium),
              // 歌曲信息
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      style: TvTheme.bodyStyle(
                        context,
                      ).copyWith(fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      song.artist ?? AppLocalizations.of(context).playerUnknownArtist,
                      style: TvTheme.captionStyle(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // 播放控制
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TvIconButton(
                    icon: Icons.skip_previous_rounded,
                    onPressed: state.hasPrev ? notifier.playPrev : null,
                    enabled: state.hasPrev,
                    size: 56,
                    iconSize: 28,
                  ),
                  const SizedBox(width: TvTheme.spacingSmall),
                  TvIconButton(
                    icon:
                        state.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                    onPressed: notifier.togglePlay,
                    size: 56,
                    iconSize: 32,
                    backgroundColor: theme.colorScheme.primary,
                    iconColor: theme.colorScheme.onPrimary,
                  ),
                  const SizedBox(width: TvTheme.spacingSmall),
                  TvIconButton(
                    icon: Icons.skip_next_rounded,
                    onPressed: state.hasNext ? notifier.playNext : null,
                    enabled: state.hasNext,
                    size: 56,
                    iconSize: 28,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
