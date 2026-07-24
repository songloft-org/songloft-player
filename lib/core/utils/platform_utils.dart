import 'dart:io';

import 'package:flutter/foundation.dart';

/// 平台检测工具类
class PlatformUtils {
  PlatformUtils._();

  /// 是否是 Android 平台
  static bool get isAndroid {
    if (kIsWeb) return false;
    return Platform.isAndroid;
  }

  /// 是否是 iOS 平台
  static bool get isIOS {
    if (kIsWeb) return false;
    return Platform.isIOS;
  }

  /// 是否是移动平台（Android 或 iOS）
  static bool get isMobile {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// 是否是桌面平台
  static bool get isDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  /// 是否是 Web 平台
  static bool get isWeb => kIsWeb;

  /// 是否是 Windows 平台
  static bool get isWindows {
    if (kIsWeb) return false;
    return Platform.isWindows;
  }

  /// 是否可能是 Android TV
  /// 
  /// 注意：这只是一个基础判断，实际的 TV 检测需要结合屏幕尺寸。
  /// 在 Flutter 中，最准确的 TV 检测方式是：
  /// Android 平台 + 大屏幕（>= 1920 宽）+ 无触摸屏
  /// 
  /// 实际使用时应配合 context.isTv 使用：
  /// ```dart
  /// if (PlatformUtils.isAndroid && context.isTv) {
  ///   // Android TV specific code
  /// }
  /// ```
  static bool get isPotentiallyTv {
    if (kIsWeb) return false;
    // Android TV 应用只能在 Android 平台运行
    // 实际是否为 TV 需要结合屏幕尺寸判断
    return Platform.isAndroid;
  }

  /// 是否支持触摸操作
  /// 
  /// TV 设备通常不支持触摸，主要通过遥控器的 D-Pad 操作
  /// 但这在纯 Dart 层面无法准确检测，需要使用平台通道
  static bool get supportsTouchInput {
    if (kIsWeb) return true;
    // 移动设备支持触摸
    if (Platform.isAndroid || Platform.isIOS) return true;
    // 桌面设备假设支持鼠标/触摸
    return true;
  }

  /// 获取当前平台名称
  static String get platformName {
    if (kIsWeb) return 'Web';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }
}
