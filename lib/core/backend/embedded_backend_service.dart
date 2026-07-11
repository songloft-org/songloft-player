import 'dart:io' show Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

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

  /// 请求 Android 存储读取权限（本地模式需要 Go 后端直接遍历文件系统）。
  /// Android ≤12 请求 READ_EXTERNAL_STORAGE，Android 13+ 请求 READ_MEDIA_AUDIO。
  static Future<void> ensureStoragePermission() async {
    if (kIsWeb || !Platform.isAndroid) return;

    // Android 13+ (API 33): READ_MEDIA_AUDIO
    var status = await Permission.audio.status;
    if (!status.isGranted) {
      status = await Permission.audio.request();
      debugPrint('[Backend] audio permission: $status');
    }

    // Android ≤12: READ_EXTERNAL_STORAGE
    status = await Permission.storage.status;
    if (!status.isGranted && !status.isPermanentlyDenied) {
      status = await Permission.storage.request();
      debugPrint('[Backend] storage permission: $status');
    }
  }

  /// iOS 本地模式的音乐目录是否固定（不允许用户手动选择外部目录）。
  ///
  /// iOS 沙盒禁止内嵌后端读取 file_picker 选中的外部目录（security scope 在
  /// 选择器关闭后即释放），因此本地模式固定使用 app 自身的 Documents 目录，
  /// 通过「文件」App / Finder 文件共享（Info.plist `UIFileSharingEnabled` +
  /// `LSSupportsOpeningDocumentsInPlace`）让用户把音乐放进来。沙盒内目录可被
  /// 内嵌后端直接遍历，无需 security-scoped 访问。
  static bool get usesFixedMusicDir => !kIsWeb && Platform.isIOS;

  /// 解析本地模式实际使用的音乐目录（不弹出选择器）。
  /// - iOS：固定返回 app Documents 目录，忽略传入的 [current]。
  /// - 其他平台：返回已选目录（为空时返回 null）。
  ///
  /// 用于自动登录 / 生命周期重启等不应打断用户的场景。
  static Future<String?> resolveMusicDir(String? current) async {
    if (usesFixedMusicDir) {
      return (await getApplicationDocumentsDirectory()).path;
    }
    return (current != null && current.isNotEmpty) ? current : null;
  }

  /// 解析音乐目录，必要时弹出目录选择器。
  /// - iOS：等同 [resolveMusicDir]，直接返回 Documents 目录，不弹选择器。
  /// - 其他平台：已有 [current] 直接返回；否则弹出 file_picker，用户取消返回 null。
  ///
  /// 用于用户主动开启本地模式 / 切换音乐目录的场景。
  static Future<String?> pickMusicDir(String? current) async {
    if (usesFixedMusicDir) {
      return (await getApplicationDocumentsDirectory()).path;
    }
    if (current != null && current.isNotEmpty) return current;
    return FilePicker.platform.getDirectoryPath(dialogTitle: '选择音乐文件夹');
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
