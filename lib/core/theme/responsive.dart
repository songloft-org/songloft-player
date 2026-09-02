import 'package:flutter/material.dart';

import 'app_theme.dart';

enum ScreenType { mobile, tablet, desktop, widescreen }

class ResponsiveBreakpoints {
  static const double mobile = 0;
  static const double tablet = 600;
  static const double desktop = 900;
}

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  bool get isMobile => screenWidth < ResponsiveBreakpoints.tablet;
  bool get isTablet =>
      screenWidth >= ResponsiveBreakpoints.tablet &&
      screenWidth < ResponsiveBreakpoints.desktop;
  bool get isDesktop => screenWidth >= ResponsiveBreakpoints.desktop;

  /// 超宽屏模式：宽度 >= 900 且宽高比 > 2.2:1（横向超宽屏幕）
  bool get isWidescreen {
    if (screenWidth < ResponsiveBreakpoints.desktop) return false;
    if (screenHeight <= 0) return false;
    return screenWidth / screenHeight > 2.2;
  }

  ScreenType get screenType {
    if (isWidescreen) return ScreenType.widescreen;
    if (isDesktop) return ScreenType.desktop;
    if (isTablet) return ScreenType.tablet;
    return ScreenType.mobile;
  }

  bool get isLandscape =>
      MediaQuery.orientationOf(this) == Orientation.landscape;
  bool get isPortrait => MediaQuery.orientationOf(this) == Orientation.portrait;

  /// 是否是宽屏（平板以上）
  bool get isWideScreen => screenWidth >= ResponsiveBreakpoints.tablet;

  /// 全站统一的双栏（主从）布局判断：平板及以上的常规宽屏（含超宽屏 isWidescreen）。
  /// 超宽屏（桌面超宽显示器）空间充裕，采用桌面两栏更合理。
  /// 所有需要「左右分栏 vs 单列」分叉的页面都应引用此 getter，
  /// 避免各处各写断点组合导致漂移 (songloft-org/songloft#268)。
  bool get useWideLayout => isWideScreen;

  /// 根据屏幕类型返回不同值
  T responsive<T>({required T mobile, T? tablet, T? desktop, T? widescreen}) {
    switch (screenType) {
      case ScreenType.widescreen:
        return widescreen ?? desktop ?? tablet ?? mobile;
      case ScreenType.desktop:
        return desktop ?? tablet ?? mobile;
      case ScreenType.tablet:
        return tablet ?? mobile;
      case ScreenType.mobile:
        return mobile;
    }
  }

  /// 获取响应式按钮最小尺寸
  Size get responsiveButtonMinSize {
    switch (screenType) {
      case ScreenType.widescreen:
        return const Size(112, 56);
      case ScreenType.desktop:
        return const Size(88, 44);
      case ScreenType.tablet:
        return const Size(80, 40);
      case ScreenType.mobile:
        return const Size(64, 36);
    }
  }

  /// 底部滚动间距（等价 Lynx --nav-inset）。
  /// capsule 模式 extendBody: true → padding.bottom 已含胶囊高度，加 16px 呼吸空间；
  /// standard 模式 extendBody: false → 手动加 80px 腾出导航栏空间。
  double get navScrollInset {
    final ext = Theme.of(this).extension<SongloftThemeExtension>();
    final bottom = MediaQuery.paddingOf(this).bottom;
    if (ext?.navigationStyle == 'capsule') return bottom + 16;
    return bottom + 80;
  }

  /// 获取响应式对话框最大宽度
  double get responsiveDialogMaxWidth {
    switch (screenType) {
      case ScreenType.widescreen:
        return 420;
      case ScreenType.desktop:
        return 480;
      case ScreenType.tablet:
        return 400;
      case ScreenType.mobile:
        return 300;
    }
  }
}
