import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/app_config.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/responsive.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/jsplugin_api.dart';
import '../providers/jsplugin_provider.dart';
import 'plugin_icon.dart';

/// JS 插件入口网格组件
class JSPluginGrid extends ConsumerWidget {
  const JSPluginGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pluginsAsync = ref.watch(jsPluginsProvider);

    return pluginsAsync.when(
      data: (plugins) {
        final activePlugins =
            plugins
                .where(
                  (p) =>
                      p.isActive &&
                      p.entryPath != null &&
                      p.entryPath!.isNotEmpty,
                )
                .toList();

        if (activePlugins.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                AppLocalizations.of(context).jspluginGridTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final containerWidth = constraints.maxWidth - 24;
                final int crossAxisCount;
                if (context.isMobile ||
                    containerWidth < ResponsiveBreakpoints.tablet) {
                  // 手机：每列约 90px，3-5 列自适应
                  crossAxisCount = (containerWidth / 90).floor().clamp(3, 5);
                } else if (containerWidth < ResponsiveBreakpoints.desktop) {
                  // 平板：4-5 列
                  crossAxisCount = (containerWidth / 110).floor().clamp(4, 5);
                } else {
                  // 桌面：5-8 列
                  crossAxisCount = (containerWidth / 120).floor().clamp(5, 8);
                }

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.88,
                  ),
                  itemCount: activePlugins.length,
                  itemBuilder: (context, index) {
                    final plugin = activePlugins[index];
                    return _JSPluginCard(plugin: plugin);
                  },
                );
              },
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

/// JS 插件卡片组件
class _JSPluginCard extends StatelessWidget {
  final JSPlugin plugin;

  const _JSPluginCard({required this.plugin});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      child: InkWell(
        onTap: () => _openPlugin(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 顶部插件图标
              PluginIcon(
                iconUrl: plugin.iconUrl,
                displayName: plugin.displayName,
                size: 46,
              ),
              const SizedBox(height: 8),
              // 底部插件名称
              Text(
                plugin.displayName,
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 打开插件入口
  void _openPlugin(BuildContext context) {
    if (plugin.entryPath == null || plugin.entryPath!.isEmpty) {
      return;
    }

    final url =
        '${AppConfig.baseUrl}${AppConfig.basePath}/api/v1/jsplugin/${plugin.entryPath}';

    // Web/native 统一走应用内 WebView（传裸 url，theme/token 由 WebView 页面内部补齐）。
    context.push(
      Uri(
        path: AppRoutes.plugin,
        queryParameters: {'url': url, 'name': plugin.displayName},
      ).toString(),
    );
  }
}
