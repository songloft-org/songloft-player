import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('服务器'),
        actions: [
          if (!isLocal)
            IconButton(
              tooltip: '全部测试',
              icon: const Icon(Icons.network_check),
              onPressed: () => _probeAll(context, ref),
            ),
        ],
      ),
      body: serversAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
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
                            '尚未添加服务器',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '点击右下角「+」添加 API 地址。\n启动时会按顺序探测，优先使用排在前面的可达项。',
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
                  onReorder: (oldIndex, newIndex) {
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
        tooltip: '添加服务器',
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    ServerEntry? existing,
  ) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final urlController = TextEditingController(text: existing?.url ?? '');
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? '添加服务器' : '编辑服务器'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '名称（可选）',
                  hintText: '局域网 / 广域网 / 备用',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: urlController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'API 地址',
                  hintText: 'http://192.168.1.10:58091',
                  border: OutlineInputBorder(),
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
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final url = ServerEntry.normalizeUrl(urlController.text);
      final name = nameController.text.trim();
      final notifier = ref.read(serversProvider.notifier);
      if (existing == null) {
        await notifier.add(
          ServerEntry(id: ServerEntry.generateId(), name: name, url: url),
        );
      } else {
        await notifier.editEntry(existing.copyWith(name: name, url: url));
      }
    } catch (e) {
      if (context.mounted) {
        ResponsiveSnackBar.showError(context, message: '保存失败: $e');
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ServerEntry entry,
    bool isCurrent,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除服务器'),
        content: Text(
          isCurrent
              ? '此为当前正在使用的服务器，删除后下次启动将重新探测列表中其他项。是否继续？'
              : '确定要删除「${entry.displayName}」吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
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
    _setStatus(ref, entry.id, ProbeStatus.probing);
    final result = await ServerProbe.probeOne(entry);
    _setStatus(ref, entry.id, result.ok ? ProbeStatus.ok : ProbeStatus.fail);
    if (context.mounted) {
      ResponsiveSnackBar.show(
        context,
        message: result.ok
            ? '${entry.displayName} 可达'
            : '${entry.displayName} 不可达',
      );
    }
  }

  Future<void> _probeAll(BuildContext context, WidgetRef ref) async {
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
        message: '探测完成：$okCount / ${results.length} 可达',
      );
    }
  }

  Future<void> _switchTo(
    BuildContext context,
    WidgetRef ref,
    ServerEntry entry,
    bool isCurrent,
  ) async {
    if (isCurrent) {
      ResponsiveSnackBar.show(context, message: '已是当前使用的服务器');
      return;
    }
    await applyServerSelection(ref, entry);
    if (context.mounted) {
      ResponsiveSnackBar.show(
        context,
        message: '已切换到 ${entry.displayName}，请重新登录',
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
            tooltip: '更多',
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
              const PopupMenuItem(value: 'switch', child: Text('切换到此项')),
              const PopupMenuItem(value: 'test', child: Text('测试连接')),
              const PopupMenuItem(value: 'edit', child: Text('编辑')),
              const PopupMenuItem(
                value: 'delete',
                child: Text('删除'),
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
                    '本地模式',
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
              '开启后在设备上运行后端，无需网络即可播放本地音乐。',
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
                          '音乐目录',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          musicDir ?? '未选择',
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
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: () => _pickMusicDir(),
                    child: const Text('选择'),
                  ),
                ],
              ),
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
        ResponsiveSnackBar.showError(context, message: '切换失败：$e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSwitching = false);
      }
    }
  }

  Future<void> _switchToLocal() async {
    var musicDir = ref.read(localMusicDirProvider);
    if (musicDir == null || musicDir.isEmpty) {
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择音乐文件夹',
      );
      if (result == null) return;
      await ref.read(localMusicDirProvider.notifier).set(result);
      musicDir = result;
    }

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

    await ref.read(authStateProvider.notifier).login(
      username: 'admin',
      password: 'admin',
    );

    if (mounted) {
      ResponsiveSnackBar.show(context, message: '已切换到本地模式');
    }
  }

  Future<void> _switchToRemote() async {
    await ref.read(runModeProvider.notifier).set(RunMode.remote);
    await EmbeddedBackendService.stop();
    await ref.read(authStateProvider.notifier).logout();
  }

  Future<void> _pickMusicDir() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择音乐文件夹',
    );
    if (result != null) {
      await ref.read(localMusicDirProvider.notifier).set(result);
      if (mounted) {
        ResponsiveSnackBar.show(context, message: '音乐目录已更新');
      }
    }
  }
}
