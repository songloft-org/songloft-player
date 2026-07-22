import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../config/app_config.dart';
import 'platform_utils.dart';

class FileLogger {
  FileLogger._();

  static IOSink? _sink;
  static String? _currentPath;
  static String? _currentDir;

  static const _maxAgeDays = 3;

  /// 单次会话写入文件的体积上限（兜底防护）。热路径日志异常刷屏时，
  /// 超过此上限即停止落盘（控制台不受影响），避免日志文件被撑到数百 MB。
  static const _maxSessionBytes = 20 * 1024 * 1024;
  static int _writtenBytes = 0;
  static bool _capReached = false;

  /// 敏感 token 脱敏：日志里的 access_token / token 查询参数值一律替换为 ***，
  /// 避免可用凭证明文落盘。
  static final RegExp _tokenPattern = RegExp(
    r'((?:access_token|token)=)[^&\s]+',
    caseSensitive: false,
  );

  static String _redact(String line) =>
      line.replaceAllMapped(_tokenPattern, (m) => '${m[1]}***');

  static Future<void> init() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final logsDir = Directory('${appDir.path}${Platform.pathSeparator}logs');
      if (!logsDir.existsSync()) {
        logsDir.createSync(recursive: true);
      }
      _currentDir = logsDir.path;

      final now = DateTime.now();
      final dateStr =
          '${now.year}-${_pad(now.month)}-${_pad(now.day)}';
      final logFile = File(
        '${logsDir.path}${Platform.pathSeparator}songloft_$dateStr.log',
      );
      _currentPath = logFile.path;

      _sink = logFile.openWrite(mode: FileMode.append);

      const version = AppConfig.frontendVersion;
      final platform = PlatformUtils.platformName;
      final ts = _formatDateTime(now);
      _sink!.writeln(
        '========== Songloft v$version | $ts | $platform ==========',
      );

      _cleanOldLogs(logsDir, now);
    } catch (e) {
      debugPrint('[FileLogger] 初始化失败: $e');
    }
  }

  static void writeln(String line) {
    final sink = _sink;
    if (sink == null || _capReached) return;
    final now = DateTime.now();
    final ts =
        '${_pad(now.hour)}:${_pad(now.minute)}:${_pad(now.second)}.${_pad3(now.millisecond)}';
    final entry = '[$ts] ${_redact(line)}';
    _writtenBytes += entry.length + 1; // +1 约计换行符
    if (_writtenBytes > _maxSessionBytes) {
      _capReached = true;
      sink.writeln(
        '[$ts] [FileLogger] 已达单次会话日志上限 '
        '(${_maxSessionBytes ~/ (1024 * 1024)}MB)，后续日志仅输出到控制台。',
      );
      return;
    }
    sink.writeln(entry);
  }

  static Future<void> flush() async {
    await _sink?.flush();
  }

  static Future<void> close() async {
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
  }

  static String? get logFilePath => _currentPath;

  static String? get logDir => _currentDir;

  /// 返回当前日志文件内容（UTF-8 字节），供导出打包。先 flush 确保缓冲落盘。
  /// 文件不存在或读取失败时返回 null。
  static Future<List<int>?> readLogBytes() async {
    final path = _currentPath;
    if (path == null) return null;
    try {
      await _sink?.flush();
      final file = File(path);
      if (!file.existsSync()) return null;
      return await file.readAsBytes();
    } catch (e) {
      debugPrint('[FileLogger] 读取日志文件失败: $e');
      return null;
    }
  }

  static void _cleanOldLogs(Directory logsDir, DateTime now) {
    try {
      final cutoff = now.subtract(const Duration(days: _maxAgeDays));
      for (final entity in logsDir.listSync()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (!name.startsWith('songloft_') || !name.endsWith('.log')) continue;
        final datePart = name.substring(9, name.length - 4);
        final fileDate = DateTime.tryParse(datePart);
        if (fileDate != null && fileDate.isBefore(cutoff)) {
          entity.deleteSync();
        }
      }
    } catch (e) {
      debugPrint('[FileLogger] 清理旧日志失败: $e');
    }
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
  static String _pad3(int n) => n.toString().padLeft(3, '0');

  static String _formatDateTime(DateTime dt) =>
      '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)} '
      '${_pad(dt.hour)}:${_pad(dt.minute)}:${_pad(dt.second)}';
}
