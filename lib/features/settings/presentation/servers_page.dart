import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../config/app_config.dart';
import '../../../core/backend/embedded_backend_service.dart';
import '../../../core/backend/run_mode_provider.dart';
import '../../../core/network/base_url_provider.dart';
import '../../../core/network/server_entry.dart';
import '../../../core/network/server_probe.dart';
import '../../../core/network/servers_provider.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/responsive_snackbar.dart';
import '../../auth/presentation/providers/auth_provider.dart';

class ServersPage extends ConsumerWidget {
  const ServersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serversAsync = ref.watch(serversProvider);
    final currentUrl = ref.watch(baseUrlProvider);
    final statuses = ref.watch(probeStatusProvider);
    final isLocal = ref.watch(runModeProvider) == RunMode.local;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsServersTitle),
        actions: [
          if (!isLocal)
            IconButton(
              tooltip: l10n.settingsServersTestAll,
              icon: const Icon(Icons.network_check),
              onPressed: () => _probeAll(context, ref),
            ),
        ],
      ),
      body: serversAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.commonLoadFailedDetail('$e'))),
        data: (servers) {
          const showLocalMode = !kIsWeb && AppConfig.hasEmbeddedBackend;
          const localModeCard = showLocalMode
              ? _LocalModeCard()
              : null;

          if (servers.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (localModeCard != null) ...[
                  localModeCard,
                  const SizedBox(height: 24),
                ],
                if (!isLocal)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cloud_off_outlined,
                            size: 64,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.settingsServersEmptyTitle,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.settingsServersEmptyHint,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          }
          return Column(
            children: [
              if (localModeCard != null)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: localModeCard,
                ),
              Expanded(
                child: ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: servers.length,
                  onReorderItem: (oldIndex, newIndex) {
                    ref.read(serversProvider.notifier).reorder(oldIndex, newIndex);
                  },
                  itemBuilder: (context, index) {
                    final entry = servers[index];
                    final isCurrent = entry.url == currentUrl;
                    final status = statuses[entry.id] ?? ProbeStatus.unknown;
                    return _ServerTile(
                      key: ValueKey(entry.id),
                      index: index,
                      entry: entry,
                      isCurrent: isCurrent,
                      status: status,
                      onEdit: () => _showEditDialog(context, ref, entry),
                      onDelete: () => _confirmDelete(context, ref, entry, isCurrent),
                      onTest: () => _probeOne(context, ref, entry),
                      onSwitchTo: () => _switchTo(context, ref, entry, isCurrent),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: isLocal ? null : FloatingActionButton(
        onPressed: () => _showEditDialog(context, ref, null),
        tooltip: l10n.settingsServersAdd,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    ServerEntry? existing,
  ) async {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController(text: existing?.name ?? '');
    final urlController = TextEditingController(text: existing?.url ?? '');
    // 新建时默认继承当前凭证，编辑时显示已保存的凭证
    String? defaultUser;
    String? defaultPass;
    if (existing != null) {
      defaultUser = existing.username;
      defaultPass = existing.password;
    } else {
      // 从当前服务器获取凭证作为默认值
      final currentUrl = ref.read(baseUrlProvider);
      final servers = ref.read(serversProvider).value ?? const <ServerEntry>[];
      final current = servers.where((e) => e.url == currentUrl).firstOrNull;
      defaultUser = current?.username;
      defaultPass = current?.password;
    }
    final usernameController = TextEditingController(text: defaultUser ?? '');
    final passwordController = TextEditingController(text: defaultPass ?? '');
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null
            ? l10n.settingsServersAdd
            : l10n.settingsServersEditTitle),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: l10n.settingsServersNameLabel,
                    hintText: l10n.settingsServersNameHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: urlController,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: l10n.settingsServersUrlLabel,
                    hintText: 'http://192.168.1.10:58091',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    try {
                      ServerEntry.normalizeUrl(v ?? '');
                      return null;
                    } on FormatException catch (e) {
                      return e.message;
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: usernameController,
                  decoration: InputDecoration(
                    labelText: l10n.settingsServersUsername,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.settingsServersPassword,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: Text(l10n.settingsServersSave),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final url = ServerEntry.normalizeUrl(urlController.text);
      final name = nameController.text.trim();
      final username = usernameController.text.trim().isEmpty
          ? null : usernameController.text.trim();
      final password = passwordController.text.isEmpty
          ? null : passwordController.text;
      final notifier = ref.read(serversProvider.notifier);
      if (existing == null) {
        await notifier.add(
          ServerEntry(
            id: ServerEntry.generateId(),
            name: name,
            url: url,
            username: username,
            password: password,
          ),
        );
      } else {
        await notifier.editEntry(existing.copyWith(
          name: name,
          url: url,
          usernameOverride: () => username,
          passwordOverride: () => password,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ResponsiveSnackBar.showError(context, message: l10n.settingsServersSaveFailed('$e'));
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ServerEntry entry,
    bool isCurrent,
  ) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsServersDeleteTitle),
        content: Text(
          isCurrent
              ? l10n.settingsServersDeleteCurrentConfirm
              : l10n.settingsServersDeleteConfirm(entry.displayName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(serversProvider.notifier).remove(entry.id);
  }

  Future<void> _probeOne(
    BuildContext context,
    WidgetRef ref,
    ServerEntry entry,
  ) async {
    final l10n = AppLocalizations.of(context);
    _setStatus(ref, entry.id, ProbeStatus.probing);
    final result = await ServerProbe.probeOne(entry);
    _setStatus(ref, entry.id, result.ok ? ProbeStatus.ok : ProbeStatus.fail);
    if (context.mounted) {
      ResponsiveSnackBar.show(
        context,
        message: result.ok
            ? l10n.settingsServersReachable(entry.displayName)
            : l10n.settingsServersUnreachable(entry.displayName),
      );
    }
  }

  Future<void> _probeAll(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final servers = ref.read(serversProvider).value ?? const <ServerEntry>[];
    if (servers.isEmpty) return;
    for (final s in servers) {
      _setStatus(ref, s.id, ProbeStatus.probing);
    }
    final results = await ServerProbe.probeAll(servers);
    for (final r in results) {
      _setStatus(ref, r.entry.id, r.ok ? ProbeStatus.ok : ProbeStatus.fail);
    }
    if (context.mounted) {
      final okCount = results.where((r) => r.ok).length;
      ResponsiveSnackBar.show(
        context,
        message: l10n.settingsServersProbeResult(okCount, results.length),
      );
    }
  }

  Future<void> _switchTo(
    BuildContext context,
    WidgetRef ref,
    ServerEntry entry,
    bool isCurrent,
  ) async {
    final l10n = AppLocalizations.of(context);
    if (isCurrent) {
      ResponsiveSnackBar.show(context, message: l10n.settingsServersAlreadyCurrent);
      return;
    }
    await applyServerSelection(ref, entry);
    if (context.mounted) {
      ResponsiveSnackBar.show(
        context,
        message: l10n.settingsServersSwitched(entry.displayName),
      );
    }
  }

  void _setStatus(WidgetRef ref, String id, ProbeStatus status) {
    ref.read(probeStatusProvider.notifier).setStatus(id, status);
  }
}

class _ServerTile extends StatelessWidget {
  final int index;
  final ServerEntry entry;
  final bool isCurrent;
  final ProbeStatus status;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTest;
  final VoidCallback onSwitchTo;

  const _ServerTile({
    super.key,
    required this.index,
    required this.entry,
    required this.isCurrent,
    required this.status,
    required this.onEdit,
    required this.onDelete,
    required this.onTest,
    required this.onSwitchTo,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: SizedBox(
        width: 40,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatusDot(status: status),
            const SizedBox(width: 6),
            if (isCurrent)
              Icon(Icons.check_circle, size: 18, color: colorScheme.primary)
            else
              const SizedBox(width: 18),
          ],
        ),
      ),
      title: Text(
        entry.name.isNotEmpty ? entry.name : entry.displayName,
        style: TextStyle(
          fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle: Text(entry.url, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: onEdit,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PopupMenuButton<String>(
            tooltip: l10n.more,
            onSelected: (v) {
              switch (v) {
                case 'edit':
                  onEdit();
                case 'delete':
                  onDelete();
                case 'test':
                  onTest();
                case 'switch':
                  onSwitchTo();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'switch', child: Text(l10n.settingsServersSwitchTo)),
              PopupMenuItem(value: 'test', child: Text(l10n.settingsServersTestConnection)),
              PopupMenuItem(value: 'edit', child: Text(l10n.settingsServersEditAction)),
              PopupMenuItem(
                value: 'delete',
                child: Text(l10n.commonDelete),
              ),
            ],
          ),
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.drag_handle),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final ProbeStatus status;
  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case ProbeStatus.ok:
        color = Colors.green;
      case ProbeStatus.fail:
        color = Theme.of(context).colorScheme.error;
      case ProbeStatus.probing:
        return const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case ProbeStatus.unknown:
        color = Theme.of(context).colorScheme.outlineVariant;
    }
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// 本地模式配置卡片（仅在 HAS_BACKEND=true 的移动端构建中显示）
class _LocalModeCard extends ConsumerStatefulWidget {
  const _LocalModeCard();

  @override
  ConsumerState<_LocalModeCard> createState() => _LocalModeCardState();
}

class _LocalModeCardState extends ConsumerState<_LocalModeCard> {
  bool _isSwitching = false;

  @override
  Widget build(BuildContext context) {
    final runMode = ref.watch(runModeProvider);
    final musicDir = ref.watch(localMusicDirProvider);
    final isLocal = runMode == RunMode.local;
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.phone_android, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.settingsServersLocalMode,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Switch(
                  value: isLocal,
                  onChanged: _isSwitching
                      ? null
                      : (value) => _handleToggle(value),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.settingsServersLocalModeDesc,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            if (_isSwitching) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
            ],
            if (isLocal && !_isSwitching) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.settingsServersMusicDir,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          musicDir ?? l10n.settingsServersNotSelected,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: musicDir != null
                                    ? colorScheme.onSurface
                                    : colorScheme.error,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // iOS 固定使用 app Documents 目录，不提供手动选择。
                  if (!EmbeddedBackendService.usesFixedMusicDir) ...[
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      onPressed: () => _pickMusicDir(),
                      child: Text(l10n.settingsServersSelect),
                    ),
                  ],
                ],
              ),
              if (EmbeddedBackendService.usesFixedMusicDir) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.settingsServersFixedMusicDirHint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleToggle(bool enableLocal) async {
    setState(() => _isSwitching = true);
    try {
      if (enableLocal) {
        await _switchToLocal();
      } else {
        await _switchToRemote();
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(context,
            message: AppLocalizations.of(context).settingsServersSwitchFailed('$e'));
      }
    } finally {
      if (mounted) {
        setState(() => _isSwitching = false);
      }
    }
  }

  Future<void> _switchToLocal() async {
    final musicDir = await EmbeddedBackendService.pickMusicDir(
      ref.read(localMusicDirProvider),
    );
    if (musicDir == null || musicDir.isEmpty) return;
    await ref.read(localMusicDirProvider.notifier).set(musicDir);

    // 存档当前远程 session
    final storage = SecureStorageService();
    final currentUrl = ref.read(baseUrlProvider);
    await storage.saveWallet(SecureStorageService.walletKey(currentUrl));

    await ref.read(runModeProvider.notifier).set(RunMode.local);
    await EmbeddedBackendService.ensureStoragePermission();

    final dataDir = (await getApplicationSupportDirectory()).path;
    final port = await EmbeddedBackendService.start(
      dataDir: dataDir,
      musicDir: musicDir,
    );

    final baseUrl = 'http://127.0.0.1:$port';
    ref.read(baseUrlProvider.notifier).set(baseUrl);

    final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 2)));
    for (var i = 0; i < 10; i++) {
      try {
        final resp = await dio.get('$baseUrl/api/v1/health');
        if (resp.statusCode == 200) break;
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
    dio.close();

    // 尝试恢复本地 session
    final restored = await storage.restoreWallet(SecureStorageService.localWalletKey);
    if (restored && !await storage.isAccessTokenExpired()) {
      ref.read(authStateProvider.notifier).setAuthenticated();
    } else {
      await ref.read(authStateProvider.notifier).login(
        username: 'admin',
        password: 'admin',
      );
    }

    if (mounted) {
      ResponsiveSnackBar.show(context,
          message: AppLocalizations.of(context).settingsServersSwitchedLocal);
    }
  }

  Future<void> _switchToRemote() async {
    // 存档本地 session
    final storage = SecureStorageService();
    await storage.saveWallet(SecureStorageService.localWalletKey);

    await ref.read(runModeProvider.notifier).set(RunMode.remote);
    await EmbeddedBackendService.stop();

    // 尝试恢复上次使用的远程服务器 session
    final servers = await ref.read(serversProvider.future);
    if (servers.isNotEmpty) {
      final target = servers.first;
      ref.read(baseUrlProvider.notifier).set(target.url);
      final restored = await storage.restoreWallet(SecureStorageService.walletKey(target.url));
      if (restored && !await storage.isAccessTokenExpired()) {
        ref.read(authStateProvider.notifier).setAuthenticated();
        return;
      }
    }
    // 无可恢复的 session → 清除并回到登录页
    await storage.clearTokens();
    ref.read(authStateProvider.notifier).setUnauthenticated();
  }

  Future<void> _pickMusicDir() async {
    // 传 null 强制在非 iOS 平台弹出选择器重新选目录；iOS 固定 Documents 目录。
    final result = await EmbeddedBackendService.pickMusicDir(null);
    if (result != null) {
      await ref.read(localMusicDirProvider.notifier).set(result);
      if (mounted) {
        ResponsiveSnackBar.show(context,
            message: AppLocalizations.of(context).settingsServersMusicDirUpdated);
      }
    }
  }
}
