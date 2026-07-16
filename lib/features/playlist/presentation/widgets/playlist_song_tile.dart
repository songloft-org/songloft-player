import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/models/song.dart';
import '../../../../shared/widgets/browse_card.dart' show BrowseCardAction;
import '../../../../shared/widgets/song_tile.dart';

/// 歌单详情歌曲行：通用 [SongTile] 的歌单适配封装（序号/拖拽/复选 + 编辑/移除/删除菜单）。
class PlaylistSongTile extends StatelessWidget {
  final Song song;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final VoidCallback? onDeleteFromLibrary;
  final VoidCallback? onEdit;
  final VoidCallback? onLongPress;

  /// 是否显示拖拽手柄（排序模式）
  final bool showDragHandle;

  /// 是否显示复选框（多选模式）
  final bool showCheckbox;

  /// 复选框是否选中
  final bool isChecked;

  /// 复选框状态变化回调
  final ValueChanged<bool?>? onCheckChanged;

  /// 是否显示尾部操作按钮（时长 + 更多菜单）
  final bool showTrailing;

  const PlaylistSongTile({
    super.key,
    required this.song,
    required this.index,
    required this.onTap,
    required this.onRemove,
    this.onDeleteFromLibrary,
    this.onEdit,
    this.onLongPress,
    this.showDragHandle = false,
    this.showCheckbox = false,
    this.isChecked = false,
    this.onCheckChanged,
    this.showTrailing = true,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final actions = <BrowseCardAction>[
      if (showTrailing && onEdit != null)
        BrowseCardAction(
          value: 'edit',
          icon: Icons.edit,
          label: l10n.playlistEditAction,
          onTap: onEdit!,
        ),
      if (showTrailing)
        BrowseCardAction(
          value: 'remove',
          icon: Icons.remove_circle_outline,
          label: l10n.playlistRemoveFromPlaylist,
          onTap: onRemove,
        ),
      if (showTrailing && onDeleteFromLibrary != null)
        BrowseCardAction(
          value: 'delete',
          icon: Icons.delete_outline,
          label: l10n.playlistDeleteFromLibrary,
          onTap: onDeleteFromLibrary!,
          destructive: true,
        ),
    ];

    return SongTile(
      song: song,
      index: index,
      showIndex: !showDragHandle && !showCheckbox,
      showDragHandle: showDragHandle,
      dragIndex: index - 1,
      showCheckbox: showCheckbox,
      isChecked: isChecked,
      onCheckChanged: onCheckChanged,
      showDuration: showTrailing,
      menuActions: actions,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}
