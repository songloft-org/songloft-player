import 'package:flutter/material.dart';

import '../../core/theme/app_dimensions.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../models/song.dart';
import 'browse_card.dart' show BrowseCardAction;
import 'cover_image.dart';
import 'favorite_button.dart';

/// 通用歌曲行（ListTile 形态）：封面 + 标题 + 艺术家 + 可配置 leading / trailing。
///
/// leading 组合：可选 拖拽手柄 / 复选框 / 序号 前缀 + 可选封面；
/// trailing：可选 收藏按钮 + 可选时长 + 可选「更多」菜单（[BrowseCardAction] 列表）。
/// 曲库移动端行与歌单详情歌曲行共用它；曲库桌面「表格行」为库特有布局，仍在
/// SongListTile 内单独实现。
class SongTile extends StatelessWidget {
  final Song song;

  /// 展示用序号（1-based），showIndex 时显示。
  final int index;

  final bool showCover;
  final bool showIndex;

  final bool showDragHandle;

  /// ReorderableListView 拖拽手柄索引（0-based）。
  final int? dragIndex;

  final bool showCheckbox;
  final bool isChecked;
  final ValueChanged<bool?>? onCheckChanged;

  final bool isCurrentSong;

  final bool showFavorite;
  final bool showDuration;
  final List<BrowseCardAction> menuActions;

  final IconData placeholderIcon;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const SongTile({
    super.key,
    required this.song,
    this.index = 0,
    this.showCover = true,
    this.showIndex = false,
    this.showDragHandle = false,
    this.dragIndex,
    this.showCheckbox = false,
    this.isChecked = false,
    this.onCheckChanged,
    this.isCurrentSong = false,
    this.showFavorite = false,
    this.showDuration = false,
    this.menuActions = const [],
    this.placeholderIcon = Icons.music_note,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      tileColor: isCurrentSong ? colorScheme.secondaryContainer : null,
      shape: isCurrentSong
          ? RoundedRectangleBorder(borderRadius: AppRadius.mdAll)
          : null,
      leading: _buildLeading(context),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: isCurrentSong
            ? TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              )
            : null,
      ),
      subtitle: Text(
        song.artist ?? l10n.libraryUnknownArtist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
      trailing: _buildTrailing(context),
    );
  }

  Widget? _buildLeading(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final prefix = <Widget>[];
    if (showDragHandle) {
      prefix.add(
        ReorderableDragStartListener(
          index: dragIndex ?? 0,
          child: Icon(Icons.drag_handle, color: colorScheme.onSurfaceVariant),
        ),
      );
    } else if (showCheckbox) {
      prefix.add(
        SizedBox(
          width: 32,
          child: Checkbox(value: isChecked, onChanged: onCheckChanged),
        ),
      );
    } else if (showIndex) {
      prefix.add(
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
      );
    }

    if (!showCover) {
      if (prefix.isEmpty) return null;
      return Row(mainAxisSize: MainAxisSize.min, children: prefix);
    }

    final cover = CoverImage(
      coverUrl: song.coverUrl,
      size: 48,
      borderRadius: AppRadius.sm,
      placeholderIcon: placeholderIcon,
    );

    if (prefix.isEmpty) return cover;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [...prefix, const SizedBox(width: 8), cover],
    );
  }

  Widget? _buildTrailing(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final children = <Widget>[
      if (showFavorite)
        FavoriteButton(songId: song.id, songType: song.type, size: 20),
      if (showDuration)
        Text(
          Formatters.formatDuration(song.duration),
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      if (menuActions.isNotEmpty)
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: colorScheme.onSurfaceVariant),
          onSelected: (value) {
            for (final a in menuActions) {
              if (a.value == value) {
                a.onTap();
                return;
              }
            }
          },
          itemBuilder: (context) => [
            for (final a in menuActions)
              PopupMenuItem<String>(
                value: a.value,
                child: ListTile(
                  leading: Icon(
                    a.icon,
                    color: a.destructive ? colorScheme.error : null,
                  ),
                  title: Text(
                    a.label,
                    style: a.destructive
                        ? TextStyle(color: colorScheme.error)
                        : null,
                  ),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
          ],
        ),
    ];

    if (children.isEmpty) return null;
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }
}
