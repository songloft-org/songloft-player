import 'package:flutter/material.dart';

/// 全局间距规范（基于 8px 基数）
class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// 全局圆角规范
class AppRadius {
  AppRadius._();
  static const double sm = 8; // 小组件（图标、标签）
  static const double md = 12; // 卡片、输入框
  static const double lg = 16; // 封面、大面板
  static const double xl = 24; // 搜索栏、胶囊按钮
  static const double xxl = 28; // 播放按钮、大胶囊

  // 便捷 BorderRadius
  static final BorderRadius smAll = BorderRadius.circular(sm);
  static final BorderRadius mdAll = BorderRadius.circular(md);
  static final BorderRadius lgAll = BorderRadius.circular(lg);
  static final BorderRadius xlAll = BorderRadius.circular(xl);
  static final BorderRadius xxlAll = BorderRadius.circular(xxl);
}

/// 全局阴影规范
class AppShadows {
  AppShadows._();
  static const List<BoxShadow> light = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.06),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];
  static const List<BoxShadow> medium = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.08),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];
  static const List<BoxShadow> heavy = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.15),
      blurRadius: 20,
      offset: Offset(0, 10),
    ),
  ];
}

/// 视觉特效（glow 发光阴影）
class AppEffects {
  AppEffects._();

  /// 主色发光 — 播放按钮、封面强调
  static List<BoxShadow> primaryGlow(Color primaryColor) => [
    BoxShadow(
      color: primaryColor.withValues(alpha: 0.30),
      spreadRadius: 1,
    ),
    BoxShadow(
      color: primaryColor.withValues(alpha: 0.45),
      blurRadius: 40,
      offset: const Offset(0, 18),
      spreadRadius: -10,
    ),
    const BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.45),
      blurRadius: 18,
      offset: Offset(0, 6),
      spreadRadius: -4,
    ),
  ];

  /// 柔和发光 — 封面、浮动卡片
  static List<BoxShadow> softGlow(Color onSurfaceColor) => [
    BoxShadow(
      color: onSurfaceColor.withValues(alpha: 0.08),
      spreadRadius: 1,
    ),
    const BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.55),
      blurRadius: 60,
      offset: Offset(0, 30),
      spreadRadius: -20,
    ),
  ];
}
