import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/responsive_snackbar.dart';
import 'widgets/section_card.dart';
import '../../jsplugin/data/jsplugin_api.dart';
import '../../jsplugin/presentation/providers/jsplugin_provider.dart';
import '../../jsplugin/presentation/widgets/plugin_icon.dart';
import '../data/settings_api.dart';
import 'providers/settings_provider.dart';

class TabConfigPage extends ConsumerWidget {
  const TabConfigPage({super.key});

  static const int _maxTabs = 12;
  static const int _fixedTabs = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabConfigAsync = ref.watch(tabConfigProvider);
    final pluginsAsync = ref.watch(jsPluginsProvider);
    final config = tabConfigAsync.value ?? TabConfig.defaultConfig();
    final plugins = pluginsAsync.value ?? [];
    final activePlugins = plugins
        .where((p) =>
            p.isActive &&
            p.entryPath != null &&
            p.entryPath!.isNotEmpty)
        .toList();

    final usedCount = _fixedTabs + config.optionalCount;
    final atLimit = usedCount >= _maxTabs;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTabConfigTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          SectionCard(
            title: l10n.settingsTabConfigBuiltInSection,
            icon: Icons.dashboard_outlined,
            children: [
              // 歌单已并入曲库（作为曲库的歌单视图），不再作为独立底部 tab，
              // 故此处仅保留「曲库」开关。
              SwitchListTile(
                secondary: const Icon(Icons.library_music_outlined),
                title: Text(l10n.settingsTabConfigLibrary),
                value: config.showLibrary,
                onChanged: atLimit && !config.showLibrary
                    ? null
                    : (value) => _updateConfig(
                          context,
                          ref,
                          config.copyWith(showLibrary: value),
                          atLimit && value,
                        ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: l10n.settingsTabConfigPluginEntry,
            icon: Icons.extension_outlined,
            children: activePlugins.isEmpty
                ? [
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: Text(l10n.settingsTabConfigNoPlugins),
                      subtitle: Text(l10n.settingsTabConfigNoPluginsHint),
                    ),
                  ]
                : _buildPluginTiles(context, ref, config, activePlugins, atLimit),
          ),
          if (config.pluginTabs.length > 1) ...[
            const SizedBox(height: 16),
            SectionCard(
              title: l10n.settingsTabConfigPluginOrder,
              icon: Icons.reorder,
              children: [
                _PluginTabReorderList(
                  config: config,
                  plugins: plugins,
                  onReorder: (newConfig) =>
                      _updateConfig(context, ref, newConfig, false),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Center(
            child: Text(
              l10n.settingsTabConfigEnabledCount(usedCount) +
                  (usedCount > 5
                      ? '\n${l10n.settingsTabConfigCollapseHint}'
                      : ''),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  List<Widget> _buildPluginTiles(
    BuildContext context,
    WidgetRef ref,
    TabConfig config,
    List<JSPlugin> activePlugins,
    bool atLimit,
  ) {
    final widgets = <Widget>[];
    for (var i = 0; i < activePlugins.length; i++) {
      final plugin = activePlugins[i];
      final isEnabled = config.pluginTabs
          .any((pt) => pt.entryPath == plugin.entryPath);

      if (i > 0) widgets.add(const Divider(height: 1));
      widgets.add(
        SwitchListTile(
          secondary: PluginNavIcon(
            iconUrl: plugin.iconUrl,
            size: 24,
            fallbackIcon: const Icon(Icons.extension_outlined),
          ),
          title: Text(plugin.displayName),
          subtitle: plugin.version != null ? Text('v${plugin.version}') : null,
          value: isEnabled,
          onChanged: atLimit && !isEnabled
              ? null
              : (value) {
                  final newPluginTabs = List<PluginTabEntry>.from(config.pluginTabs);
                  if (value) {
                    newPluginTabs.add(PluginTabEntry(
                      pluginId: plugin.id,
                      entryPath: plugin.entryPath!,
                      name: plugin.displayName,
                    ));
                  } else {
                    newPluginTabs.removeWhere(
                        (pt) => pt.entryPath == plugin.entryPath);
                  }
                  _updateConfig(
                    context,
                    ref,
                    config.copyWith(pluginTabs: newPluginTabs),
                    atLimit && value,
                  );
                },
        ),
      );
    }
    return widgets;
  }

  Future<void> _updateConfig(
    BuildContext context,
    WidgetRef ref,
    TabConfig config,
    bool wouldExceedLimit,
  ) async {
    final l10n = AppLocalizations.of(context);
    if (wouldExceedLimit) {
      ResponsiveSnackBar.showError(
        context,
        message: l10n.settingsTabConfigMaxTabs(_maxTabs),
      );
      return;
    }
    try {
      await ref.read(tabConfigProvider.notifier).updateConfig(config);
    } catch (e) {
      if (context.mounted) {
        ResponsiveSnackBar.showError(
          context,
          message: l10n.settingsTabConfigSaveFailed(e.toString()),
        );
      }
    }
  }
}

class _PluginTabReorderList extends StatelessWidget {
  final TabConfig config;
  final List<JSPlugin> plugins;
  final ValueChanged<TabConfig> onReorder;

  const _PluginTabReorderList({
    required this.config,
    required this.plugins,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    final pluginTabs = config.pluginTabs;
    final colorScheme = Theme.of(context).colorScheme;

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: pluginTabs.length,
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex--;
        final newList = List<PluginTabEntry>.from(pluginTabs);
        final item = newList.removeAt(oldIndex);
        newList.insert(newIndex, item);
        onReorder(config.copyWith(pluginTabs: newList));
      },
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) => Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: child,
          ),
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final pt = pluginTabs[index];
        final plugin = plugins
            .where((p) => p.entryPath == pt.entryPath)
            .firstOrNull;

        return ListTile(
          key: ValueKey(pt.entryPath),
          leading: PluginNavIcon(
            iconUrl: plugin?.iconUrl,
            size: 24,
            fallbackIcon: const Icon(Icons.extension_outlined),
          ),
          title: Text(pt.name),
          trailing: ReorderableDragStartListener(
            index: index,
            child: Icon(
              Icons.drag_handle,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        );
      },
    );
  }
}
