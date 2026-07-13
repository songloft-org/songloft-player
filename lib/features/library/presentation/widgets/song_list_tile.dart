import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/constants.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/responsive.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/song.dart';
import '../../../../shared/widgets/cover_image.dart';
import '../../../../shared/widgets/favorite_button.dart';

/// 桌面端「操作按钮」列宽度。tile 内的按钮区与列表表头占位需保持一致，
/// 否则表头与行的操作列对不齐；宽度需容纳 5 个紧凑按钮（play/收藏/编辑/加歌单/删除）。
const double kDesktopActionsWidth = 180;

/// 歌曲列表项组件
class SongListTile extends ConsumerWidget {
  final Song song;
  final int index;
  final bool isSelected;
  final bool isSelectionMode;
  final bool isNarrow; // 窄屏模式（隐藏专辑列）
  final bool isCurrentSong; // 当前正在播放的歌曲
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSelect;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onAddToPlaylist;

  const SongListTile({
    super.key,
    required this.song,
    required this.index,
    this.isSelected = false,
    this.isSelectionMode = false,
    this.isNarrow = false,
    this.isCurrentSong = false,
    this.onTap,
    this.onLongPress,
    this.onSelect,
    this.onDelete,
    this.onEdit,
    this.onAddToPlaylist,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 使用实际可用宽度判断，而非屏幕宽度，避免在窄容器中溢出
        if (context.isMobile ||
            constraints.maxWidth < ResponsiveBreakpoints.tablet) {
          return _buildMobileLayout(context);
        } else {
          return _buildDesktopLayout(context);
        }
      },
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final coverUrl = song.coverUrl;

    return ListTile(
      tileColor: isCurrentSong ? colorScheme.secondaryContainer : null,
      shape: isCurrentSong
          ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
          : null,
      leading:
          isSelectionMode
              ? Checkbox(value: isSelected, onChanged: (_) => onSelect?.call())
              : _buildCoverImage(coverUrl, 48),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: isCurrentSong
            ? TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w600)
            : null,
      ),
      subtitle: Text(
        song.artist ?? AppLocalizations.of(context).libraryUnknownArtist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
      trailing: _buildTrailingActions(context),
      onTap: isSelectionMode ? onSelect : onTap,
      onLongPress: isSelectionMode ? null : onLongPress,
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final coverUrl = song.coverUrl;

    return InkWell(
      onTap: isSelectionMode ? onSelect : onTap,
      onLongPress: isSelectionMode ? null : onLongPress,
      hoverColor: colorScheme.surfaceContainerHigh,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isCurrentSong ? colorScheme.secondaryContainer : null,
          borderRadius: isCurrentSong ? BorderRadius.circular(12) : null,
          border: isCurrentSong
              ? null
              : Border(
                  bottom: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    width: 0.5,
                  ),
                ),
        ),
        child: Row(
          children: [
            // 多选复选框
            if (isSelectionMode)
              Checkbox(value: isSelected, onChanged: (_) => onSelect?.call())
            else
              SizedBox(
                width: 40,
                child: isCurrentSong
                    ? Icon(
                        Icons.equalizer_rounded,
                        size: 20,
                        color: colorScheme.primary,
                      )
                    : Text(
                        '${index + 1}',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
              ),
            const SizedBox(width: 12),
            // 封面
            _buildCoverImage(coverUrl, 40),
            const SizedBox(width: 12),
            // 标题
            Expanded(
              flex: 3,
              child: Text(
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
            ),
            const SizedBox(width: 16),
            // 艺术家
            Expanded(
              flex: 2,
              child: Text(
                song.artist ?? AppLocalizations.of(context).libraryUnknownArtist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(width: 16),
            // 专辑（窄屏隐藏）
            if (!isNarrow) ...[
              Expanded(
                flex: 2,
                child: Text(
                  song.album ?? AppLocalizations.of(context).libraryUnknownAlbum,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 16),
            ],
            // 类型标签
            SizedBox(width: 60, child: _buildTypeChip(context)),
            const SizedBox(width: 16),
            // 时长
            SizedBox(
              width: 60,
              child: Text(
                Formatters.formatDuration(song.duration),
                style: TextStyle(color: colorScheme.onSurfaceVariant),
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 8),
            // 操作按钮
            SizedBox(
              width: kDesktopActionsWidth,
              child: _buildDesktopActions(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverImage(String? coverUrl, double size) {
    return CoverImage(
      coverUrl: coverUrl,
      size: size,
      borderRadius: AppRadius.sm,
      placeholderIcon: _getTypeIcon(),
    );
  }

  IconData _getTypeIcon() {
    switch (song.type) {
      case AppConstants.songTypeRadio:
        return Icons.radio;
      case AppConstants.songTypeRemote:
        return Icons.cloud;
      default:
        return Icons.music_note;
    }
  }

  Widget _buildTypeChip(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    String label;
    Color color;

    switch (song.type) {
      case AppConstants.songTypeRadio:
        label = l10n.songTypeRadio;
        color = colorScheme.tertiary;
        break;
      case AppConstants.songTypeRemote:
        label = l10n.songTypeRemote;
        color = colorScheme.secondary;
        break;
      default:
        label = l10n.songTypeLocal;
        color = colorScheme.primary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: color),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTrailingActions(BuildContext context) {
    if (isSelectionMode) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FavoriteButton(songId: song.id, songType: song.type, size: 20),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            switch (value) {
              case 'play':
                onTap?.call();
                break;
              case 'edit':
                onEdit?.call();
                break;
              case 'add_to_playlist':
                onAddToPlaylist?.call();
                break;
              case 'delete':
                onDelete?.call();
                break;
            }
          },
          itemBuilder:
              (context) => [
                PopupMenuItem(
                  value: 'play',
                  child: ListTile(
                    leading: const Icon(Icons.play_arrow),
                    title: Text(l10n.libraryPlay),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: const Icon(Icons.edit),
                    title: Text(l10n.libraryEdit),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'add_to_playlist',
                  child: ListTile(
                    leading: const Icon(Icons.playlist_add),
                    title: Text(l10n.addToPlaylist),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: const Icon(Icons.delete),
                    title: Text(l10n.commonDelete),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
        ),
      ],
    );
  }

  Widget _buildDesktopActions(BuildContext context) {
    if (isSelectionMode) return const SizedBox(width: kDesktopActionsWidth);

    final l10n = AppLocalizations.of(context);

    // 紧凑化：默认 IconButton 触摸目标 48px，5 个按钮会撑破操作列导致右侧按钮
    // （编辑/添加/删除）被裁剪不可见。shrinkWrap + compact 让按钮回落到 minWidth。
    const constraints = BoxConstraints(minWidth: 28, minHeight: 28);

    Widget actionButton({
      required IconData icon,
      required String tooltip,
      required VoidCallback? onPressed,
    }) {
      return IconButton(
        icon: Icon(icon),
        tooltip: tooltip,
        onPressed: onPressed,
        iconSize: 20,
        padding: EdgeInsets.zero,
        constraints: constraints,
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        actionButton(
          icon: Icons.play_arrow,
          tooltip: l10n.libraryPlay,
          onPressed: onTap,
        ),
        FavoriteButton(songId: song.id, songType: song.type, size: 20),
        actionButton(icon: Icons.edit, tooltip: l10n.libraryEdit, onPressed: onEdit),
        actionButton(
          icon: Icons.playlist_add,
          tooltip: l10n.addToPlaylist,
          onPressed: onAddToPlaylist,
        ),
        actionButton(
          icon: Icons.delete_outline,
          tooltip: l10n.commonDelete,
          onPressed: onDelete,
        ),
      ],
    );
  }
}
