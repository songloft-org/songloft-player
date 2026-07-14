import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/responsive.dart';
import '../../core/theme/tv_theme.dart';
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
      case ScreenType.auto_:
        return _buildAutoLayout(context);
      case ScreenType.tv:
        return _buildTvLayout(context);
    }
  }

  static const int _mobileMaxVisible = 5;
  static const int _mobileRealSlots = 4;

  /// Mobile: 底部导航栏布局
  Widget _buildMobileLayout(BuildContext context) {
    final hasOverflow = destinations.length > _mobileMaxVisible;

    if (!hasOverflow) {
      return Scaffold(
        body: body,
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (bottomPlayer != null) bottomPlayer!,
            NavigationBar(
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
            ),
          ],
        ),
      );
    }

    final barSelectedIndex = currentIndex < _mobileRealSlots
        ? currentIndex
        : _mobileRealSlots;

    return Scaffold(
      body: body,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (bottomPlayer != null) bottomPlayer!,
          NavigationBar(
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
          ),
        ],
      ),
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
          color: isSelected
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant,
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
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

  /// Desktop: 宽侧边导航布局
  Widget _buildDesktopLayout(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 240,
            child: Column(
              children: [
                // App 标题区域
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
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
                const Divider(height: 1),
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
                              color:
                                  isSelected
                                      ? colorScheme.primary
                                      : colorScheme.onSurfaceVariant,
                            ),
                            child: isSelected
                                ? dest.selectedIcon
                                : dest.icon,
                          ),
                          title: Text(
                            dest.label,
                            style: TextStyle(
                              color:
                                  isSelected
                                      ? colorScheme.primary
                                      : colorScheme.onSurface,
                              fontWeight:
                                  isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                            ),
                          ),
                          selected: isSelected,
                          selectedTileColor: colorScheme.primaryContainer
                              .withValues(alpha: 0.3),
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
            ),
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

  /// Auto/Car: 左侧 Dock 导航布局（宽高比 > 2.2 的超宽屏幕）
  Widget _buildAutoLayout(BuildContext context) {
    // 超宽屏纵向空间稀缺：播放器改走右侧竖排常驻面板（bottomPlayer 在 auto 模式下
    // 由 ShellLayout 传入 AutoSidePlayer），而非底部横条，避免吃掉宝贵的高度。
    return Scaffold(
      body: Row(
        children: [
          _AutoDock(
            destinations: destinations,
            currentIndex: currentIndex,
            onDestinationSelected: onDestinationSelected,
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: body),
          if (playlistDrawer != null) playlistDrawer!,
          if (bottomPlayer != null) bottomPlayer!,
        ],
      ),
    );
  }

  /// TV: 顶部 Tab 导航布局
  Widget _buildTvLayout(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final router = GoRouter.of(context);
        if (router.canPop()) {
          router.pop();
        }
        // 一级页面不做任何操作，防止退出应用
      },
      child: Scaffold(
        body: Column(
          children: [
            // 顶部导航栏
            Container(
              height: TvTheme.navBarHeight,
              padding: const EdgeInsets.symmetric(
                horizontal: TvTheme.contentPadding,
                vertical: TvTheme.spacingSmall,
              ),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: colorScheme.outlineVariant,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Logo 和标题
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/icons/app_icon.png',
                      width: 40,
                      height: 40,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Songloft',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: TvTheme.fontSizeTitle,
                    ),
                  ),
                  const SizedBox(width: TvTheme.spacingXLarge),
                  // 导航按钮
                  Expanded(
                    child: FocusTraversalGroup(
                      policy: OrderedTraversalPolicy(),
                      child: Row(
                        children:
                            destinations.asMap().entries.map((entry) {
                              final index = entry.key;
                              final dest = entry.value;
                              final isSelected = index == currentIndex;
                              return Padding(
                                padding: const EdgeInsets.only(
                                  right: TvTheme.spacingMedium,
                                ),
                                child: _TvNavButton(
                                  icon:
                                      isSelected
                                          ? dest.selectedIcon
                                          : dest.icon,
                                  label: dest.label,
                                  isSelected: isSelected,
                                  onPressed: () => onDestinationSelected(index),
                                  autofocus: index == 0,
                                ),
                              );
                            }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 主内容区域
            Expanded(
              child: FocusTraversalGroup(
                child: Row(
                  children: [
                    Expanded(child: body),
                    if (playlistDrawer != null) playlistDrawer!,
                  ],
                ),
              ),
            ),
            // 底部播放器
            if (bottomPlayer != null) bottomPlayer!,
          ],
        ),
      ),
    );
  }
}

/// TV 导航按钮组件
///
/// 支持 D-Pad 焦点导航的大尺寸导航按钮
class _TvNavButton extends StatefulWidget {
  final Widget icon;
  final String label;
  final bool isSelected;
  final VoidCallback onPressed;
  final bool autofocus;

  const _TvNavButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onPressed,
    this.autofocus = false,
  });

  @override
  State<_TvNavButton> createState() => _TvNavButtonState();
}

class _TvNavButtonState extends State<_TvNavButton> {
  bool _hasFocus = false;

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.gameButtonA ||
        event.logicalKey == LogicalKeyboardKey.space) {
      widget.onPressed();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Focus(
      autofocus: widget.autofocus,
      onKeyEvent: _handleKeyEvent,
      onFocusChange: (hasFocus) {
        setState(() {
          _hasFocus = hasFocus;
        });
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _hasFocus ? TvTheme.focusScale : 1.0,
          duration: TvTheme.focusAnimationDuration,
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: TvTheme.focusAnimationDuration,
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(
              minHeight: TvTheme.tabItemMinHeight,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: TvTheme.spacingLarge,
              vertical: TvTheme.spacingMedium,
            ),
            decoration: BoxDecoration(
              color:
                  widget.isSelected
                      ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                      : (_hasFocus
                          ? colorScheme.surfaceContainerHighest
                          : null),
              borderRadius: BorderRadius.circular(12),
              border:
                  _hasFocus
                      ? Border.all(
                        color: colorScheme.primary,
                        width: TvTheme.focusBorderWidth,
                      )
                      : null,
              boxShadow:
                  _hasFocus
                      ? [
                        BoxShadow(
                          color: colorScheme.primary.withValues(
                            alpha: TvTheme.focusGlowOpacity,
                          ),
                          blurRadius: TvTheme.focusShadowBlurRadius,
                          spreadRadius: TvTheme.focusGlowSpreadRadius,
                        ),
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.2),
                          blurRadius: TvTheme.focusShadowBlurRadius * 2,
                          spreadRadius: 0,
                        ),
                      ]
                      : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconTheme(
                      data: IconThemeData(
                        size: 28,
                        color:
                            widget.isSelected || _hasFocus
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                      ),
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: widget.icon,
                      ),
                    ),
                    const SizedBox(width: TvTheme.spacingSmall),
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: TvTheme.fontSizeButton,
                        color:
                            widget.isSelected || _hasFocus
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                        fontWeight:
                            widget.isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // 选中指示条
                AnimatedContainer(
                  duration: TvTheme.focusAnimationDuration,
                  height: widget.isSelected ? 3 : 0,
                  width: 24,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Auto/Car 模式左侧 Dock 导航组件
///
/// 140px 宽的垂直导航栏，顶部 Logo，下方导航项（图标+标签），
/// 适配车机超宽屏幕，大触控目标（最小 56dp 高度）。
class _AutoDock extends StatelessWidget {
  final List<NavDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  static const double _dockWidth = 140;
  static const double _itemHeight = 60;

  const _AutoDock({
    required this.destinations,
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: _dockWidth,
      color: colorScheme.surfaceContainerLow,
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
                  color: isSelected
                      ? colorScheme.secondaryContainer
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
                              color: isSelected
                                  ? colorScheme.onSecondaryContainer
                                  : colorScheme.onSurfaceVariant,
                            ),
                            child: isSelected
                                ? dest.selectedIcon
                                : dest.icon,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dest.label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isSelected
                                  ? colorScheme.onSecondaryContainer
                                  : colorScheme.onSurfaceVariant,
                              fontWeight: isSelected
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
