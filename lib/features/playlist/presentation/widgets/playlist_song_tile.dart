import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/url_helper.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/models/song.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    final coverUrl = song.coverUrl;

    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽手柄（排序模式）
          if (showDragHandle)
            ReorderableDragStartListener(
              index: index - 1,
              child: Icon(
                Icons.drag_handle,
                color: colorScheme.onSurfaceVariant,
              ),
            )
          // 复选框（多选模式）
          else if (showCheckbox)
            SizedBox(
              width: 32,
              child: Checkbox(value: isChecked, onChanged: onCheckChanged),
            )
          // 序号（正常模式）
          else
            SizedBox(
              width: 32,
              child: Text(
                '$index',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(width: 8),
          // 封面
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              width: 48,
              height: 48,
              child:
                  coverUrl != null
                      ? ExcludeSemantics(
                        child: CachedNetworkImage(
                          imageUrl: UrlHelper.buildCoverUrl(coverUrl),
                          fit: BoxFit.cover,
                          placeholder:
                              (context, url) =>
                                  _buildCoverPlaceholder(colorScheme),
                          errorWidget:
                              (context, url, error) =>
                                  _buildCoverPlaceholder(colorScheme),
                        ),
                      )
                      : _buildCoverPlaceholder(colorScheme),
            ),
          ),
        ],
      ),
      title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        song.artist ?? l10n.playlistUnknownArtist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      trailing:
          showTrailing
              ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 时长
                  Text(
                    Formatters.formatDuration(song.duration),
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  // 更多按钮
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    onSelected: (value) {
                      if (value == 'edit') {
                        onEdit?.call();
                      } else if (value == 'remove') {
                        onRemove();
                      } else if (value == 'delete') {
                        onDeleteFromLibrary?.call();
                      }
                    },
                    itemBuilder:
                        (context) => [
                          if (onEdit != null)
                            PopupMenuItem(
                              value: 'edit',
                              child: ListTile(
                                leading: const Icon(Icons.edit),
                                title: Text(l10n.playlistEditAction),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          PopupMenuItem(
                            value: 'remove',
                            child: ListTile(
                              leading: const Icon(Icons.remove_circle_outline),
                              title: Text(l10n.playlistRemoveFromPlaylist),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: ListTile(
                              leading: Icon(
                                Icons.delete_outline,
                                color: colorScheme.error,
                              ),
                              title: Text(
                                l10n.playlistDeleteFromLibrary,
                                style: TextStyle(color: colorScheme.error),
                              ),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                  ),
                ],
              )
              : null,
    );
  }

  Widget _buildCoverPlaceholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.music_note,
        size: 24,
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
      ),
    );
  }
}
