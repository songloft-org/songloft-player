import 'package:flutter/material.dart';

import '../../core/theme/responsive.dart';

/// 多选态工具栏的动作按钮。
///
/// 窄屏（< 600px）只渲染图标，文字退化成 tooltip：多选态现在有 4 个动作
/// （加歌单/管理标签/删除/全选），窄屏全部带文字时 AppBar 会被撑破
/// （360px 宽实测溢出 63px，右侧按钮直接不可点）。宽屏空间充裕，保留文字。
class SelectionActionButton extends StatelessWidget {
  const SelectionActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String label;

  /// 为 null 时按钮禁用（多选态未选中任何歌曲）。
  final VoidCallback? onPressed;

  /// 启用状态下的图标/文字颜色（如删除用 error 色）；禁用时跟随主题默认灰。
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = onPressed == null ? null : color;

    if (context.isMobile) {
      return IconButton(
        icon: Icon(icon, color: tint),
        tooltip: label,
        onPressed: onPressed,
      );
    }

    return TextButton.icon(
      icon: Icon(icon, color: tint),
      label: Text(label, style: TextStyle(color: tint)),
      onPressed: onPressed,
    );
  }
}
