import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/url_helper.dart';
import '../../domain/playlist.dart';

/// 歌单列表项组件（列表视图）
class PlaylistListItem extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onPlayAll;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onSelect;

  const PlaylistListItem({
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
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              // 多选模式下显示 Checkbox
              if (isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (_) => onSelect?.call(),
                  ),
                ),
              // 左侧：方形封面 56x56
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child:
                      coverUrl != null && coverUrl.isNotEmpty
                          ? CachedNetworkImage(
                            imageUrl: UrlHelper.buildCoverUrl(coverUrl),
                            fit: BoxFit.cover,
                            placeholder:
                                (context, url) =>
                                    _buildPlaceholder(colorScheme),
                            errorWidget:
                                (context, url, error) =>
                                    _buildPlaceholder(colorScheme),
                          )
                          : _buildPlaceholder(colorScheme),
                ),
              ),
              const SizedBox(width: 12),

              // 中间：歌单信息（Expanded）
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 第一行：歌单名称 + 电台标签
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            playlist.name,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (playlist.type == 'radio') ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.secondary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '电台',
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSecondary,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),

                    // 第二行：歌曲数量 · 描述
                    Text(
                      _buildSubtitle(),
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // 第三行：标签（可选）
                    if (playlist.labels.isNotEmpty) ...[
                      const SizedBox(height: 4),
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
                ),
              ),

              // 右侧：操作按钮（多选模式下隐藏）
              if (!isSelectionMode) ...[
                if (onPlayAll != null)
                  IconButton(
                    onPressed: onPlayAll,
                    icon: const Icon(Icons.play_arrow),
                    tooltip: '播放全部',
                  ),
                IconButton(
                  onPressed: _showMoreMenu(context),
                  icon: const Icon(Icons.more_vert),
                  tooltip: '更多操作',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 构建副标题：歌曲数量 · 描述
  String _buildSubtitle() {
    final parts = <String>['${playlist.songCount} 首歌曲'];
    if (playlist.description?.isNotEmpty == true) {
      parts.add(playlist.description!);
    }
    return parts.join(' · ');
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          playlist.type == 'radio' ? Icons.radio : Icons.queue_music,
          size: 24,
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

  /// 更多按钮点击显示菜单
  VoidCallback? _showMoreMenu(BuildContext context) {
    if (onEdit == null && onDelete == null) return null;

    return () {
      final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox == null) return;

      final position = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;

      showMenu(
        context: context,
        position: RelativeRect.fromLTRB(
          position.dx + size.width - 48,
          position.dy + size.height,
          position.dx + size.width,
          position.dy + size.height,
        ),
        items: _buildMenuItems(context),
      );
    };
  }

  /// 长按显示上下文菜单
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
        items: _buildMenuItems(context),
      );
    };
  }

  /// 构建菜单项
  List<PopupMenuEntry<void>> _buildMenuItems(BuildContext context) {
    return [
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
    ];
  }
}
