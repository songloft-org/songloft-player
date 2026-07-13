import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/network/api_exceptions.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/theme/responsive.dart';
import '../../../../shared/constants/github_proxy.dart';
import '../../../../shared/utils/responsive_snackbar.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../data/jsplugin_api.dart';
import '../providers/jsplugin_provider.dart';
import 'github_proxy_selection.dart';
import 'plugin_icon.dart';

/// JS 插件管理组件
class JSPluginManager extends ConsumerStatefulWidget {
  const JSPluginManager({super.key});

  @override
  ConsumerState<JSPluginManager> createState() => _JSPluginManagerState();
}

class _JSPluginManagerState extends ConsumerState<JSPluginManager>
    with GithubProxySelectionMixin<JSPluginManager> {
  @override
  List<String> get proxyPresetValues =>
      kGithubProxyPresets.map((e) => e.value).toList();

  @override
  void initState() {
    super.initState();
    restoreGithubProxy();
  }

  /// 当前代理的展示文案
  String get _proxyLabel {
    if (selectedProxyIndex == -1) {
      final v = customProxyController.text.trim();
      return v.isEmpty ? AppLocalizations.of(context).jspluginCustomProxy : v;
    }
    if (selectedProxyIndex >= 0 && selectedProxyIndex < kGithubProxyPresets.length) {
      return kGithubProxyPresets[selectedProxyIndex].label;
    }
    return kGithubProxyPresets.first.label;
  }

  /// 插件自动更新开关
  Widget _buildAutoUpdateTile(AppLocalizations l10n) {
    final autoUpdateAsync = ref.watch(pluginAutoUpdateProvider);
    return SwitchListTile(
      secondary: const Icon(Icons.autorenew),
      title: Text(l10n.jspluginAutoUpdate),
      subtitle: Text(l10n.jspluginAutoUpdateHint),
      value: autoUpdateAsync.asData?.value ?? false,
      onChanged: autoUpdateAsync.isLoading
          ? null
          : (enabled) => _toggleAutoUpdate(enabled),
    );
  }

  Future<void> _toggleAutoUpdate(bool enabled) async {
    final api = ref.read(settingsApiProvider);
    try {
      await api.setPluginAutoUpdate(enabled);
    } catch (e) {
      if (!mounted) return;
      ResponsiveSnackBar.showError(context, message: e.toString());
    } finally {
      ref.invalidate(pluginAutoUpdateProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pluginsAsync = ref.watch(jsPluginsProvider);

    return ExpansionTile(
      leading: const Icon(Icons.javascript),
      title: Text(l10n.jspluginManagerTitle),
      subtitle: Text(l10n.jspluginManagerSubtitle),
      initiallyExpanded: true,
      onExpansionChanged: (expanded) {
        if (expanded) ref.invalidate(jsPluginsProvider);
      },
      children: [
        // 统一的 GitHub 代理选择（更新/批量更新/强制更新共用）
        _buildProxySelectorTile(),
        const Divider(height: 1),
        // 顶部操作栏
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child:
              context.isMobile
                  ? Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _showUploadDialog,
                        icon: const Icon(Icons.upload_file),
                        label: Text(l10n.jspluginUploadPlugin),
                      ),
                      OutlinedButton.icon(
                        onPressed: _showBatchUpdateDialog,
                        icon: const Icon(Icons.system_update),
                        label: Text(l10n.jspluginUpdateAll),
                      ),
                      OutlinedButton.icon(
                        onPressed: _cleanupOrphanStorage,
                        icon: const Icon(Icons.cleaning_services_outlined),
                        label: Text(l10n.jspluginCleanupData),
                      ),
                    ],
                  )
                  : Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _showUploadDialog,
                        icon: const Icon(Icons.upload_file),
                        label: Text(l10n.jspluginUploadPlugin),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _showBatchUpdateDialog,
                        icon: const Icon(Icons.system_update),
                        label: Text(l10n.jspluginUpdateAll),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _cleanupOrphanStorage,
                        icon: const Icon(Icons.cleaning_services_outlined),
                        label: Text(l10n.jspluginCleanupData),
                      ),
                    ],
                  ),
        ),
        const Divider(height: 1),

        // 自动更新开关
        _buildAutoUpdateTile(l10n),
        const Divider(height: 1),

        // 插件列表
        pluginsAsync.when(
          data: (plugins) => _buildPluginList(plugins),
          loading:
              () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
          error:
              (error, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      error is ApiException ? error.message : l10n.commonLoadFailed,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => ref.invalidate(jsPluginsProvider),
                      child: Text(l10n.commonRetry),
                    ),
                  ],
                ),
              ),
        ),
      ],
    );
  }

  /// 统一的 GitHub 代理选择入口（下拉菜单）
  Widget _buildProxySelectorTile() {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return PopupMenuButton<int>(
      tooltip: l10n.jspluginGithubProxy,
      onSelected: (value) {
        if (value == -1) {
          _showCustomProxyDialog();
        } else {
          setState(() => selectedProxyIndex = value);
          persistGithubProxy();
        }
      },
      itemBuilder: (context) => [
        ...List.generate(kGithubProxyPresets.length, (index) {
          return PopupMenuItem<int>(
            value: index,
            child: Row(
              children: [
                if (selectedProxyIndex == index)
                  Icon(Icons.check, size: 18, color: theme.colorScheme.primary)
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 8),
                Text(
                  kGithubProxyPresets[index].value.isEmpty
                      ? l10n.githubProxyDirect
                      : kGithubProxyPresets[index].label,
                ),
              ],
            ),
          );
        }),
        const PopupMenuDivider(),
        PopupMenuItem<int>(
          value: -1,
          child: Row(
            children: [
              if (selectedProxyIndex == -1)
                Icon(Icons.check, size: 18, color: theme.colorScheme.primary)
              else
                const SizedBox(width: 18),
              const SizedBox(width: 8),
              Text(
                selectedProxyIndex == -1
                    ? l10n.jspluginCustomProxyWith(customProxyController.text)
                    : l10n.jspluginCustomProxyEllipsis,
              ),
            ],
          ),
        ),
      ],
      child: ListTile(
        leading: Icon(
          Icons.vpn_key_outlined,
          color: effectiveProxy.isNotEmpty ? theme.colorScheme.primary : null,
        ),
        title: Text(l10n.jspluginGithubProxy),
        subtitle: Text(
          effectiveProxy.isEmpty ? l10n.githubProxyDirect : _proxyLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.arrow_drop_down),
      ),
    );
  }

  void _showCustomProxyDialog() {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: customProxyController.text);
    showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.jspluginCustomProxy),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'https://your-proxy.com/',
            helperText: l10n.jspluginProxyHelper,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) =>
              Navigator.of(context).pop(controller.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(controller.text.trim()),
            child: Text(l10n.jspluginOk),
          ),
        ],
      ),
    ).then((value) {
      if (value != null && mounted) {
        customProxyController.text = value;
        setState(() => selectedProxyIndex = -1);
        persistGithubProxy();
      }
    });
  }

  void _showUploadDialog() {
    showDialog(
      context: context,
      builder:
          (context) => _JSPluginUploadDialog(
            onUploadComplete: () {
              ref.invalidate(jsPluginsProvider);
            },
            pluginApi: ref.read(jsPluginApiProvider),
          ),
    );
  }

  void _showBatchUpdateDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _JSPluginBatchUpdateDialog(
        pluginApi: ref.read(jsPluginApiProvider),
        onUpdateComplete: () => ref.invalidate(jsPluginsProvider),
      ),
    );
  }

  Future<void> _cleanupOrphanStorage() async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.jspluginCleanupOrphanTitle),
            content: Text(l10n.jspluginCleanupOrphanContent),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.jspluginCleanup),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    try {
      final api = ref.read(jsPluginApiProvider);
      final message = await api.cleanupOrphanStorage();
      if (mounted) {
        ResponsiveSnackBar.show(context, message: message);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(
          context,
          message: l10n.jspluginCleanupFailed(e.message),
        );
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(
          context,
          message: l10n.jspluginCleanupFailed(e.toString()),
        );
      }
    }
  }

  Widget _buildPluginList(List<JSPlugin> plugins) {
    if (plugins.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.extension_off, size: 48, color: Colors.grey),
              const SizedBox(height: 8),
              Text(AppLocalizations.of(context).jspluginNoInstalled),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: plugins.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final plugin = plugins[index];
        return _JSPluginItem(plugin: plugin);
      },
    );
  }
}

/// JS 插件上传对话框
class _JSPluginUploadDialog extends StatefulWidget {
  final VoidCallback onUploadComplete;
  final JSPluginApi pluginApi;

  const _JSPluginUploadDialog({
    required this.onUploadComplete,
    required this.pluginApi,
  });

  @override
  State<_JSPluginUploadDialog> createState() => _JSPluginUploadDialogState();
}

class _JSPluginUploadDialogState extends State<_JSPluginUploadDialog> {
  PlatformFile? _selectedFile;
  bool _uploading = false;

  /// 格式化文件大小
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// 选择文件
  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        withData: kIsWeb,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = result.files.first;
        });
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(
          context,
          message: AppLocalizations.of(context).jspluginPickFileFailed(e.toString()),
        );
      }
    }
  }

  /// 上传文件
  Future<void> _uploadFile() async {
    final file = _selectedFile;
    if (file == null) return;

    final l10n = AppLocalizations.of(context);
    setState(() => _uploading = true);

    try {
      JSPluginUploadResponse response;

      if (kIsWeb) {
        final bytes = file.bytes;
        if (bytes == null) {
          throw ApiException(message: l10n.jspluginCannotReadFile);
        }
        response = await widget.pluginApi.uploadPluginBytes(bytes, file.name);
      } else {
        final path = file.path;
        if (path == null) {
          throw ApiException(message: l10n.jspluginCannotGetPath);
        }
        response = await widget.pluginApi.uploadPlugin(path, file.name);
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onUploadComplete();

        if (response.success > 0 && response.failed == 0) {
          ResponsiveSnackBar.showSuccess(
            context,
            message:
                response.message.isNotEmpty
                    ? response.message
                    : l10n.jspluginUploadSuccess(response.success),
          );
        } else if (response.failed > 0) {
          final failedResults =
              response.results.where((r) => !r.success).toList();
          final errorMsg = failedResults
              .map((r) => '${r.fileName}: ${r.error}')
              .join('\n');
          ResponsiveSnackBar.show(
            context,
            message: l10n.jspluginUploadPartial(
              response.success,
              response.failed,
              errorMsg,
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          );
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(
          context,
          message: l10n.jspluginUploadFailed(e.message),
        );
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(
          context,
          message: l10n.jspluginUploadFailed(e.toString()),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Text(l10n.jspluginUploadDialogTitle),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 文件选择区域
            Semantics(
              button: true,
              label: l10n.jspluginSelectFileSemantics,
              child: InkWell(
              onTap: _uploading ? null : _pickFile,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border.all(
                    color:
                        _selectedFile != null
                            ? colorScheme.primary
                            : colorScheme.outline,
                    width: _selectedFile != null ? 2 : 1,
                    strokeAlign: BorderSide.strokeAlignInside,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color:
                      _selectedFile != null
                          ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                          : null,
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 48,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    Text(l10n.jspluginTapToSelectFile, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 4),
                    Text(
                      l10n.jspluginUploadHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            ),

            // 已选文件信息
            if (_selectedFile != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.insert_drive_file,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedFile!.name,
                            style: theme.textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _formatFileSize(_selectedFile!.size),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed:
                          _uploading
                              ? null
                              : () => setState(() => _selectedFile = null),
                      tooltip: l10n.jspluginRemove,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _uploading ? null : () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton.icon(
          onPressed: _selectedFile != null && !_uploading ? _uploadFile : null,
          icon:
              _uploading
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                  : const Icon(Icons.upload),
          label: Text(_uploading ? l10n.jspluginUploading : l10n.jspluginUpload),
        ),
      ],
    );
  }
}

/// JS 插件列表项
class _JSPluginItem extends ConsumerStatefulWidget {
  final JSPlugin plugin;

  const _JSPluginItem({required this.plugin});

  @override
  ConsumerState<_JSPluginItem> createState() => _JSPluginItemState();
}

class _JSPluginItemState extends ConsumerState<_JSPluginItem> {
  bool _isToggling = false;
  bool _isDeleting = false;
  bool _isForceUpdating = false;

  Future<void> _togglePlugin() async {
    setState(() => _isToggling = true);

    try {
      final api = ref.read(jsPluginApiProvider);
      if (widget.plugin.isActive) {
        await api.disablePlugin(widget.plugin.id);
      } else {
        await api.enablePlugin(widget.plugin.id);
      }
      ref.invalidate(jsPluginsProvider);
    } on ApiException catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(
          context,
          message: AppLocalizations.of(context).jspluginOperationFailed(e.message),
        );
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(
          context,
          message: AppLocalizations.of(context).jspluginOperationFailed(e.toString()),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isToggling = false);
      }
    }
  }

  Future<void> _openHomepage(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ResponsiveSnackBar.show(
        context,
        message: AppLocalizations.of(context).jspluginCannotOpenLink(url),
      );
    }
  }

  void _showUpdateDialog() {
    showDialog(
      context: context,
      builder: (context) => _JSPluginUpdateDialog(
        plugin: widget.plugin,
        pluginApi: ref.read(jsPluginApiProvider),
        onUpdateComplete: () => ref.invalidate(jsPluginsProvider),
      ),
    );
  }

  Future<void> _showForceUpdateDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _ForceUpdateConfirmDialog(
        pluginName: widget.plugin.displayName,
      ),
    );
    if (confirmed != true || !mounted) return;

    final proxy = ref.read(githubProxyProvider).value ?? '';
    setState(() => _isForceUpdating = true);
    try {
      final api = ref.read(jsPluginApiProvider);
      await api.updatePlugin(
        widget.plugin.id,
        githubProxy: proxy.isNotEmpty ? proxy : null,
        force: true,
      );
      ref.invalidate(jsPluginsProvider);
      if (mounted) {
        ResponsiveSnackBar.showSuccess(
          context,
          message: AppLocalizations.of(context).jspluginForceUpdateSuccess,
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(
          context,
          message: AppLocalizations.of(context).jspluginForceUpdateFailed(e.message),
        );
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(
          context,
          message: AppLocalizations.of(context).jspluginForceUpdateFailed(e.toString()),
        );
      }
    } finally {
      if (mounted) setState(() => _isForceUpdating = false);
    }
  }

  Future<void> _toggleKeepAlive() async {
    final settingsApi = ref.read(settingsApiProvider);
    final currentList =
        ref.read(pluginKeepAliveProvider).value ?? <String>[];
    final entryPath = widget.plugin.entryPath;
    if (entryPath == null) return;

    final List<String> newList = currentList.contains(entryPath)
        ? currentList.where((e) => e != entryPath).toList()
        : [...currentList, entryPath];

    try {
      await settingsApi.setPluginKeepAlive(newList);
      ref.invalidate(pluginKeepAliveProvider);
    } on ApiException catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(
          context,
          message: AppLocalizations.of(context).jspluginOperationFailed(e.message),
        );
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(
          context,
          message: AppLocalizations.of(context).jspluginOperationFailed(e.toString()),
        );
      }
    }
  }

  Future<void> _deletePlugin() async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<({bool confirmed, bool keepData})>(
      context: context,
      builder: (context) {
        var keepData = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(l10n.jspluginConfirmDelete),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.jspluginDeleteConfirmContent(widget.plugin.displayName)),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: keepData,
                    onChanged: (v) => setDialogState(() => keepData = v!),
                    title: Text(l10n.jspluginKeepData),
                    subtitle: Text(l10n.jspluginKeepDataSubtitle),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed:
                      () => Navigator.pop(
                        context,
                        (confirmed: false, keepData: false),
                      ),
                  child: Text(l10n.commonCancel),
                ),
                FilledButton(
                  onPressed:
                      () => Navigator.pop(
                        context,
                        (confirmed: true, keepData: keepData),
                      ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: Text(l10n.commonDelete),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null || !result.confirmed) return;

    setState(() => _isDeleting = true);

    try {
      final api = ref.read(jsPluginApiProvider);
      await api.deletePlugin(widget.plugin.id, keepData: result.keepData);
      ref.invalidate(jsPluginsProvider);
      if (mounted) {
        ResponsiveSnackBar.show(context, message: l10n.jspluginDeleted);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(
          context,
          message: l10n.jspluginDeleteFailed(e.message),
        );
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(
          context,
          message: l10n.jspluginDeleteFailed(e.toString()),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final plugin = widget.plugin;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMobile = context.isMobile;

    // 状态颜色
    Color statusColor;
    if (plugin.isError) {
      statusColor = Colors.red;
    } else if (plugin.isActive) {
      statusColor = Colors.green;
    } else {
      statusColor = Colors.grey;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 第 1 行 —— 标题行：头像 + 插件名 + 操作区
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              PluginIcon(
                iconUrl: plugin.iconUrl,
                displayName: plugin.displayName,
                size: 36,
                statusColor: statusColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  plugin.displayName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ..._buildTrailingActions(isMobile),
            ],
          ),
          // 第 2 行 —— 元信息行：状态胶囊 + 版本号 + 作者
          Padding(
            padding: const EdgeInsets.only(left: 48, top: 6),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildStatusChip(plugin, colorScheme),
                if (plugin.version != null)
                  _buildVersionBadge(plugin.version!, theme),
                if (plugin.author != null)
                  Text(
                    l10n.jspluginAuthor(plugin.author!),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          // 第 3 行 —— 描述（如果存在）
          if (plugin.description != null)
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 6),
              child: Text(
                plugin.description!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          // 第 4 行 —— 主页链接（仅桌面端）
          if (!isMobile &&
              plugin.homepage != null &&
              plugin.homepage!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 4),
              child: Semantics(
                link: true,
                label: l10n.jspluginOpenHomepageSemantics,
                child: GestureDetector(
                onTap: () => _openHomepage(plugin.homepage!),
                child: Text(
                  plugin.homepage!,
                  style: TextStyle(
                    color: colorScheme.primary,
                    decoration: TextDecoration.underline,
                    decorationColor: colorScheme.primary,
                    fontSize: theme.textTheme.bodySmall?.fontSize,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ),
            ),
        ],
      ),
    );
  }

  /// 状态胶囊
  Widget _buildStatusChip(JSPlugin plugin, ColorScheme colorScheme) {
    final l10n = AppLocalizations.of(context);
    final String label;
    final Color color;
    if (plugin.isError) {
      label = l10n.jspluginStatusError;
      color = Colors.red;
    } else if (plugin.isActive) {
      label = l10n.jspluginStatusEnabled;
      color = Colors.green;
    } else {
      label = l10n.jspluginStatusDisabled;
      color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 版本号徽章
  Widget _buildVersionBadge(String version, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text('v$version', style: theme.textTheme.labelSmall),
    );
  }

  /// 标题行右侧的操作区
  List<Widget> _buildTrailingActions(bool isMobile) {
    final l10n = AppLocalizations.of(context);
    final plugin = widget.plugin;
    final colorScheme = Theme.of(context).colorScheme;
    final keepAliveList =
        ref.watch(pluginKeepAliveProvider).value ?? [];
    final isKeepAlive = keepAliveList.contains(plugin.entryPath);

    final Widget switchOrLoader =
        _isToggling
            ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
            : Switch(value: plugin.isActive, onChanged: (_) => _togglePlugin());

    if (isMobile) {
      return [
        switchOrLoader,
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          tooltip: l10n.jspluginMoreActions,
          onSelected: (value) {
            switch (value) {
              case 'homepage':
                _openHomepage(plugin.homepage!);
              case 'keep_alive':
                _toggleKeepAlive();
              case 'update':
                _showUpdateDialog();
              case 'force_update':
                _showForceUpdateDialog();
              case 'delete':
                _deletePlugin();
            }
          },
          itemBuilder:
              (context) => [
                if (plugin.homepage != null && plugin.homepage!.isNotEmpty) ...[
                  PopupMenuItem<String>(
                    value: 'homepage',
                    child: ListTile(
                      leading: const Icon(Icons.open_in_new),
                      title: Text(l10n.jspluginOpenHomepage),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuDivider(),
                ],
                if (plugin.isActive)
                  PopupMenuItem<String>(
                    value: 'keep_alive',
                    child: ListTile(
                      leading: Icon(
                        isKeepAlive
                            ? Icons.push_pin
                            : Icons.push_pin_outlined,
                      ),
                      title: Text(l10n.jspluginKeepAlive),
                      trailing: isKeepAlive
                          ? const Icon(Icons.check, size: 18)
                          : null,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                PopupMenuItem<String>(
                  value: 'update',
                  child: ListTile(
                    leading: const Icon(Icons.system_update_alt),
                    title: Text(l10n.jspluginCheckUpdate),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'force_update',
                  enabled: !_isForceUpdating,
                  child: ListTile(
                    leading:
                        _isForceUpdating
                            ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.refresh),
                    title: Text(l10n.jspluginForceUpdate),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  enabled: !_isDeleting,
                  child: ListTile(
                    leading:
                        _isDeleting
                            ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : Icon(
                              Icons.delete_outline,
                              color: colorScheme.error,
                            ),
                    title: Text(
                      l10n.commonDelete,
                      style: TextStyle(color: colorScheme.error),
                    ),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
        ),
      ];
    }

    // 桌面端
    return [
      switchOrLoader,
      if (plugin.isActive)
        IconButton(
          icon: Icon(
            isKeepAlive ? Icons.push_pin : Icons.push_pin_outlined,
          ),
          onPressed: _toggleKeepAlive,
          tooltip: isKeepAlive ? l10n.jspluginCancelKeepAlive : l10n.jspluginKeepAlive,
        ),
      PopupMenuButton<String>(
        icon:
            _isForceUpdating
                ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : const Icon(Icons.system_update_alt),
        tooltip: l10n.jspluginUpdate,
        onSelected: (value) {
          switch (value) {
            case 'update':
              _showUpdateDialog();
            case 'force_update':
              _showForceUpdateDialog();
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            value: 'update',
            child: ListTile(
              leading: const Icon(Icons.system_update_alt),
              title: Text(l10n.jspluginCheckUpdate),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem<String>(
            value: 'force_update',
            child: ListTile(
              leading: const Icon(Icons.refresh),
              title: Text(l10n.jspluginForceUpdate),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
      IconButton(
        icon:
            _isDeleting
                ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : const Icon(Icons.delete_outline),
        onPressed: _isDeleting ? null : _deletePlugin,
        tooltip: l10n.commonDelete,
      ),
    ];
  }
}

/// JS 插件远程更新对话框：支持代理选择 + 检查更新 + 立即更新
class _JSPluginUpdateDialog extends ConsumerStatefulWidget {
  final JSPlugin plugin;
  final JSPluginApi pluginApi;
  final VoidCallback onUpdateComplete;

  const _JSPluginUpdateDialog({
    required this.plugin,
    required this.pluginApi,
    required this.onUpdateComplete,
  });

  @override
  ConsumerState<_JSPluginUpdateDialog> createState() =>
      _JSPluginUpdateDialogState();
}

class _JSPluginUpdateDialogState extends ConsumerState<_JSPluginUpdateDialog> {
  bool _isChecking = false;
  bool _isUpdating = false;
  String? _error;
  JSPluginUpdateCheck? _checkResult;

  /// 当前生效的 GitHub 代理，来自插件管理顶部的统一选择。
  String get _proxy => ref.read(githubProxyProvider).value ?? '';

  Future<void> _checkUpdate() async {
    final proxy = _proxy;
    setState(() {
      _isChecking = true;
      _error = null;
      _checkResult = null;
    });

    try {
      final result = await widget.pluginApi
          .checkUpdate(
            widget.plugin.id,
            githubProxy: proxy.isNotEmpty ? proxy : null,
          )
          .timeout(const Duration(seconds: 20));
      if (mounted) setState(() => _checkResult = result);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on TimeoutException {
      if (mounted) {
        setState(() => _error = AppLocalizations.of(context).jspluginCheckUpdateTimeout);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = AppLocalizations.of(context).jspluginCheckUpdateFailed(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _executeUpdate() async {
    final proxy = _proxy;
    setState(() {
      _isUpdating = true;
      _error = null;
    });

    try {
      await widget.pluginApi
          .updatePlugin(
            widget.plugin.id,
            githubProxy: proxy.isNotEmpty ? proxy : null,
          )
          .timeout(const Duration(seconds: 120));
      if (mounted) {
        Navigator.pop(context);
        widget.onUpdateComplete();
        ResponsiveSnackBar.showSuccess(
          context,
          message: AppLocalizations.of(context).jspluginUpdateSuccess,
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = AppLocalizations.of(context).jspluginUpdateFailed(e.message));
      }
    } on TimeoutException {
      if (mounted) {
        setState(() => _error = AppLocalizations.of(context).jspluginUpdateTimeout);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = AppLocalizations.of(context).jspluginUpdateFailed(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.system_update_alt),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.jspluginUpdateDialogTitle(widget.plugin.displayName),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: context.responsiveDialogMaxWidth,
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: colorScheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: colorScheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),

              if (_isChecking)
                Center(
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(l10n.jspluginCheckingUpdate),
                    ],
                  ),
                )
              else if (_isUpdating)
                Center(
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(l10n.jspluginDownloadingUpdate),
                      const SizedBox(height: 8),
                      Text(l10n.jspluginDoNotCloseDialog, style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              else if (_checkResult != null)
                _buildCheckResult(_checkResult!),
            ],
          ),
        ),
      ),
      actions: _buildActions(),
    );
  }

  Widget _buildCheckResult(JSPluginUpdateCheck check) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (!check.hasUpdate) {
      return Center(
        child: Column(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 48),
            const SizedBox(height: 16),
            Text(l10n.jspluginAlreadyLatest),
            const SizedBox(height: 8),
            Text(
              l10n.jspluginCurrentVersion(check.currentVersion),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.new_releases, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(l10n.jspluginNewVersionFound)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'v${check.currentVersion}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward,
                size: 16,
                color: colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              Text(
                'v${check.remoteVersion}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActions() {
    final l10n = AppLocalizations.of(context);
    if (_isUpdating) {
      return [];
    }

    if (_isChecking) {
      return [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            minimumSize: context.responsiveButtonMinSize,
          ),
          child: Text(l10n.commonCancel),
        ),
      ];
    }

    if (_checkResult != null && _checkResult!.hasUpdate) {
      return [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            minimumSize: context.responsiveButtonMinSize,
          ),
          child: Text(l10n.commonCancel),
        ),
        OutlinedButton(
          onPressed: _checkUpdate,
          style: OutlinedButton.styleFrom(
            minimumSize: context.responsiveButtonMinSize,
          ),
          child: Text(l10n.jspluginRecheck),
        ),
        FilledButton(
          onPressed: _executeUpdate,
          style: FilledButton.styleFrom(
            minimumSize: context.responsiveButtonMinSize,
          ),
          child: Text(l10n.jspluginUpdateNow),
        ),
      ];
    }

    if (_checkResult != null || _error != null) {
      return [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            minimumSize: context.responsiveButtonMinSize,
          ),
          child: Text(l10n.jspluginClose),
        ),
        FilledButton(
          onPressed: _checkUpdate,
          style: FilledButton.styleFrom(
            minimumSize: context.responsiveButtonMinSize,
          ),
          child: Text(l10n.jspluginRecheck),
        ),
      ];
    }

    return [
      TextButton(
        onPressed: () => Navigator.pop(context),
        style: TextButton.styleFrom(
          minimumSize: context.responsiveButtonMinSize,
        ),
        child: Text(l10n.commonCancel),
      ),
      FilledButton(
        onPressed: _checkUpdate,
        style: FilledButton.styleFrom(
          minimumSize: context.responsiveButtonMinSize,
        ),
        child: Text(l10n.jspluginCheckUpdate),
      ),
    ];
  }
}

/// JS 插件批量更新对话框
class _JSPluginBatchUpdateDialog extends ConsumerStatefulWidget {
  final JSPluginApi pluginApi;
  final VoidCallback onUpdateComplete;

  const _JSPluginBatchUpdateDialog({
    required this.pluginApi,
    required this.onUpdateComplete,
  });

  @override
  ConsumerState<_JSPluginBatchUpdateDialog> createState() =>
      _JSPluginBatchUpdateDialogState();
}

class _JSPluginBatchUpdateDialogState
    extends ConsumerState<_JSPluginBatchUpdateDialog> {
  bool _isUpdating = false;
  JSPluginBatchUpdateResponse? _response;
  String? _error;

  /// 当前生效的 GitHub 代理，来自插件管理顶部的统一选择。
  String get _proxy => ref.read(githubProxyProvider).value ?? '';

  Future<void> _executeBatchUpdate() async {
    final proxy = _proxy;
    setState(() {
      _isUpdating = true;
      _error = null;
      _response = null;
    });

    try {
      final result = await widget.pluginApi
          .updateAllPlugins(githubProxy: proxy.isNotEmpty ? proxy : null)
          .timeout(const Duration(seconds: 300));
      if (mounted) {
        setState(() => _response = result);
        widget.onUpdateComplete();
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = AppLocalizations.of(context).jspluginBatchUpdateFailed(e.message));
      }
    } on TimeoutException {
      if (mounted) {
        setState(() => _error = AppLocalizations.of(context).jspluginBatchUpdateTimeout);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = AppLocalizations.of(context).jspluginBatchUpdateFailed(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.system_update),
          const SizedBox(width: 8),
          Text(l10n.jspluginUpdateAll),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: context.responsiveDialogMaxWidth,
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: colorScheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: colorScheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_isUpdating)
                Center(
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(l10n.jspluginBatchUpdating),
                      const SizedBox(height: 8),
                      Text(l10n.jspluginDoNotCloseDialog, style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              else if (_response != null)
                _buildResults(_response!),
            ],
          ),
        ),
      ),
      actions: _buildActions(),
    );
  }

  Widget _buildResults(JSPluginBatchUpdateResponse response) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(l10n.jspluginStatUpdated, response.updated, Colors.green),
              _buildStatItem(l10n.jspluginStatFailed, response.failed, colorScheme.error),
              _buildStatItem(l10n.jspluginStatSkipped, response.skipped, Colors.grey),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...response.results.map((r) => _buildResultItem(r, theme)),
      ],
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildResultItem(JSPluginBatchUpdateResult r, ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    final IconData icon;
    final Color color;
    final String subtitle;

    if (r.success) {
      icon = Icons.check_circle;
      color = Colors.green;
      subtitle = 'v${r.currentVersion} → v${r.newVersion}';
    } else if (r.hasUpdate) {
      icon = Icons.error;
      color = theme.colorScheme.error;
      subtitle = r.error ?? l10n.jspluginUpdateFailedShort;
    } else if (r.error != null) {
      icon = Icons.warning;
      color = Colors.orange;
      subtitle = r.error!;
    } else {
      icon = Icons.check;
      color = Colors.grey;
      subtitle = l10n.jspluginVersionLatest(r.currentVersion);
    }

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color, size: 20),
      title: Text(
        r.pluginName.isNotEmpty ? r.pluginName : r.entryPath,
        style: theme.textTheme.bodyMedium,
      ),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
    );
  }

  List<Widget> _buildActions() {
    final l10n = AppLocalizations.of(context);
    if (_isUpdating) return [];

    if (_response != null) {
      return [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          style: FilledButton.styleFrom(
            minimumSize: context.responsiveButtonMinSize,
          ),
          child: Text(l10n.jspluginClose),
        ),
      ];
    }

    return [
      TextButton(
        onPressed: () => Navigator.pop(context),
        style: TextButton.styleFrom(
          minimumSize: context.responsiveButtonMinSize,
        ),
        child: Text(l10n.commonCancel),
      ),
      FilledButton(
        onPressed: _executeBatchUpdate,
        style: FilledButton.styleFrom(
          minimumSize: context.responsiveButtonMinSize,
        ),
        child: Text(l10n.jspluginStartUpdate),
      ),
    ];
  }
}

/// 强制更新确认对话框：确认返回 true，取消返回 null。
/// GitHub 代理沿用插件管理顶部的统一选择，此处不再单独选择。
class _ForceUpdateConfirmDialog extends StatelessWidget {
  final String pluginName;

  const _ForceUpdateConfirmDialog({required this.pluginName});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.refresh),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.jspluginForceUpdateDialogTitle(pluginName),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: Text(
        l10n.jspluginForceUpdateContent,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            minimumSize: context.responsiveButtonMinSize,
          ),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            minimumSize: context.responsiveButtonMinSize,
          ),
          child: Text(l10n.jspluginConfirmUpdate),
        ),
      ],
    );
  }
}
