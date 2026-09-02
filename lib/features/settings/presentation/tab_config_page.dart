import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/responsive.dart';
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
    final activePlugins =
        plugins
            .where(
              (p) =>
                  p.isActive && p.entryPath != null && p.entryPath!.isNotEmpty,
            )
            .toList();

    // 计数与限额基于「实际会渲染的条目」：孤儿条目（插件已卸载）与禁用插件
    // 不占名额，保证显示数量与首页可见 Tab 严格一致（#416）。
    final effectiveTabs = config.activeEntries(activePlugins);
    final usedCount =
        _fixedTabs + (config.showLibrary ? 1 : 0) + effectiveTabs.length;
    final atLimit = usedCount >= _maxTabs;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTabConfigTitle)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, context.navScrollInset),
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
                onChanged:
                    atLimit && !config.showLibrary
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
            children:
                activePlugins.isEmpty
                    ? [
                      ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: Text(l10n.settingsTabConfigNoPlugins),
                        subtitle: Text(l10n.settingsTabConfigNoPluginsHint),
                      ),
                    ]
                    : _buildPluginTiles(
                      context,
                      ref,
                      config,
                      activePlugins,
                      atLimit,
                    ),
          ),
          if (effectiveTabs.length > 1) ...[
            const SizedBox(height: 16),
            SectionCard(
              title: l10n.settingsTabConfigPluginOrder,
              icon: Icons.reorder,
              children: [
                _PluginTabReorderList(
                  pluginTabs: effectiveTabs,
                  plugins: plugins,
                  onReorder:
                      (newTabs) => _updateConfig(
                        context,
                        ref,
                        config.copyWith(pluginTabs: newTabs),
                        false,
                      ),
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
    // 以「实际渲染的条目」为基准增删：保存时顺带清掉孤儿条目（#416）
    final effectiveTabs = config.activeEntries(activePlugins);
    final widgets = <Widget>[];
    for (var i = 0; i < activePlugins.length; i++) {
      final plugin = activePlugins[i];
      final isEnabled = config.pluginTabs.any(
        (pt) => pt.entryPath == plugin.entryPath,
      );

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
          onChanged:
              atLimit && !isEnabled
                  ? null
                  : (value) {
                    final newPluginTabs = List<PluginTabEntry>.from(
                      effectiveTabs,
                    );
                    if (value) {
                      newPluginTabs.add(
                        PluginTabEntry(
                          pluginId: plugin.id,
                          entryPath: plugin.entryPath!,
                          name: plugin.displayName,
                        ),
                      );
                    } else {
                      newPluginTabs.removeWhere(
                        (pt) => pt.entryPath == plugin.entryPath,
                      );
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
  final List<PluginTabEntry> pluginTabs;
  final List<JSPlugin> plugins;
  final ValueChanged<List<PluginTabEntry>> onReorder;

  const _PluginTabReorderList({
    required this.pluginTabs,
    required this.plugins,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: pluginTabs.length,
      onReorderItem: (oldIndex, newIndex) {
        final newList = List<PluginTabEntry>.from(pluginTabs);
        final item = newList.removeAt(oldIndex);
        newList.insert(newIndex, item);
        onReorder(newList);
      },
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder:
              (context, child) => Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: child,
              ),
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final pt = pluginTabs[index];
        final plugin =
            plugins.where((p) => p.entryPath == pt.entryPath).firstOrNull;

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
            child: Icon(Icons.drag_handle, color: colorScheme.onSurfaceVariant),
          ),
        );
      },
    );
  }
}
