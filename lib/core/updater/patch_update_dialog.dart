import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_patcher/flutter_patcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_provider.dart'
    show appPreferencesProvider;
import '../../features/jsplugin/presentation/widgets/github_proxy_selection.dart';
import '../../features/settings/data/frontend_version_api.dart';
import '../../features/settings/presentation/providers/settings_provider.dart'
    show githubProxyProvider, frontendVersionCheckProvider;
import '../../l10n/app_localizations.dart';
import '../../shared/constants/github_proxy.dart';
import '../router/app_router.dart';
import 'patch_update_service.dart';

/// 自托管热更新的启动检查 + 手动更新对话框（仅 Android 有补丁分支）。
///
/// [maybeShow] 每会话调用一次:
/// 1. 有匹配补丁(且未被「忽略此版本」)→ 弹本对话框:选代理 → 下载 → 重启;
/// 2. 否则同渠道有更高整包版本(`FrontendVersionApi`,且未被忽略)→ 弹「不兼容」→ 跳设置页下 APK;
/// 3. 都没有 → 静默。
class PatchUpdateDialog extends ConsumerStatefulWidget {
  const PatchUpdateDialog._({required this.patch});

  final PatchInfo patch;

  static Future<void> maybeShow(BuildContext context, WidgetRef ref) async {
    final service = PatchUpdateService();

    // 读持久化代理（用于抓 manifest）+ 偏好（忽略版本）
    String proxy = '';
    try {
      proxy = await ref.read(githubProxyProvider.future);
    } catch (_) {}
    final prefs = await ref.read(appPreferencesProvider.future);

    // —— 分支 1:Shorebird 式热补丁（仅 Android）——
    if (service.isSupported) {
      final patch = await service.checkPatch(
        githubProxy: proxy.isNotEmpty ? proxy : null,
      );
      if (patch != null &&
          patch.version != prefs.getIgnoredPatchVersion() &&
          context.mounted) {
        await showDialog<void>(
          context: context,
          barrierDismissible: true, // 允许点外部关闭
          builder: (_) => PatchUpdateDialog._(patch: patch),
        );
        return;
      }
    }

    // —— 分支 2:同渠道整包新版本(不可热更)→ 引导下 APK ——
    try {
      final check = await ref.read(frontendVersionCheckProvider.future);
      if (check.hasUpdate &&
          check.latestVersion != prefs.getIgnoredClientVersion() &&
          context.mounted) {
        await _showIncompatibleDialog(context, ref, check);
      }
    } catch (_) {
      // 版本检查失败不打扰用户
    }
  }

  @override
  ConsumerState<PatchUpdateDialog> createState() => _PatchUpdateDialogState();
}

enum _Status { idle, downloading, done, failed }

class _PatchUpdateDialogState extends ConsumerState<PatchUpdateDialog>
    with GithubProxySelectionMixin<PatchUpdateDialog> {
  final _service = PatchUpdateService();
  _Status _status = _Status.idle;
  double? _fraction;

  @override
  List<String> get proxyPresetValues =>
      kGithubProxyPresets.map((e) => e.value).toList();

  @override
  void initState() {
    super.initState();
    restoreGithubProxy(); // 恢复上次选择
  }

  Future<void> _download() async {
    persistGithubProxy();
    final proxy = effectiveProxy;
    final p = widget.patch;
    final toApply = PatchInfo(
      version: p.version,
      patchUrl: PatchUpdateService.applyProxy(
        p.patchUrl,
        proxy.isEmpty ? null : proxy,
      ),
      md5: p.md5,
      signature: p.signature,
      targetVersionCode: p.targetVersionCode,
      raw: p.raw,
    );
    setState(() {
      _status = _Status.downloading;
      _fraction = null;
    });
    final ok = await _service.applyPatch(
      toApply,
      onProgress: (prog) {
        if (mounted) setState(() => _fraction = prog.fraction);
      },
    );
    if (!mounted) return;
    setState(() => _status = ok ? _Status.done : _Status.failed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (_status) {
      case _Status.downloading:
        return AlertDialog(
          content: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5, value: _fraction),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  _fraction != null
                      ? '${l10n.updateDownloading} ${(_fraction! * 100).toStringAsFixed(0)}%'
                      : l10n.updateDownloading,
                ),
              ),
            ],
          ),
        );
      case _Status.done:
        return AlertDialog(
          title: Text(l10n.updateReadyTitle),
          content: Text(l10n.updateReadyBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.updateActionLater),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                // 关闭 App,重新打开后补丁在冷启动时生效
                SystemNavigator.pop();
              },
              child: Text(l10n.updateActionRestartNow),
            ),
          ],
        );
      case _Status.failed:
        return AlertDialog(
          title: Text(l10n.updateFoundTitle),
          content: Text(l10n.updateFailed),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.updateActionLater),
            ),
            FilledButton(
              onPressed: () => setState(() => _status = _Status.idle),
              child: Text(l10n.commonRetry),
            ),
          ],
        );
      case _Status.idle:
        return AlertDialog(
          title: Text(l10n.updateFoundTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.updateFoundBody(widget.patch.version)),
              const SizedBox(height: 16),
              _buildProxySelector(context, l10n),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final prefs = await ref.read(appPreferencesProvider.future);
                await prefs.setIgnoredPatchVersion(widget.patch.version);
                if (context.mounted) Navigator.of(context).pop();
              },
              child: Text(l10n.updateActionIgnore),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.updateActionLater),
            ),
            FilledButton(
              onPressed: _download,
              child: Text(l10n.updateActionDownload),
            ),
          ],
        );
    }
  }

  Widget _buildProxySelector(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.updateProxyLabel, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        DropdownButton<int>(
          isExpanded: true,
          value: selectedProxyIndex,
          items: [
            for (int i = 0; i < kGithubProxyPresets.length; i++)
              DropdownMenuItem(
                value: i,
                child: Text(
                  kGithubProxyPresets[i].value.isEmpty
                      ? l10n.githubProxyDirect
                      : kGithubProxyPresets[i].label,
                ),
              ),
            DropdownMenuItem(value: -1, child: Text(l10n.jspluginCustomProxy)),
          ],
          onChanged: (v) => setState(() => selectedProxyIndex = v ?? 0),
        ),
        if (selectedProxyIndex == -1)
          TextField(
            controller: customProxyController,
            decoration: InputDecoration(hintText: l10n.jspluginProxyHelper),
          ),
      ],
    );
  }
}

/// 「版本不兼容,需下载新 APK」对话框:忽略 / 稍后 / 前往设置页下载。
Future<void> _showIncompatibleDialog(
  BuildContext context,
  WidgetRef ref,
  FrontendVersionCheck check,
) async {
  final l10n = AppLocalizations.of(context);
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.updateIncompatibleTitle),
      content: Text(l10n.updateIncompatibleBody(check.latestVersionDisplay)),
      actions: [
        TextButton(
          onPressed: () async {
            final prefs = await ref.read(appPreferencesProvider.future);
            await prefs.setIgnoredClientVersion(check.latestVersion);
            if (ctx.mounted) Navigator.of(ctx).pop();
          },
          child: Text(l10n.updateActionIgnore),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l10n.updateActionLater),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            ctx.go(AppRoutes.settings);
          },
          child: Text(l10n.updateActionGoDownload),
        ),
      ],
    ),
  );
}
