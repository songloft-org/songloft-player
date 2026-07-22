import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/file_logger.dart';
import '../presentation/providers/settings_provider.dart';
import 'log_share_file.dart';
import 'settings_api.dart';

/// 日志导出结果的描述，用于向用户反馈实际打包了哪些内容。
class LogExportResult {
  final bool hasBackend;
  final bool hasFrontend;

  const LogExportResult({required this.hasBackend, required this.hasFrontend});

  bool get isEmpty => !hasBackend && !hasFrontend;
}

/// 收集前后端日志、打包成 zip 并唤起系统分享。
///
/// - 后端日志：调 GET /logs/export（后端已脱敏）。三种运行模式（远程 / 桌面 Bundle /
///   移动 Bundle）都由同一后端提供该端点，故此处逻辑统一。
/// - 前端日志：读本地 FileLogger（原生为落盘文件，Web 为内存缓冲，已做 token 脱敏）。
/// - 打包：archive 打成 `songloft-logs-<date>.zip`，share_plus 唤起分享/保存。
///
/// 任一侧缺失（如离线导致后端拉取失败、Web 无前端文件）时尽力打包可得部分；
/// 两侧都拿不到才抛错。
class LogExportService {
  final SettingsApi _api;

  LogExportService(this._api);

  /// 打包并分享日志。[shareSubject] 用于部分平台的分享标题。
  /// 返回实际包含的内容描述；两侧都为空时抛 [StateError]。
  Future<LogExportResult> exportAndShare({String? shareSubject}) async {
    final archive = Archive();
    var hasBackend = false;
    var hasFrontend = false;

    // 后端日志（拉取失败不阻断，写一份错误说明进包，方便排查为何缺后端日志）。
    try {
      final backendBytes = await _api.downloadBackendLogs();
      if (backendBytes.isNotEmpty) {
        archive.addFile(
          ArchiveFile('backend.log', backendBytes.length, backendBytes),
        );
        hasBackend = true;
      }
    } catch (e) {
      final note = utf8.encode('拉取后端日志失败: $e\n');
      archive.addFile(
        ArchiveFile('backend-error.txt', note.length, note),
      );
      debugPrint('[LogExport] 后端日志拉取失败: $e');
    }

    // 前端日志（原生读文件 / Web 读内存缓冲）。
    try {
      final frontendBytes = await FileLogger.readLogBytes();
      if (frontendBytes != null && frontendBytes.isNotEmpty) {
        archive.addFile(
          ArchiveFile('frontend.log', frontendBytes.length, frontendBytes),
        );
        hasFrontend = true;
      }
    } catch (e) {
      debugPrint('[LogExport] 前端日志读取失败: $e');
    }

    if (archive.isEmpty) {
      throw StateError('没有可导出的日志');
    }

    final zipData = ZipEncoder().encode(archive);
    if (zipData == null) {
      throw StateError('日志打包失败');
    }
    final zipBytes = Uint8List.fromList(zipData);

    final now = DateTime.now();
    final dateStr =
        '${now.year}${_pad(now.month)}${_pad(now.day)}-${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';
    final fileName = 'songloft-logs-$dateStr.zip';

    final xfile = await buildLogShareFile(zipBytes, fileName);
    await Share.shareXFiles([xfile], subject: shareSubject);

    return LogExportResult(hasBackend: hasBackend, hasFrontend: hasFrontend);
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}

final logExportServiceProvider = Provider<LogExportService>((ref) {
  final api = ref.watch(settingsApiProvider);
  return LogExportService(api);
});
