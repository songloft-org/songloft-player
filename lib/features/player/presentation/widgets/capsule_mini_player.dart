import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/backend/run_mode_provider.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/widgets/liquid_glass_surface.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/url_helper.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/models/song.dart';
import '../../../../shared/widgets/favorite_button.dart';
import '../../../../shared/widgets/scrolling_text.dart';
import '../../../dlna/presentation/providers/dlna_provider.dart';
import '../../../dlna/presentation/widgets/cast_button.dart';
import '../../../settings/presentation/providers/song_cache_provider.dart';
import '../../domain/player_state.dart';
import '../providers/mini_player_controls_provider.dart';
import '../providers/player_provider.dart';
import '../utils/full_player_route.dart';
import '../utils/player_song_actions.dart';
import 'audio_track_control.dart';
import 'equalizer_panel.dart';
import 'play_controls.dart';
import 'popup_controls.dart';
import 'volume_control.dart';

/// 胶囊迷你播放器（`navigationStyle == 'capsule'`）的唯一实现。
///
/// 手机（[CapsuleMiniPlayer.compact]）与大屏（默认）共用同一套骨架：
/// 液态玻璃材质 + 顶边圆角进度 + 48px 内容行**相对胶囊垂直居中**，
/// pill 半径 = 高度 / 2。
/// 两档共用玻璃材质，shader 不可用时回退毛玻璃；减少透明度时使用实心填充。
/// 尺寸与控制区的区别：
/// - 尺寸：手机 59（顶边进度热区 11 + 48），大屏 64（顶边进度热区 16 + 48）
/// - 控制区：大屏是「常驻五项 + 更多菜单」；手机只保留播放 / 切歌，把宽度留给标题
///
/// 进度与内容行是 `Stack` 的两层，不是 `Column` 的兄弟：顶边热区是**覆盖在内容行
/// 之上**的一条命中带，不占纵向布局。这样内容行的中心就是胶囊的中心，封面 / 按钮
/// 与顶边进度同时成立 —— 反过来（热区当兄弟）内容行会被推下去约 6.5px，`padding`
/// 也补不平：那 6.5px 是布局偏移，任何均衡内边距都只能把它挪给另一侧。
class CapsuleMiniPlayer extends ConsumerWidget {
  /// 手机档（窄屏、精简控制区）
  final bool compact;

  /// 点击胶囊的回调，缺省进入全屏播放器
  final VoidCallback? onTap;

  const CapsuleMiniPlayer({super.key, this.compact = false, this.onTap});

  const CapsuleMiniPlayer.compact({super.key, this.onTap}) : compact = true;

  /// 胶囊本体（承载尺寸的那层）的 key，供集成测试量取 pill 几何。
  static const Key pillKey = Key('capsule-mini-player-pill');

  /// 顶边进度：轨道（底）与填充（顶）的 key，供测试校验它们落在 pill 圆角之内。
  static const Key progressTrackKey = Key('capsule-mini-player-progress-track');
  static const Key progressFillKey = Key('capsule-mini-player-progress-fill');

  /// 顶边进度的命中带（透明手势层）的 key，供测试校验拖动只在带内生效。
  static const Key progressHitKey = Key('capsule-mini-player-progress-hit');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(activePlaybackStateProvider);

    // 空状态：胶囊模式（手机 / 平板 / 桌面）一律整条不渲染。
    // 标准模式的桌面底栏仍会显示空播放器占位，那是另一条分支，不受这里影响。
    if (!state.hasSong) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final tier = compact ? _CapsuleTier.mobile : _CapsuleTier.dense;
    final radius = AppCapsulePlayer.pillRadius(tier.height);
    final notifier = ref.read(playerStateProvider.notifier);
    final song = state.currentSong!;

    // 内容行浮在整条胶囊上并垂直居中（上下留白等分）。顶边进度热区因此是**覆盖层**
    // 而不是 `Column` 里的兄弟：当成兄弟会把内容行整块推下去，行中心落到胶囊的
    // 56% 处，封面与按钮看着就是没对齐。
    final body = Stack(
      fit: StackFit.expand,
      children: [
        // 内容行：行顶由常量算出（两档都恰好是「(胶囊高 - 48) / 2」）
        Positioned(
          left: 0,
          right: 0,
          top: (tier.height - AppCapsulePlayer.rowHeight) / 2,
          height: AppCapsulePlayer.rowHeight,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: tier.rowPadding),
            // 行宽不足时（窄窗口 / 手机档）自动收起时间文本，把宽度让给标题
            child: LayoutBuilder(
              builder: (context, constraints) {
                final showTime = constraints.maxWidth >= tier.minWidthForTime;
                return Row(
                  children: [
                    _buildCover(context, theme, song, tier),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSongInfo(context, ref, theme, song, tier),
                    ),
                    if (showTime) ...[
                      const SizedBox(width: 12),
                      _buildTime(theme, state, tier),
                    ],
                    const SizedBox(width: 8),
                    ..._buildControls(context, ref, state, notifier, tier),
                  ],
                );
              },
            ),
          ),
        ),
        // 顶边进度：整宽贴着胶囊顶边框，热区是覆盖在内容行之上的一条命中带
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: tier.progressHitHeight,
          child: _CapsuleProgressBar(
            position: state.currentTime,
            duration: state.duration,
            onSeek: notifier.seek,
            hitHeight: tier.progressHitHeight,
            pillHeight: tier.height,
          ),
        ),
      ],
    );

    final tappable = _RoundedHitClip(
      radius: radius,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap ?? () => openFullPlayer(context),
          child: body,
        ),
      ),
    );

    final pill = LiquidGlassSurface(
      borderRadius: radius,
      sigma: compact ? 12 : AppCapsulePlayer.blurSigma,
      // 保持原有大屏内容盒的位置；手机的进度轨道仍与胶囊顶边重合。
      contentPadding: compact ? EdgeInsets.zero : const EdgeInsets.all(.5),
      child: tappable,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        tier.horizontalMargin,
        0,
        tier.horizontalMargin,
        tier.bottomMargin + MediaQuery.paddingOf(context).bottom,
      ),
      child: Semantics(
        button: true,
        label: AppLocalizations.of(context).playerExpandPlayer,
        child: SizedBox(
          key: pillKey,
          height: tier.height,
          // 浮起感：CustomPaint 的 painter 画在 child 之下，且只画轮廓之外
          child: CustomPaint(
            painter: CapsuleShadowPainter(
              radius: radius,
              shadow: _capsuleDropShadow,
            ),
            child: pill,
          ),
        ),
      ),
    );
  }

  Widget _buildCover(
    BuildContext context,
    ThemeData theme,
    Song song,
    _CapsuleTier tier,
  ) {
    final coverUrl = song.coverUrl;
    // 3x DPR 缩略图，避免弱网/NAS 场景下全尺寸封面解码卡主线程
    // (songloft-org/songloft-player#39)
    final decodeWidth = (tier.coverSize * 3).round();

    return Container(
      width: tier.coverSize,
      height: tier.coverSize,
      decoration: BoxDecoration(
        borderRadius: AppRadius.smAll,
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
                  errorBuilder:
                      (_, _, _) => _buildCoverPlaceholder(theme, tier),
                ),
              )
              : _buildCoverPlaceholder(theme, tier),
    );
  }

  Widget _buildCoverPlaceholder(ThemeData theme, _CapsuleTier tier) {
    return Icon(
      Icons.music_note_rounded,
      size: tier.coverSize * 0.5,
      color: theme.colorScheme.onSurfaceVariant,
    );
  }

  Widget _buildSongInfo(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    Song song,
    _CapsuleTier tier,
  ) {
    final l10n = AppLocalizations.of(context);
    final titleStyle = (compact
            ? theme.textTheme.bodyMedium
            : theme.textTheme.bodyLarge)
        ?.copyWith(fontWeight: FontWeight.w600);
    final artistStyle = (compact
            ? theme.textTheme.labelSmall
            : theme.textTheme.bodySmall)
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ScrollingText(text: song.title, style: titleStyle),
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
              child: ScrollingText(
                text: song.artist ?? l10n.playerUnknownArtist,
                style: artistStyle,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 右侧紧凑时间 `mm:ss / mm:ss`。
  ///
  /// 用 `tabularFigures` 等宽数字：否则 1→0 与 9→0 的字形宽度差会让整条胶囊
  /// 每秒抖一下。是否展示由行宽决定（见 `_CapsuleTier.minWidthForTime`）。
  Widget _buildTime(ThemeData theme, PlayerState state, _CapsuleTier tier) {
    final style = (compact
            ? theme.textTheme.labelSmall
            : theme.textTheme.bodySmall)
        ?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
    final position = Formatters.formatDuration(
      state.currentTime.inSeconds.toDouble(),
    );
    final duration = Formatters.formatDuration(
      state.duration.inSeconds.toDouble(),
    );

    return Text('$position / $duration', style: style, maxLines: 1);
  }

  List<Widget> _buildControls(
    BuildContext context,
    WidgetRef ref,
    PlayerState state,
    PlayerNotifier notifier,
    _CapsuleTier tier,
  ) {
    final controls = ref.watch(miniPlayerControlsProvider);
    final playButton = CompactPlayButton(
      isPlaying: state.isPlaying,
      isBuffering: state.showBufferingIndicator,
      onPlay: notifier.togglePlay,
      onPause: notifier.togglePlay,
      size: tier.skipHitSize,
    );

    return [
      // 收藏只在大屏常驻：手机窄屏的横向余量要留给标题
      if (!compact)
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: FavoriteButton(
            songId: state.currentSong!.id,
            songType: state.currentSong!.type,
            size: 22,
          ),
        ),
      if (controls.hasPrevNext) ...[
        _buildSkipButton(
          context,
          icon: Icons.skip_previous_rounded,
          tooltip: AppLocalizations.of(context).playerPrevious,
          onPressed: state.hasPrev ? notifier.playPrev : null,
          size: tier.skipHitSize,
        ),
        playButton,
        _buildSkipButton(
          context,
          icon: Icons.skip_next_rounded,
          tooltip: AppLocalizations.of(context).playerNext,
          onPressed: state.hasNext ? notifier.playNext : null,
          size: tier.skipHitSize,
        ),
      ] else
        playButton,
      if (!compact) ..._buildToolbar(context, ref, state, notifier),
    ];
  }

  /// 上一首 / 下一首：命中框按档位缩放，禁用态用同款降透明前景色
  Widget _buildSkipButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    required double size,
  }) {
    final theme = Theme.of(context);

    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: BoxConstraints.tightFor(width: size, height: size),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        foregroundColor: theme.colorScheme.onSurface,
        disabledForegroundColor: theme.colorScheme.onSurface.withValues(
          alpha: 0.38,
        ),
      ),
    );
  }

  /// 大屏常驻工具栏：播放模式 · 音量 · 歌词 · 队列 · 更多。
  ///
  /// 投屏与音轨切换按各自可用性自动出现（`CastButton` / `AudioTrackControl`
  /// 内部已经做了隐藏判断），不占常驻名额。
  List<Widget> _buildToolbar(
    BuildContext context,
    WidgetRef ref,
    PlayerState state,
    PlayerNotifier notifier,
  ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final song = state.currentSong!;
    final hasLyrics = song.lyricUrl != null;
    // 内联音量滑块要吃掉近 200dp，只在真正宽裕的窗口里展开
    final inlineVolume = MediaQuery.sizeOf(context).width >= 1100;

    return [
      PopupPlayModeControl(
        playMode: state.playMode,
        onPlayModeChanged: notifier.setPlayMode,
      ),
      SizedBox(
        width: inlineVolume ? 200 : 48,
        child: ResponsiveVolumeControl(
          volume: state.volume,
          onVolumeChanged: notifier.setVolume,
          threshold: 160,
        ),
      ),
      IconButton(
        onPressed: () => openFullPlayer(context),
        icon: Icon(
          Icons.lyrics_rounded,
          size: 20,
          color:
              hasLyrics ||
                      theme
                              .extension<SongloftThemeExtension>()
                              ?.increaseContrast ==
                          true
                  ? null
                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        tooltip: l10n.playerLyrics,
        visualDensity: VisualDensity.compact,
      ),
      IconButton(
        onPressed: notifier.togglePlaylistDrawer,
        icon: Icon(
          Icons.queue_music_rounded,
          size: 20,
          color: state.showPlaylistDrawer ? theme.colorScheme.primary : null,
        ),
        tooltip: l10n.playerPlaylist,
        visualDensity: VisualDensity.compact,
      ),
      const CastButton(iconSize: 20, visualDensity: VisualDensity.compact),
      const AudioTrackControl(
        iconSize: 20,
        visualDensity: VisualDensity.compact,
      ),
      _buildMoreMenu(context, ref, state, notifier, song, l10n),
    ];
  }

  Widget _buildMoreMenu(
    BuildContext context,
    WidgetRef ref,
    PlayerState state,
    PlayerNotifier notifier,
    Song song,
    AppLocalizations l10n,
  ) {
    ref.watch(songCacheProvider);
    final canCache = canCacheLocally(song, runMode: ref.watch(runModeProvider));
    final isCached = ref.read(songCacheProvider.notifier).isCached(song.id);

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, size: 20),
      padding: EdgeInsets.zero,
      tooltip: l10n.more,
      onSelected: (value) {
        switch (value) {
          case 'equalizer':
            showEqualizerSheet(context);
          case 'sleep':
            SleepTimerSheet.show(
              context,
              status: state.sleepTimer,
              isLive: song.isLive,
              onSetDuration: notifier.setSleepTimerByDuration,
              onSetAfterSongs: notifier.setSleepTimerAfterSongs,
              onCancel: notifier.cancelSleepTimer,
            );
          case 'speed':
            showSpeedSheet(
              context,
              speed: state.speed,
              onSpeedChanged: notifier.setSpeed,
            );
          case 'song_info':
            showSongInfoDialog(
              context,
              ref,
              song,
              playbackSource: state.playbackSource,
            );
          case 'cache_song':
            if (isCached) {
              removeSongFromDevice(context, ref, song);
            } else {
              cacheSongToDevice(context, ref, song);
            }
        }
      },
      itemBuilder:
          (context) => [
            // 均衡器依赖 libmpv，Web 上不生效，故 Web 隐藏
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
            // 睡眠定时 / 倍速原本是带锚点的浮层按钮（PopupSleepTimerControl /
            // PopupSpeedControl），塞进菜单项后拿不到锚点，改走底部抽屉。
            PopupMenuItem(
              value: 'sleep',
              child: ListTile(
                leading: const Icon(Icons.bedtime_outlined),
                title: Text(l10n.playerSleepTimer),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'speed',
              child: ListTile(
                leading: const Icon(Icons.speed_rounded),
                title: Text(l10n.playerSpeed),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'song_info',
              child: ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: Text(l10n.songCacheInfo),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            if (canCache)
              PopupMenuItem(
                value: 'cache_song',
                child: ListTile(
                  leading: Icon(
                    isCached
                        ? Icons.download_done_rounded
                        : Icons.download_for_offline_outlined,
                  ),
                  title: Text(
                    isCached ? l10n.songCacheRemove : l10n.songCacheCacheSong,
                  ),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
          ],
    );
  }
}

/// 胶囊两档尺寸（手机 / 大屏），数值全部来自 [AppCapsulePlayer]。
class _CapsuleTier {
  final double height;
  final double horizontalMargin;
  final double bottomMargin;
  final double rowPadding;
  final double coverSize;
  final double skipHitSize;
  final double progressHitHeight;
  final double minWidthForTime;

  const _CapsuleTier({
    required this.height,
    required this.horizontalMargin,
    required this.bottomMargin,
    required this.rowPadding,
    required this.coverSize,
    required this.skipHitSize,
    required this.progressHitHeight,
    required this.minWidthForTime,
  });

  static const mobile = _CapsuleTier(
    height: AppCapsulePlayer.heightMobile,
    horizontalMargin: AppCapsulePlayer.marginHorizontalMobile,
    bottomMargin: AppCapsulePlayer.marginBottomMobile,
    rowPadding: AppCapsulePlayer.rowPaddingMobile,
    coverSize: AppCapsulePlayer.coverSizeMobile,
    skipHitSize: AppCapsulePlayer.skipHitSizeMobile,
    progressHitHeight: AppCapsulePlayer.progressHitHeightMobile,
    // 手机横向余量要留给标题，且「手机 + 播放器 → 全屏」的路径一眼可见，时间不必挤
    minWidthForTime: double.infinity,
  );

  static const dense = _CapsuleTier(
    height: AppCapsulePlayer.heightDesktop,
    horizontalMargin: AppCapsulePlayer.marginHorizontalDesktop,
    bottomMargin: AppCapsulePlayer.marginBottomDesktop,
    rowPadding: AppCapsulePlayer.rowPaddingDesktop,
    coverSize: AppCapsulePlayer.coverSizeDesktop,
    skipHitSize: AppCapsulePlayer.skipHitSizeDesktop,
    progressHitHeight: AppCapsulePlayer.progressHitHeightDesktop,
    minWidthForTime: AppCapsulePlayer.minWidthForTime,
  );
}

/// 胶囊顶边圆角进度条（手机 / 大屏共用）。
///
/// 视觉轨道 3px，**整宽贴着胶囊顶边框**，两端顺着顶角圆弧被 pill 轮廓裁掉 —— 与
/// miot 插件 `.player-bar-progress`、Lynx 客户端 `.mini-player__progress` 同一套做法
/// （两边都是「整宽 3px 细条 + 外壳 `overflow: hidden`」，端点的形状由外壳圆角决定）。
/// 所以这里既不设左右 inset、也不自己裁：由 [LiquidGlassSurface] 按胶囊轮廓裁剪。
/// 这样进度条的两端就是胶囊顶角的弧线本身，
/// 而不是悬在玻璃中间、与顶边还留一段空隙的一条分离轨道。
///
/// 整块 `hitHeight` 热区（大屏 16 / 手机 9）与胶囊等宽，承接点按跳转与横向拖动；
/// 命中范围由 [_CapsuleProgressBand] 收成「顶上 `hitHeight` 高、且在 pill 顶角
/// 轮廓之内」的一条带：顶角那两块落在轮廓之外的像素既不 seek、也不把点击交给
/// 胶囊本体（否则点空白角会打开全屏播放器）。
///
/// 不用 `LinearProgressIndicator(borderRadius:)`：那个参数只对不确定态生效
/// (`progress_indicator.dart` 里被 `_effectiveValue == null` 挡住)，故直接手绘轨道。
class _CapsuleProgressBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final double hitHeight;
  final double pillHeight;

  const _CapsuleProgressBar({
    required this.position,
    required this.duration,
    required this.onSeek,
    required this.hitHeight,
    required this.pillHeight,
  });

  @override
  State<_CapsuleProgressBar> createState() => _CapsuleProgressBarState();
}

class _CapsuleProgressBarState extends State<_CapsuleProgressBar> {
  bool _isDragging = false;
  bool _isSeeking = false;
  double _dragProgress = 0;

  double get _progress {
    if (widget.duration.inMilliseconds <= 0) return 0;
    return (widget.position.inMilliseconds / widget.duration.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  double get _displayProgress =>
      _isDragging || _isSeeking ? _dragProgress : _progress;

  @override
  void didUpdateWidget(covariant _CapsuleProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isSeeking && !_isDragging && widget.position != oldWidget.position) {
      _isSeeking = false;
    }
  }

  void _seekTo(double progress) {
    final clamped = progress.clamp(0.0, 1.0);
    setState(() {
      _dragProgress = clamped;
      _isSeeking = true;
    });
    widget.onSeek(
      Duration(
        milliseconds: (clamped * widget.duration.inMilliseconds).round(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = AppCapsulePlayer.pillRadius(
      AppCapsulePlayer.progressTrackHeight,
    );
    final trackColor = theme.colorScheme.surfaceContainerHighest;
    final fillColor = theme.colorScheme.primary;

    // 命中带：只在顶上 `hitHeight` 这一段里接收手势，其余位置落到胶囊本体
    return _CapsuleProgressBand(
      key: CapsuleMiniPlayer.progressHitKey,
      hitHeight: widget.hitHeight,
      pillHeight: widget.pillHeight,
      child: SizedBox(
        height: widget.hitHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final trackWidth = constraints.maxWidth;
            // 防御退化的 0 宽（不会发生，但除以 0 会把 NaN 送进 seek）
            final divisionWidth = math.max(1.0, trackWidth);

            // 轨道贴着胶囊顶边（top: 0）、左右通到 pill 边缘，两端交给外层轮廓裁
            final track = Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: AppCapsulePlayer.progressTrackHeight,
                  child: DecoratedBox(
                    key: CapsuleMiniPlayer.progressTrackKey,
                    decoration: BoxDecoration(
                      color: trackColor,
                      borderRadius: radius,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  height: AppCapsulePlayer.progressTrackHeight,
                  width: trackWidth * _displayProgress,
                  child: DecoratedBox(
                    key: CapsuleMiniPlayer.progressFillKey,
                    decoration: BoxDecoration(
                      color: fillColor,
                      borderRadius: radius,
                    ),
                  ),
                ),
              ],
            );

            return Semantics(
              slider: true,
              label: AppLocalizations.of(context).playerProgress,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    _seekTo(details.localPosition.dx / divisionWidth);
                  },
                  onHorizontalDragStart: (details) {
                    setState(() {
                      _isDragging = true;
                      _dragProgress = (details.localPosition.dx / divisionWidth)
                          .clamp(0.0, 1.0);
                    });
                  },
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _dragProgress = (details.localPosition.dx / divisionWidth)
                          .clamp(0.0, 1.0);
                    });
                  },
                  onHorizontalDragEnd: (_) {
                    final target = _dragProgress;
                    setState(() => _isDragging = false);
                    _seekTo(target);
                  },
                  child: track,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 顶边进度的命中带：把「顶上 `hitHeight` 高」之外的手势整块放行，让它们落到
/// 下面的内容行 / 胶囊本体上（否则整条胶囊都成了 seek 区）。
///
/// 只收高度还不够：胶囊顶角是圆弧，`hitHeight` 这一段的两端有相当一块像素落在
/// 轮廓**之外**（大屏档 64 高、半径 32，y = 0 那行轮廓已经在 x = 32）。热区横跨
/// 整宽时，点顶角的空白处会被解读成「拖到 0 秒」。所以命中范围再按 pill 轮廓
/// （高 `pillHeight`、半径 `pillHeight / 2` 的圆角矩形）收一次。
class _CapsuleProgressBand extends SingleChildRenderObjectWidget {
  final double hitHeight;
  final double pillHeight;

  const _CapsuleProgressBand({
    super.key,
    required this.hitHeight,
    required this.pillHeight,
    required super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderCapsuleProgressBand(hitHeight: hitHeight, pillHeight: pillHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderCapsuleProgressBand renderObject,
  ) {
    renderObject
      ..hitHeight = hitHeight
      ..pillHeight = pillHeight;
  }
}

class _RenderCapsuleProgressBand extends RenderProxyBox {
  _RenderCapsuleProgressBand({
    required double hitHeight,
    required double pillHeight,
  }) : _hitHeight = hitHeight,
       _pillHeight = pillHeight;

  double _hitHeight;
  set hitHeight(double value) {
    if (_hitHeight == value) return;
    _hitHeight = value;
  }

  double _pillHeight;
  set pillHeight(double value) {
    if (_pillHeight == value) return;
    _pillHeight = value;
  }

  /// pill 轮廓：热区盒子与胶囊顶边、左边缘对齐，所以这层就是胶囊的圆角矩形
  RRect get _outline => RRect.fromRectAndRadius(
    Rect.fromLTWH(0, 0, size.width, _pillHeight),
    Radius.circular(_pillHeight / 2),
  );

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (position.dy > _hitHeight) return false;
    if (!_outline.contains(position)) return false;
    return super.hitTest(result, position: position);
  }
}

/// 把命中测试收成胶囊轮廓（pill 的圆角内切区之外不响应点击）。
///
/// `ClipRRect` 在不传 `clipper` 时**只裁剪绘制**（`RenderClipRRect.hitTest` 仅在
/// `_clipper != null` 时检查轮廓），于是胶囊四角那几像素透明区仍会落到 `InkWell`
/// 上：点在胶囊轮廓外的角上会莫名其妙打开全屏播放器，而同样在轮廓外的左右外边距
/// （`tier.horizontalMargin`）却穿到下层页面，两者行为不一致。
///
/// 这里用只重写 `hitTest` 的 `RenderProxyBox` 补上这一步：轮廓内照常命中，
/// 轮廓外直接返回 false 让事件落到下层。刻意**不**裁剪绘制——胶囊的可见裁剪
/// 由 [LiquidGlassSurface] 的圆角负责，
/// 再叠一层同样的圆角 mask 会让边缘被同一个抗锯齿 mask 乘两次而变淡。
class _RoundedHitClip extends SingleChildRenderObjectWidget {
  final BorderRadius radius;

  const _RoundedHitClip({required this.radius, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderRoundedHitClip(_resolve(context), radius);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderRoundedHitClip renderObject,
  ) {
    renderObject
      ..textDirection = _resolve(context)
      ..radius = radius;
  }

  static TextDirection _resolve(BuildContext context) =>
      Directionality.maybeOf(context) ?? TextDirection.ltr;
}

class _RenderRoundedHitClip extends RenderProxyBox {
  _RenderRoundedHitClip(this._textDirection, this._radius);

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    _clip = null;
  }

  BorderRadiusGeometry _radius;
  set radius(BorderRadiusGeometry value) {
    if (_radius == value) return;
    _radius = value;
    _clip = null;
  }

  RRect? _clip;

  RRect get _outline =>
      _clip ??= _radius.resolve(_textDirection).toRRect(Offset.zero & size);

  @override
  void performLayout() {
    super.performLayout();
    _clip = null; // 尺寸变了，轮廓要重算（toRRect 依赖 size）
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!_outline.contains(position)) return false;
    return super.hitTest(result, position: position);
  }
}

/// 胶囊的落影参数（颜色 / 模糊 / 偏移，语义与 [BoxShadow] 一致）。
class CapsuleShadow {
  final Color color;
  final double blurRadius;
  final Offset offset;
  final double spreadRadius;

  const CapsuleShadow({
    required this.color,
    required this.blurRadius,
    this.offset = Offset.zero,
    this.spreadRadius = 0,
  });

  /// `BlurStyle.normal` 的 sigma 换算：与 `BoxShadow` 内部同一公式，
  /// 保证这里的模糊半径与框架别处的阴影观感一致。
  Paint toPaint() =>
      Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          blurRadius * 0.57735 + 0.5,
        );

  @override
  bool operator ==(Object other) =>
      other is CapsuleShadow &&
      other.color == color &&
      other.blurRadius == blurRadius &&
      other.offset == offset &&
      other.spreadRadius == spreadRadius;

  @override
  int get hashCode => Object.hash(color, blurRadius, offset, spreadRadius);
}

/// 浮起感的唯一来源：轮廓外一道向下略偏的柔和落影。
///
/// 刻意**不做**内阴影：胶囊顶边就是进度条，任何落在轮廓内侧顶部的暗色都会
/// 糊在进度条周围，看起来像进度条自身带着一圈很重的阴影。
///
/// 半径刻意收得比 `GlassSurface` 的默认阴影（blur 12 / offset 4）还小：
/// 胶囊底边距只有 12，太大的落影会被底部的 `Stack` 裁出硬边。
const CapsuleShadow _capsuleDropShadow = CapsuleShadow(
  color: Color(0x1A000000),
  blurRadius: 8,
  offset: Offset(0, 2),
);

/// 只把落影画在胶囊轮廓**之外**、且**不高于胶囊顶边**。
///
/// 直接给外层 `DecoratedBox`（或是给 `GlassSurface` 自己）加 `boxShadow` 时，阴影会
/// 铺到胶囊内部并被半透玻璃透出来，把整块玻璃压灰。这里把阴影裁掉轮廓内的部分，
/// 让"投影"只出现在胶囊之外，与胶囊内部的亮度完全解耦。
///
/// 顶边以上也一并裁掉：进度条整条压在胶囊顶边上，`MaskFilter.blur` 的尾巴会从顶边
/// 往上渗出 5~10px，在半透玻璃与浅色页面上就是贴着进度条上半侧的一圈灰边（比背景
/// 暗 8~20 级），看着"很重、不搭配"。掐掉顶边以上的可见区域之后，落影只剩左右两侧
/// 的月牙与底边，浮起感还在，但进度条周围一圈是干净的。
class CapsuleShadowPainter extends CustomPainter {
  final BorderRadius radius;
  final CapsuleShadow shadow;

  const CapsuleShadowPainter({required this.radius, required this.shadow});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final bounds = Offset.zero & size;
    final outline = radius.toRRect(bounds);
    // 落影必须能画到胶囊**之外**，所以可绘制区域要在轮廓的基础上外扩：
    // blur + offset 决定阴影能蔓延多远（`MaskFilter.blur` 的尾巴约等于 blurRadius）。
    final extent =
        shadow.blurRadius + shadow.offset.distance + shadow.spreadRadius.abs();
    // 顶边以上（含轮廓本身）都不画：见类注释里"为什么掐掉顶边"的说明
    final covered = Path.combine(
      PathOperation.union,
      Path()..addRRect(outline),
      Path()..addRect(Rect.fromLTRB(-extent, -extent, size.width + extent, 0)),
    );
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(bounds.inflate(extent)),
      covered,
    );

    canvas.clipPath(outside);
    canvas.drawRRect(
      outline.shift(shadow.offset).inflate(shadow.spreadRadius),
      shadow.toPaint(),
    );
  }

  @override
  bool shouldRepaint(covariant CapsuleShadowPainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.shadow != shadow;
}
