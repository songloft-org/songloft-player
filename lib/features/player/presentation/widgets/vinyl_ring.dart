import 'package:flutter/material.dart';

/// 唱片环效果：封面周围的同心圆纹路 + 旋转动画
class VinylRing extends StatelessWidget {
  final Animation<double> rotationAnimation;
  final double ringExtent;
  final Widget child;

  const VinylRing({
    super.key,
    required this.rotationAnimation,
    this.ringExtent = 8.0,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final grooveColor =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06);

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Positioned(
          left: -ringExtent,
          top: -ringExtent,
          right: -ringExtent,
          bottom: -ringExtent,
          child: RotationTransition(
            turns: rotationAnimation,
            child: Opacity(
              opacity: 0.5,
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _VinylRingPainter(grooveColor: grooveColor),
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _VinylRingPainter extends CustomPainter {
  final Color grooveColor;

  const _VinylRingPainter({required this.grooveColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.shortestSide / 2;
    final paint = Paint()
      ..color = grooveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (double r = 3; r < maxRadius; r += 3) {
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(_VinylRingPainter oldDelegate) =>
      grooveColor != oldDelegate.grooveColor;
}
