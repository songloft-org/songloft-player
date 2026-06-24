import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/constants.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/responsive.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/url_helper.dart';
import '../../../../shared/models/song.dart';
import '../../../../shared/widgets/favorite_button.dart';

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
      tileColor: isCurrentSong ? colorScheme.primaryContainer.withValues(alpha: 0.3) : null,
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
        song.artist ?? '未知艺术家',
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
          color: isCurrentSong
              ? colorScheme.primaryContainer.withValues(alpha: 0.3)
              : null,
          border: Border(
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
                song.artist ?? '未知艺术家',
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
                  song.album ?? '未知专辑',
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
            SizedBox(width: 140, child: _buildDesktopActions(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverImage(String? coverUrl, double size) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child:
          coverUrl != null
              ? ExcludeSemantics(
                child: Image.network(
                  UrlHelper.buildCoverUrl(coverUrl),
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _buildDefaultCover(size),
                ),
              )
              : _buildDefaultCover(size),
    );
  }

  Widget _buildDefaultCover(double size) {
    return Builder(
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return Container(
          width: size,
          height: size,
          color: colorScheme.surfaceContainerHighest,
          child: Icon(
            _getTypeIcon(),
            size: size * 0.5,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        );
      },
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
    final colorScheme = Theme.of(context).colorScheme;
    String label;
    Color color;

    switch (song.type) {
      case AppConstants.songTypeRadio:
        label = '电台';
        color = colorScheme.tertiary;
        break;
      case AppConstants.songTypeRemote:
        label = '网络';
        color = colorScheme.secondary;
        break;
      default:
        label = '本地';
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
                const PopupMenuItem(
                  value: 'play',
                  child: ListTile(
                    leading: Icon(Icons.play_arrow),
                    title: Text('播放'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (song.type != AppConstants.songTypeLocal)
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit),
                      title: Text('编辑'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                const PopupMenuItem(
                  value: 'add_to_playlist',
                  child: ListTile(
                    leading: Icon(Icons.playlist_add),
                    title: Text('添加到歌单'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete),
                    title: Text('删除'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
        ),
      ],
    );
  }

  Widget _buildDesktopActions(BuildContext context) {
    if (isSelectionMode) return const SizedBox(width: 140);

    const constraints = BoxConstraints(minWidth: 28, minHeight: 28);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.play_arrow),
          tooltip: '播放',
          onPressed: onTap,
          iconSize: 20,
          padding: EdgeInsets.zero,
          constraints: constraints,
        ),
        FavoriteButton(songId: song.id, songType: song.type, size: 20),
        if (song.type != AppConstants.songTypeLocal)
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: '编辑',
            onPressed: onEdit,
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: constraints,
          ),
        IconButton(
          icon: const Icon(Icons.playlist_add),
          tooltip: '添加到歌单',
          onPressed: onAddToPlaylist,
          iconSize: 20,
          padding: EdgeInsets.zero,
          constraints: constraints,
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: '删除',
          onPressed: onDelete,
          iconSize: 20,
          padding: EdgeInsets.zero,
          constraints: constraints,
        ),
      ],
    );
  }
}
