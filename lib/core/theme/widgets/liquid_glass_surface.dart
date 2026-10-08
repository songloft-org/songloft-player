import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../app_theme.dart';
import 'glass_surface.dart';

/// Shader availability is separate from appearance and route policy.
/// Without startup initialization, surfaces safely use the existing blur.
class SongloftGlassScope extends InheritedWidget {
  final bool enabled;

  const SongloftGlassScope({
    super.key,
    required this.enabled,
    required super.child,
  });

  static bool useShadersOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<SongloftGlassScope>();
    final ext = Theme.of(context).extension<SongloftThemeExtension>();
    return scope?.enabled == true &&
        ext?.opaqueGlass != true &&
        !GlassAccessibilityData.of(context).reduceTransparency;
  }

  @override
  bool updateShouldNotify(SongloftGlassScope oldWidget) =>
      enabled != oldWidget.enabled;
}

/// Material for floating controls, derived from the current Songloft theme.
LiquidGlassSettings songloftGlassSettings(
  BuildContext context, {
  double blur = 10,
}) {
  final theme = Theme.of(context);
  final ext = theme.extension<SongloftThemeExtension>();
  final fill = ext?.glassFill ?? theme.colorScheme.surfaceContainer;
  return LiquidGlassSettings(
    glassColor: fill.withValues(alpha: fill.a * .7),
    blur: blur,
    thickness: 24,
    lightIntensity: theme.brightness == Brightness.light ? .55 : .35,
    saturation: 1.1,
    chromaticAberration: 0,
    shadowElevation: 0,
  );
}

/// A clipped capsule material; its border does not consume layout space.
class LiquidGlassSurface extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final double sigma;
  final EdgeInsetsGeometry contentPadding;

  const LiquidGlassSurface({
    super.key,
    required this.child,
    required this.borderRadius,
    this.sigma = 12,
    this.contentPadding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<SongloftThemeExtension>();
    final border = ext?.glassBorder ?? theme.colorScheme.outlineVariant;
    final content = Padding(padding: contentPadding, child: child);
    if (SongloftGlassScope.useShadersOf(context)) {
      return GlassContainer(
        useOwnLayer: true,
        quality: GlassQuality.standard,
        shape: LiquidRoundedRectangle(
          borderRadius: borderRadius.topLeft.x,
          side: BorderSide(color: border, width: .5),
        ),
        clipBehavior: Clip.antiAlias,
        settings: songloftGlassSettings(context, blur: sigma / 2),
        child: content,
      );
    }
    return GlassSurface(
      borderRadius: borderRadius,
      sigma: sigma,
      showBorder: false,
      boxShadow: const [],
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          border: Border.all(color: border, width: .5),
        ),
        child: content,
      ),
    );
  }
}
