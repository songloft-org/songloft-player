import 'package:flutter/material.dart';

import '../../core/router/app_router.dart';
import '../../features/jsplugin/data/jsplugin_api.dart';
import '../../features/jsplugin/presentation/widgets/plugin_icon.dart';
import '../../features/settings/data/settings_api.dart';
import '../../l10n/app_localizations.dart';
import 'adaptive_scaffold.dart';

class ActiveDestinations {
  final List<NavDestination> destinations;
  final Map<String, int> routeToIndex;
  final List<String> indexToRoute;

  ActiveDestinations._({
    required this.destinations,
    required this.routeToIndex,
    required this.indexToRoute,
  });

  factory ActiveDestinations.compute(
    TabConfig config,
    List<JSPlugin> plugins,
    AppLocalizations l10n,
  ) {
    final destinations = <NavDestination>[];
    final indexToRoute = <String>[];

    destinations.add(
      NavDestination(
        label: l10n.navHome,
        icon: const Icon(Icons.home_outlined),
        selectedIcon: const Icon(Icons.home),
      ),
    );
    indexToRoute.add(AppRoutes.home);

    if (config.showLibrary) {
      destinations.add(
        NavDestination(
          label: l10n.navLibrary,
          icon: const Icon(Icons.library_music_outlined),
          selectedIcon: const Icon(Icons.library_music),
        ),
      );
      indexToRoute.add(AppRoutes.library);
    }

    if (config.showPlaylists) {
      destinations.add(
        NavDestination(
          label: l10n.navPlaylists,
          icon: const Icon(Icons.queue_music_outlined),
          selectedIcon: const Icon(Icons.queue_music),
        ),
      );
      indexToRoute.add(AppRoutes.playlists);
    }

    for (final pt in config.pluginTabs) {
      final plugin =
          plugins
              .where(
                (p) =>
                    p.entryPath == pt.entryPath &&
                    p.isActive &&
                    p.entryPath != null &&
                    p.entryPath!.isNotEmpty,
              )
              .firstOrNull;
      if (plugin != null) {
        destinations.add(
          NavDestination(
            label: plugin.displayName,
            icon: PluginNavIcon(
              iconUrl: plugin.iconUrl,
              fallbackIcon: const Icon(Icons.extension_outlined),
            ),
            selectedIcon: PluginNavIcon(
              iconUrl: plugin.iconUrl,
              fallbackIcon: const Icon(Icons.extension),
            ),
          ),
        );
        indexToRoute.add('/plugin-tab/${pt.entryPath}');
      }
    }

    destinations.add(
      NavDestination(
        label: l10n.navSettings,
        icon: const Icon(Icons.settings_outlined),
        selectedIcon: const Icon(Icons.settings),
      ),
    );
    indexToRoute.add(AppRoutes.settings);

    final routeToIndex = <String, int>{};
    for (var i = 0; i < indexToRoute.length; i++) {
      routeToIndex[indexToRoute[i]] = i;
    }

    return ActiveDestinations._(
      destinations: destinations,
      routeToIndex: routeToIndex,
      indexToRoute: indexToRoute,
    );
  }
}
