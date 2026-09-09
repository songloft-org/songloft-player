import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/plugin_iframe_gate.dart';
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
  final bool allowExtendBody;

  const AdaptiveScaffold({
    super.key,
    required this.body,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.bottomPlayer,
    this.playlistDrawer,
    this.allowExtendBody = true,
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

  /// 挂在当前导航栏（NavigationBar / GlassCapsuleBar）上的 key，用于弹出
  /// 溢出菜单时定位“更多”槽位（songloft-org/songloft#451）。两种导航风格
  /// 互斥渲染，同一 key 不会同时挂两处；仅在有溢出项时挂。
  static final GlobalKey _navBarKey = GlobalKey(
    debugLabel: 'adaptive-scaffold-nav-bar',
  );

  /// Mobile: 底部导航栏布局
  Widget _buildMobileLayout(BuildContext context) {
    final ext = Theme.of(context).extension<SongloftThemeExtension>();
    final useCapsule = ext?.navigationStyle == 'capsule';

    return Scaffold(
      body: body,
      extendBody: useCapsule && allowExtendBody,
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
    final visibleDests =
        hasOverflow ? destinations.sublist(0, _mobileRealSlots) : destinations;
    final barSelectedIndex =
        hasOverflow && currentIndex >= _mobileRealSlots
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
      key: hasOverflow ? _navBarKey : null,
      selectedIndex: barSelectedIndex,
      onDestinationSelected: (index) {
        if (hasOverflow && index == _mobileRealSlots) {
          _showOverflowMenu(context);
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
      key: hasOverflow ? _navBarKey : null,
      selectedIndex: barSelectedIndex,
      onDestinationSelected: (index) {
        if (index < _mobileRealSlots) {
          onDestinationSelected(index);
        } else {
          _showOverflowMenu(context);
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

  /// 弹出溢出导航菜单（songloft-org/songloft#451）。
  ///
  /// 旧实现是 showModalBottomSheet：内容不带滚动，溢出项多时 Column 超出
  /// sheet 最大高度（默认 9/16 屏高）被裁剪，最后一项「设置」落在屏幕底边
  /// 无法点击。现改为自绘浮层 [_OverflowMenuPanel]：底边锚定在底部导航栏
  /// 顶部上方，不遮挡底部 tab；高度超过可用空间时内部滚动。
  ///
  /// Web 端弹出期间挂起插件 iframe 的指针事件：iframe 位于 Flutter canvas
  /// 之上，与菜单重叠区域的点击会被 iframe 截获（见 plugin_iframe_gate.dart）。
  Future<void> _showOverflowMenu(BuildContext context) async {
    final colorScheme = Theme.of(context).colorScheme;
    final overflowDests = destinations.sublist(_mobileRealSlots);
    final navRect = _navBarRect(context);

    setPluginIframePointerEventsSuspended(true);
    try {
      final selected = await showGeneralDialog<int>(
        context: context,
        // 与 PopupMenu 一致：barrier 不变暗，点击空白处关闭。
        barrierColor: Colors.transparent,
        barrierDismissible: true,
        barrierLabel:
            MaterialLocalizations.of(context).modalBarrierDismissLabel,
        transitionDuration: const Duration(milliseconds: 150),
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          return _OverflowMenuPanel(
            destinations: overflowDests,
            baseIndex: _mobileRealSlots,
            currentIndex: currentIndex,
            colorScheme: colorScheme,
            navBarTop: navRect.top,
          );
        },
        transitionBuilder: (
          dialogContext,
          animation,
          secondaryAnimation,
          child,
        ) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
      );
      if (selected != null) {
        onDestinationSelected(selected);
      }
    } finally {
      setPluginIframePointerEventsSuspended(false);
    }
  }

  /// 返回导航栏在 overlay 坐标系中的矩形，用于锚定溢出菜单。
  Rect _navBarRect(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null || !overlay.attached || !overlay.hasSize) {
      // 防御：overlay 不可用（理论不发生，AdaptiveScaffold 必在 Navigator 内），
      // 退回屏幕右下角区域，保证菜单仍可弹出。
      return Rect.fromLTWH(
        size.width * 0.6,
        size.height - 120,
        size.width * 0.4,
        120,
      );
    }

    final navBox = _navBarKey.currentContext?.findRenderObject();
    if (navBox is RenderBox && navBox.attached && navBox.hasSize) {
      final topLeft = navBox.localToGlobal(Offset.zero, ancestor: overlay);
      return topLeft & navBox.size;
    }
    // 防御：导航栏 RenderBox 不可用（点击必然来自导航栏，理论不发生），
    // 退回屏幕右下角区域，保证菜单仍可弹出。
    return Rect.fromLTWH(
      overlay.size.width * 0.6,
      overlay.size.height - 120,
      overlay.size.width * 0.4,
      120,
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

  /// Desktop: 宽侧边导航布局
  Widget _buildDesktopLayout(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final ext = theme.extension<SongloftThemeExtension>();
    final useCapsule = ext?.navigationStyle == 'capsule';

    final bodyColumn = Column(
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
    );

    final sidebarContent = _buildDesktopSidebarContent(
      context,
      theme,
      colorScheme,
      useCapsule ? ext : null,
    );

    if (useCapsule) {
      // 玻璃模式：Stack + BackdropFilter 毛玻璃侧边栏
      return Scaffold(
        body: Stack(
          children: [
            Row(
              children: [
                const SizedBox(width: _desktopSidebarWidth),
                Expanded(child: bodyColumn),
              ],
            ),
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
                      color: ext!.glassFill,
                      border: Border(
                        right: BorderSide(color: ext.glassBorder, width: 0.5),
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: sidebarContent,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 标准模式：原始 Row 布局
    return Scaffold(
      body: Row(
        children: [
          SizedBox(width: _desktopSidebarWidth, child: sidebarContent),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: bodyColumn),
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
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: destinations.length,
            itemBuilder: (context, index) {
              final dest = destinations[index];
              final isSelected = index == currentIndex;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: ListTile(
                  leading: IconTheme(
                    data: IconThemeData(
                      color:
                          isSelected
                              ? (ext?.glassGlow ?? colorScheme.primary)
                              : colorScheme.onSurfaceVariant,
                    ),
                    child: isSelected ? dest.selectedIcon : dest.icon,
                  ),
                  title: Text(
                    dest.label,
                    style: TextStyle(
                      color:
                          isSelected
                              ? (ext?.glassGlow ?? colorScheme.primary)
                              : colorScheme.onSurface,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  selected: isSelected,
                  selectedTileColor:
                      ext != null
                          ? ext.glassGlow.withAlpha(77)
                          : colorScheme.primaryContainer.withValues(alpha: 0.3),
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
    final useCapsule = ext?.navigationStyle == 'capsule';

    final dock = _WidescreenDock(
      destinations: destinations,
      currentIndex: currentIndex,
      onDestinationSelected: onDestinationSelected,
    );

    if (useCapsule) {
      return Scaffold(
        body: Stack(
          children: [
            Row(
              children: [
                const SizedBox(width: _WidescreenDock._dockWidth),
                Expanded(child: body),
                if (playlistDrawer != null) playlistDrawer!,
                if (bottomPlayer != null) bottomPlayer!,
              ],
            ),
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
                      color: ext!.glassFill,
                      border: Border(
                        right: BorderSide(color: ext.glassBorder, width: 0.5),
                      ),
                    ),
                    child: Material(color: Colors.transparent, child: dock),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          dock,
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: body),
          if (playlistDrawer != null) playlistDrawer!,
          if (bottomPlayer != null) bottomPlayer!,
        ],
      ),
    );
  }
}

/// 溢出导航菜单浮层（songloft-org/songloft#451）。
///
/// 底边锚定在底部导航栏顶部上方（留 8dp 间隙），不遮挡底部 tab；高度
/// 超过可用空间时内部滚动（兜底插件极多的场景）。水平贴屏幕右缘，
/// 与「更多」按钮所在的最后一槽对齐。
class _OverflowMenuPanel extends StatelessWidget {
  final List<NavDestination> destinations;
  final int baseIndex;
  final int currentIndex;
  final ColorScheme colorScheme;

  /// 底部导航栏顶边在 overlay 坐标系中的 y 值（菜单底边的锚点）。
  final double navBarTop;

  const _OverflowMenuPanel({
    required this.destinations,
    required this.baseIndex,
    required this.currentIndex,
    required this.colorScheme,
    required this.navBarTop,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // 菜单底边 = 导航栏顶 - 8（不遮挡底部 tab）；顶部不越过状态栏安全区。
    final bottomInset = mq.size.height - navBarTop + 8;
    final maxHeight = math.max(0.0, navBarTop - 8 - (mq.padding.top + 8));
    return Stack(
      children: [
        Positioned(
          right: 8,
          bottom: bottomInset,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: maxHeight,
              maxWidth: mq.size.width - 16,
            ),
            child: Material(
              color: colorScheme.surfaceContainer,
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < destinations.length; i++)
                      _buildItem(context, destinations[i], baseIndex + i),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItem(BuildContext context, NavDestination dest, int index) {
    final isSelected = currentIndex == index;
    final color = isSelected ? colorScheme.primary : colorScheme.onSurface;
    return InkWell(
      onTap: () => Navigator.pop(context, index),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: AlignmentDirectional.centerStart,
        color:
            isSelected
                ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTheme(
              data: IconThemeData(color: color),
              child: isSelected ? dest.selectedIcon : dest.icon,
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                dest.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
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
                  color:
                      isSelected
                          ? (ext?.glassGlow.withAlpha(77) ??
                              colorScheme.secondaryContainer)
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
