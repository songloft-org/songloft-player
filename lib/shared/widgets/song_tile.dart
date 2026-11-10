import 'package:flutter/material.dart';

import '../../core/theme/app_dimensions.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../models/song.dart';
import 'browse_card.dart' show BrowseCardAction;
import 'cover_image.dart';
import 'favorite_button.dart';
import 'scrolling_text.dart';

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

  /// 序号上方的浏览提示（如歌名拼音首字母），不改变歌曲标题。
  final String? indexLabel;

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

  /// 追加到副标题（艺术家）后的补充信息，形如「艺术家 · 07-29 21:30」。
  /// 为空时副标题保持只显示艺术家。
  final String? subtitleSuffix;

  final IconData placeholderIcon;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const SongTile({
    super.key,
    required this.song,
    this.index = 0,
    this.indexLabel,
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
    this.subtitleSuffix,
    this.placeholderIcon = Icons.music_note,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.only(left: 8, right: 4),
      minLeadingWidth: 24,
      horizontalTitleGap: 8,
      onTap: onTap,
      onLongPress: onLongPress,
      tileColor: isCurrentSong ? colorScheme.secondaryContainer : null,
      shape:
          isCurrentSong
              ? RoundedRectangleBorder(borderRadius: AppRadius.mdAll)
              : null,
      leading: _buildLeading(context),
      title: ScrollingText(
        text: song.title,
        style:
            isCurrentSong
                ? TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                )
                : null,
      ),
      subtitle: Text(
        _subtitleText(l10n),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
      trailing: _buildTrailing(context),
    );
  }

  String _subtitleText(AppLocalizations l10n) {
    final artist = song.artist ?? l10n.libraryUnknownArtist;
    final suffix = [
      if (showDuration) Formatters.formatDuration(song.duration),
      if (subtitleSuffix?.isNotEmpty == true) subtitleSuffix!,
    ].join(' · ');
    if (suffix.isEmpty) return artist;
    // artist 可能是空串而非 null（后端该列 NOT NULL DEFAULT ''），
    // 此时不能拼分隔符，否则副标题变成前导的 " · 07-30 01:23"。
    if (artist.isEmpty) return suffix;
    return '$artist · $suffix';
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
          width: 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (indexLabel != null)
                Text(
                  indexLabel!,
                  style: textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              Text(
                '$index',
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
                style: (indexLabel == null
                        ? textTheme.bodyMedium
                        : textTheme.labelSmall)
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
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
    final children = <Widget>[
      if (showFavorite)
        SizedBox(
          width: 44,
          height: 44,
          child: FavoriteButton(songId: song.id, songType: song.type, size: 20),
        ),
      if (menuActions.isNotEmpty)
        PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          style: IconButton.styleFrom(
            minimumSize: const Size(44, 44),
            fixedSize: const Size(44, 44),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: Icon(Icons.more_vert, color: colorScheme.onSurfaceVariant),
          onSelected: (value) {
            for (final a in menuActions) {
              if (a.value == value) {
                a.onTap();
                return;
              }
            }
          },
          itemBuilder:
              (context) => [
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
                        style:
                            a.destructive
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
