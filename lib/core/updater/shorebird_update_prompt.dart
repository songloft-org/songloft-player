import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/utils/responsive_snackbar.dart';
import 'shorebird_update_service.dart';

/// Shorebird 主动式更新流程（`auto_update: false` 搭配使用）。
///
/// 进入首页时调用一次：
/// 1. 若上次会话已下载好补丁（restartRequired）→ 直接弹「重启生效」；
/// 2. 否则若服务端有可用新补丁（outdated）→ 弹「发现新版本，是否下载」
///    → 用户确认后弹下载进度 → 完成弹「重启生效」。
///
/// 非 Shorebird 构建（dev/web/desktop）下 service 各方法返回 false/无，静默跳过。
/// 全程用 `context.mounted` 守卫跨 await 的 context 使用。
Future<void> maybePromptShorebirdUpdate(BuildContext context) async {
  final service = ShorebirdUpdateService();
  if (!service.isAvailable) return;

  // 上次会话已下载、等待重启生效
  if (await service.isPatchReadyToInstall()) {
    if (!context.mounted) return;
    await _showRestartDialog(context);
    return;
  }

  // 服务端有可下载的新补丁
  if (!await service.isUpdateAvailable()) return;
  if (!context.mounted) return;

  final l10n = AppLocalizations.of(context);
  final shouldDownload = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.updateAvailableTitle),
      content: Text(l10n.updateAvailableBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.updateActionLater),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l10n.updateActionDownloadNow),
        ),
      ],
    ),
  );
  if (shouldDownload != true || !context.mounted) return;

  // 下载进度弹窗（不可关闭；update() 无进度回调，用不确定进度条）
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      content: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(width: 20),
          Expanded(child: Text(l10n.updateDownloading)),
        ],
      ),
    ),
  );

  final ok = await service.downloadUpdate();

  // 关闭进度弹窗
  if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  if (!context.mounted) return;

  if (ok) {
    await _showRestartDialog(context);
  } else {
    ResponsiveSnackBar.show(context, message: l10n.updateDownloadFailed);
  }
}

Future<void> _showRestartDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.updateReadyTitle),
      content: Text(l10n.updateReadyBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l10n.updateActionLater),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            // 关闭 App，用户重新打开后补丁在冷启动时生效。
            SystemNavigator.pop();
          },
          child: Text(l10n.updateActionRestartNow),
        ),
      ],
    ),
  );
}
