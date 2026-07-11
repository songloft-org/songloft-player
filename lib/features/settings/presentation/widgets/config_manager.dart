import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exceptions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/utils/responsive_snackbar.dart';
import '../../data/config_api.dart';
import '../providers/settings_provider.dart';

/// 配置管理组件
class ConfigManager extends ConsumerWidget {
  const ConfigManager({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configsAsync = ref.watch(configsProvider);
    final l10n = AppLocalizations.of(context);

    return ExpansionTile(
      leading: const Icon(Icons.tune),
      title: Text(l10n.settingsConfigTitle),
      subtitle: Text(l10n.settingsConfigSubtitle),
      children: [
        // 添加按钮
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _showAddConfigDialog(context, ref),
                icon: const Icon(Icons.add),
                label: Text(l10n.settingsConfigAdd),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => ref.invalidate(configsProvider),
                tooltip: l10n.settingsConfigRefresh,
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // 配置列表
        configsAsync.when(
          data: (configs) => _buildConfigList(context, ref, configs),
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
                      error is ApiException
                          ? error.message
                          : AppLocalizations.of(context).commonLoadFailed,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => ref.invalidate(configsProvider),
                      child: Text(AppLocalizations.of(context).commonRetry),
                    ),
                  ],
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildConfigList(
    BuildContext context,
    WidgetRef ref,
    List<Config> configs,
  ) {
    if (configs.isEmpty) {
      final l10n = AppLocalizations.of(context);
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.settings_outlined, size: 48, color: Colors.grey),
              const SizedBox(height: 8),
              Text(l10n.settingsConfigEmpty),
              const SizedBox(height: 4),
              Text(
                l10n.settingsConfigEmptyHint,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: configs.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final config = configs[index];
        return _ConfigItem(config: config);
      },
    );
  }

  Future<void> _showAddConfigDialog(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final keyController = TextEditingController();
    final valueController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.settingsConfigAdd),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: keyController,
                    decoration: InputDecoration(
                      labelText: l10n.settingsConfigKeyLabel,
                      hintText: l10n.settingsConfigKeyHint,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return l10n.settingsConfigKeyRequired;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: valueController,
                    decoration: InputDecoration(
                      labelText: l10n.settingsConfigValueLabel,
                      hintText: l10n.settingsConfigValueHint,
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return l10n.settingsConfigValueRequired;
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(context, true);
                  }
                },
                child: Text(l10n.settingsConfigAddButton),
              ),
            ],
          ),
    );

    if (result != true) return;

    try {
      final configApi = ref.read(configApiProvider);
      await configApi.createConfig(
        key: keyController.text.trim(),
        value: valueController.text.trim(),
      );
      ref.invalidate(configsProvider);
      if (context.mounted) {
        ResponsiveSnackBar.showSuccess(
          context,
          message: AppLocalizations.of(context).settingsConfigAdded,
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ResponsiveSnackBar.showError(
          context,
          message: AppLocalizations.of(
            context,
          ).settingsConfigAddFailed(e.message),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ResponsiveSnackBar.showError(
          context,
          message: AppLocalizations.of(context).settingsConfigAddFailed('$e'),
        );
      }
    }
  }
}

class _ConfigItem extends ConsumerStatefulWidget {
  final Config config;

  const _ConfigItem({required this.config});

  @override
  ConsumerState<_ConfigItem> createState() => _ConfigItemState();
}

class _ConfigItemState extends ConsumerState<_ConfigItem> {
  bool _isDeleting = false;

  Future<void> _editConfig() async {
    final l10n = AppLocalizations.of(context);
    final valueController = TextEditingController(text: widget.config.value);

    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.settingsConfigEditTitle(widget.config.key)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.settingsConfigKeyDisplay(widget.config.key),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: valueController,
                  decoration: InputDecoration(
                    labelText: l10n.settingsConfigValueLabel,
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 5,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.settingsConfigSave),
              ),
            ],
          ),
    );

    if (result != true) return;

    try {
      final configApi = ref.read(configApiProvider);
      await configApi.updateConfig(
        key: widget.config.key,
        value: valueController.text.trim(),
      );
      ref.invalidate(configsProvider);
      if (mounted) {
        ResponsiveSnackBar.showSuccess(
          context,
          message: AppLocalizations.of(context).settingsConfigUpdated,
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(
          context,
          message: AppLocalizations.of(
            context,
          ).settingsConfigUpdateFailed(e.message),
        );
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(
          context,
          message: AppLocalizations.of(
            context,
          ).settingsConfigUpdateFailed('$e'),
        );
      }
    }
  }

  Future<void> _deleteConfig() async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.settingsConfigConfirmDelete),
            content: Text(l10n.settingsConfigDeleteConfirm(widget.config.key)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: Text(l10n.commonDelete),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);

    try {
      final configApi = ref.read(configApiProvider);
      await configApi.deleteConfig(widget.config.key);
      ref.invalidate(configsProvider);
      if (mounted) {
        ResponsiveSnackBar.showSuccess(
          context,
          message: AppLocalizations.of(context).settingsConfigDeleted,
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(
          context,
          message: AppLocalizations.of(
            context,
          ).settingsConfigDeleteFailed(e.message),
        );
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(
          context,
          message: AppLocalizations.of(
            context,
          ).settingsConfigDeleteFailed('$e'),
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
    final config = widget.config;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Icon(
          Icons.settings,
          color: theme.colorScheme.onPrimaryContainer,
          size: 20,
        ),
      ),
      title: Text(
        config.key,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Tooltip(
        message: config.value,
        child: Text(config.value, maxLines: 2, overflow: TextOverflow.ellipsis),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 编辑按钮
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _editConfig,
            tooltip: l10n.settingsConfigEdit,
          ),
          // 删除按钮
          IconButton(
            icon:
                _isDeleting
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.delete_outline),
            onPressed: _isDeleting ? null : _deleteConfig,
            tooltip: l10n.commonDelete,
          ),
        ],
      ),
      isThreeLine: true,
      onTap: _editConfig,
    );
  }
}
