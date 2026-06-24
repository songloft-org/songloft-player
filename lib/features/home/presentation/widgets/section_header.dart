import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/responsive.dart';

/// 首页区域标题组件
///
/// 统一的「标题 + 查看全部」样式，用于歌单区域、电台区域等。
class SectionHeader extends StatelessWidget {
  /// 区域标题
  final String title;

  /// 右侧按钮文字（可选）
  final String? actionText;

  /// 右侧按钮回调（可选）
  final VoidCallback? onAction;

  /// 图标（可选，显示在标题左侧）
  final IconData? icon;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionText,
    this.onAction,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.responsive<double>(
          mobile: AppSpacing.md,
          tablet: AppSpacing.lg,
          desktop: AppSpacing.lg,
        ),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: context.responsive<double>(
                mobile: 20,
                tablet: 22,
                desktop: 24,
              ),
              color: colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Text(
            title,
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: context.responsive<double>(
                mobile: 20,
                tablet: 22,
                desktop: 24,
              ),
            ),
          ),
          const Spacer(),
          if (actionText != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                actionText!,
                style: textTheme.labelMedium?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
