import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/responsive.dart';

class SettingsCategory {
  final IconData icon;
  final String title;
  final String subtitle;

  const SettingsCategory({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

class SettingsMasterDetail extends StatelessWidget {
  final List<SettingsCategory> categories;
  final int selectedIndex;
  final ValueChanged<int> onCategorySelected;
  final IndexedWidgetBuilder contentBuilder;

  /// Optional header widget displayed above the category list (mobile only).
  final Widget? header;

  const SettingsMasterDetail({
    super.key,
    required this.categories,
    required this.selectedIndex,
    required this.onCategorySelected,
    required this.contentBuilder,
    this.header,
  });

  @override
  Widget build(BuildContext context) {
    if (context.isWideScreen && !context.isTv && !context.isAuto) {
      return _buildWideLayout(context);
    }
    return _buildMobileLayout(context);
  }

  Widget _buildMobileLayout(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      itemCount: categories.length + (header != null ? 1 : 0),
      itemBuilder: (context, index) {
        // Render header as the first item
        if (header != null && index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: header!,
          );
        }

        final categoryIndex = header != null ? index - 1 : index;
        final category = categories[categoryIndex];

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Material(
            color: Colors.transparent,
            borderRadius: AppRadius.mdAll,
            child: InkWell(
              borderRadius: AppRadius.mdAll,
              onTap: () => onCategorySelected(categoryIndex),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm + 2,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        category.icon,
                        size: 20,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.title,
                            style: textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            category.subtitle,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWideLayout(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 280,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            itemCount: categories.length + (header != null ? 1 : 0),
            itemBuilder: (context, index) {
              // Render header as the first item in wide layout too
              if (header != null && index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(
                    bottom: AppSpacing.sm,
                    left: AppSpacing.xs,
                    right: AppSpacing.xs,
                  ),
                  child: header!,
                );
              }

              final categoryIndex = header != null ? index - 1 : index;
              final category = categories[categoryIndex];
              final isSelected = categoryIndex == selectedIndex;

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Material(
                  color: isSelected
                      ? colorScheme.secondaryContainer
                      : Colors.transparent,
                  borderRadius: AppRadius.mdAll,
                  child: InkWell(
                    borderRadius: AppRadius.mdAll,
                    onTap: () => onCategorySelected(categoryIndex),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm + 2,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colorScheme.onSecondaryContainer
                                      .withValues(alpha: 0.12)
                                  : colorScheme.surfaceContainerHigh,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              category.icon,
                              size: 20,
                              color: isSelected
                                  ? colorScheme.onSecondaryContainer
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm + 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  category.title,
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : null,
                                    color: isSelected
                                        ? colorScheme.onSecondaryContainer
                                        : null,
                                  ),
                                ),
                                Text(
                                  category.subtitle,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: isSelected
                                        ? colorScheme.onSecondaryContainer
                                            .withValues(alpha: 0.7)
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: contentBuilder(context, selectedIndex),
            ),
          ),
        ),
      ],
    );
  }
}
