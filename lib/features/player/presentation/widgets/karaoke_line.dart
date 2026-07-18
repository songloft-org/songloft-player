import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/lyric_parser.dart';
import '../providers/player_provider.dart';

/// 逐字歌词单行渲染。
///
/// 仅用于**当前行**。以 [Ticker] 在两次 [PlayerState.currentTime] 采样之间做插值，
/// 得到平滑（~60fps）的估计播放位置，据此对每个字做 inactive → active 的颜色渐变，
/// 实现逐字渐进高亮。暂停时估计位置冻结，恢复/seek 时重新锚定，避免跳变。
class KaraokeLine extends ConsumerStatefulWidget {
  final LyricLine line;

  /// 已唱字的颜色。
  final Color activeColor;

  /// 未唱字的颜色。
  final Color inactiveColor;

  final double fontSize;
  final FontWeight fontWeight;

  /// 文字阴影/描边（视频字幕场景用于保证任意画面上可读）。
  final List<Shadow>? shadows;

  /// 最大行数与行高。
  final int maxLines;
  final double height;

  const KaraokeLine({
    super.key,
    required this.line,
    required this.activeColor,
    required this.inactiveColor,
    required this.fontSize,
    this.fontWeight = FontWeight.bold,
    this.shadows,
    this.maxLines = 2,
    this.height = 1.2,
  });

  @override
  ConsumerState<KaraokeLine> createState() => _KaraokeLineState();
}

class _KaraokeLineState extends ConsumerState<KaraokeLine>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  /// Ticker 单调时钟的最新读数。
  Duration _lastElapsed = Duration.zero;

  /// 锚点：`_anchorPos` 是最近一次权威播放位置，对应 ticker 时钟 `_anchorElapsedMicros`。
  Duration _anchorPos = Duration.zero;
  int _anchorElapsedMicros = 0;
  bool _playing = false;

  /// 当前估计播放位置（驱动渲染）。
  Duration _estimated = Duration.zero;

  @override
  void initState() {
    super.initState();
    final ps = ref.read(playerStateProvider);
    _anchorPos = ps.currentTime;
    _estimated = ps.currentTime;
    _playing = ps.isPlaying;
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    _lastElapsed = elapsed;
    final est = _playing
        ? _anchorPos +
            Duration(microseconds: elapsed.inMicroseconds - _anchorElapsedMicros)
        : _anchorPos;
    // 变化超过约一帧才重绘，避免无谓 setState。
    if ((est.inMicroseconds - _estimated.inMicroseconds).abs() >= 16000) {
      setState(() => _estimated = est);
    }
  }

  /// 用权威位置 [pos] 重新锚定（seek / 周期采样 / 播放态切换）。
  /// 主动请求重绘：暂停态下 seek 不会有 ticker 变化触发重绘。
  void _reanchor(Duration pos) {
    _anchorPos = pos;
    _anchorElapsedMicros = _lastElapsed.inMicroseconds;
    _estimated = pos;
    if (mounted) setState(() {});
  }

  double _wordProgress(LyricWord w) {
    final est = _estimated.inMicroseconds;
    final s = w.start.inMicroseconds;
    final e = w.end.inMicroseconds;
    if (e <= s) return est >= s ? 1.0 : 0.0;
    if (est >= e) return 1.0;
    if (est <= s) return 0.0;
    return (est - s) / (e - s);
  }

  @override
  Widget build(BuildContext context) {
    // 权威播放位置更新 → 重新锚定。
    ref.listen(playerStateProvider.select((s) => s.currentTime), (_, next) {
      _reanchor(next);
    });
    // 播放/暂停切换 → 以当前估计位置为锚，避免跳变。
    ref.listen(playerStateProvider.select((s) => s.isPlaying), (_, next) {
      _reanchor(_estimated);
      _playing = next;
    });

    final words = widget.line.words!;
    final spans = <TextSpan>[
      for (final w in words)
        TextSpan(
          text: w.text,
          style: TextStyle(
            color: Color.lerp(
              widget.inactiveColor,
              widget.activeColor,
              _wordProgress(w),
            ),
            shadows: widget.shadows,
          ),
        ),
    ];

    return Text.rich(
      TextSpan(children: spans),
      textAlign: TextAlign.center,
      maxLines: widget.maxLines,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: widget.fontSize,
        fontWeight: widget.fontWeight,
        height: widget.height,
      ),
    );
  }
}
