import 'package:flutter/material.dart';

import '../../features/settings/data/theme_pack_api.dart';
import 'app_dimensions.dart';
import 'responsive.dart';

/// 自定义主题扩展，承载主题包特有的参数（圆角、渐变等）
class SongloftThemeExtension extends ThemeExtension<SongloftThemeExtension> {
  final List<Color>? playerGradientColors;
  final double cardRadius;
  final double controlRadius;
  final double navigationRadius;

  const SongloftThemeExtension({
    this.playerGradientColors,
    this.cardRadius = AppRadius.md,
    this.controlRadius = AppRadius.md,
    this.navigationRadius = AppRadius.md,
  });

  @override
  SongloftThemeExtension copyWith({
    List<Color>? playerGradientColors,
    double? cardRadius,
    double? controlRadius,
    double? navigationRadius,
  }) {
    return SongloftThemeExtension(
      playerGradientColors: playerGradientColors ?? this.playerGradientColors,
      cardRadius: cardRadius ?? this.cardRadius,
      controlRadius: controlRadius ?? this.controlRadius,
      navigationRadius: navigationRadius ?? this.navigationRadius,
    );
  }

  @override
  SongloftThemeExtension lerp(
    covariant ThemeExtension<SongloftThemeExtension>? other,
    double t,
  ) {
    if (other is! SongloftThemeExtension) return this;
    return SongloftThemeExtension(
      playerGradientColors:
          t < 0.5 ? playerGradientColors : other.playerGradientColors,
      cardRadius: lerpDouble(cardRadius, other.cardRadius, t) ?? cardRadius,
      controlRadius:
          lerpDouble(controlRadius, other.controlRadius, t) ?? controlRadius,
      navigationRadius:
          lerpDouble(navigationRadius, other.navigationRadius, t) ??
          navigationRadius,
    );
  }

  static double? lerpDouble(double? a, double? b, double t) {
    if (a == null && b == null) return null;
    a ??= 0.0;
    b ??= 0.0;
    return a + (b - a) * t;
  }
}

class AppTheme {
  // M3 Blue baseline — 与设计系统对齐
  static const Color _defaultSeedColor = Color(0xFF415F91);

  /// 亮色主题
  /// [screenType] 屏幕类型，默认为 mobile
  /// [themePack] 可选主题包
  static ThemeData lightTheme({
    ScreenType screenType = ScreenType.mobile,
    ThemePack? themePack,
  }) {
    return _buildTheme(Brightness.light, screenType, themePack);
  }

  /// 暗色主题
  /// [screenType] 屏幕类型，默认为 mobile
  /// [themePack] 可选主题包
  static ThemeData darkTheme({
    ScreenType screenType = ScreenType.mobile,
    ThemePack? themePack,
  }) {
    return _buildTheme(Brightness.dark, screenType, themePack);
  }

  /// 构建主题的统一方法
  static ThemeData _buildTheme(
    Brightness brightness,
    ScreenType screenType,
    ThemePack? themePack,
  ) {
    final isDesktop = screenType == ScreenType.desktop;
    final isLight = brightness == Brightness.light;

    // 从主题包获取配色
    final themeColors = isLight ? themePack?.light : themePack?.dark;
    final seedColor = themeColors?.seedColor ?? _defaultSeedColor;

    // 生成 ColorScheme
    var colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );

    // 覆盖 surface/background
    if (themeColors?.backgroundColor != null ||
        themeColors?.surfaceColor != null) {
      colorScheme = colorScheme.copyWith(
        surface: themeColors?.surfaceColor ?? themeColors?.backgroundColor,
        surfaceContainerLowest: themeColors?.backgroundColor,
      );
    }

    // 主题包圆角
    final cardRadius = themePack?.cardRadius ?? AppRadius.md;
    final controlRadius = themePack?.controlRadius ?? AppRadius.md;
    final navigationRadius = themePack?.navigationRadius ?? AppRadius.md;

    final cardBorderRadius = BorderRadius.circular(cardRadius);
    final controlBorderRadius = BorderRadius.circular(controlRadius);

    // 主题扩展
    final extension = SongloftThemeExtension(
      playerGradientColors: themePack?.playerGradient,
      cardRadius: cardRadius,
      controlRadius: controlRadius,
      navigationRadius: navigationRadius,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamilyFallback: const ['NotoSansSC', 'NotoSansKR', 'sans-serif'],
      colorScheme: colorScheme,
      extensions: [extension],
      appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: cardBorderRadius),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: controlBorderRadius),
        filled: true,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(navigationRadius),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        insetPadding:
            isDesktop
                ? const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
                : null,
        width: isDesktop ? 480 : null,
      ),
      filledButtonTheme:
          isDesktop
              ? FilledButtonThemeData(
                style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
              )
              : null,
      outlinedButtonTheme:
          isDesktop
              ? OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(88, 44),
                ),
              )
              : null,
      textButtonTheme:
          isDesktop
              ? TextButtonThemeData(
                style: TextButton.styleFrom(minimumSize: const Size(88, 44)),
              )
              : null,
    );
  }
}
