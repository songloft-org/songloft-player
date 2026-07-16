import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_dimensions.dart';
import '../../core/utils/url_helper.dart';

/// 卡片布局形态。
enum BrowseCardLayout {
  /// 网格：方形封面在上、信息在下。
  grid,

  /// 列表：横向封面 + 信息 + 尾部操作。
  list,
}

/// 「更多」菜单里的一个操作项。
class BrowseCardAction {
  final String value;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// 破坏性操作（如删除），文字/图标用 error 色。
  final bool destructive;

  const BrowseCardAction({
    required this.value,
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });
}

/// 通用浏览卡片：歌单、歌手/专辑等分类取值统一用它渲染。
///
/// 承载布局与交互骨架（封面 / 标题 / 副标题 / 标签 / 选中态 / 播放叠层 / 更多菜单），
/// 业务字段与回调由调用方注入，不耦合具体领域模型。
class BrowseCard extends StatelessWidget {
  final BrowseCardLayout layout;

  /// 后端封面 URL（交给 [CoverImage] / [UrlHelper] 处理，可为空）。
  final String? coverUrl;
  final IconData placeholderIcon;

  final String title;

  /// 第二行（通常是「N 首」歌曲数）。
  final String? subtitle;

  /// 第三行（可选，如歌单描述）。grid 形态按可用高度决定是否显示。
  final String? detail;

  /// 底部标签行（如歌单的内置/自动/隐藏标签）。
  final List<Widget> chips;

  /// 类型徽标（如电台标签），显示在 grid 左上 / list 标题右侧。
  final Widget? typeBadge;

  /// 高亮边框（选中或当前正在播放的项）。
  final bool highlighted;

  /// 标题用 primary 色（当前项）。
  final bool highlightTitle;

  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onSelect;

  /// 正在播放：封面叠加遮罩 + 均衡器图标。
  final bool isPlaying;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// 播放全部：grid 右下圆钮 / list 尾部按钮。
  final VoidCallback? onPlayAll;
  final String? playAllTooltip;

  /// 更多菜单项；为空则不显示菜单。
  final List<BrowseCardAction> menuActions;
  final String? menuTooltip;

  /// list 形态右侧显示下钻箭头（分类取值卡片用）。
  final bool showChevron;

  const BrowseCard({
    super.key,
    required this.layout,
    required this.title,
    this.coverUrl,
    this.placeholderIcon = Icons.music_note,
    this.subtitle,
    this.detail,
    this.chips = const [],
    this.typeBadge,
    this.highlighted = false,
    this.highlightTitle = false,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelect,
    this.isPlaying = false,
    this.onTap,
    this.onLongPress,
    this.onPlayAll,
    this.playAllTooltip,
    this.menuActions = const [],
    this.menuTooltip,
    this.showChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    return layout == BrowseCardLayout.grid
        ? _buildGrid(context)
        : _buildList(context);
  }

  // ---------- grid 形态 ----------

  Widget _buildGrid(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadius.lgAll,
        boxShadow: AppShadows.light,
      ),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
          side: highlighted
              ? BorderSide(color: colorScheme.primary, width: 2)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: isSelectionMode ? onSelect : onTap,
          onLongPress: isSelectionMode ? null : onLongPress,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildCoverFill(context),
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
                    if (isPlaying)
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
                    if (onPlayAll != null)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: _buildPlayAllFab(context),
                      ),
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
                    else if (typeBadge != null)
                      Positioned(left: 8, top: 8, child: typeBadge!),
                    if (!isSelectionMode && menuActions.isNotEmpty)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Material(
                          color: colorScheme.surface.withValues(alpha: 0.7),
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: _buildMenu(context, compact: true),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final maxH = constraints.maxHeight;
                      final hasDetail = detail?.isNotEmpty == true;
                      final hasChips = chips.isNotEmpty;
                      final showDetail = hasDetail && maxH >= 58;
                      final showChips =
                          hasChips && maxH >= (showDetail ? 82 : 62);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: highlightTitle ? colorScheme.primary : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle!,
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (showDetail) ...[
                            const SizedBox(height: 2),
                            Text(
                              detail!,
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (showChips) ...[
                            const SizedBox(height: 2),
                            Wrap(spacing: 4, runSpacing: 2, children: chips),
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

  // ---------- list 形态 ----------

  Widget _buildList(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.mdAll,
        side: highlighted
            ? BorderSide(color: colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: isSelectionMode ? onSelect : onTap,
        onLongPress: isSelectionMode ? null : onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              if (isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (_) => onSelect?.call(),
                  ),
                ),
              _buildCoverThumb(context, size: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: highlightTitle
                                  ? colorScheme.primary
                                  : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (typeBadge != null) ...[
                          const SizedBox(width: 6),
                          typeBadge!,
                        ],
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (chips.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(spacing: 4, runSpacing: 2, children: chips),
                    ],
                  ],
                ),
              ),
              if (!isSelectionMode) ...[
                if (onPlayAll != null)
                  IconButton(
                    onPressed: onPlayAll,
                    icon: const Icon(Icons.play_arrow),
                    tooltip: playAllTooltip,
                  ),
                if (menuActions.isNotEmpty) _buildMenu(context),
                if (showChevron && onPlayAll == null && menuActions.isEmpty)
                  Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ---------- 公共零件 ----------

  Widget _buildPlayAllFab(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fab = Material(
      color: colorScheme.primary,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        onTap: onPlayAll,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(Icons.play_arrow, color: colorScheme.onPrimary, size: 24),
        ),
      ),
    );
    if (playAllTooltip == null) return fab;
    return Semantics(
      button: true,
      label: playAllTooltip,
      child: Tooltip(message: playAllTooltip!, child: fab),
    );
  }

  /// grid 用：填满 AspectRatio 的封面（CoverImage 是定尺寸，这里需要 fill）。
  Widget _buildCoverFill(BuildContext context) {
    final url = coverUrl != null && coverUrl!.isNotEmpty
        ? UrlHelper.buildCoverUrl(coverUrl!)
        : null;
    if (url == null) return _buildPlaceholder(context, iconSize: 48);
    return ExcludeSemantics(
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (context, url) =>
            _buildPlaceholder(context, iconSize: 48),
        errorWidget: (context, url, error) =>
            _buildPlaceholder(context, iconSize: 48),
      ),
    );
  }

  /// list 用：定尺寸封面缩略图（叠加正在播放遮罩）。
  Widget _buildCoverThumb(BuildContext context, {required double size}) {
    final colorScheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: AppRadius.smAll,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildCoverFill(context),
            if (isPlaying)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Icon(
                    Icons.equalizer_rounded,
                    size: 24,
                    color: colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context, {required double iconSize}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          placeholderIcon,
          size: iconSize,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildMenu(BuildContext context, {bool compact = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        size: compact ? 20 : 24,
        color: colorScheme.onSurface,
      ),
      padding: EdgeInsets.zero,
      constraints: compact
          ? const BoxConstraints(minWidth: 32, minHeight: 32)
          : null,
      tooltip: menuTooltip,
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
    );
  }
}
