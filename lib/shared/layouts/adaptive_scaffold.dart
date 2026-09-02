import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../core/theme/widgets/glass_capsule_bar.dart';
import '../../l10n/app_localizations.dart';

/// 导航目的地定义
class NavDestination {
  final String label;
  final Widget icon;
  final Widget selectedIcon;

  const NavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

/// 自适应脚手架，根据屏幕尺寸切换布局模式
class AdaptiveScaffold extends StatelessWidget {
  final Widget body;
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavDestination> destinations;
  final Widget? bottomPlayer;
  final Widget? playlistDrawer;

  const AdaptiveScaffold({
    super.key,
    required this.body,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.bottomPlayer,
    this.playlistDrawer,
  });

  @override
  Widget build(BuildContext context) {
    final screenType = context.screenType;

    switch (screenType) {
      case ScreenType.mobile:
        return _buildMobileLayout(context);
      case ScreenType.tablet:
        return _buildTabletLayout(context);
      case ScreenType.desktop:
        return _buildDesktopLayout(context);
      case ScreenType.widescreen:
        return _buildWidescreenLayout(context);
    }
  }

  static const int _mobileMaxVisible = 5;
  static const int _mobileRealSlots = 4;

  /// Mobile: 底部导航栏布局
  Widget _buildMobileLayout(BuildContext context) {
    final ext = Theme.of(context).extension<SongloftThemeExtension>();
    final useCapsule = ext?.navigationStyle == 'capsule';

    return Scaffold(
      body: body,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (bottomPlayer != null) bottomPlayer!,
          if (useCapsule)
            _buildCapsuleNav(context)
          else
            _buildStandardNav(context),
        ],
      ),
    );
  }

  Widget _buildCapsuleNav(BuildContext context) {
    final hasOverflow = destinations.length > _mobileMaxVisible;
    final visibleDests = hasOverflow
        ? destinations.sublist(0, _mobileRealSlots)
        : destinations;
    final barSelectedIndex = hasOverflow && currentIndex >= _mobileRealSlots
        ? _mobileRealSlots
        : currentIndex;

    final capsuleDests = [
      for (final dest in visibleDests)
        GlassCapsuleDestination(
          label: dest.label,
          icon: dest.icon,
          selectedIcon: dest.selectedIcon,
        ),
      if (hasOverflow)
        GlassCapsuleDestination(
          label: AppLocalizations.of(context).more,
          icon: const Icon(Icons.more_horiz),
          selectedIcon: const Icon(Icons.more_horiz),
        ),
    ];

    return GlassCapsuleBar(
      selectedIndex: barSelectedIndex,
      onDestinationSelected: (index) {
        if (hasOverflow && index == _mobileRealSlots) {
          _showOverflowSheet(context);
        } else {
          onDestinationSelected(index);
        }
      },
      destinations: capsuleDests,
    );
  }

  Widget _buildStandardNav(BuildContext context) {
    final hasOverflow = destinations.length > _mobileMaxVisible;

    if (!hasOverflow) {
      return NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: onDestinationSelected,
        destinations:
            destinations.map((dest) {
              return NavigationDestination(
                icon: dest.icon,
                selectedIcon: dest.selectedIcon,
                label: dest.label,
              );
            }).toList(),
      );
    }

    final barSelectedIndex =
        currentIndex < _mobileRealSlots ? currentIndex : _mobileRealSlots;

    return NavigationBar(
      selectedIndex: barSelectedIndex,
      onDestinationSelected: (index) {
        if (index < _mobileRealSlots) {
          onDestinationSelected(index);
        } else {
          _showOverflowSheet(context);
        }
      },
      destinations: [
        for (var i = 0; i < _mobileRealSlots; i++)
          NavigationDestination(
            icon: destinations[i].icon,
            selectedIcon: destinations[i].selectedIcon,
            label: destinations[i].label,
          ),
        NavigationDestination(
          icon: const Icon(Icons.more_horiz),
          selectedIcon: const Icon(Icons.more_horiz),
          label: AppLocalizations.of(context).more,
        ),
      ],
    );
  }

  void _showOverflowSheet(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final overflowDests = destinations.sublist(_mobileRealSlots);

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              for (var i = 0; i < overflowDests.length; i++)
                _buildOverflowTile(
                  sheetContext,
                  overflowDests[i],
                  _mobileRealSlots + i,
                  colorScheme,
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOverflowTile(
    BuildContext sheetContext,
    NavDestination dest,
    int originalIndex,
    ColorScheme colorScheme,
  ) {
    final isSelected = currentIndex == originalIndex;
    return ListTile(
      leading: IconTheme(
        data: IconThemeData(
          color:
              isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
        ),
        child: isSelected ? dest.selectedIcon : dest.icon,
      ),
      title: Text(
        dest.label,
        style: TextStyle(
          color: isSelected ? colorScheme.primary : colorScheme.onSurface,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: colorScheme.primaryContainer.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: () {
        Navigator.pop(sheetContext);
        onDestinationSelected(originalIndex);
      },
    );
  }

  /// Tablet: NavigationRail 布局
  Widget _buildTabletLayout(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: currentIndex,
            onDestinationSelected: onDestinationSelected,
            labelType: NavigationRailLabelType.all,
            destinations:
                destinations.map((dest) {
                  return NavigationRailDestination(
                    icon: dest.icon,
                    selectedIcon: dest.selectedIcon,
                    label: Text(dest.label),
                  );
                }).toList(),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: body),
                      if (playlistDrawer != null) playlistDrawer!,
                    ],
                  ),
                ),
                if (bottomPlayer != null) bottomPlayer!,
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const double _desktopSidebarWidth = 240;

  /// Desktop: 宽侧边导航布局（Apple HIG Materials — 毛玻璃侧边栏）
  Widget _buildDesktopLayout(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final ext = theme.extension<SongloftThemeExtension>();

    return Scaffold(
      body: Stack(
        children: [
          // 底层：body 内容（左侧预留侧边栏宽度）
          Row(
            children: [
              const SizedBox(width: _desktopSidebarWidth),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(child: body),
                          if (playlistDrawer != null) playlistDrawer!,
                        ],
                      ),
                    ),
                    if (bottomPlayer != null) bottomPlayer!,
                  ],
                ),
              ),
            ],
          ),
          // 玻璃侧边栏：BackdropFilter + 半透着色
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: _desktopSidebarWidth,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  decoration: BoxDecoration(
                    color: ext?.glassFill ?? colorScheme.surface,
                    border: Border(
                      right: BorderSide(
                        color: ext?.glassBorder ?? colorScheme.outlineVariant,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: _buildDesktopSidebarContent(context, theme, colorScheme, ext),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopSidebarContent(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    SongloftThemeExtension? ext,
  ) {
    return Column(
      children: [
        // App 标题区域
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/icons/app_icon.png',
                  width: 32,
                  height: 32,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Songloft',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          color: ext?.glassBorder ?? colorScheme.outlineVariant,
        ),
        // 导航列表
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: destinations.length,
            itemBuilder: (context, index) {
              final dest = destinations[index];
              final isSelected = index == currentIndex;
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                child: ListTile(
                  leading: IconTheme(
                    data: IconThemeData(
                      color: isSelected
                          ? (ext?.glassGlow ?? colorScheme.primary)
                          : colorScheme.onSurfaceVariant,
                    ),
                    child: isSelected ? dest.selectedIcon : dest.icon,
                  ),
                  title: Text(
                    dest.label,
                    style: TextStyle(
                      color: isSelected
                          ? (ext?.glassGlow ?? colorScheme.primary)
                          : colorScheme.onSurface,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  selected: isSelected,
                  selectedTileColor: ext?.glassGlow.withAlpha(77) ??
                      colorScheme.primaryContainer.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () => onDestinationSelected(index),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 超宽屏：左侧 Dock 导航布局（宽高比 > 2.2）
  Widget _buildWidescreenLayout(BuildContext context) {
    final ext = Theme.of(context).extension<SongloftThemeExtension>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          // 底层：body 内容
          Row(
            children: [
              const SizedBox(width: _WidescreenDock._dockWidth),
              Expanded(child: body),
              if (playlistDrawer != null) playlistDrawer!,
              if (bottomPlayer != null) bottomPlayer!,
            ],
          ),
          // 玻璃 Dock
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: _WidescreenDock._dockWidth,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  decoration: BoxDecoration(
                    color: ext?.glassFill ?? colorScheme.surfaceContainerLow,
                    border: Border(
                      right: BorderSide(
                        color: ext?.glassBorder ?? colorScheme.outlineVariant,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: _WidescreenDock(
                      destinations: destinations,
                      currentIndex: currentIndex,
                      onDestinationSelected: onDestinationSelected,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 超宽屏模式左侧 Dock 导航组件
///
/// 140px 宽的垂直导航栏，顶部 Logo，下方导航项（图标+标签），
/// 适配超宽屏幕，大触控目标（最小 56dp 高度）。
class _WidescreenDock extends StatelessWidget {
  final List<NavDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  static const double _dockWidth = 140;
  static const double _itemHeight = 60;

  const _WidescreenDock({
    required this.destinations,
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final ext = theme.extension<SongloftThemeExtension>();

    return SizedBox(
      width: _dockWidth,
      child: Column(
        children: [
          // Logo 区域
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/icons/app_icon.png',
                width: 48,
                height: 48,
              ),
            ),
          ),
          // 导航项列表
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              itemCount: destinations.length,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final dest = destinations[index];
                final isSelected = index == currentIndex;
                return Material(
                  color:
                      isSelected
                          ? (ext?.glassGlow.withAlpha(77) ?? colorScheme.secondaryContainer)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => onDestinationSelected(index),
                    child: SizedBox(
                      height: _itemHeight,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconTheme(
                            data: IconThemeData(
                              size: 26,
                              color:
                                  isSelected
                                      ? colorScheme.onSecondaryContainer
                                      : colorScheme.onSurfaceVariant,
                            ),
                            child: isSelected ? dest.selectedIcon : dest.icon,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dest.label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color:
                                  isSelected
                                      ? colorScheme.onSecondaryContainer
                                      : colorScheme.onSurfaceVariant,
                              fontWeight:
                                  isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
