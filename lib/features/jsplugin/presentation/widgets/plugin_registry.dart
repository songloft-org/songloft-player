import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/network/api_exceptions.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/constants/github_proxy.dart';
import '../../../../shared/utils/responsive_snackbar.dart';
import '../../../settings/data/settings_api.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../data/jsplugin_api.dart';
import '../providers/jsplugin_provider.dart';
import 'github_proxy_selection.dart';

/// 官方插件源 URL
const _kOfficialRegistryUrl =
    'https://raw.githubusercontent.com/songloft-org/songloft-plugin-registry/main/registry.json';

/// 插件商店页面
class PluginRegistryPage extends ConsumerStatefulWidget {
  const PluginRegistryPage({super.key});

  @override
  ConsumerState<PluginRegistryPage> createState() =>
      _PluginRegistryPageState();
}

class _PluginRegistryPageState extends ConsumerState<PluginRegistryPage>
    with GithubProxySelectionMixin<PluginRegistryPage> {
  @override
  List<String> get proxyPresetValues =>
      kGithubProxyPresets.map((e) => e.value).toList();

  List<PluginRegistryConfig> _registries = [];
  PluginRegistryConfig? _selectedRegistry;
  String _searchText = '';
  int _currentPage = 1;
  static const int _pageSize = 20;

  bool _loadingRegistries = true;
  bool _loadingPlugins = false;
  RegistryRefreshResponse? _pluginResponse;
  String? _pluginError;

  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // 先恢复上次使用的代理，保证首次刷新用到持久化的代理设置。
    await restoreGithubProxy();
    await _loadRegistries();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadRegistries() async {
    setState(() => _loadingRegistries = true);
    try {
      final api = ref.read(settingsApiProvider);
      final registries = await api.getPluginRegistries();
      if (!mounted) return;
      setState(() {
        _registries = registries;
        _loadingRegistries = false;
        final enabled = registries.where((r) => r.enabled).toList();
        if (enabled.isNotEmpty && _selectedRegistry == null) {
          _selectedRegistry = enabled.first;
          _refreshPlugins();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingRegistries = false;
      });
    }
  }

  Future<void> _refreshPlugins() async {
    if (_selectedRegistry == null) return;
    setState(() {
      _loadingPlugins = true;
      _pluginError = null;
    });
    try {
      final api = ref.read(jsPluginApiProvider);
      final response = await api.refreshRegistry(
        registryUrl: _selectedRegistry!.url,
        page: _currentPage,
        pageSize: _pageSize,
        search: _searchText.isEmpty ? null : _searchText,
        githubProxy: effectiveProxy.isEmpty ? null : effectiveProxy,
        token: _selectedRegistry!.token.isEmpty
            ? null
            : _selectedRegistry!.token,
      );
      if (!mounted) return;
      setState(() {
        _pluginResponse = response;
        _loadingPlugins = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _pluginError = e.message;
        _loadingPlugins = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pluginError = e.toString();
        _loadingPlugins = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchText = value;
        _currentPage = 1;
      });
      _refreshPlugins();
    });
  }

  void _onRegistryChanged(PluginRegistryConfig? registry) {
    setState(() {
      _selectedRegistry = registry;
      _currentPage = 1;
      _pluginResponse = null;
    });
    _refreshPlugins();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
        appBar: AppBar(
          title: Text(l10n.jspluginStoreTitle),
          actions: [
            if (_selectedRegistry != null)
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: l10n.jspluginRefreshList,
                onPressed: _loadingPlugins ? null : _refreshPlugins,
              ),
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: l10n.jspluginManageRegistries,
              onPressed: _showRegistryManagement,
            ),
          ],
        ),
        body: _loadingRegistries
            ? const Center(child: CircularProgressIndicator())
            : _registries.isEmpty
                ? _buildEmptyState(theme)
                : _buildContent(theme),
    );
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

  /// 统一的 GitHub 代理选择入口（下拉菜单），与插件管理样式一致
  Widget _buildProxySelectorTile(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<int>(
      tooltip: l10n.jspluginGithubProxy,
      onSelected: (value) {
        if (value == -1) {
          _showCustomProxyDialog();
        } else {
          setState(() => selectedProxyIndex = value);
          persistGithubProxy();
          _refreshPlugins();
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
                Text(kGithubProxyPresets[index].label),
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

  Widget _buildEmptyState(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.store_outlined, size: 64, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text(l10n.jspluginNoRegistries, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            l10n.jspluginNoRegistriesHint,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _showRegistryManagement,
            icon: const Icon(Icons.add),
            label: Text(l10n.jspluginAddRegistry),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    final enabledRegistries = _registries.where((r) => r.enabled).toList();

    return Column(
      children: [
        // GitHub 代理（统一下拉选择）
        _buildProxySelectorTile(theme),
        const Divider(height: 1),
        // 订阅源选择 + 搜索
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              DropdownButtonFormField<PluginRegistryConfig>(
                initialValue: _selectedRegistry,
                decoration: InputDecoration(
                  labelText: l10n.jspluginRegistry,
                  border: const OutlineInputBorder(),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                isExpanded: true,
                items: enabledRegistries
                    .map(
                      (r) => DropdownMenuItem(
                        value: r,
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                r.name.isEmpty ? r.url : r.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (r.url == _kOfficialRegistryUrl) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  l10n.jspluginOfficial,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _onRegistryChanged,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: l10n.jspluginSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  suffixIcon: _searchText.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: l10n.clearSearch,
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                ),
                onChanged: _onSearchChanged,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // 插件列表
        Expanded(child: _buildPluginList(theme)),
      ],
    );
  }

  Widget _buildPluginList(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    if (_loadingPlugins) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 200,
              child: LinearProgressIndicator(),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.jspluginLoadingList,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }
    if (_pluginError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _pluginError!,
              style: TextStyle(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: _refreshPlugins, child: Text(l10n.commonRetry)),
          ],
        ),
      );
    }
    if (_pluginResponse == null || _pluginResponse!.plugins.isEmpty) {
      return Center(
        child: Text(
          _searchText.isNotEmpty ? l10n.jspluginNoMatch : l10n.jspluginRegistryEmpty,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      );
    }

    final plugins = _pluginResponse!.plugins;
    final total = _pluginResponse!.total;
    final totalPages = (total / _pageSize).ceil();

    return Column(
      children: [
        // warnings
        if (_pluginResponse!.warnings.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: theme.colorScheme.errorContainer,
            child: Text(
              _pluginResponse!.warnings.join('\n'),
              style: TextStyle(
                color: theme.colorScheme.onErrorContainer,
                fontSize: 12,
              ),
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: plugins.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 16),
            itemBuilder: (context, index) =>
                _RegistryPluginItem(
                  entry: plugins[index],
                  githubProxy: effectiveProxy,
                  token: _selectedRegistry?.token ?? '',
                  onInstalled: () {
                    _refreshPlugins();
                    ref.invalidate(jsPluginsProvider);
                  },
                ),
          ),
        ),
        // 分页
        if (totalPages > 1)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  tooltip: l10n.jspluginPrevPage,
                  onPressed: _currentPage > 1
                      ? () {
                          setState(() => _currentPage--);
                          _refreshPlugins();
                        }
                      : null,
                ),
                Text('$_currentPage / $totalPages'),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  tooltip: l10n.jspluginNextPage,
                  onPressed: _currentPage < totalPages
                      ? () {
                          setState(() => _currentPage++);
                          _refreshPlugins();
                        }
                      : null,
                ),
              ],
            ),
          ),
      ],
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
      if (value != null) {
        customProxyController.text = value;
        setState(() => selectedProxyIndex = -1);
        persistGithubProxy();
        _refreshPlugins();
      }
    });
  }

  void _showRegistryManagement() {
    showDialog(
      context: context,
      builder: (context) => _RegistryManagementDialog(
        registries: _registries,
        onSaved: (registries) {
          setState(() {
            _registries = registries;
            final enabled = registries.where((r) => r.enabled).toList();
            if (_selectedRegistry != null &&
                !enabled.any((r) => r.url == _selectedRegistry!.url)) {
              _selectedRegistry = enabled.isNotEmpty ? enabled.first : null;
            }
            if (_selectedRegistry == null && enabled.isNotEmpty) {
              _selectedRegistry = enabled.first;
            }
          });
          ref.invalidate(pluginRegistriesProvider);
          if (_selectedRegistry != null) {
            _refreshPlugins();
          } else {
            setState(() => _pluginResponse = null);
          }
        },
      ),
    );
  }
}

/// 单个注册表插件项
class _RegistryPluginItem extends ConsumerStatefulWidget {
  final RegistryPluginEntry entry;
  final String githubProxy;
  final String token;
  final VoidCallback onInstalled;

  const _RegistryPluginItem({
    required this.entry,
    required this.githubProxy,
    this.token = '',
    required this.onInstalled,
  });

  @override
  ConsumerState<_RegistryPluginItem> createState() =>
      _RegistryPluginItemState();
}

class _RegistryPluginItemState extends ConsumerState<_RegistryPluginItem> {
  bool _installing = false;

  Future<void> _install() async {
    setState(() => _installing = true);
    try {
      final api = ref.read(jsPluginApiProvider);
      final result = await api.installFromRegistry(
        downloadUrl: widget.entry.downloadUrl,
        githubProxy: widget.githubProxy.isEmpty ? null : widget.githubProxy,
        token: widget.token.isEmpty ? null : widget.token,
      );
      if (!mounted) return;
      if (result.success > 0) {
        ResponsiveSnackBar.showSuccess(context, message: result.message);
        widget.onInstalled();
      } else if (result.results.isNotEmpty &&
          result.results.first.error != null) {
        ResponsiveSnackBar.showError(
          context,
          message: result.results.first.error!,
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(context, message: e.message);
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(
          context,
          message: AppLocalizations.of(context).jspluginInstallFailed(e.toString()),
        );
      }
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final theme = Theme.of(context);

    return ListTile(
      leading: _buildIcon(entry, theme),
      title: Text(entry.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entry.author != null && entry.author!.isNotEmpty)
            Text(entry.author!, style: theme.textTheme.bodySmall),
          if (entry.description != null && entry.description!.isNotEmpty)
            Text(
              entry.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
        ],
      ),
      trailing: _buildAction(entry, theme),
      isThreeLine: entry.description != null && entry.description!.isNotEmpty,
    );
  }

  Widget _buildIcon(RegistryPluginEntry entry, ThemeData theme) {
    if (entry.icon != null && entry.icon!.isNotEmpty) {
      final url = entry.icon!;
      final isSvg = url.toLowerCase().endsWith('.svg');
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: isSvg
            ? SvgPicture.network(
                url,
                width: 40,
                height: 40,
                fit: BoxFit.contain,
                placeholderBuilder: (_) => _buildFallbackIcon(entry, theme),
                errorBuilder: (_, _, _) => _buildFallbackIcon(entry, theme),
              )
            : ExcludeSemantics(
              child: Image.network(
                  url,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _buildFallbackIcon(entry, theme),
                ),
              ),
      );
    }
    return _buildFallbackIcon(entry, theme);
  }

  Widget _buildFallbackIcon(RegistryPluginEntry entry, ThemeData theme) {
    final color =
        Colors.primaries[entry.entryPath.hashCode % Colors.primaries.length];
    final initial =
        entry.name.isNotEmpty ? entry.name.characters.first.toUpperCase() : '?';
    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.2),
      foregroundColor: color,
      radius: 20,
      child: Text(initial, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildAction(RegistryPluginEntry entry, ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    if (_installing) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (entry.installed && !entry.hasUpdate) {
      return ActionChip(
        avatar: const Icon(Icons.refresh, size: 16),
        label: Text('v${entry.installedVersion ?? entry.version}'),
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        side: BorderSide.none,
        visualDensity: VisualDensity.compact,
        tooltip: l10n.jspluginReinstall,
        onPressed: _install,
      );
    }
    if (entry.installed && entry.hasUpdate) {
      return FilledButton.tonal(
        onPressed: _install,
        child: Text(l10n.jspluginUpdateTo(entry.version)),
      );
    }
    return FilledButton(
      onPressed: _install,
      child: Text(l10n.jspluginInstall),
    );
  }
}

/// 订阅源管理对话框
class _RegistryManagementDialog extends ConsumerStatefulWidget {
  final List<PluginRegistryConfig> registries;
  final ValueChanged<List<PluginRegistryConfig>> onSaved;

  const _RegistryManagementDialog({
    required this.registries,
    required this.onSaved,
  });

  @override
  ConsumerState<_RegistryManagementDialog> createState() =>
      _RegistryManagementDialogState();
}

class _RegistryManagementDialogState
    extends ConsumerState<_RegistryManagementDialog> {
  late List<PluginRegistryConfig> _registries;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _registries = List.from(widget.registries);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final api = ref.read(settingsApiProvider);
      final saved = await api.updatePluginRegistries(_registries);
      if (!mounted) return;
      widget.onSaved(saved);
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(
          context,
          message: AppLocalizations.of(context).jspluginSaveFailed(e.message),
        );
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(
          context,
          message: AppLocalizations.of(context).jspluginSaveFailed(e.toString()),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addRegistry() {
    _showRegistryEditDialog();
  }

  void _editRegistry(int index) {
    final r = _registries[index];
    _showRegistryEditDialog(
      initialUrl: r.url,
      initialName: r.name,
      initialToken: r.token,
      onSave: (url, name, token) {
        setState(() {
          _registries[index] = r.copyWith(
            url: url,
            name: name,
            token: token,
          );
        });
      },
    );
  }

  void _showRegistryEditDialog({
    String initialUrl = '',
    String initialName = '',
    String initialToken = '',
    void Function(String url, String name, String token)? onSave,
  }) {
    final urlController = TextEditingController(text: initialUrl);
    final nameController = TextEditingController(text: initialName);
    final tokenController = TextEditingController(text: initialToken);
    final isEdit = onSave != null;
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? l10n.jspluginEditRegistry : l10n.jspluginAddRegistry),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'https://example.com/registry.json',
                border: OutlineInputBorder(),
              ),
              autofocus: !isEdit,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: l10n.jspluginNameOptional,
                hintText: l10n.jspluginRegistryNameHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tokenController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.jspluginTokenOptional,
                hintText: 'Bearer Token / GitHub PAT',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              final url = urlController.text.trim();
              if (url.isEmpty) return;
              if (isEdit) {
                onSave(
                  url,
                  nameController.text.trim(),
                  tokenController.text.trim(),
                );
              } else {
                setState(() {
                  _registries.add(PluginRegistryConfig(
                    url: url,
                    name: nameController.text.trim(),
                    enabled: true,
                    token: tokenController.text.trim(),
                  ));
                });
              }
              Navigator.of(ctx).pop();
            },
            child: Text(isEdit ? l10n.jspluginSave : l10n.jspluginAdd),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.jspluginManageRegistries),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_registries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(l10n.jspluginNoRegistries),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _registries.length,
                  itemBuilder: (context, index) {
                    final r = _registries[index];
                    return ListTile(
                      leading: Switch(
                        value: r.enabled,
                        onChanged: (v) {
                          setState(() {
                            _registries[index] = r.copyWith(enabled: v);
                          });
                        },
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              r.name.isNotEmpty ? r.name : r.url,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (r.url == _kOfficialRegistryUrl) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                l10n.jspluginOfficial,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
                          if (r.token.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Tooltip(
                              message: l10n.jspluginAuthConfigured,
                              child: Icon(
                                Icons.lock_outline,
                                size: 14,
                                color: Theme.of(context)
                                    .colorScheme
                                    .outline,
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: r.name.isNotEmpty
                          ? Text(
                              r.url,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            )
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: l10n.jspluginEditRegistry,
                            onPressed: () => _editRegistry(index),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: l10n.jspluginDeleteRegistry,
                            onPressed: () {
                              setState(() => _registries.removeAt(index));
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _addRegistry,
              icon: const Icon(Icons.add),
              label: Text(l10n.jspluginAddRegistry),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.jspluginSave),
        ),
      ],
    );
  }
}
