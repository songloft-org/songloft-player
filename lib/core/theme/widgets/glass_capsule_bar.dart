import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../app_theme.dart';
import 'liquid_glass_surface.dart';

class GlassCapsuleBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<GlassCapsuleDestination> destinations;
  final bool allowGlass;

  const GlassCapsuleBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.allowGlass = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<SongloftThemeExtension>();
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    final fill = ext?.glassFill ?? theme.colorScheme.surfaceContainer;
    final border = ext?.glassBorder ?? theme.colorScheme.outlineVariant;
    final selectedFill =
        ext?.glassGlowFaint ?? theme.colorScheme.primaryContainer.withAlpha(77);
    final glow = ext?.glassGlow ?? theme.colorScheme.primary;

    if (allowGlass && SongloftGlassScope.useShadersOf(context)) {
      return Padding(
        padding: EdgeInsets.fromLTRB(12, 4, 12, bottomPadding + 8),
        child: GlassTabBar.bottom(
          tabs: [
            for (final dest in destinations)
              GlassTab(
                icon: dest.icon,
                activeIcon: dest.selectedIcon,
                label: dest.label,
                semanticLabel: dest.label,
              ),
          ],
          selectedIndex: selectedIndex,
          onTabSelected: onDestinationSelected,
          barHeight: 56,
          barBorderRadius: 28,
          horizontalPadding: 0,
          verticalPadding: 0,
          spacing: 0,
          iconSize: 22,
          labelFontSize: 10,
          iconLabelSpacing: 2,
          quality: GlassQuality.standard,
          backgroundQuality: GlassQuality.standard,
          settings: songloftGlassSettings(context, blur: 6),
          indicatorColor: selectedFill,
          selectedIconColor: glow,
          selectedLabelColor: glow,
          unselectedIconColor: theme.colorScheme.onSurfaceVariant,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          magnification: 1,
          pressScale: 1.02,
          indicatorExpansion: EdgeInsets.zero,
        ),
      );
    }

    final items = Row(
      children: List.generate(destinations.length, (index) {
        final dest = destinations[index];
        final isSelected = index == selectedIndex;
        return Expanded(
          child: Semantics(
            button: true,
            selected: isSelected,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onDestinationSelected(index),
                borderRadius: BorderRadius.circular(28),
                child: _CapsuleItem(
                  icon: isSelected ? dest.selectedIcon : dest.icon,
                  label: dest.label,
                  isSelected: isSelected,
                  selectedFill: selectedFill,
                  selectedColor: glow,
                  unselectedColor: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        );
      }),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 4, 12, bottomPadding + 8),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: allowGlass ? null : fill.withAlpha(255),
          borderRadius: BorderRadius.circular(28),
          border: allowGlass ? null : Border.all(color: border, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(15),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child:
            allowGlass
                ? LiquidGlassSurface(
                  borderRadius: BorderRadius.circular(28),
                  child: items,
                )
                : items,
      ),
    );
  }
}

class _CapsuleItem extends StatelessWidget {
  final Widget icon;
  final String label;
  final bool isSelected;
  final Color selectedFill;
  final Color selectedColor;
  final Color unselectedColor;

  const _CapsuleItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.selectedFill,
    required this.selectedColor,
    required this.unselectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? selectedColor : unselectedColor;

    return Center(
      child: AnimatedContainer(
        duration:
            GlassAccessibilityData.of(context).reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? selectedFill : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTheme(data: IconThemeData(color: color, size: 22), child: icon),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class GlassCapsuleDestination {
  final String label;
  final Widget icon;
  final Widget selectedIcon;

  const GlassCapsuleDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}
