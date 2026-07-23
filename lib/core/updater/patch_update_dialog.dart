import 'package:flutter/material.dart';
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
import '../backend/embedded_backend_service.dart';
import '../network/api_client.dart' show dioProvider;
import '../router/app_router.dart';
import 'backend_patch_service.dart';
import 'patch_update_service.dart';

/// 统一的启动更新检查 + 手动更新对话框（Android）。
///
/// [maybeShow] 每会话调用一次，把**前端补丁（flutter_patcher，libapp.so）**与
/// **后端补丁（Bundle 版，libgojni.so）**合并为一次体验：
/// 1. 并行检查两类补丁（同渠道/同 tag，各自未被忽略）→ 有任一 → 弹**一个**对话框，
///    列出待更新组件，一次「下载并更新」把可用补丁一起下载（前端 stage libapp.so、
///    后端 stage libgojni.so），完成后**只重启一次**（[EmbeddedBackendService.restartProcess]
///    真进程冷启：既让 flutter_patcher 的 libapp.so 生效，又触发 Application 预加载
///    libgojni.so）；
/// 2. 否则同渠道有更高整包版本（不可热更）→ 弹「不兼容」→ 跳设置页下 APK；
/// 3. 都没有 → 静默。
class PatchUpdateDialog extends ConsumerStatefulWidget {
  const PatchUpdateDialog._({this.frontendPatch, this.backendPatch});

  /// 前端 flutter_patcher 补丁（libapp.so），无则 null。
  final PatchInfo? frontendPatch;

  /// 后端补丁（libgojni.so，仅 Bundle 版 Android），无则 null。
  final BackendPatchInfo? backendPatch;

  static Future<void> maybeShow(BuildContext context, WidgetRef ref) async {
    // 读持久化代理（用于抓 manifest）+ 偏好（忽略版本）
    String proxy = '';
    try {
      proxy = await ref.read(githubProxyProvider.future);
    } catch (_) {}
    final prefs = await ref.read(appPreferencesProvider.future);
    final proxyOrNull = proxy.isNotEmpty ? proxy : null;

    // —— 并行检查前端补丁（libapp.so）与后端补丁（libgojni.so）——
    final frontendService = PatchUpdateService();
    final backendService = BackendPatchService(appDio: ref.read(dioProvider));

    final results = await Future.wait<Object?>([
      frontendService.isSupported
          ? frontendService.checkPatch(githubProxy: proxyOrNull)
          : Future<PatchInfo?>.value(null),
      backendService.isSupported
          ? backendService.checkPatch(githubProxy: proxyOrNull)
          : Future<BackendPatchInfo?>.value(null),
    ]);

    var frontendPatch = results[0] as PatchInfo?;
    var backendPatch = results[1] as BackendPatchInfo?;

    // 过滤「忽略此版本」
    if (frontendPatch != null &&
        frontendPatch.version == prefs.getIgnoredPatchVersion()) {
      frontendPatch = null;
    }
    if (backendPatch != null &&
        backendPatch.patchLabel == prefs.getIgnoredBackendPatchVersion()) {
      backendPatch = null;
    }

    if ((frontendPatch != null || backendPatch != null) && context.mounted) {
      await showDialog<void>(
        context: context,
        barrierDismissible: true, // 允许点外部关闭
        builder: (_) => PatchUpdateDialog._(
          frontendPatch: frontendPatch,
          backendPatch: backendPatch,
        ),
      );
      return;
    }

    // —— 同渠道整包新版本(不可热更)→ 引导下 APK ——
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
  final _frontendService = PatchUpdateService();
  late final BackendPatchService _backendService = BackendPatchService(
    appDio: ref.read(dioProvider),
  );
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
    final proxyOrNull = proxy.isEmpty ? null : proxy;
    setState(() {
      _status = _Status.downloading;
      _fraction = null;
    });

    var ok = true;

    // 1) 前端补丁（libapp.so）
    final fp = widget.frontendPatch;
    if (ok && fp != null) {
      final toApply = PatchInfo(
        version: fp.version,
        patchUrl: PatchUpdateService.applyProxy(fp.patchUrl, proxyOrNull),
        md5: fp.md5,
        signature: fp.signature,
        targetVersionCode: fp.targetVersionCode,
        raw: fp.raw,
      );
      ok = await _frontendService.applyPatch(
        toApply,
        onProgress: (prog) {
          if (mounted) setState(() => _fraction = prog.fraction);
        },
      );
    }

    // 2) 后端补丁（libgojni.so）
    final bp = widget.backendPatch;
    if (ok && bp != null) {
      if (mounted) setState(() => _fraction = null);
      ok = await _backendService.downloadAndStage(
        bp,
        githubProxy: proxyOrNull,
        onProgress: (f) {
          if (mounted) setState(() => _fraction = f);
        },
      );
    }

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
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  value: _fraction,
                ),
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
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.updateReadyBody),
              const SizedBox(height: 8),
              Text(
                l10n.updateRestartInterrupt,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.updateActionLater),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                // 真进程冷启：libapp.so 冷启生效 + Application 预加载 libgojni.so。
                EmbeddedBackendService.restartProcess();
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
              Text(l10n.updateComponentsHeader),
              const SizedBox(height: 8),
              if (widget.frontendPatch != null)
                _componentLine(
                  context,
                  l10n.updateComponentFrontend(widget.frontendPatch!.version),
                ),
              if (widget.backendPatch != null)
                _componentLine(
                  context,
                  l10n.updateComponentBackend(widget.backendPatch!.patchLabel),
                ),
              const SizedBox(height: 16),
              _buildProxySelector(context, l10n),
            ],
          ),
          actions: [
            TextButton(
              onPressed: _ignoreAndClose,
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

  Future<void> _ignoreAndClose() async {
    final prefs = await ref.read(appPreferencesProvider.future);
    if (widget.frontendPatch != null) {
      await prefs.setIgnoredPatchVersion(widget.frontendPatch!.version);
    }
    if (widget.backendPatch != null) {
      await prefs.setIgnoredBackendPatchVersion(widget.backendPatch!.patchLabel);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Widget _componentLine(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text('• $text', style: Theme.of(context).textTheme.bodyMedium),
    );
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
