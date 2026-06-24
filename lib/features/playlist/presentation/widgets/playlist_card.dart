import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/utils/url_helper.dart';
import '../../domain/playlist.dart';

/// 歌单卡片组件
class PlaylistCard extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onPlayAll;
  final VoidCallback? onLongPress;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onSelect;
  final bool isCurrentPlaylist;
  final bool isPlaying;

  const PlaylistCard({
    super.key,
    required this.playlist,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onPlayAll,
    this.onLongPress,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelect,
    this.isCurrentPlaylist = false,
    this.isPlaying = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadius.lgAll,
        boxShadow: AppShadows.light,
      ),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape:
            (isSelectionMode && isSelected) || isCurrentPlaylist
                ? RoundedRectangleBorder(
                  borderRadius: AppRadius.lgAll,
                  side: BorderSide(color: colorScheme.primary, width: 2),
                )
                : RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        child: InkWell(
          onTap: isSelectionMode ? onSelect : onTap,
          onLongPress: isSelectionMode ? null : onLongPress,
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
                    playlist.coverImageUrl != null
                        ? ExcludeSemantics(
                          child: CachedNetworkImage(
                            imageUrl: UrlHelper.buildCoverUrl(
                              playlist.coverImageUrl!,
                            ),
                            fit: BoxFit.cover,
                            placeholder:
                                (context, url) => _buildPlaceholder(colorScheme),
                            errorWidget:
                                (context, url, error) =>
                                    _buildPlaceholder(colorScheme),
                          ),
                        )
                        : _buildPlaceholder(colorScheme),

                    // 底部渐变遮罩
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 48,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.3),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // 正在播放指示器
                    if (isCurrentPlaylist && isPlaying)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black54,
                          child: Center(
                            child: Icon(
                              Icons.equalizer_rounded,
                              size: 32,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ),

                    // 播放全部按钮（右下角）
                    if (onPlayAll != null)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Semantics(
                          button: true,
                          label: '播放全部',
                          child: Tooltip(
                            message: '播放全部',
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
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            '电台',
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSecondary,
                            ),
                          ),
                        ),
                      ),

                    // 更多按钮（右上角，非多选模式下显示）
                    if (!isSelectionMode && (onEdit != null || onDelete != null))
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Material(
                          color: colorScheme.surface.withValues(alpha: 0.7),
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: _buildMoreButton(context),
                        ),
                      ),
                  ],
                ),
              ),

              // 歌单信息
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                              color: isCurrentPlaylist
                                  ? colorScheme.primary
                                  : null,
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

  Widget _buildMoreButton(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        size: 20,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      tooltip: '更多操作',
      onSelected: (value) {
        switch (value) {
          case 'edit':
            onEdit?.call();
          case 'delete':
            onDelete?.call();
        }
      },
      itemBuilder: (context) => [
        if (onEdit != null)
          const PopupMenuItem(
            value: 'edit',
            child: ListTile(
              leading: Icon(Icons.edit),
              title: Text('编辑'),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (onDelete != null && !playlist.isBuiltIn)
          PopupMenuItem(
            value: 'delete',
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
  }
}
