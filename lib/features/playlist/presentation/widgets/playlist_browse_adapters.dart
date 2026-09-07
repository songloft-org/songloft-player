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

/// 歌单标签行（置顶 / 网络 / 内置 / 自动 / 隐藏等）。置顶与「网络」都不是 labels 数组的
/// 一员（分别来自 pinned_at 与 remote_count 字段），故单独判断后拼在最前面，与其余标签
/// 同款式渲染。
///
/// 「网络」徽标**只标网络、不标本地**：本地是绝大多数歌单的默认预期，给每张卡都挂一个
/// 「本地」chip 只是噪音；需要区分的是混在里面的少数网络歌单（songloft-org/songloft#445）。
/// 电台歌单已有独立的电台 typeBadge（见 [playlistTypeBadge]），不再叠加来源徽标。
List<Widget> playlistLabelChips(BuildContext context, Playlist playlist) {
  return [
    if (playlist.isPinned) _pinnedChip(context),
    if (playlist.type != 'radio' && playlist.hasRemoteSongs)
      _remoteChip(context),
    ...playlist.labels.map((label) => _labelChip(context, label)),
  ];
}

Widget _remoteChip(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  final textTheme = Theme.of(context).textTheme;
  final l10n = AppLocalizations.of(context);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: colorScheme.tertiaryContainer,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      l10n.playlistLabelRemote,
      style: textTheme.labelSmall?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

Widget _pinnedChip(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  final textTheme = Theme.of(context).textTheme;
  final l10n = AppLocalizations.of(context);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      l10n.playlistLabelPinned,
      style: textTheme.labelSmall?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
    ),
  );
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
      style: textTheme.labelSmall?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

/// 歌单「更多」菜单项（编辑 / 显隐 / 删除），按内置与回调可用性裁剪。
List<BrowseCardAction> playlistMenuActions({
  required BuildContext context,
  required Playlist playlist,
  VoidCallback? onEdit,
  VoidCallback? onToggleVisibility,
  VoidCallback? onTogglePin,
  VoidCallback? onDelete,
}) {
  final l10n = AppLocalizations.of(context);
  return [
    if (onTogglePin != null)
      BrowseCardAction(
        value: 'toggle_pin',
        icon: playlist.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
        label: playlist.isPinned ? l10n.playlistUnpin : l10n.playlistPin,
        onTap: onTogglePin,
      ),
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
