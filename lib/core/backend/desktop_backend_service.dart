import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

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
      final resourcePath =
          '${exeFile.parent.parent.path}${Platform.pathSeparator}Resources${Platform.pathSeparator}$name';
      if (File(resourcePath).existsSync()) return resourcePath;
    }

    return null;
  }

  /// 检查 Go 后端二进制是否存在
  static bool isAvailable() {
    return _findServerBinary() != null;
  }

  /// 启动 Go 后端子进程，返回实际监听端口。
  ///
  /// 默认 [port] = 0：传 `-port 0` 让后端由系统自动分配空闲端口，避免固定端口
  /// （如 58091）被占用时启动失败。真实端口从后端 stdout 打印的
  /// `http://localhost:PORT/` 一行解析，解析到后 [start] 才返回。
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

    final dbPath = '$dataDir${Platform.pathSeparator}songloft.db';

    // 后端监听 0.0.0.0（桌面端 DLNA 投屏需要局域网设备拉流），局域网可达，
    // 绝不能用默认 admin/admin：同网段任何人都能登入并经 /jsplugins 拿到代码执行。
    // 为每个安装生成一次随机密码并落盘复用，getAdminPassword() 从同一文件读取后登录。
    final password = await _ensureAdminPassword(dataDir);

    final tools = Directory(
      '${File(binary).parent.path}${Platform.pathSeparator}tools',
    );
    final extension = Platform.isWindows ? '.exe' : '';
    final ffmpeg = '${tools.path}${Platform.pathSeparator}ffmpeg$extension';
    final ffprobe = '${tools.path}${Platform.pathSeparator}ffprobe$extension';
    final toolEnvironment = {
      if (File(ffmpeg).existsSync()) 'SONGLOFT_BUNDLE_FFMPEG': ffmpeg,
      if (File(ffprobe).existsSync()) 'SONGLOFT_BUNDLE_FFPROBE': ffprobe,
    };

    final process = await Process.start(binary, [
      '-port', '${port > 0 ? port : 0}',
      '-db', dbPath,
      // 传入用户选择的音乐目录（绝对路径），覆盖后端 DB 中的相对默认值 "music"，
      // 否则后端会按子进程 CWD 解析相对路径导致扫描失败。
      if (musicDir.isNotEmpty) ...['-music', musicDir],
      '-username', 'admin',
      '-password', password,
    ], environment: toolEnvironment);
    _process = process;
    _port = 0;

    final portReady = Completer<int>();

    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          debugPrint('[GoBackend] $line');
          final match = RegExp(r'http://localhost:(\d+)').firstMatch(line);
          if (match != null) {
            _port = int.parse(match.group(1)!);
            if (!portReady.isCompleted) portReady.complete(_port);
          }
        });

    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          debugPrint('[GoBackend:err] $line');
        });

    process.exitCode.then((code) {
      debugPrint('[GoBackend] 进程退出, code=$code');
      if (identical(_process, process)) {
        _process = null;
        _port = 0;
      }
      if (!portReady.isCompleted) {
        portReady.completeError(
          StateError('Go backend exited before reporting port (code=$code)'),
        );
      }
    });

    try {
      _port = await portReady.future.timeout(const Duration(seconds: 15));
    } catch (e) {
      // 未能拿到端口：确保清理子进程，避免残留
      process.kill(ProcessSignal.sigkill);
      if (identical(_process, process)) {
        _process = null;
        _port = 0;
      }
      rethrow;
    }

    debugPrint('[DesktopBackend] 后端已启动, port=$_port, pid=${process.pid}');
    return _port;
  }

  /// 读取 dataDir 下的管理员密码文件，不存在则生成随机密码并落盘复用。
  /// 与移动端共用 admin_password 文件名；getAdminPassword() 从同一路径读取。
  static Future<String> _ensureAdminPassword(String dataDir) async {
    final f = File('$dataDir${Platform.pathSeparator}admin_password');
    try {
      if (await f.exists()) {
        final pw = (await f.readAsString()).trim();
        if (pw.isNotEmpty) return pw;
      }
    } catch (_) {
      // 落空则重新生成
    }

    final rnd = Random.secure();
    final bytes = List<int>.generate(18, (_) => rnd.nextInt(256));
    final pw = base64Url.encode(bytes).replaceAll('=', '');

    try {
      await f.writeAsString(pw);
    } catch (e) {
      // 无法落盘时仍返回本次随机密码，保证本次启动可登录（下次会再生成）
      debugPrint('[DesktopBackend] 写入 admin_password 失败: $e');
    }
    return pw;
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
