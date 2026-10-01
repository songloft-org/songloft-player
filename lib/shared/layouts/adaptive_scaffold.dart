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

/// 桌面侧边栏的几何与动画常量。
///
/// 展开态与折叠态共用同一套「图标列 + 文字列」骨架，所有位置都由这里的常量决定：
/// 图标中心恒为 `x = 36`、行高恒为 48，折叠动画期间没有任何元素需要重新定位。
const double _desktopSidebarWidth = 240;
const double _desktopSidebarCollapsedWidth = 72;

/// 图标列宽 = 折叠态侧栏宽度，展开态则是「图标 + 文字」的分栏线。
const double _desktopSidebarRailWidth = _desktopSidebarCollapsedWidth;

const double _desktopSidebarItemHeight = 48;
const double _desktopSidebarItemCollapsedInset = 12;
const double _desktopSidebarItemExpandedInset = 8;

/// 文字透明度区间（相对折叠进度）：先把文字淡掉，再让裁切边缘扫过。
///
/// 顺序很重要 —— 文字必须在裁切边缘推过来之前就淡掉。反过来（先裁后淡）会
/// 出现「半截文字挂在裁切线上」的一帧；而如果干脆不淡只靠裁切，长标签的右端
/// 会被边缘推着走，看起来像是在拖拽而不是收缩。
const Interval _sidebarLabelFade = Interval(0.5, 1, curve: Curves.easeOut);

const Duration _sidebarAnimDuration = Duration(milliseconds: 260);
const Curve _sidebarAnimCurve = Curves.easeInOutCubic;

/// 自适应脚手架，根据屏幕尺寸切换布局模式
class AdaptiveScaffold extends StatelessWidget {
  final Widget body;
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavDestination> destinations;
  final Widget? bottomPlayer;
  final Widget? playlistDrawer;
  final bool allowExtendBody;
  final bool isSidebarCollapsed;
  final VoidCallback? onToggleSidebar;

  const AdaptiveScaffold({
    super.key,
    required this.body,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.bottomPlayer,
    this.playlistDrawer,
    this.allowExtendBody = true,
    this.isSidebarCollapsed = false,
    this.onToggleSidebar,
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
  ///
  /// 胶囊模式下底部播放器是**浮起**的胶囊条，由 [_overlayBottomPlayer] 叠在内容
  /// 之上、横跨「内容列 + 播放列表抽屉」整宽；标准模式仍是占布局高度的底栏。
  Widget _buildTabletLayout(BuildContext context) {
    final useCapsule =
        Theme.of(
          context,
        ).extension<SongloftThemeExtension>()?.navigationStyle ==
        'capsule';

    final content = Row(
      children: [
        Expanded(child: body),
        if (playlistDrawer != null) playlistDrawer!,
      ],
    );

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
            child:
                useCapsule
                    ? _overlayBottomPlayer(content, bottomPlayer)
                    : Column(
                      children: [
                        Expanded(child: content),
                        if (bottomPlayer != null) bottomPlayer!,
                      ],
                    ),
          ),
        ],
      ),
    );
  }

  /// 把底部播放器浮在内容之上（胶囊模式）。
  ///
  /// 浮起后播放器不占布局高度，因此必须用 `Stack` 承载：`Column` 本身没有
  /// RenderObject，`BackdropFilter` 落在它下面会命中「无 backdrop 可采」的优化分支
  /// 而静默失效，毛玻璃就白做了。内容则按 `ResponsiveContext.navScrollInset`
  /// （胶囊档 84）预留底部滚动间距。
  static Widget _overlayBottomPlayer(Widget content, Widget? bottomPlayer) {
    if (bottomPlayer == null) return content;

    return Stack(
      children: [
        Positioned.fill(child: content),
        Positioned(left: 0, right: 0, bottom: 0, child: bottomPlayer),
      ],
    );
  }

  /// Desktop: 宽侧边导航布局（支持折叠）
  Widget _buildDesktopLayout(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final ext = theme.extension<SongloftThemeExtension>();
    final useCapsule = ext?.navigationStyle == 'capsule';
    final collapsed = isSidebarCollapsed;

    final content = Row(
      children: [
        Expanded(child: body),
        if (playlistDrawer != null) playlistDrawer!,
      ],
    );

    final bodyColumn = Column(
      children: [
        Expanded(child: content),
        if (bottomPlayer != null) bottomPlayer!,
      ],
    );

    final overlayContent = _overlayBottomPlayer(content, bottomPlayer);

    return Scaffold(
      // 折叠动画只有一条时间轴：侧栏宽度、裁切边缘、文字透明度、选中胶囊宽度
      // 全部由同一个 progress 派生，不会出现多套隐式动画各自为政导致的错帧。
      body: _SidebarCollapseAnimator(
        collapsed: collapsed,
        duration: _sidebarAnimDuration,
        curve: _sidebarAnimCurve,
        builder: (context, progress) {
          final sidebarWidth =
              lerpDouble(
                _desktopSidebarCollapsedWidth,
                _desktopSidebarWidth,
                progress,
              )!;
          final sidebar = _clipSidebarAtWidth(
            width: sidebarWidth,
            child: _buildDesktopSidebarContent(
              context,
              theme,
              colorScheme,
              useCapsule ? ext : null,
              collapsed,
              progress,
            ),
          );

          if (useCapsule) {
            return Stack(
              children: [
                Row(
                  children: [
                    SizedBox(width: sidebarWidth),
                    Expanded(child: overlayContent),
                  ],
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: sidebarWidth,
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                      child: Container(
                        decoration: BoxDecoration(
                          color: ext!.glassFill,
                          border: Border(
                            right: BorderSide(
                              color: ext.glassBorder,
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: sidebar,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return Row(
            children: [
              sidebar,
              const VerticalDivider(thickness: 1, width: 1),
              Expanded(child: bodyColumn),
            ],
          );
        },
      ),
    );
  }

  /// 把侧栏内容按展开宽度定宽布局，再裁切到 [width]。
  ///
  /// 这是消除抖动的关键：内容**不参与宽度动画**，整个动画期间拿到的约束保持不变，
  /// 一帧都不会触发内部重排，折叠只是裁切边缘在扫动。
  ///
  /// 旧写法把内容直接交给动画中的宽度去 layout：折叠的瞬间图标先跳到容器正中
  /// （240 / 2 = 120）再滑回 36，展开的瞬间整列文字被挤进 72px 里重新折行、
  /// 行高来回跳变（还会触发 RenderFlex overflow）——就是肉眼看到的抖动。
  static Widget _clipSidebarAtWidth({
    required double width,
    required Widget child,
  }) {
    return SizedBox(
      key: const ValueKey('desktop-sidebar-viewport'),
      width: width,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          minWidth: _desktopSidebarWidth,
          maxWidth: _desktopSidebarWidth,
          child: child,
        ),
      ),
    );
  }

  /// 侧栏内容（展开态骨架）：展开与折叠**共用同一棵子树**，[progress] 只驱动
  /// 文字透明度与选中胶囊宽度（0 = 完全折叠，1 = 完全展开）；[collapsed] 仅用于
  /// 决定是否挂悬浮提示，不参与布局。
  Widget _buildDesktopSidebarContent(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    SongloftThemeExtension? ext,
    bool collapsed,
    double progress,
  ) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        // 头部 logo 与导航图标共用同一条图标列，折叠时同样不位移。
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Row(
            children: [
              SizedBox(
                width: _desktopSidebarRailWidth,
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/icons/app_icon.png',
                      width: 32,
                      height: 32,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _SidebarLabel(
                  progress: progress,
                  child: Text(
                    'Songloft',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
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
              final accent = ext?.glassGlow ?? colorScheme.primary;
              return _DesktopSidebarItem(
                progress: progress,
                icon: isSelected ? dest.selectedIcon : dest.icon,
                iconColor: isSelected ? accent : colorScheme.onSurfaceVariant,
                label: dest.label,
                labelColor: isSelected ? accent : colorScheme.onSurface,
                labelWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                highlightColor:
                    isSelected
                        ? (ext != null
                            ? ext.glassGlow.withAlpha(77)
                            : colorScheme.primaryContainer.withValues(
                              alpha: 0.3,
                            ))
                        : null,
                // 只有折叠态（只剩图标）才需要悬浮提示。
                tooltip: collapsed ? dest.label : null,
                onTap: () => onDestinationSelected(index),
              );
            },
          ),
        ),
        if (onToggleSidebar != null) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _DesktopSidebarItem(
              progress: progress,
              // 双箭头绕中心转 180°：展开态朝左（收起），折叠态朝右（展开）。
              icon: Transform.rotate(
                angle: (1 - progress) * math.pi,
                child: const Icon(Icons.keyboard_double_arrow_left, size: 20),
              ),
              iconColor: colorScheme.onSurfaceVariant,
              // 文案跟着动画进度切换：切换那一刻文字已淡到 0，看不到突变。
              label:
                  progress >= 0.5 ? l10n.collapseSidebar : l10n.expandSidebar,
              labelColor: colorScheme.onSurfaceVariant,
              labelFontSize: 13,
              tooltip: collapsed ? l10n.expandSidebar : null,
              onTap: onToggleSidebar,
            ),
          ),
        ],
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

/// 折叠时淡出的侧栏文字：透明度只在进度过半后才抬起来（见 [_sidebarLabelFade]），
/// 保证文字一定在裁切边缘扫到它之前就消失。
class _SidebarLabel extends StatelessWidget {
  const _SidebarLabel({required this.progress, required this.child});

  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Opacity(opacity: _sidebarLabelFade.transform(progress), child: child);
}

/// 按需套一层 [Tooltip]：不需要（展开态）时直接返回 child，避免多出一个
/// 无意义的 hover 层。
Widget _maybeTooltip({required String? message, required Widget child}) {
  if (message == null || message.isEmpty) return child;
  return Tooltip(
    message: message,
    preferBelow: false,
    waitDuration: const Duration(milliseconds: 500),
    child: child,
  );
}

/// 侧栏折叠动画的唯一时间轴。
///
/// 侧栏宽度、裁切边缘、文字透明度、选中胶囊宽度全部由同一个 [progress]
/// （0 = 完全折叠，1 = 完全展开）派生并同步推进；中途反向切换时从当前值继续
/// （`animateTo`），不会跳回起点，也不会像多个隐式动画那样互相错帧。
class _SidebarCollapseAnimator extends StatefulWidget {
  const _SidebarCollapseAnimator({
    required this.collapsed,
    required this.duration,
    required this.curve,
    required this.builder,
  });

  final bool collapsed;
  final Duration duration;
  final Curve curve;
  final Widget Function(BuildContext context, double progress) builder;

  @override
  State<_SidebarCollapseAnimator> createState() =>
      _SidebarCollapseAnimatorState();
}

class _SidebarCollapseAnimatorState extends State<_SidebarCollapseAnimator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.collapsed ? 0 : 1,
  );

  late final CurvedAnimation _progress = CurvedAnimation(
    parent: _controller,
    curve: widget.curve,
  );

  @override
  void didUpdateWidget(covariant _SidebarCollapseAnimator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }
    if (widget.collapsed != oldWidget.collapsed) {
      _controller.animateTo(widget.collapsed ? 0 : 1);
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, _) => widget.builder(context, _progress.value),
    );
  }
}

/// 侧栏导航项：展开态与折叠态**共用同一棵子树**，[progress] 只改两样东西 ——
/// 选中胶囊的宽度、文字的透明度。
///
/// 关键约束（也就是抖动消失的原因）：
/// - 图标槽固定 [_desktopSidebarRailWidth] 宽并左对齐，图标中心恒为 x = 36，
///   折叠前后不产生任何位移（旧实现会先跳到渲染宽度正中再滑回来）；
/// - 行高固定 [_desktopSidebarItemHeight]，折叠前后每行的纵向位置一致
///   （旧实现展开态用 ListTile、折叠态用 48 高容器，行高不同 → 整列上下跳）；
/// - 胶囊宽度在 48（折叠）与 224（展开）之间插值，任何一帧都完整落在可见宽度内，
///   不会被裁切边缘切掉；
/// - 文字只做淡入淡出，位置与宽度恒定，不参与重排。
class _DesktopSidebarItem extends StatelessWidget {
  const _DesktopSidebarItem({
    required this.progress,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.labelColor,
    required this.onTap,
    this.labelWeight,
    this.labelFontSize,
    this.highlightColor,
    this.tooltip,
  });

  /// 0 = 完全折叠，1 = 完全展开。
  final double progress;
  final Widget icon;
  final Color iconColor;
  final String label;
  final Color labelColor;
  final VoidCallback? onTap;
  final FontWeight? labelWeight;
  final double? labelFontSize;
  final Color? highlightColor;

  /// 折叠态（只剩图标）时的悬浮提示；展开态传 null，不额外套 Tooltip 层。
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final pillLeft =
        lerpDouble(
          _desktopSidebarItemCollapsedInset,
          _desktopSidebarItemExpandedInset,
          progress,
        )!;
    final pillWidth =
        lerpDouble(
          _desktopSidebarItemHeight,
          _desktopSidebarWidth - _desktopSidebarItemExpandedInset * 2,
          progress,
        )!;
    final borderRadius = BorderRadius.circular(12);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: SizedBox(
        height: _desktopSidebarItemHeight,
        child: Stack(
          children: [
            Positioned(
              left: pillLeft,
              top: 0,
              bottom: 0,
              width: pillWidth,
              child: _maybeTooltip(
                message: tooltip,
                // 提示锚在胶囊上（折叠态胶囊即图标方块）。
                child: Material(
                  color: highlightColor ?? Colors.transparent,
                  borderRadius: borderRadius,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    borderRadius: borderRadius,
                    onTap: onTap,
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
            // 图标与文字只负责绘制，不接收指针事件，点击落到下层胶囊的 InkWell。
            Positioned.fill(
              child: IgnorePointer(
                child: Row(
                  children: [
                    SizedBox(
                      width: _desktopSidebarRailWidth,
                      child: Center(
                        child: IconTheme(
                          data: IconThemeData(color: iconColor),
                          child: icon,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _SidebarLabel(
                        progress: progress,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: Text(
                            label,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: labelColor,
                              fontSize: labelFontSize,
                              fontWeight: labelWeight,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
