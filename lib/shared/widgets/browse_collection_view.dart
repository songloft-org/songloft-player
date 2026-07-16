import 'package:flutter/material.dart';

import '../../core/theme/app_dimensions.dart';
import '../../core/theme/responsive.dart';
import 'browse_card.dart';

/// 通用一级浏览内容区：grid/list 两形态渲染 + 触底分页指示 + 居中约束。
///
/// 只负责「集合的排布」，单项卡片由 [cardBuilder] 返回（通常是 [BrowseCard]），
/// 搜索框等放到 [header]。空态 / 错误态由调用方在外层用 async.when 处理，
/// 本组件只在 [itemCount] > 0 时使用。
class BrowseCollectionView extends StatelessWidget {
  final BrowseCardLayout layout;
  final int itemCount;
  final Widget Function(BuildContext context, int index) cardBuilder;

  final ScrollController? scrollController;
  final bool isLoadingMore;
  final Future<void> Function()? onRefresh;

  /// 顶部固定区（如搜索框），随视图切换保留。
  final Widget? header;

  const BrowseCollectionView({
    super.key,
    required this.layout,
    required this.itemCount,
    required this.cardBuilder,
    this.scrollController,
    this.isLoadingMore = false,
    this.onRefresh,
    this.header,
  });

  @override
  Widget build(BuildContext context) {
    final content = layout == BrowseCardLayout.grid
        ? _buildGrid(context)
        : _buildList(context);

    final centered = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: onRefresh != null
            ? RefreshIndicator(onRefresh: onRefresh!, child: content)
            : content,
      ),
    );

    if (header == null) return centered;
    return Column(children: [header!, Expanded(child: centered)]);
  }

  double _horizontalPadding(BuildContext context) => context.responsive<double>(
    mobile: AppSpacing.md,
    tablet: AppSpacing.lg,
    desktop: AppSpacing.xl,
    tv: AppSpacing.xxl,
  );

  Widget _buildGrid(BuildContext context) {
    final crossAxisCount = context.responsive<int>(
      mobile: 2,
      tablet: 3,
      desktop: 4,
      tv: 5,
    );
    final hp = _horizontalPadding(context);
    return GridView.builder(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(
        hp,
        AppSpacing.md,
        hp,
        MediaQuery.of(context).padding.bottom + 80,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.7,
      ),
      itemCount: itemCount + (isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= itemCount) return _loadingCell();
        return cardBuilder(context, index);
      },
    );
  }

  Widget _buildList(BuildContext context) {
    final hp = _horizontalPadding(context);
    return ListView.builder(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(
        hp,
        AppSpacing.sm,
        hp,
        MediaQuery.of(context).padding.bottom + 80,
      ),
      itemCount: itemCount + (isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= itemCount) return _loadingCell();
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: cardBuilder(context, index),
        );
      },
    );
  }

  Widget _loadingCell() => const Center(
    child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
  );
}
