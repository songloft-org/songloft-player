import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/responsive.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/github_plugin.dart';
import '../providers/github_discovery_provider.dart';
import '../providers/jsplugin_provider.dart';
import '../widgets/github_plugin_detail.dart';

class GithubDiscoveryPage extends ConsumerStatefulWidget {
  const GithubDiscoveryPage({super.key});
  @override
  ConsumerState<GithubDiscoveryPage> createState() =>
      _GithubDiscoveryPageState();
}

class _GithubDiscoveryPageState extends ConsumerState<GithubDiscoveryPage> {
  final _search = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _resetScroll() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _details(GithubPlugin plugin) {
    if (MediaQuery.sizeOf(context).width < 600) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder:
            (_) => FractionallySizedBox(
              heightFactor: .85,
              child: GithubPluginDetail(plugin: plugin),
            ),
      );
    } else {
      showDialog<void>(
        context: context,
        builder:
            (_) => Dialog(
              child: SizedBox(
                width: 620,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * .85,
                  ),
                  child: GithubPluginDetail(plugin: plugin),
                ),
              ),
            ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final state = ref.watch(githubDiscoveryProvider);
    final notifier = ref.read(githubDiscoveryProvider.notifier);
    final installed = ref.watch(jsPluginsProvider).value ?? [];
    final local = ref.watch(githubDiscoveryInstallsProvider);
    final plugins = state.plugins;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.githubDiscoveryTitle),
        leading: BackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.pluginRegistry);
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: l10n.githubDiscoveryHelpTitle,
            onPressed:
                () => showDialog<void>(
                  context: context,
                  builder:
                      (ctx) => AlertDialog(
                        title: Text(l10n.githubDiscoveryHelpTitle),
                        scrollable: true,
                        content: Text(l10n.githubDiscoveryHelp),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(l10n.jspluginClose),
                          ),
                        ],
                      ),
                ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.jspluginRefreshList,
            onPressed:
                state.loading
                    ? null
                    : () {
                      _resetScroll();
                      notifier.refresh();
                    },
          ),
        ],
      ),
      body: ListView.builder(
        controller: _scroll,
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + context.navScrollInset),
        itemCount: plugins.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    l10n.githubDiscoveryNotice,
                    style: TextStyle(color: colors.onSecondaryContainer),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: l10n.githubDiscoverySearch,
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    suffixIcon:
                        _search.text.isEmpty
                            ? null
                            : IconButton(
                              icon: const Icon(Icons.clear),
                              tooltip: l10n.clearSearch,
                              onPressed: () {
                                _search.clear();
                                _resetScroll();
                                notifier.search('');
                              },
                            ),
                  ),
                  onChanged: (value) {
                    _resetScroll();
                    notifier.search(value);
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: PopupMenuButton<String>(
                    tooltip: l10n.githubDiscoverySort,
                    initialValue: state.sort,
                    onSelected: (value) {
                      _resetScroll();
                      notifier.sort(value);
                    },
                    itemBuilder:
                        (_) => [
                          CheckedPopupMenuItem(
                            value: 'updated',
                            checked: state.sort == 'updated',
                            child: Text(l10n.githubDiscoveryUpdated),
                          ),
                          CheckedPopupMenuItem(
                            value: 'stars',
                            checked: state.sort == 'stars',
                            child: Text(l10n.githubDiscoveryStars),
                          ),
                        ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              state.sort == 'stars'
                                  ? l10n.githubDiscoveryStars
                                  : l10n.githubDiscoveryUpdated,
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                ),
                if (state.loading) const LinearProgressIndicator(),
                const SizedBox(height: 8),
              ],
            );
          }
          if (index == plugins.length + 1) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.error != null || state.limited) ...[
                  Text(
                    state.limited
                        ? l10n.githubDiscoveryRateLimited
                        : l10n.githubDiscoveryLoadFailed,
                    style: TextStyle(color: colors.error),
                  ),
                  if (state.retryAt != null)
                    Text(
                      l10n.githubDiscoveryRetryAt(
                        state.retryAt!.toLocal().toString(),
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed:
                          state.loading
                              ? null
                              : () {
                                if (state.error != null &&
                                    state.pages.isNotEmpty &&
                                    !state.limited) {
                                  notifier.loadMore();
                                } else {
                                  notifier.refresh();
                                }
                              },
                      child: Text(l10n.commonRetry),
                    ),
                  ),
                ],
                if (!state.loading && state.error == null && plugins.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      state.unverified > 0 || state.limited
                          ? l10n.githubDiscoveryPending
                          : l10n.githubDiscoveryEmpty,
                    ),
                  ),
                if (state.pages.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      l10n.githubDiscoverySummary(
                        state.checked,
                        plugins.length,
                        state.excluded,
                        state.unverified,
                      ),
                    ),
                  ),
                if (state.pages.any((page) => page.incomplete))
                  Text(l10n.githubDiscoveryIncomplete),
                if (state.nextPage != null)
                  OutlinedButton(
                    onPressed: state.loading ? null : notifier.loadMore,
                    child: Text(
                      state.loading
                          ? l10n.jspluginLoadingList
                          : l10n.githubDiscoveryLoadMore,
                    ),
                  ),
              ],
            );
          }
          final plugin = plugins[index - 1];
          final occupied =
              installed
                  .where((item) => item.entryPath == plugin.manifest.entryPath)
                  .firstOrNull;
          final successful = local[plugin.manifest.entryPath];
          final same =
              successful != null
                  ? successful.repository.id == plugin.repository.id
                  : plugin.installedFrom(occupied);
          final version =
              successful?.manifest.version ?? occupied?.version ?? '';
          return Card(
            key: ValueKey(plugin.repository.id),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Text(plugin.manifest.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(plugin.repository.fullName),
                  if (plugin.manifest.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        plugin.manifest.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  Text(
                    'v${plugin.manifest.version} · ${plugin.manifest.renderEngine.isEmpty ? 'webview' : plugin.manifest.renderEngine} · ★ ${plugin.repository.stars}',
                  ),
                  if (same)
                    Text(
                      (comparePluginVersions(
                                    plugin.manifest.version,
                                    version,
                                  ) ??
                                  0) >
                              0
                          ? l10n.githubDiscoveryUpdateAvailable
                          : l10n.githubDiscoveryInstalled,
                    ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.githubDiscoveryDetails,
                    style: TextStyle(color: colors.primary),
                  ),
                ],
              ),
              onTap: () => _details(plugin),
            ),
          );
        },
      ),
    );
  }
}
