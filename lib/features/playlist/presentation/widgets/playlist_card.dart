import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/url_helper.dart';
import '../../domain/playlist.dart';

/// 歌单卡片组件
class PlaylistCard extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onPlayAll;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onSelect;

  const PlaylistCard({
    super.key,
    required this.playlist,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onPlayAll,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final coverUrl = playlist.coverUrl;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape:
          isSelectionMode && isSelected
              ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: colorScheme.primary, width: 2),
              )
              : null,
      child: InkWell(
        onTap: isSelectionMode ? onSelect : onTap,
        onLongPress: isSelectionMode ? null : _showContextMenu(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 方形封面区域
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 封面图
                  coverUrl != null && coverUrl.isNotEmpty
                      ? CachedNetworkImage(
                        imageUrl: UrlHelper.buildCoverUrl(coverUrl),
                        fit: BoxFit.cover,
                        placeholder:
                            (context, url) => _buildPlaceholder(colorScheme),
                        errorWidget:
                            (context, url, error) =>
                                _buildPlaceholder(colorScheme),
                      )
                      : _buildPlaceholder(colorScheme),

                  // 播放全部按钮（右下角）
                  if (onPlayAll != null)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Material(
                        color: colorScheme.primary,
                        shape: const CircleBorder(),
                        elevation: 4,
                        child: InkWell(
                          onTap: onPlayAll,
                          customBorder: const CircleBorder(),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              Icons.play_arrow,
                              color: colorScheme.onPrimary,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // 多选模式下显示 Checkbox（左上角）
                  if (isSelectionMode)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surface.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Checkbox(
                          value: isSelected,
                          onChanged: (_) => onSelect?.call(),
                        ),
                      ),
                    )
                  // 类型标签（左上角）
                  else if (playlist.type == 'radio')
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.secondary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '电台',
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSecondary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 歌单信息
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxH = constraints.maxHeight;
                    // 根据可用高度决定显示内容，避免溢出
                    // titleSmall ~20px, bodySmall ~16px, label ~22px, spacing 2px
                    // 歌曲数量始终显示，基础高度: name ~20 + spacing 2 + songCount ~16 = 38
                    final hasDesc = playlist.description?.isNotEmpty == true;
                    final hasLabels = playlist.labels.isNotEmpty;
                    final showDesc = hasDesc && maxH >= 58;
                    final showLabels =
                        hasLabels && maxH >= (showDesc ? 82 : 62);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 歌单名称
                        Text(
                          playlist.name,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        // 歌曲数量
                        Text(
                          '${playlist.songCount} 首歌曲',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (showDesc) ...[
                          const SizedBox(height: 2),
                          // 歌单描述
                          Text(
                            playlist.description!,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (showLabels) ...[
                          const SizedBox(height: 2),
                          // 标签
                          Wrap(
                            spacing: 4,
                            runSpacing: 2,
                            children:
                                playlist.labels.map((label) {
                                  return _buildLabel(context, label);
                                }).toList(),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          playlist.type == 'radio' ? Icons.radio : Icons.queue_music,
          size: 48,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildLabel(BuildContext context, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    String displayLabel;
    Color backgroundColor;

    switch (label) {
      case 'built_in':
        displayLabel = '内置';
        backgroundColor = colorScheme.primaryContainer;
        break;
      case 'auto_created':
        displayLabel = '自动';
        backgroundColor = colorScheme.secondaryContainer;
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

  VoidCallback? _showContextMenu(BuildContext context) {
    if (onEdit == null && onDelete == null) return null;

    return () {
      final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox == null) return;

      final position = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;

      showMenu(
        context: context,
        position: RelativeRect.fromLTRB(
          position.dx,
          position.dy + size.height / 2,
          position.dx + size.width,
          position.dy + size.height,
        ),
        items: [
          if (onEdit != null)
            PopupMenuItem(
              onTap: onEdit,
              child: const ListTile(
                leading: Icon(Icons.edit),
                title: Text('编辑'),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          if (onDelete != null && !playlist.isBuiltIn)
            PopupMenuItem(
              onTap: onDelete,
              child: ListTile(
                leading: Icon(
                  Icons.delete,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  '删除',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
        ],
      );
    };
  }
}
