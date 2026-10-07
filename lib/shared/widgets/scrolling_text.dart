import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/presentation/providers/song_title_scrolling_provider.dart';

/// 自动滚动文本组件
/// 当文本溢出时自动水平滚动显示完整内容
class ScrollingText extends ConsumerWidget {
  /// 要显示的文本
  final String text;

  /// 文本样式
  final TextStyle? style;

  /// 滚动速度（像素/秒）
  final double velocity;

  /// 滚动前后的暂停时间
  final Duration pauseDuration;

  const ScrollingText({
    super.key,
    required this.text,
    this.style,
    this.velocity = 30.0,
    this.pauseDuration = const Duration(seconds: 2),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(songTitleScrollingProvider);
    return Semantics(
      // 保留完整文本，静态省略与滚动容器都不改变读屏内容。
      label: text,
      child: ExcludeSemantics(
        child:
            enabled
                ? _AnimatedScrollingText(
                  text: text,
                  style: style,
                  velocity: velocity,
                  pauseDuration: pauseDuration,
                )
                : Text(
                  text,
                  style: style,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                ),
      ),
    );
  }
}

class _AnimatedScrollingText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final double velocity;
  final Duration pauseDuration;

  const _AnimatedScrollingText({
    required this.text,
    this.style,
    required this.velocity,
    required this.pauseDuration,
  });

  @override
  State<_AnimatedScrollingText> createState() => _ScrollingTextState();
}

class _ScrollingTextState extends State<_AnimatedScrollingText>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  bool _isOverflowing = false;
  bool _isScrolling = false;

  // 代计数器：文本/宽度变化时 +1，使仍停留在 await 中的旧滚动循环失效退出，
  // 避免新旧两个循环同时驱动同一个 controller
  int _generation = 0;
  double _lastMaxWidth = 0;
  Timer? _pauseTimer;
  Completer<void>? _pauseCompleter;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOverflow();
    });
  }

  @override
  void didUpdateWidget(_AnimatedScrollingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _restart();
    }
  }

  void _restart() {
    _generation++;
    _isScrolling = false;
    _cancelPause();
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOverflow();
    });
  }

  @override
  void dispose() {
    _cancelPause();
    _scrollController.dispose();
    super.dispose();
  }

  void _cancelPause() {
    _pauseTimer?.cancel();
    _pauseTimer = null;
    _pauseCompleter?.complete();
    _pauseCompleter = null;
  }

  Future<void> _pause() {
    final completer = Completer<void>();
    _pauseCompleter = completer;
    _pauseTimer = Timer(widget.pauseDuration, () {
      _pauseTimer = null;
      _pauseCompleter = null;
      completer.complete();
    });
    return completer.future;
  }

  void _checkOverflow() {
    if (!mounted || !_scrollController.hasClients) return;

    final maxScrollExtent = _scrollController.position.maxScrollExtent;
    final overflow = maxScrollExtent > 0;

    if (overflow != _isOverflowing) {
      setState(() {
        _isOverflowing = overflow;
      });
    }

    if (_isOverflowing && !_isScrolling) {
      _startScrolling();
    }
  }

  Future<void> _startScrolling() async {
    if (!mounted || !_isOverflowing) return;
    _isScrolling = true;
    final generation = _generation;
    bool alive() =>
        mounted &&
        _isScrolling &&
        generation == _generation &&
        _scrollController.hasClients;

    while (alive() && _isOverflowing) {
      // 暂停在开头
      await _pause();
      if (!alive()) return;

      // 计算滚动时长
      final maxScrollExtent = _scrollController.position.maxScrollExtent;
      final duration = Duration(
        milliseconds: (maxScrollExtent / widget.velocity * 1000).round(),
      );

      // 滚动到末尾
      await _scrollController.animateTo(
        maxScrollExtent,
        duration: duration,
        curve: Curves.linear,
      );
      if (!alive()) return;

      // 暂停在末尾
      await _pause();
      if (!alive()) return;

      // 滚动回开头
      await _scrollController.animateTo(
        0,
        duration: duration,
        curve: Curves.linear,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth != _lastMaxWidth) {
          _lastMaxWidth = constraints.maxWidth;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _restart();
          });
        }
        return SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Text(
            widget.text,
            style: widget.style,
            maxLines: 1,
            softWrap: false,
          ),
        );
      },
    );
  }
}
