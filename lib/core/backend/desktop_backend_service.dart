import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// 桌面端（macOS/Windows/Linux）通过子进程启动打包的 Go 后端二进制。
/// Go 二进制与 Flutter 可执行文件打包在同一目录中。
class DesktopBackendService {
  static Process? _process;
  static int _port = 0;

  /// 查找打包的 Go 后端二进制路径
  static String? _findServerBinary() {
    final exeFile = File(Platform.resolvedExecutable);
    final exeDir = exeFile.parent.path;
    final name = Platform.isWindows ? 'songloft-server.exe' : 'songloft-server';

    // macOS .app bundle: Contents/MacOS/ 目录
    // Windows/Linux: 与 Flutter 可执行文件同目录
    final candidate = '$exeDir${Platform.pathSeparator}$name';
    if (File(candidate).existsSync()) return candidate;

    // macOS 也检查 Resources 目录
    if (Platform.isMacOS) {
      final resourcePath = '${exeFile.parent.parent.path}${Platform.pathSeparator}Resources${Platform.pathSeparator}$name';
      if (File(resourcePath).existsSync()) return resourcePath;
    }

    return null;
  }

  /// 检查 Go 后端二进制是否存在
  static bool isAvailable() {
    return _findServerBinary() != null;
  }

  /// 启动 Go 后端子进程，返回监听端口
  static Future<int> start({
    required String dataDir,
    required String musicDir,
    int port = 0,
  }) async {
    if (_process != null) return _port;

    final binary = _findServerBinary();
    if (binary == null) {
      throw StateError('Go backend binary not found');
    }

    final usePort = port > 0 ? port : 58091;
    final dbPath = '$dataDir${Platform.pathSeparator}songloft.db';

    _process = await Process.start(binary, [
      '-port', '$usePort',
      '-db', dbPath,
      '-username', 'admin',
      '-password', 'admin',
    ]);

    _port = usePort;

    _process!.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      debugPrint('[GoBackend] $line');
      final match = RegExp(r'http://localhost:(\d+)').firstMatch(line);
      if (match != null) {
        _port = int.parse(match.group(1)!);
      }
    });

    _process!.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      debugPrint('[GoBackend:err] $line');
    });

    _process!.exitCode.then((code) {
      debugPrint('[GoBackend] 进程退出, code=$code');
      _process = null;
      _port = 0;
    });

    debugPrint('[DesktopBackend] 后端已启动, port=$_port, pid=${_process!.pid}');
    return _port;
  }

  /// 停止后端子进程
  static Future<void> stop() async {
    if (_process == null) return;
    _process!.kill(ProcessSignal.sigterm);
    try {
      await _process!.exitCode.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      _process!.kill(ProcessSignal.sigkill);
    }
    _process = null;
    _port = 0;
    debugPrint('[DesktopBackend] 后端已停止');
  }

  /// 检查后端子进程是否在运行
  static bool isRunning() {
    return _process != null;
  }

  /// 获取当前端口
  static int getPort() {
    return _port;
  }
}
