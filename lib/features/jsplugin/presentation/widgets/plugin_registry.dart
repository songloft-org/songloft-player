import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exceptions.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../shared/utils/responsive_snackbar.dart';
import '../../../settings/data/settings_api.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../data/jsplugin_api.dart';
import '../providers/jsplugin_provider.dart';

/// 官方插件源 URL
const _kOfficialRegistryUrl =
    'https://raw.githubusercontent.com/songloft-org/songloft-plugin-registry/main/registry.json';

/// 预设 GitHub 代理列表
const List<_ProxyOption> _kGithubProxies = [
  _ProxyOption(label: '直连 (不使用代理)', value: ''),
  _ProxyOption(label: 'ghproxy.com', value: 'https://ghproxy.com/'),
  _ProxyOption(label: 'ghfast.top', value: 'https://ghfast.top/'),
  _ProxyOption(label: 'gh.con.sh', value: 'https://gh.con.sh/'),
  _ProxyOption(
    label: 'mirror.ghproxy.com',
    value: 'https://mirror.ghproxy.com/',
  ),
];

class _ProxyOption {
  final String label;
  final String value;
  const _ProxyOption({required this.label, required this.value});
}

/// 打开插件商店对话框
void showPluginRegistryDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => const _PluginRegistryDialog(),
  );
}

class _PluginRegistryDialog extends ConsumerStatefulWidget {
  const _PluginRegistryDialog();

  @override
  ConsumerState<_PluginRegistryDialog> createState() =>
      _PluginRegistryDialogState();
}

class _PluginRegistryDialogState extends ConsumerState<_PluginRegistryDialog> {
  List<PluginRegistryConfig> _registries = [];
  PluginRegistryConfig? _selectedRegistry;
  String _searchText = '';
  int _currentPage = 1;
  static const int _pageSize = 20;

  bool _loadingRegistries = true;
  bool _loadingPlugins = false;
  RegistryRefreshResponse? _pluginResponse;
  String? _pluginError;

  int _selectedProxyIndex = 0;
  final TextEditingController _customProxyController = TextEditingController();

  String get _effectiveProxy {
    if (_selectedProxyIndex == -1) {
      return _customProxyController.text.trim();
    }
    if (_selectedProxyIndex >= 0 &&
        _selectedProxyIndex < _kGithubProxies.length) {
      return _kGithubProxies[_selectedProxyIndex].value;
    }
    return '';
  }

  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _loadRegistries();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customProxyController.dispose();
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
        githubProxy: _effectiveProxy.isEmpty ? null : _effectiveProxy,
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
    final theme = Theme.of(context);
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('插件商店'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            PopupMenuButton<int>(
              icon: Icon(
                Icons.vpn_key_outlined,
                color: _effectiveProxy.isNotEmpty
                    ? theme.colorScheme.primary
                    : null,
              ),
              tooltip: 'GitHub 代理',
              onSelected: (value) {
                if (value == -1) {
                  _showCustomProxyDialog();
                } else {
                  setState(() => _selectedProxyIndex = value);
                  _refreshPlugins();
                }
              },
              itemBuilder: (context) => [
                ...List.generate(_kGithubProxies.length, (index) {
                  return PopupMenuItem<int>(
                    value: index,
                    child: Row(
                      children: [
                        if (_selectedProxyIndex == index)
                          Icon(Icons.check,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary)
                        else
                          const SizedBox(width: 18),
                        const SizedBox(width: 8),
                        Text(_kGithubProxies[index].label),
                      ],
                    ),
                  );
                }),
                const PopupMenuDivider(),
                PopupMenuItem<int>(
                  value: -1,
                  child: Row(
                    children: [
                      if (_selectedProxyIndex == -1)
                        Icon(Icons.check,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary)
                      else
                        const SizedBox(width: 18),
                      const SizedBox(width: 8),
                      Text(_selectedProxyIndex == -1
                          ? '自定义: ${_customProxyController.text}'
                          : '自定义代理...'),
                    ],
                  ),
                ),
              ],
            ),
            if (_selectedRegistry != null)
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: '刷新插件列表',
                onPressed: _loadingPlugins ? null : _refreshPlugins,
              ),
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: '管理订阅源',
              onPressed: _showRegistryManagement,
            ),
          ],
        ),
        body: _loadingRegistries
            ? const Center(child: CircularProgressIndicator())
            : _registries.isEmpty
                ? _buildEmptyState(theme)
                : _buildContent(theme),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.store_outlined, size: 64, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text('还没有添加订阅源', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '添加订阅源后即可浏览和安装插件',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _showRegistryManagement,
            icon: const Icon(Icons.add),
            label: const Text('添加订阅源'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    final enabledRegistries = _registries.where((r) => r.enabled).toList();

    return Column(
      children: [
        // 订阅源选择 + 代理 + 搜索
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              DropdownButtonFormField<PluginRegistryConfig>(
                initialValue: _selectedRegistry,
                decoration: const InputDecoration(
                  labelText: '订阅源',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                  '官方',
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
                  hintText: '搜索插件...',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  suffixIcon: _searchText.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
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
              '正在加载插件列表…',
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
            TextButton(onPressed: _refreshPlugins, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_pluginResponse == null || _pluginResponse!.plugins.isEmpty) {
      return Center(
        child: Text(
          _searchText.isNotEmpty ? '没有找到匹配的插件' : '该订阅源暂无插件',
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
                  githubProxy: _effectiveProxy,
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
    final controller = TextEditingController(text: _customProxyController.text);
    showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('自定义代理'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'https://your-proxy.com/',
            helperText: '输入代理地址，如 https://ghproxy.com/',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) =>
              Navigator.of(context).pop(controller.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    ).then((value) {
      if (value != null) {
        _customProxyController.text = value;
        setState(() => _selectedProxyIndex = -1);
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
  final VoidCallback onInstalled;

  const _RegistryPluginItem({
    required this.entry,
    required this.githubProxy,
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
        ResponsiveSnackBar.showError(context, message: '安装失败: $e');
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
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          entry.icon!,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildFallbackIcon(entry, theme),
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
    if (_installing) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (entry.installed && !entry.hasUpdate) {
      return Chip(
        label: Text('v${entry.installedVersion ?? entry.version}'),
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        side: BorderSide.none,
        visualDensity: VisualDensity.compact,
      );
    }
    if (entry.installed && entry.hasUpdate) {
      return FilledButton.tonal(
        onPressed: _install,
        child: Text('更新至 v${entry.version}'),
      );
    }
    return FilledButton(
      onPressed: _install,
      child: const Text('安装'),
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
        ResponsiveSnackBar.showError(context, message: '保存失败: ${e.message}');
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(context, message: '保存失败: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addRegistry() {
    final urlController = TextEditingController();
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加订阅源'),
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
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '名称（可选）',
                hintText: '官方插件',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final url = urlController.text.trim();
              if (url.isEmpty) return;
              setState(() {
                _registries.add(PluginRegistryConfig(
                  url: url,
                  name: nameController.text.trim(),
                  enabled: true,
                ));
              });
              Navigator.of(ctx).pop();
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('管理订阅源'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_registries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('还没有添加订阅源'),
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
                                '官方',
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
                      subtitle: r.name.isNotEmpty
                          ? Text(
                              r.url,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            )
                          : null,
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          setState(() => _registries.removeAt(index));
                        },
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _addRegistry,
              icon: const Icon(Icons.add),
              label: const Text('添加订阅源'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('保存'),
        ),
      ],
    );
  }
}
