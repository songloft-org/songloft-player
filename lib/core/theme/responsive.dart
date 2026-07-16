import 'package:flutter/material.dart';

enum ScreenType { mobile, tablet, desktop, auto_, tv }

class ResponsiveBreakpoints {
  static const double mobile = 0;
  static const double tablet = 600;
  static const double desktop = 900;
  static const double tv = 1920;
}

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;

  bool get isMobile => screenWidth < ResponsiveBreakpoints.tablet;
  bool get isTablet =>
      screenWidth >= ResponsiveBreakpoints.tablet &&
      screenWidth < ResponsiveBreakpoints.desktop;
  bool get isDesktop =>
      screenWidth >= ResponsiveBreakpoints.desktop &&
      screenWidth < ResponsiveBreakpoints.tv;
  bool get isTv => screenWidth >= ResponsiveBreakpoints.tv;

  /// 车机模式：宽度 >= 900 且宽高比 > 2.2:1（横向超宽屏幕）
  bool get isAuto {
    if (screenWidth < ResponsiveBreakpoints.desktop) return false;
    if (screenHeight <= 0) return false;
    return screenWidth / screenHeight > 2.2;
  }

  ScreenType get screenType {
    // 车机模式优先于其他宽屏断点（desktop/tv），因为它靠宽高比区分
    if (isAuto) return ScreenType.auto_;
    if (isTv) return ScreenType.tv;
    if (isDesktop) return ScreenType.desktop;
    if (isTablet) return ScreenType.tablet;
    return ScreenType.mobile;
  }

  bool get isLandscape =>
      MediaQuery.of(this).orientation == Orientation.landscape;
  bool get isPortrait =>
      MediaQuery.of(this).orientation == Orientation.portrait;

  /// 是否是宽屏（平板以上）
  bool get isWideScreen => screenWidth >= ResponsiveBreakpoints.tablet;

  /// 全站统一的双栏（主从）布局判断：平板及以上的常规宽屏（含超宽屏 isAuto），
  /// 仅排除 TV（遥控器焦点导航走单栏更友好）。超宽屏（桌面超宽显示器 / 车机横屏）
  /// 空间充裕，采用桌面两栏更合理。所有需要「左右分栏 vs 单列」分叉的页面都应引用
  /// 此 getter，避免各处各写断点组合导致漂移 (songloft-org/songloft#268)。
  bool get useWideLayout => isWideScreen && !isTv;

  /// 根据屏幕类型返回不同值
  T responsive<T>({
    required T mobile,
    T? tablet,
    T? desktop,
    T? auto_,
    T? tv,
  }) {
    switch (screenType) {
      case ScreenType.tv:
        return tv ?? desktop ?? tablet ?? mobile;
      case ScreenType.auto_:
        return auto_ ?? desktop ?? tablet ?? mobile;
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
      case ScreenType.tv:
        return const Size(120, 56);
      case ScreenType.auto_:
        return const Size(112, 56);
      case ScreenType.desktop:
        return const Size(88, 44);
      case ScreenType.tablet:
        return const Size(80, 40);
      case ScreenType.mobile:
        return const Size(64, 36);
    }
  }

  /// 获取响应式对话框最大宽度
  double get responsiveDialogMaxWidth {
    switch (screenType) {
      case ScreenType.tv:
        return 600;
      case ScreenType.auto_:
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
