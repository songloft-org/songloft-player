import 'package:flutter/material.dart';

import '../../features/settings/data/theme_pack_api.dart';
import 'app_dimensions.dart';
import 'responsive.dart';

/// 自定义主题扩展，承载主题包特有的参数（圆角、渐变、玻璃色等）
class SongloftThemeExtension extends ThemeExtension<SongloftThemeExtension> {
  final List<Color>? playerGradientColors;
  final double cardRadius;
  final double controlRadius;
  final double navigationRadius;

  // Liquid Glass tokens
  final Color glassFill;
  final Color glassFillStrong;
  final Color glassBorder;
  final Color glassHighlight;
  final Color glassGlow;
  final Color glassGlowFaint;
  final Color glassSheen;
  final String navigationStyle;

  const SongloftThemeExtension({
    this.playerGradientColors,
    this.cardRadius = AppRadius.md,
    this.controlRadius = AppRadius.md,
    this.navigationRadius = AppRadius.md,
    this.glassFill = const Color(0xB8FFFFFF),
    this.glassFillStrong = const Color(0xD9FFFFFF),
    this.glassBorder = const Color(0x73FFFFFF),
    this.glassHighlight = const Color(0x99FFFFFF),
    this.glassGlow = const Color(0xFF3BAEEF),
    this.glassGlowFaint = const Color(0x193BAEEF),
    this.glassSheen = const Color(0x2E3BAEEF),
    this.navigationStyle = 'standard',
  });

  @override
  SongloftThemeExtension copyWith({
    List<Color>? playerGradientColors,
    double? cardRadius,
    double? controlRadius,
    double? navigationRadius,
    Color? glassFill,
    Color? glassFillStrong,
    Color? glassBorder,
    Color? glassHighlight,
    Color? glassGlow,
    Color? glassGlowFaint,
    Color? glassSheen,
    String? navigationStyle,
  }) {
    return SongloftThemeExtension(
      playerGradientColors: playerGradientColors ?? this.playerGradientColors,
      cardRadius: cardRadius ?? this.cardRadius,
      controlRadius: controlRadius ?? this.controlRadius,
      navigationRadius: navigationRadius ?? this.navigationRadius,
      glassFill: glassFill ?? this.glassFill,
      glassFillStrong: glassFillStrong ?? this.glassFillStrong,
      glassBorder: glassBorder ?? this.glassBorder,
      glassHighlight: glassHighlight ?? this.glassHighlight,
      glassGlow: glassGlow ?? this.glassGlow,
      glassGlowFaint: glassGlowFaint ?? this.glassGlowFaint,
      glassSheen: glassSheen ?? this.glassSheen,
      navigationStyle: navigationStyle ?? this.navigationStyle,
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
      glassFill: Color.lerp(glassFill, other.glassFill, t) ?? glassFill,
      glassFillStrong:
          Color.lerp(glassFillStrong, other.glassFillStrong, t) ??
          glassFillStrong,
      glassBorder:
          Color.lerp(glassBorder, other.glassBorder, t) ?? glassBorder,
      glassHighlight:
          Color.lerp(glassHighlight, other.glassHighlight, t) ??
          glassHighlight,
      glassGlow: Color.lerp(glassGlow, other.glassGlow, t) ?? glassGlow,
      glassGlowFaint:
          Color.lerp(glassGlowFaint, other.glassGlowFaint, t) ??
          glassGlowFaint,
      glassSheen: Color.lerp(glassSheen, other.glassSheen, t) ?? glassSheen,
      navigationStyle: t < 0.5 ? navigationStyle : other.navigationStyle,
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

    // 玻璃色：从主题包取 glassColor，无则回落星蓝基线
    final glassBase = themeColors?.glassColor ??
        (isLight ? const Color(0xFF3BAEEF) : const Color(0xFF5BC0F5));
    final glassFill = isLight
        ? const Color(0xB8FFFFFF)   // white @ 0.72
        : const Color(0xAD1C1C1E); // #1C1C1E @ 0.68
    final glassFillStrong = isLight
        ? const Color(0xD9FFFFFF)   // white @ 0.85
        : const Color(0xD11C1C1E); // #1C1C1E @ 0.82
    final glassBorder = isLight
        ? const Color(0x73FFFFFF)   // white @ 0.45
        : const Color(0x1FFFFFFF); // white @ 0.12
    final glassHighlight = isLight
        ? const Color(0x99FFFFFF)   // white @ 0.60
        : const Color(0x26FFFFFF); // white @ 0.15
    final glassGlowFaint = glassBase.withAlpha(isLight ? 26 : 36);  // 0.10 / 0.14
    final glassSheen = glassBase.withAlpha(isLight ? 46 : 26);      // 0.18 / 0.10

    // 主题扩展
    final extension = SongloftThemeExtension(
      playerGradientColors: themePack?.playerGradient,
      cardRadius: cardRadius,
      controlRadius: controlRadius,
      navigationRadius: navigationRadius,
      glassFill: glassFill,
      glassFillStrong: glassFillStrong,
      glassBorder: glassBorder,
      glassHighlight: glassHighlight,
      glassGlow: glassBase,
      glassGlowFaint: glassGlowFaint,
      glassSheen: glassSheen,
      navigationStyle: themePack?.navigationStyle ?? 'standard',
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
        backgroundColor: glassFill,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: glassGlowFaint,
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
