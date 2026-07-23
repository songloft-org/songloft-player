import 'package:flutter/foundation.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

/// Shorebird 热更新（Dart code push）的防御式封装。
///
/// 只做**只读查询**：是否有已下载待重启的补丁、当前生效的补丁号。补丁的下载/应用由
/// `shorebird.yaml` 的 `auto_update: true` 在启动时自动完成，本 service 不主动触发
/// `update()`（避免与 auto_update 竞争、也不做强制重启）。
///
/// 全程守卫：
/// - 非 Shorebird 构建（dev / web / desktop，未内置 Shorebird 引擎）时 `isAvailable`
///   为 false，所有方法安全返回「无更新 / null」。
/// - 任意异常都被吞掉并降级为「无更新」，绝不影响调用方（UI / 启动流程）。
///
/// 详见 docs/cn/shorebird_hot_update.md。API 以 pub.dev 上 shorebird_code_push v2 为准。
class ShorebirdUpdateService {
  ShorebirdUpdateService();

  final ShorebirdUpdater _updater = ShorebirdUpdater();

  /// 当前构建是否内置了可用的 Shorebird updater。
  bool get isAvailable {
    try {
      return _updater.isAvailable;
    } catch (_) {
      return false;
    }
  }

  /// 是否已有下载完成、等待下次冷启动生效的补丁（上次会话下载好、尚未重启）。
  ///
  /// 用于进入 App 时直接提示「重启生效」。不可用 / 出错时返回 false。
  Future<bool> isPatchReadyToInstall() async {
    if (!isAvailable) return false;
    try {
      final status = await _updater.checkForUpdate();
      return status == UpdateStatus.restartRequired;
    } catch (e) {
      debugPrint('[Shorebird] checkForUpdate 失败: $e');
      return false;
    }
  }

  /// 服务端是否有「可下载但尚未下载」的新补丁（`auto_update: false` 下由客户端主动下载）。
  ///
  /// 不可用 / 出错时返回 false。
  Future<bool> isUpdateAvailable() async {
    if (!isAvailable) return false;
    try {
      final status = await _updater.checkForUpdate();
      return status == UpdateStatus.outdated;
    } catch (e) {
      debugPrint('[Shorebird] checkForUpdate 失败: $e');
      return false;
    }
  }

  /// 主动下载当前可用补丁（阻塞到下载完成）。成功返回 true，下载完成后需重启生效。
  ///
  /// 不可用 / 下载失败时返回 false（已吞异常，不抛给调用方）。
  Future<bool> downloadUpdate() async {
    if (!isAvailable) return false;
    try {
      await _updater.update();
      return true;
    } on UpdateException catch (e) {
      debugPrint('[Shorebird] update 失败: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[Shorebird] update 失败: $e');
      return false;
    }
  }

  /// 当前**已生效**的补丁号；未打补丁 / 不可用 / 出错时返回 null。
  ///
  /// 仅用于日志 / 监控上报区分「打没打补丁」（补丁不改 App 版本号）。
  Future<int?> currentPatchNumber() async {
    if (!isAvailable) return null;
    try {
      final patch = await _updater.readCurrentPatch();
      return patch?.number;
    } catch (e) {
      debugPrint('[Shorebird] readCurrentPatch 失败: $e');
      return null;
    }
  }
}
