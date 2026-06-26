import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import 'desktop_backend_service.dart';

/// 统一的内嵌后端服务接口。
/// - 移动端（Android/iOS）：通过 MethodChannel 调用 gomobile 生成的原生库
/// - 桌面端（macOS/Windows/Linux）：启动打包的 Go 二进制子进程
/// - Web：不支持
class EmbeddedBackendService {
  static const _channel = MethodChannel('com.songloft/backend');

  static bool get _isMobile =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static bool get _isDesktop =>
      !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  /// 检查 Go 后端是否可用（已打包进当前构建）
  static Future<bool> isAvailable() async {
    if (kIsWeb) return false;

    if (_isDesktop) {
      return DesktopBackendService.isAvailable();
    }

    if (_isMobile) {
      try {
        final result = await _channel.invokeMethod<bool>('isAvailable');
        return result ?? false;
      } on MissingPluginException {
        return false;
      } on PlatformException {
        return false;
      }
    }

    return false;
  }

  /// 启动内嵌后端，返回实际监听端口
  static Future<int> start({
    required String dataDir,
    required String musicDir,
    int port = 0,
  }) async {
    if (_isDesktop) {
      return DesktopBackendService.start(
        dataDir: dataDir,
        musicDir: musicDir,
        port: port,
      );
    }

    final result = await _channel.invokeMethod<int>('start', {
      'dataDir': dataDir,
      'musicDir': musicDir,
      'port': port,
    });
    if (result == null) throw PlatformException(code: 'NULL_PORT');
    return result;
  }

  /// 优雅停止后端
  static Future<void> stop() async {
    if (_isDesktop) {
      return DesktopBackendService.stop();
    }

    try {
      await _channel.invokeMethod('stop');
    } on MissingPluginException {
      // not bundled
    }
  }

  /// 检查后端是否在运行
  static Future<bool> isRunning() async {
    if (_isDesktop) {
      return DesktopBackendService.isRunning();
    }

    try {
      final result = await _channel.invokeMethod<bool>('isRunning');
      return result ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  /// 获取当前监听端口，未运行时返回 0
  static Future<int> getPort() async {
    if (_isDesktop) {
      return DesktopBackendService.getPort();
    }

    try {
      final result = await _channel.invokeMethod<int>('getPort');
      return result ?? 0;
    } on MissingPluginException {
      return 0;
    }
  }
}
