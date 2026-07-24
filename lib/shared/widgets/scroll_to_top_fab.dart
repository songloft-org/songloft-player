import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

class ScrollToTopFab extends StatefulWidget {
  const ScrollToTopFab({
    super.key,
    required this.scrollController,
    this.showThreshold = 500.0,
    this.bottomPadding = 80.0,
  });

  final ScrollController scrollController;
  final double showThreshold;
  final double bottomPadding;

  @override
  State<ScrollToTopFab> createState() => _ScrollToTopFabState();
}

class _ScrollToTopFabState extends State<ScrollToTopFab> {
  bool _show = false;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(ScrollToTopFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_onScroll);
      widget.scrollController.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    final shouldShow = widget.scrollController.hasClients &&
        widget.scrollController.offset > widget.showThreshold;
    if (shouldShow != _show) {
      setState(() => _show = shouldShow);
    }
  }

  void _scrollToTop() {
    if (!widget.scrollController.hasClients) return;
    widget.scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: widget.bottomPadding,
      child: IgnorePointer(
        ignoring: !_show,
        child: AnimatedOpacity(
          opacity: _show ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: AnimatedScale(
            scale: _show ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: FloatingActionButton.small(
              onPressed: _scrollToTop,
              tooltip: AppLocalizations.of(context).scrollToTop,
              child: const Icon(Icons.arrow_upward),
            ),
          ),
        ),
      ),
    );
  }
}
