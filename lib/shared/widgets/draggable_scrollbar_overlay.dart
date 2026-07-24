import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_dimensions.dart';
import '../../core/theme/responsive.dart';

class DraggableScrollbarOverlay extends StatefulWidget {
  const DraggableScrollbarOverlay({
    super.key,
    required this.child,
    required this.scrollController,
    required this.totalItemCount,
    this.estimatedItemHeight = 72.0,
    this.headerExtent = 0.0,
    this.enabled = true,
    this.labelBuilder,
    this.onDragToUnloaded,
  });

  final Widget child;
  final ScrollController scrollController;
  final int totalItemCount;
  final double estimatedItemHeight;
  final double headerExtent;
  final bool enabled;
  final String Function(int index, int total)? labelBuilder;
  final Future<void> Function()? onDragToUnloaded;

  @override
  State<DraggableScrollbarOverlay> createState() =>
      _DraggableScrollbarOverlayState();
}

class _DraggableScrollbarOverlayState extends State<DraggableScrollbarOverlay> {
  static const double _trackWidth = 4.0;
  static const double _thumbWidth = 6.0;
  static const double _thumbMinHeight = 40.0;
  static const double _trackRightMargin = 4.0;
  static const double _hitAreaWidth = 32.0;
  static const double _trackVerticalPadding = 4.0;

  bool _isDragging = false;
  double _dragThumbFraction = 0.0;
  bool _isVisible = false;
  Timer? _hideTimer;
  bool _isLoadingAll = false;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(DraggableScrollbarOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_onScroll);
      widget.scrollController.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    _hideTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (!widget.enabled || _isDragging) return;
    if (!mounted) return;
    setState(() => _isVisible = true);
    _resetHideTimer();
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    if (context.isDesktop) return;
    _hideTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted && !_isDragging) {
        setState(() => _isVisible = false);
      }
    });
  }

  double _scrollFraction() {
    if (!widget.scrollController.hasClients) return 0.0;
    final position = widget.scrollController.position;
    if (position.maxScrollExtent <= 0) return 0.0;

    final songOffset =
        math.max(0.0, position.pixels - widget.headerExtent);
    final totalSongExtent =
        widget.totalItemCount * widget.estimatedItemHeight;
    if (totalSongExtent <= 0) return 0.0;
    return (songOffset / totalSongExtent).clamp(0.0, 1.0);
  }

  int _currentIndex() {
    if (!widget.scrollController.hasClients) return 0;
    final songOffset = math.max(
      0.0,
      widget.scrollController.offset - widget.headerExtent,
    );
    final index = (songOffset / widget.estimatedItemHeight).floor();
    return index.clamp(0, widget.totalItemCount);
  }

  int _indexFromFraction(double fraction) {
    return (fraction * widget.totalItemCount)
        .round()
        .clamp(0, widget.totalItemCount);
  }

  double _thumbHeight(double trackHeight) {
    if (widget.totalItemCount <= 0) return _thumbMinHeight;
    if (!widget.scrollController.hasClients) return _thumbMinHeight;
    final viewportHeight =
        widget.scrollController.position.viewportDimension;
    final visibleItems = viewportHeight / widget.estimatedItemHeight;
    final fraction = visibleItems / widget.totalItemCount;
    return math.max(_thumbMinHeight, trackHeight * fraction);
  }

  void _onDragStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
      _dragThumbFraction = _scrollFraction();
    });
    _hideTimer?.cancel();
  }

  void _onDragUpdate(DragUpdateDetails details, double trackHeight) {
    final thumbH = _thumbHeight(trackHeight);
    final scrollableTrack = trackHeight - thumbH;
    if (scrollableTrack <= 0) return;

    final newFraction =
        (_dragThumbFraction + details.delta.dy / scrollableTrack).clamp(0.0, 1.0);
    setState(() => _dragThumbFraction = newFraction);

    _scrollToFraction(newFraction, jump: true);
  }

  void _onDragEnd(DragEndDetails details) {
    final targetFraction = _dragThumbFraction;
    setState(() => _isDragging = false);
    _scrollToFraction(targetFraction, jump: false);
    _resetHideTimer();
  }

  void _onTapTrack(TapUpDetails details, double trackHeight) {
    final thumbH = _thumbHeight(trackHeight);
    final scrollableTrack = trackHeight - thumbH;
    if (scrollableTrack <= 0) return;

    final tapY = details.localPosition.dy - _trackVerticalPadding;
    final fraction = (tapY / scrollableTrack).clamp(0.0, 1.0);
    setState(() {
      _isDragging = false;
      _dragThumbFraction = fraction;
      _isVisible = true;
    });
    _scrollToFraction(fraction, jump: false);
    _resetHideTimer();
  }

  void _scrollToFraction(double fraction, {required bool jump}) {
    if (!widget.scrollController.hasClients) return;
    final position = widget.scrollController.position;

    final targetOffset =
        fraction * widget.totalItemCount * widget.estimatedItemHeight +
            widget.headerExtent;

    if (targetOffset <= position.maxScrollExtent) {
      if (jump) {
        widget.scrollController.jumpTo(targetOffset);
      } else {
        widget.scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        );
      }
    } else if (jump) {
      widget.scrollController.jumpTo(position.maxScrollExtent);
    } else if (!_isLoadingAll) {
      _loadAllAndScroll(targetOffset);
    }
  }

  Future<void> _loadAllAndScroll(double targetOffset) async {
    if (widget.onDragToUnloaded == null) return;
    setState(() => _isLoadingAll = true);
    try {
      await widget.onDragToUnloaded!();
      if (!mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      if (widget.scrollController.hasClients) {
        final maxExtent =
            widget.scrollController.position.maxScrollExtent;
        widget.scrollController.animateTo(
          math.min(targetOffset, maxExtent),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || widget.totalItemCount <= 0) {
      return widget.child;
    }

    return Stack(
      children: [
        widget.child,
        if (context.isDesktop || _isVisible || _isDragging)
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            width: _hitAreaWidth,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final trackHeight =
                    constraints.maxHeight - _trackVerticalPadding * 2;
                if (trackHeight <= _thumbMinHeight) return const SizedBox();
                return _buildScrollbar(context, trackHeight);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildScrollbar(BuildContext context, double trackHeight) {
    final colorScheme = Theme.of(context).colorScheme;
    final thumbH = _thumbHeight(trackHeight);
    final scrollableTrack = trackHeight - thumbH;

    final fraction = _isDragging ? _dragThumbFraction : _scrollFraction();
    final thumbTop =
        _trackVerticalPadding + (scrollableTrack * fraction).clamp(0.0, scrollableTrack);

    final displayIndex = _isDragging
        ? _indexFromFraction(_dragThumbFraction)
        : _currentIndex();

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragStart: _onDragStart,
      onVerticalDragUpdate: (d) => _onDragUpdate(d, trackHeight),
      onVerticalDragEnd: _onDragEnd,
      onTapUp: (d) => _onTapTrack(d, trackHeight),
      child: AnimatedOpacity(
        opacity: (_isDragging || _isVisible || context.isDesktop) ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Track
            Positioned(
              top: _trackVerticalPadding,
              bottom: _trackVerticalPadding,
              right: _trackRightMargin,
              width: _trackWidth,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                  borderRadius: AppRadius.smAll,
                ),
              ),
            ),
            // Thumb
            Positioned(
              top: thumbTop,
              right: _trackRightMargin - (_thumbWidth - _trackWidth) / 2,
              width: _thumbWidth,
              height: thumbH,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _isDragging
                      ? colorScheme.primary.withValues(alpha: 0.8)
                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  borderRadius: AppRadius.smAll,
                ),
              ),
            ),
            // Position label
            if (_isDragging && widget.labelBuilder != null)
              Positioned(
                top: thumbTop + thumbH / 2 - 16,
                right: _hitAreaWidth + AppSpacing.sm,
                child: _buildLabel(context, displayIndex),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(BuildContext context, int index) {
    final colorScheme = Theme.of(context).colorScheme;
    final text = widget.labelBuilder!(
      math.min(index + 1, widget.totalItemCount),
      widget.totalItemCount,
    );

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface,
          borderRadius: AppRadius.smAll,
          boxShadow: AppShadows.light,
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colorScheme.onInverseSurface,
              ),
        ),
      ),
    );
  }
}
