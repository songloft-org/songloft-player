import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/network/api_exceptions.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/responsive.dart';
import '../../../../core/utils/url_helper.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/utils/responsive_snackbar.dart';
import '../../../settings/data/settings_api.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../data/jsplugin_api.dart';
import '../providers/jsplugin_provider.dart';
import 'plugin_icon_utils.dart';

/// 官方插件源 URL
const _kOfficialRegistryUrl =
    'https://raw.githubusercontent.com/songloft-org/songloft-plugin-registry/main/registry.json';

/// 源下拉中「全部」聚合选项的哨兵值
const _kAllSourcesValue = '__all_sources__';

/// 插件商店页面
class PluginRegistryPage extends ConsumerStatefulWidget {
  const PluginRegistryPage({super.key});

  @override
  ConsumerState<PluginRegistryPage> createState() => _PluginRegistryPageState();
}

class _PluginRegistryPageState extends ConsumerState<PluginRegistryPage> {
  List<PluginRegistryConfig> _registries = [];
  PluginRegistryConfig? _selectedRegistry;
  bool _allSources = false;
  String _searchText = '';
  int _currentPage = 1;
  static const int _pageSize = 20;

  bool _loadingRegistries = true;
  bool _loadingPlugins = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _requestGeneration = 0;
  RegistryRefreshResponse? _pluginResponse;
  String? _pluginError;
  String? _loadMoreError;
  final _installedDuringListing = <String, RegistryPluginEntry>{};

  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
    _loadRegistries();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
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
        // 首次加载默认选「全部」，打开商店即聚合展示所有启用源
        if (enabled.isNotEmpty && _selectedRegistry == null && !_allSources) {
          _allSources = true;
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

  /// [force] 为 true 时让后端绕过缓存重拉。翻页与搜索**不要**传：它们在后端
  /// 缓存的完整列表上切片/过滤，传了会让每次翻页都重拉整棵注册表树。
  Future<void> _refreshPlugins({
    bool force = false,
    bool append = false,
  }) async {
    if (append && (_loadingPlugins || _loadingMore || !_hasMore)) return;
    final generation = append ? _requestGeneration : ++_requestGeneration;
    final allSources = _allSources;
    final registry = _selectedRegistry;
    final search = _searchText;
    final page = append ? _currentPage + 1 : 1;
    setState(() {
      _loadMoreError = null;
      if (append) {
        _loadingMore = true;
      } else {
        _loadingPlugins = allSources || registry != null;
        _loadingMore = false;
        _hasMore = false;
        _currentPage = 1;
        _pluginResponse = null;
        _pluginError = null;
        _installedDuringListing.clear();
      }
    });
    if (!allSources && registry == null) return;
    if (!append && _scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    try {
      final proxy = await ref.read(githubProxyProvider.future);
      if (!mounted || generation != _requestGeneration) return;
      final api = ref.read(jsPluginApiProvider);
      final response = await api.refreshRegistry(
        registryUrl: allSources ? '' : registry!.url,
        allSources: allSources,
        page: page,
        pageSize: _pageSize,
        search: search.isEmpty ? null : search,
        githubProxy: proxy.isEmpty ? null : proxy,
        // 「全部」模式各源用自身存储的 token，前端不传
        token: allSources || registry!.token.isEmpty ? null : registry.token,
        force: force,
      );
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        final plugins = <String, RegistryPluginEntry>{
          if (append)
            for (final plugin in _pluginResponse!.plugins)
              plugin.rowKey: plugin,
          for (final plugin in response.plugins)
            plugin.rowKey: _withInstalledState(plugin),
        };
        _pluginResponse = RegistryRefreshResponse(
          plugins: plugins.values.toList(),
          total: response.total,
          page: response.page,
          pageSize: response.pageSize,
          warnings: append ? _pluginResponse!.warnings : response.warnings,
        );
        _currentPage = response.page;
        _hasMore =
            response.plugins.isNotEmpty &&
            response.page * response.pageSize < response.total;
        _loadingPlugins = false;
        _loadingMore = false;
      });
      _scheduleLoadMore();
    } catch (e) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        final message = e is ApiException ? e.message : e.toString();
        if (append) {
          _loadMoreError = message;
        } else {
          _pluginError = message;
        }
        _loadingPlugins = false;
        _loadingMore = false;
      });
    }
  }

  void _maybeLoadMore() {
    if (!mounted ||
        _searchDebounce != null ||
        _loadMoreError != null ||
        !_scrollController.hasClients) {
      return;
    }
    if (_scrollController.position.extentAfter <= 200) {
      _refreshPlugins(append: true);
    }
  }

  // 首屏不足一屏、以及窗口变大时也继续加载，不依赖用户先滚动。
  void _scheduleLoadMore() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadMore());
  }

  RegistryPluginEntry _withInstalledState(RegistryPluginEntry plugin) {
    final installed = _installedDuringListing[plugin.entryPath];
    if (installed == null) return plugin;
    if (plugin.matches(installed.entryPath, installed.identity)) {
      return plugin.copyWith(
        installed: true,
        installedVersion: installed.version,
        hasUpdate: false,
        conflict: false,
        conflictWith: '',
      );
    }
    return plugin.copyWith(
      installed: false,
      conflict: true,
      conflictWith:
          '${installed.name}'
          '${installed.author != null && installed.author!.isNotEmpty ? '（作者：${installed.author}）' : ''}'
          ' v${installed.version}',
    );
  }

  /// 安装成功后就地更新状态。必须按 (entryPath, identity) 匹配：只比 entryPath
  /// 会把同名不同作者的其他条目一起点亮成「已安装」（songloft-org/songloft#339）。
  void _markPluginInstalled(RegistryPluginEntry installed) {
    if (_pluginResponse == null) return;
    _installedDuringListing[installed.entryPath] = installed;
    final updatedPlugins =
        _pluginResponse!.plugins.map(_withInstalledState).toList();
    setState(() {
      _pluginResponse = RegistryRefreshResponse(
        plugins: updatedPlugins,
        total: _pluginResponse!.total,
        page: _pluginResponse!.page,
        pageSize: _pluginResponse!.pageSize,
        warnings: _pluginResponse!.warnings,
      );
    });
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    // 输入时立即作废旧请求，防止防抖窗口内旧页返回并混入新搜索。
    ++_requestGeneration;
    setState(() {
      _searchText = value;
      _loadingPlugins = true;
      _loadingMore = false;
    });
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _searchDebounce = null;
      _refreshPlugins();
    });
  }

  /// 源下拉切换：值为哨兵 `_kAllSourcesValue` 时进入「全部」聚合模式，
  /// 否则按 URL 定位到具体订阅源。
  void _onRegistrySelectionChanged(String? value) {
    if (value == null) return;
    setState(() {
      if (value == _kAllSourcesValue) {
        _allSources = true;
      } else {
        _allSources = false;
        final enabled = _registries.where((r) => r.enabled).toList();
        final match = enabled.where((r) => r.url == value);
        if (match.isNotEmpty) {
          _selectedRegistry = match.first;
        }
      }
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
          if (_allSources || _selectedRegistry != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: l10n.jspluginRefreshList,
              // 用户主动刷新：绕过缓存拉最新的源内容
              onPressed:
                  _loadingPlugins || _loadingMore
                      ? null
                      : () => _refreshPlugins(force: true),
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: l10n.jspluginManageRegistries,
            onPressed: _showRegistryManagement,
          ),
        ],
      ),
      body:
          _loadingRegistries
              ? const Center(child: CircularProgressIndicator())
              : _registries.isEmpty
              ? _buildEmptyState(theme)
              : _buildContent(theme),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.store_outlined,
            size: 64,
            color: theme.colorScheme.outline,
          ),
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
        // 订阅源选择 + 搜索
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue:
                    _allSources ? _kAllSourcesValue : _selectedRegistry?.url,
                decoration: InputDecoration(
                  labelText: l10n.jspluginRegistry,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                isExpanded: true,
                items: [
                  // 「全部」聚合项置顶
                  DropdownMenuItem(
                    value: _kAllSourcesValue,
                    child: Row(
                      children: [
                        const Icon(Icons.all_inclusive, size: 18),
                        const SizedBox(width: 8),
                        Text(l10n.jspluginAllSources),
                      ],
                    ),
                  ),
                  ...enabledRegistries.map(
                    (r) => DropdownMenuItem(
                      value: r.url,
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
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                l10n.jspluginOfficial,
                                style: TextStyle(
                                  fontSize: 10,
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
                onChanged: _onRegistrySelectionChanged,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: l10n.jspluginSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  suffixIcon:
                      _searchText.isNotEmpty
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
            const SizedBox(width: 200, child: LinearProgressIndicator()),
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
            TextButton(
              // 拉取失败后的重试：同样绕过缓存
              onPressed: () => _refreshPlugins(force: true),
              child: Text(l10n.commonRetry),
            ),
          ],
        ),
      );
    }
    if (_pluginResponse == null || _pluginResponse!.plugins.isEmpty) {
      return Column(
        children: [
          if (_pluginResponse != null && _pluginResponse!.warnings.isNotEmpty)
            PluginRegistryWarningsBanner(warnings: _pluginResponse!.warnings),
          Expanded(
            child: Center(
              child: Text(
                _searchText.isNotEmpty
                    ? l10n.jspluginNoMatch
                    : l10n.jspluginRegistryEmpty,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          ),
        ],
      );
    }

    final plugins = _pluginResponse!.plugins;

    return Column(
      children: [
        // warnings
        if (_pluginResponse!.warnings.isNotEmpty)
          PluginRegistryWarningsBanner(warnings: _pluginResponse!.warnings),
        Expanded(
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (_) {
              _scheduleLoadMore();
              return false;
            },
            child: ListView.separated(
              controller: _scrollController,
              // 在页面 Scaffold 外的 context 读取 shell 提供的导航栏 inset。
              // 留白随列表一起滚动，最后一条及加载/重试入口都可滚到导航栏上方。
              padding: EdgeInsets.fromLTRB(0, 8, 0, context.navScrollInset),
              itemCount: plugins.length + (_hasMore ? 1 : 0),
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 16),
              itemBuilder: (context, index) {
                if (index == plugins.length) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child:
                        _loadMoreError != null
                            ? Column(
                              children: [
                                Text(
                                  _loadMoreError!,
                                  style: TextStyle(
                                    color: theme.colorScheme.error,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                TextButton(
                                  onPressed:
                                      () => _refreshPlugins(append: true),
                                  child: Text(l10n.commonRetry),
                                ),
                              ],
                            )
                            : _loadingMore
                            ? const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(),
                              ),
                            )
                            : const SizedBox(height: 24),
                  );
                }
                final plugin = plugins[index];
                return _RegistryPluginItem(
                  // rowKey 而非 index：追加/搜索后保持每一行的安装状态身份。
                  key: ValueKey(plugin.rowKey),
                  entry: plugin,
                  token: _allSources ? '' : (_selectedRegistry?.token ?? ''),
                  onInstalled: () {
                    _markPluginInstalled(plugin);
                    ref.invalidate(jsPluginsProvider);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _showRegistryManagement() {
    showDialog(
      context: context,
      builder:
          (context) => _RegistryManagementDialog(
            registries: _registries,
            onSaved: (registries) {
              setState(() {
                _registries = registries;
                final enabled = registries.where((r) => r.enabled).toList();
                // 选中的具体源被删除/禁用后回退：优先保持「全部」聚合
                if (!_allSources &&
                    _selectedRegistry != null &&
                    !enabled.any((r) => r.url == _selectedRegistry!.url)) {
                  _selectedRegistry = null;
                  _allSources = enabled.isNotEmpty;
                }
                if (!_allSources &&
                    _selectedRegistry == null &&
                    enabled.isNotEmpty) {
                  _allSources = true;
                }
              });
              ref.invalidate(pluginRegistriesProvider);
              if (_allSources || _selectedRegistry != null) {
                _refreshPlugins();
              } else {
                setState(() => _pluginResponse = null);
              }
            },
          ),
    );
  }
}

/// 将可能很长的订阅源错误收进详情对话框，避免局部失败遮住成功加载的插件。
class PluginRegistryWarningsBanner extends StatelessWidget {
  final List<String> warnings;

  const PluginRegistryWarningsBanner({required this.warnings, super.key});

  void _showDetails(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            scrollable: true,
            title: Text(l10n.jspluginRegistryWarningsTitle),
            content: SelectableText(warnings.join('\n\n')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.jspluginClose),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4, right: 4),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 20,
              color: colors.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.jspluginRegistryWarningsSummary(warnings.length),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onErrorContainer),
              ),
            ),
            IconButton(
              onPressed: () => _showDetails(context),
              icon: const Icon(Icons.info_outline),
              color: colors.onErrorContainer,
              tooltip: l10n.jspluginRegistryWarningsDetails,
            ),
          ],
        ),
      ),
    );
  }
}

/// 单个注册表插件项
class _RegistryPluginItem extends ConsumerStatefulWidget {
  final RegistryPluginEntry entry;
  final String token;
  final VoidCallback onInstalled;

  const _RegistryPluginItem({
    super.key,
    required this.entry,
    this.token = '',
    required this.onInstalled,
  });

  @override
  ConsumerState<_RegistryPluginItem> createState() =>
      _RegistryPluginItemState();
}

class _RegistryPluginItemState extends ConsumerState<_RegistryPluginItem> {
  bool _installing = false;

  /// 冲突条目的安装入口：先让用户确认会替换掉本地那个同名插件。
  Future<void> _confirmThenInstall() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.jspluginConflictDialogTitle),
            content: Text(
              l10n.jspluginConflictDialogBody(
                widget.entry.entryPath,
                widget.entry.conflictWith ?? '',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.jspluginConflictDialogConfirm),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    await _install(overwrite: true);
  }

  Future<void> _install({bool overwrite = false}) async {
    final proxy = await ref.read(githubProxyProvider.future);
    if (!mounted) return;
    setState(() => _installing = true);
    try {
      final api = ref.read(jsPluginApiProvider);
      final result = await api.installFromRegistry(
        downloadUrl: widget.entry.downloadUrl,
        githubProxy: proxy.isEmpty ? null : proxy,
        token: widget.token.isEmpty ? null : widget.token,
        sourceUrl: widget.entry.sourceUrl,
        overwrite: overwrite,
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
          message: AppLocalizations.of(
            context,
          ).jspluginInstallFailed(e.toString()),
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

    final l10n = AppLocalizations.of(context);
    final hasDescription =
        entry.description != null && entry.description!.isNotEmpty;

    return ListTile(
      leading: _buildIcon(entry, theme),
      title: Text(entry.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 作者与来源是用户区分「同名不同插件」的唯一依据，故并排展示
          if ((entry.author != null && entry.author!.isNotEmpty) ||
              (entry.sourceName != null && entry.sourceName!.isNotEmpty))
            Text(
              [
                if (entry.author != null && entry.author!.isNotEmpty)
                  entry.author!,
                if (entry.sourceName != null && entry.sourceName!.isNotEmpty)
                  entry.sourceName!,
              ].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
          if (hasDescription)
            Text(
              entry.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          if (entry.conflict)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      l10n.jspluginConflictBanner(entry.conflictWith ?? ''),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      trailing: _buildAction(entry, theme),
      isThreeLine: hasDescription || entry.conflict,
    );
  }

  Widget _buildIcon(RegistryPluginEntry entry, ThemeData theme) {
    if (entry.icon != null && entry.icon!.isNotEmpty) {
      final rawIcon = entry.icon!;
      // 商店条目的 icon 来自后端返回的 `/api/v1/proxy?url=<encoded>`：
      // `endsWith('.svg')` 会误判为位图并交给 `Image.network` 解码 SVG，
      // errorBuilder 兜底成首字母。用 `isSvgIconUrl` 解析 query 里的目标 URL。
      final isSvg = isSvgIconUrl(rawIcon);
      final url = UrlHelper.buildResourceUrl(rawIcon);
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child:
            isSvg
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
    // 用 rowKey 而非 entryPath：同名不同作者的两个条目否则连颜色和首字母都一样
    final color =
        Colors.primaries[entry.rowKey.hashCode % Colors.primaries.length];
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
    // entry_path 被另一个作者的插件占用：安装会替换它，先让用户确认
    if (entry.conflict) {
      return FilledButton.tonal(
        onPressed: _confirmThenInstall,
        style: FilledButton.styleFrom(
          backgroundColor: theme.colorScheme.errorContainer,
          foregroundColor: theme.colorScheme.onErrorContainer,
        ),
        child: Text(l10n.jspluginOverwriteInstall),
      );
    }
    return FilledButton(onPressed: _install, child: Text(l10n.jspluginInstall));
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
          message: AppLocalizations.of(
            context,
          ).jspluginSaveFailed(e.toString()),
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
          _registries[index] = r.copyWith(url: url, name: name, token: token);
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
      builder:
          (ctx) => AlertDialog(
            title: Text(
              isEdit ? l10n.jspluginEditRegistry : l10n.jspluginAddRegistry,
            ),
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
                      _registries.add(
                        PluginRegistryConfig(
                          url: url,
                          name: nameController.text.trim(),
                          enabled: true,
                          token: tokenController.text.trim(),
                        ),
                      );
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
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                l10n.jspluginOfficial,
                                style: TextStyle(
                                  fontSize: 10,
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer,
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
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle:
                          r.name.isNotEmpty
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
          child:
              _saving
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
