import 'dart:ui';

import 'package:flutter/material.dart';

import '../app_dimensions.dart';
import '../app_theme.dart';

class GlassSurface extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final double sigma;
  final bool strong;
  final EdgeInsetsGeometry? padding;
  final List<BoxShadow>? boxShadow;
  final bool showBorder;

  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadius.lg)),
    this.sigma = 24,
    this.strong = false,
    this.padding,
    this.boxShadow,
    this.showBorder = true,
  });

  static const _fallbackFill = Color(0xB8FFFFFF);
  static const _fallbackFillStrong = Color(0xD9FFFFFF);
  static const _fallbackBorder = Color(0x73FFFFFF);
  static const _fallbackHighlight = Color(0x99FFFFFF);

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<SongloftThemeExtension>();
    final fill = strong
        ? (ext?.glassFillStrong ?? _fallbackFillStrong)
        : (ext?.glassFill ?? _fallbackFill);
    final border = ext?.glassBorder ?? _fallbackBorder;
    final highlight = ext?.glassHighlight ?? _fallbackHighlight;

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: Container(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: borderRadius,
            border: showBorder
                ? Border.all(color: border, width: 0.5)
                : null,
            boxShadow: boxShadow ??
                [
                  BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.3],
                colors: [highlight, Colors.transparent],
              ),
            ),
            child: Padding(
              padding: padding ?? EdgeInsets.zero,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
