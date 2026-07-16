import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/browse_card.dart';
import '../../domain/playlist.dart';

/// 把 [Playlist] 领域字段适配到通用 [BrowseCard] 的零件（标签 chips / 类型徽标 / 更多菜单），
/// 供 PlaylistCard（grid）与 PlaylistListItem（list）共用，避免两处重复。

/// 电台类型徽标；非电台返回 null。
Widget? playlistTypeBadge(BuildContext context, Playlist playlist) {
  if (playlist.type != 'radio') return null;
  final colorScheme = Theme.of(context).colorScheme;
  final textTheme = Theme.of(context).textTheme;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: colorScheme.secondary,
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
    child: Text(
      AppLocalizations.of(context).songTypeRadio,
      style: textTheme.labelSmall?.copyWith(color: colorScheme.onSecondary),
    ),
  );
}

/// 歌单标签行（内置 / 自动 / 隐藏等）。
List<Widget> playlistLabelChips(BuildContext context, Playlist playlist) {
  return playlist.labels.map((label) => _labelChip(context, label)).toList();
}

Widget _labelChip(BuildContext context, String label) {
  final colorScheme = Theme.of(context).colorScheme;
  final textTheme = Theme.of(context).textTheme;
  final l10n = AppLocalizations.of(context);

  String displayLabel;
  Color backgroundColor;
  switch (label) {
    case 'built_in':
      displayLabel = l10n.playlistLabelBuiltIn;
      backgroundColor = colorScheme.primaryContainer;
      break;
    case 'auto_created':
      displayLabel = l10n.playlistLabelAuto;
      backgroundColor = colorScheme.secondaryContainer;
      break;
    case 'hidden':
      displayLabel = l10n.playlistLabelHidden;
      backgroundColor = colorScheme.errorContainer;
      break;
    default:
      displayLabel = label;
      backgroundColor = colorScheme.tertiaryContainer;
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      displayLabel,
      style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
    ),
  );
}

/// 歌单「更多」菜单项（编辑 / 显隐 / 删除），按内置与回调可用性裁剪。
List<BrowseCardAction> playlistMenuActions({
  required BuildContext context,
  required Playlist playlist,
  VoidCallback? onEdit,
  VoidCallback? onToggleVisibility,
  VoidCallback? onDelete,
}) {
  final l10n = AppLocalizations.of(context);
  return [
    if (onEdit != null)
      BrowseCardAction(
        value: 'edit',
        icon: Icons.edit,
        label: l10n.playlistEditAction,
        onTap: onEdit,
      ),
    if (onToggleVisibility != null && !playlist.isBuiltIn)
      BrowseCardAction(
        value: 'toggle_visibility',
        icon: playlist.isHidden ? Icons.visibility : Icons.visibility_off,
        label: playlist.isHidden ? l10n.playlistUnhide : l10n.playlistHide,
        onTap: onToggleVisibility,
      ),
    if (onDelete != null && !playlist.isBuiltIn)
      BrowseCardAction(
        value: 'delete',
        icon: Icons.delete,
        label: l10n.commonDelete,
        onTap: onDelete,
        destructive: true,
      ),
  ];
}
