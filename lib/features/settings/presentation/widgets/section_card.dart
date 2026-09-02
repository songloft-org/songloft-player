import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_theme.dart';

class SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const SectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group label (small uppercase style)
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.sm + 2,
            bottom: AppSpacing.sm,
          ),
          child: Text(
            title.toUpperCase(),
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        // Card container — light glass
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).extension<SongloftThemeExtension>()?.glassFillStrong
                ?? colorScheme.surfaceContainer,
            borderRadius: AppRadius.lgAll,
            border: Border.all(
              color: Theme.of(context).extension<SongloftThemeExtension>()?.glassBorder
                  ?? colorScheme.outlineVariant,
              width: 0.5,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }
}
