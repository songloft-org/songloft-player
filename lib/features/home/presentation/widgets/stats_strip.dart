import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/responsive.dart';

/// 统计信息条
///
/// Material 3 风格的紧凑统计信息展示，用于首页底部。
/// 使用 primaryContainer 背景色，替代原来的 Card 样式。
class StatsStrip extends StatelessWidget {
  final int normalCount;
  final int radioCount;

  const StatsStrip({
    super.key,
    required this.normalCount,
    required this.radioCount,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.responsive<double>(
          mobile: AppSpacing.md,
          tablet: AppSpacing.lg,
          desktop: AppSpacing.lg,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md + 4,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: AppRadius.lgAll,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _StatChip(
              icon: Icons.queue_music_rounded,
              label: '歌单',
              value: normalCount.toString(),
              color: colorScheme.onPrimaryContainer,
              textTheme: textTheme,
            ),
            _Divider(color: colorScheme.onPrimaryContainer),
            _StatChip(
              icon: Icons.radio_rounded,
              label: '电台',
              value: radioCount.toString(),
              color: colorScheme.onPrimaryContainer,
              textTheme: textTheme,
            ),
            _Divider(color: colorScheme.onPrimaryContainer),
            _StatChip(
              icon: Icons.library_music_rounded,
              label: '总计',
              value: (normalCount + radioCount).toString(),
              color: colorScheme.onPrimaryContainer,
              textTheme: textTheme,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final TextTheme textTheme;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: AppSpacing.sm),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                color: color.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  final Color color;

  const _Divider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      color: color.withValues(alpha: 0.2),
    );
  }
}
