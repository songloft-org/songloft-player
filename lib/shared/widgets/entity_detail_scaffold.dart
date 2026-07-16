import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimensions.dart';
import '../../core/theme/responsive.dart';
import '../../core/utils/color_extraction.dart';
import 'cover_image.dart';

/// 通用「实体详情」骨架：封面 header（调色板渐变）+ 信息区 + 操作按钮 + 歌曲列表。
///
/// 窄屏单列 [CustomScrollView]（SliverAppBar + header + slivers）；
/// 宽屏左右分栏（左侧封面/信息/按钮，右侧歌曲列表）。歌曲列表等由调用方以
/// [bodySlivers] 注入，AppBar 操作与主次操作按钮亦由调用方提供，保证与
/// 歌单详情页视觉一致而不耦合具体领域。
class EntityDetailScaffold extends ConsumerWidget {
  final Widget titleWidget;
  final Widget? leading;
  final VoidCallback? onBack;

  /// 封面 URL（用于展示 + 调色板渐变）。
  final String? coverUrl;
  final IconData placeholderIcon;

  /// 聚合副标题（如「歌手 · 42 首」）。
  final String? subtitle;
  final String? description;

  final List<Widget> appBarActions;

  /// 主次操作按钮区（如「播放全部」「加入歌单」）；多选/排序态可传 null 隐藏。
  final Widget? actionButtons;

  /// 歌曲列表相关 sliver（歌曲 SliverList + 加载更多 + 底部安全区，可含搜索栏）。
  final List<Widget> bodySlivers;

  final ScrollController? scrollController;
  final Future<void> Function()? onRefresh;

  const EntityDetailScaffold({
    super.key,
    required this.titleWidget,
    required this.bodySlivers,
    this.leading,
    this.onBack,
    this.coverUrl,
    this.placeholderIcon = Icons.music_note,
    this.subtitle,
    this.description,
    this.appBarActions = const [],
    this.actionButtons,
    this.scrollController,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final body = context.useWideLayout
        ? _buildWide(context, ref)
        : _buildNarrow(context, ref);

    return Scaffold(
      body: onRefresh != null
          ? RefreshIndicator(onRefresh: onRefresh!, child: body)
          : body,
    );
  }

  Widget? _effectiveLeading(BuildContext context) {
    if (leading != null) return leading;
    if (onBack != null) {
      return IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: onBack,
      );
    }
    return null;
  }

  // ---------- 窄屏 ----------

  Widget _buildNarrow(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return CustomScrollView(
      controller: scrollController,
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.onSurface,
          title: titleWidget,
          leading: _effectiveLeading(context),
          actions: appBarActions,
        ),
        SliverToBoxAdapter(child: _buildCoverHeader(context, ref)),
        SliverToBoxAdapter(child: _buildInfo(context)),
        if (actionButtons != null) SliverToBoxAdapter(child: actionButtons!),
        ...bodySlivers,
      ],
    );
  }

  // ---------- 宽屏 ----------

  Widget _buildWide(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        AppBar(
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.onSurface,
          title: titleWidget,
          leading: _effectiveLeading(context),
          actions: appBarActions,
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 320, child: _buildWideLeftPanel(context, ref)),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: colorScheme.outlineVariant,
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: CustomScrollView(
                      controller: scrollController,
                      slivers: bodySlivers,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWideLeftPanel(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bgColor = _paletteColor(ref, colorScheme);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: AppRadius.xlAll,
              boxShadow: AppShadows.medium,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [bgColor.withValues(alpha: 0.3), Colors.transparent],
              ),
            ),
            child: CoverImage(
              coverUrl: coverUrl,
              size: 240,
              borderRadius: AppRadius.xl,
              placeholderIcon: placeholderIcon,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          DefaultTextStyle.merge(
            textAlign: TextAlign.center,
            child: titleWidget is Text
                ? Text(
                    (titleWidget as Text).data ?? '',
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  )
                : titleWidget,
          ),
          if (description?.isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              description!,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (subtitle?.isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              subtitle!,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (actionButtons != null) ...[
            const SizedBox(height: AppSpacing.lg),
            actionButtons!,
          ],
        ],
      ),
    );
  }

  // ---------- 公共零件 ----------

  Color _paletteColor(WidgetRef ref, ColorScheme colorScheme) {
    final palette = ref.watch(coverColorsProvider(coverUrl ?? '')).value;
    return palette?.darkMutedColor ?? colorScheme.surfaceContainerHighest;
  }

  Widget _buildCoverHeader(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isWide = context.isWideScreen;
    final coverSize = isWide ? 180.0 : 140.0;
    final bgColor = _paletteColor(ref, colorScheme);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [bgColor.withValues(alpha: 0.6), colorScheme.surface],
        ),
      ),
      padding: EdgeInsets.symmetric(
        vertical: isWide ? AppSpacing.lg : AppSpacing.md,
      ),
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.medium,
          ),
          child: CoverImage(
            coverUrl: coverUrl,
            size: coverSize,
            borderRadius: AppRadius.lg,
            placeholderIcon: placeholderIcon,
          ),
        ),
      ),
    );
  }

  Widget _buildInfo(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    if ((description?.isEmpty ?? true) && (subtitle?.isEmpty ?? true)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (description?.isNotEmpty == true) ...[
            Text(
              description!,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (subtitle?.isNotEmpty == true)
            Text(
              subtitle!,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
