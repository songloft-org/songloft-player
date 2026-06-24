import 'package:flutter/material.dart';

import 'app_dimensions.dart';
import 'responsive.dart';

class AppTheme {
  // M3 Blue baseline — 与设计系统对齐
  static const Color _seedColor = Color(0xFF415F91);

  /// 亮色主题
  /// [screenType] 屏幕类型，默认为 mobile
  static ThemeData lightTheme({ScreenType screenType = ScreenType.mobile}) {
    return _buildTheme(Brightness.light, screenType);
  }

  /// 暗色主题
  /// [screenType] 屏幕类型，默认为 mobile
  static ThemeData darkTheme({ScreenType screenType = ScreenType.mobile}) {
    return _buildTheme(Brightness.dark, screenType);
  }

  /// 构建主题的统一方法
  static ThemeData _buildTheme(Brightness brightness, ScreenType screenType) {
    final isTv = screenType == ScreenType.tv;
    final isDesktopOrTv =
        screenType == ScreenType.desktop || screenType == ScreenType.tv;

    return ThemeData(
      useMaterial3: true,
      // 配置字体回退链，确保中文字符使用 Noto Sans SC
      fontFamilyFallback: const ['NotoSansSC', 'sans-serif'],
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: brightness,
      ),
      appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: AppRadius.mdAll),
        filled: true,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      // 响应式 SnackBar 主题
      // contentTextStyle 在 ResponsiveSnackBar widget 层控制，避免双重定义冲突
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            isDesktopOrTv ? (isTv ? AppRadius.md : AppRadius.sm) : AppRadius.sm,
          ),
        ),
        insetPadding:
            isDesktopOrTv
                ? (isTv
                    ? const EdgeInsets.symmetric(horizontal: 48, vertical: 24)
                    : const EdgeInsets.symmetric(horizontal: 24, vertical: 12))
                : null,
        width: isDesktopOrTv ? (isTv ? 600 : 480) : null,
      ),
      // 响应式 FilledButton 主题
      filledButtonTheme:
          isDesktopOrTv
              ? FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  minimumSize: isTv ? const Size(120, 56) : const Size(88, 44),
                  textStyle:
                      isTv
                          ? const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          )
                          : null,
                ),
              )
              : null,
      // 响应式 OutlinedButton 主题
      outlinedButtonTheme:
          isDesktopOrTv
              ? OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  minimumSize: isTv ? const Size(120, 56) : const Size(88, 44),
                  textStyle:
                      isTv
                          ? const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          )
                          : null,
                ),
              )
              : null,
      // 响应式 TextButton 主题
      textButtonTheme:
          isDesktopOrTv
              ? TextButtonThemeData(
                style: TextButton.styleFrom(
                  minimumSize: isTv ? const Size(120, 56) : const Size(88, 44),
                  textStyle:
                      isTv
                          ? const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          )
                          : null,
                ),
              )
              : null,
    );
  }
}
