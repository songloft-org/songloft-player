import 'package:flutter/material.dart';

import '../app_theme.dart';

class GlassCapsuleBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<GlassCapsuleDestination> destinations;

  const GlassCapsuleBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<SongloftThemeExtension>();
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    final fill = ext?.glassFill ?? theme.colorScheme.surfaceContainer;
    final border = ext?.glassBorder ?? theme.colorScheme.outlineVariant;
    final selectedFill = ext?.glassGlowFaint ??
        theme.colorScheme.primaryContainer.withAlpha(77);
    final glow = ext?.glassGlow ?? theme.colorScheme.primary;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 4, 12, bottomPadding + 8),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: border, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(15),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: List.generate(destinations.length, (index) {
            final dest = destinations[index];
            final isSelected = index == selectedIndex;
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onDestinationSelected(index),
                child: _CapsuleItem(
                  icon: isSelected ? dest.selectedIcon : dest.icon,
                  label: dest.label,
                  isSelected: isSelected,
                  selectedFill: selectedFill,
                  selectedColor: glow,
                  unselectedColor: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }),
        ),
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
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? selectedFill : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTheme(
              data: IconThemeData(color: color, size: 22),
              child: icon,
            ),
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
