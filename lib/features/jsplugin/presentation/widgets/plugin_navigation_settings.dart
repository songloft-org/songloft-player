import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/utils/responsive_snackbar.dart';
import '../../../settings/data/settings_api.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../data/jsplugin_api.dart';
import '../providers/jsplugin_provider.dart';
import 'plugin_icon.dart';

Future<void> _saveNavigationConfig(
  BuildContext context,
  WidgetRef ref,
  TabConfig config,
) async {
  try {
    await ref.read(tabConfigProvider.notifier).updateConfig(config);
  } catch (e) {
    if (!context.mounted) return;
    ResponsiveSnackBar.showError(
      context,
      message: AppLocalizations.of(context).settingsSaveFailed(e.toString()),
    );
  }
}

/// 导航偏好独立于插件运行状态；停用时保留选择，启用后恢复。
class PluginNavigationToggle extends ConsumerWidget {
  final JSPlugin plugin;
  final bool busy;

  const PluginNavigationToggle({
    super.key,
    required this.plugin,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = plugin.entryPath;
    if (path == null || path.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final configAsync = ref.watch(tabConfigProvider);
    final pluginsAsync = ref.watch(jsPluginsProvider);
    final config = configAsync.value;
    final visible = config?.pluginTabs.any((e) => e.entryPath == path) ?? false;
    final atLimit =
        config != null &&
        2 +
                (config.showLibrary ? 1 : 0) +
                config.activeEntries(pluginsAsync.value ?? []).length >=
            12;
    final ready =
        !busy &&
        !ref.watch(tabConfigSavingProvider) &&
        plugin.isActive &&
        configAsync.hasValue &&
        !configAsync.hasError &&
        !configAsync.isLoading &&
        pluginsAsync.hasValue &&
        !pluginsAsync.hasError &&
        !pluginsAsync.isLoading;

    return SwitchListTile(
      key: ValueKey('plugin-navigation-${plugin.id}'),
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(l10n.jspluginShowInNavigation),
      subtitle: Text(
        !plugin.isActive
            ? l10n.jspluginNavigationDisabledHint
            : atLimit && !visible
            ? l10n.settingsMaxTabsLimit(12)
            : l10n.jspluginShowInNavigationHint,
      ),
      value: visible,
      onChanged:
          !ready || (atLimit && !visible)
              ? null
              : (value) {
                // 只修改当前插件，保留其他插件（含停用插件）的选择与排序。
                final tabs = List<PluginTabEntry>.from(config!.pluginTabs);
                if (value) {
                  tabs.add(
                    PluginTabEntry(
                      pluginId: plugin.id,
                      entryPath: path,
                      name: plugin.displayName,
                    ),
                  );
                } else {
                  tabs.removeWhere((e) => e.entryPath == path);
                }
                _saveNavigationConfig(
                  context,
                  ref,
                  config.copyWith(pluginTabs: tabs),
                );
              },
    );
  }
}

class PluginNavigationOrder extends ConsumerWidget {
  const PluginNavigationOrder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final configAsync = ref.watch(tabConfigProvider);
    final pluginsAsync = ref.watch(jsPluginsProvider);
    if (configAsync.hasError) {
      return ListTile(
        title: Text(l10n.commonLoadFailed),
        trailing: TextButton(
          onPressed: () => ref.invalidate(tabConfigProvider),
          child: Text(l10n.commonRetry),
        ),
      );
    }
    final config = configAsync.value;
    if (config == null) return const SizedBox.shrink();
    final plugins = pluginsAsync.value ?? <JSPlugin>[];
    final entries = config.activeEntries(plugins);
    if (entries.isEmpty) return const SizedBox.shrink();
    final saving =
        ref.watch(tabConfigSavingProvider) ||
        configAsync.isLoading ||
        pluginsAsync.hasError ||
        pluginsAsync.isLoading;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.reorder),
          title: Text(l10n.jspluginNavigationOrder),
          subtitle: Text(l10n.settingsTabsCollapseHint),
        ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: entries.length,
          onReorderItem: (oldIndex, newIndex) {
            if (saving) return;
            final reordered = List<PluginTabEntry>.from(entries);
            reordered.insert(newIndex, reordered.removeAt(oldIndex));
            final activePaths = entries.map((e) => e.entryPath).toSet();
            var activeIndex = 0;
            // 替换可见条目的槽位，保留停用插件原来的位置与显示偏好。
            final tabs = [
              for (final entry in config.pluginTabs)
                if (activePaths.contains(entry.entryPath))
                  reordered[activeIndex++]
                else
                  entry,
            ];
            _saveNavigationConfig(
              context,
              ref,
              config.copyWith(pluginTabs: tabs),
            );
          },
          proxyDecorator:
              (child, index, animation) => Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: child,
              ),
          itemBuilder: (context, index) {
            final entry = entries[index];
            final plugin = plugins.firstWhere(
              (p) => p.entryPath == entry.entryPath,
            );
            return ListTile(
              key: ValueKey(entry.entryPath),
              leading: PluginNavIcon(
                iconUrl: plugin.iconUrl,
                size: 24,
                fallbackIcon: const Icon(Icons.extension_outlined),
              ),
              title: Text(plugin.displayName),
              trailing: ReorderableDragStartListener(
                index: index,
                enabled: !saving,
                child: Icon(
                  Icons.drag_handle,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
