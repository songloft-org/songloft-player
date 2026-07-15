import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/responsive.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/models/song.dart';
import '../../../../shared/widgets/cover_image.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../providers/category_provider.dart';
import 'library_view_switcher.dart';

/// 某分类维度的 facet 卡片网格视图：顶部服务端搜索 + 带封面缩略图的取值卡片 + 触底分页，
/// 点卡片 push 到现有 `/library/categories/:field?value=` 下钻页（复用现有路由，不自造页内下钻）。
class FacetGridView extends ConsumerStatefulWidget {
  final String field;

  const FacetGridView({super.key, required this.field});

  @override
  ConsumerState<FacetGridView> createState() => _FacetGridViewState();
}

class _FacetGridViewState extends ConsumerState<FacetGridView> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant FacetGridView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 切换维度时清空搜索框（不同维度取值空间不同，保留旧关键词会造成困惑）。
    if (oldWidget.field != widget.field) {
      _searchController.clear();
      _debounceTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(facetListProvider(widget.field).notifier).loadMore();
    }
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      ref.read(facetListProvider(widget.field).notifier).search(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(facetListProvider(widget.field));

    return Column(
      children: [
        _buildSearchBar(context),
        Expanded(
          child: asyncState.when(
            data: (state) => _buildGrid(context, state),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => ErrorView(
              message: error.toString(),
              onRetry: () => ref.invalidate(facetListProvider(widget.field)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fieldLabel = libraryViewLabel(l10n, widget.field);
    final horizontalPadding = context.responsive<double>(
      mobile: AppSpacing.md,
      tablet: AppSpacing.lg,
      desktop: AppSpacing.xl,
      tv: AppSpacing.xxl,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        AppSpacing.sm,
        horizontalPadding,
        0,
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: l10n.categorySearchHint(fieldLabel),
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: l10n.clearSearch,
                  onPressed: () {
                    _searchController.clear();
                    ref
                        .read(facetListProvider(widget.field).notifier)
                        .search('');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }

  Widget _buildGrid(BuildContext context, FacetListState state) {
    final l10n = AppLocalizations.of(context);
    final fieldLabel = libraryViewLabel(l10n, widget.field);

    if (state.items.isEmpty) {
      if (state.keyword.trim().isNotEmpty) {
        return EmptyState(
          icon: Icons.search_off,
          title: l10n.categoryNoMatch(fieldLabel),
          subtitle: l10n.libraryTryOtherKeywords,
        );
      }
      return EmptyState(
        icon: Icons.label_off_outlined,
        title: l10n.categoryEmptyTitle(fieldLabel),
        subtitle: l10n.categoryEmptySubtitle,
      );
    }

    final crossAxisCount = context.responsive<int>(
      mobile: 2,
      tablet: 3,
      desktop: 4,
      tv: 5,
    );
    final horizontalPadding = context.responsive<double>(
      mobile: AppSpacing.md,
      tablet: AppSpacing.lg,
      desktop: AppSpacing.xl,
      tv: AppSpacing.xxl,
    );

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(facetListProvider(widget.field)),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: GridView.builder(
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              AppSpacing.md,
              horizontalPadding,
              MediaQuery.of(context).padding.bottom + 80,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              // 固定卡片高度（含缩略图 + 两行文字），比宽高比更稳，避免窄列裁掉「N 首」。
              mainAxisExtent: 76,
            ),
            // 触底会加载更多；末尾多一格 loading 指示。
            itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= state.items.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              final facet = state.items[index];
              return _FacetCard(
                field: widget.field,
                facet: facet,
                onTap: () {
                  // value 走 query 参数：Uri 负责编码，避免路径段里的 % / 等字符
                  // 引发 go_router 编解码问题（沿用原 categories_page 做法）。
                  context.push(
                    Uri(
                      path: '/library/categories/${widget.field}',
                      queryParameters: {'value': facet.value},
                    ).toString(),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 取值卡片：左侧封面缩略图 + 取值名称 + 歌曲数量。
/// 封面复用 CoverImage（后端下发的 cover_url，空则回退到维度占位图标）。
class _FacetCard extends StatelessWidget {
  final String field;
  final SongFacet facet;
  final VoidCallback onTap;

  const _FacetCard({
    required this.field,
    required this.facet,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              CoverImage(
                coverUrl: facet.coverUrl,
                size: 52,
                borderRadius: AppRadius.sm,
                placeholderIcon: libraryViewIcon(field),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      categoryValueLabel(l10n, field, facet.value),
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.categorySongCount(facet.count),
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
