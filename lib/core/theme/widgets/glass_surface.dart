import 'dart:ui';

import 'package:flutter/material.dart';

import '../app_dimensions.dart';
import '../app_theme.dart';
import 'glass_backdrop_filter.dart';

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
    final fill =
        strong
            ? (ext?.glassFillStrong ?? _fallbackFillStrong)
            : (ext?.glassFill ?? _fallbackFill);
    final border = ext?.glassBorder ?? _fallbackBorder;
    final highlight = ext?.glassHighlight ?? _fallbackHighlight;

    return ClipRRect(
      borderRadius: borderRadius,
      child: GlassBackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: Container(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: borderRadius,
            border: showBorder ? Border.all(color: border, width: 0.5) : null,
            boxShadow:
                boxShadow ??
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
                // 终点必须是「同色透明」而不是 `Colors.transparent`：
                // `Colors.transparent` 是透明**黑**，而渐变色是按未预乘的 RGBA
                // 逐通道插值的，白 60% → 透明黑会在中途插出灰 30% —— 落在半透玻璃
                // 上就是顶边一条 30% 高度的暗带（比页面背景还暗 30 级），看着就像
                // 玻璃自带一圈很重的阴影。用 `highlight.withValues(alpha: 0)` 则全程
                // 只有一个亮度递减的白色，只会提亮、不会压暗。
                colors: [highlight, highlight.withValues(alpha: 0)],
              ),
            ),
            child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
          ),
        ),
      ),
    );
  }
}
