import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/responsive.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/song.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/filter_pill.dart';
import 'providers/category_provider.dart';

/// 分类总览页：顶部切换维度，下方展示该维度所有取值卡片（含歌曲数）。
class CategoriesPage extends ConsumerStatefulWidget {
  const CategoriesPage({super.key});

  @override
  ConsumerState<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends ConsumerState<CategoriesPage> {
  /// 当前选中的维度字段（默认第一个：流派）
  String _field = categoryFields.first;

  /// 分类取值搜索关键词（客户端过滤，实时生效）
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 切换维度：清空搜索，不同维度取值空间不同，保留旧关键词会造成困惑。
  void _onFieldChanged(String field) {
    setState(() {
      _field = field;
      _searchController.clear();
      _searchQuery = '';
    });
  }

  /// 客户端过滤：按显示文案 + 原始取值做大小写不敏感子串匹配。
  /// facets 已由 FutureProvider 全量加载到内存，过滤零网络开销、即时响应。
  List<SongFacet> _filterFacets(List<SongFacet> facets) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return facets;
    final l10n = AppLocalizations.of(context);
    return facets.where((f) {
      final label = categoryValueLabel(l10n, _field, f.value).toLowerCase();
      return label.contains(query) || f.value.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final facetsAsync = ref.watch(facetsProvider(_field));
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.categoryBrowseTitle)),
      body: Column(
        children: [
          // 搜索栏（固定置顶，位于维度筛选上方，对齐曲库主页）
          _buildSearchBar(context),
          // 维度切换（横向滚动 Chip 行）
          _buildDimensionSelector(context),
          const Divider(height: 1),
          // 取值清单（客户端按关键词过滤）
          Expanded(
            child: facetsAsync.when(
              data: (facets) => _buildFacetGrid(context, _filterFacets(facets)),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _buildError(context, error.toString()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fieldLabel = categoryFieldLabel(l10n, _field);
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
          suffixIcon:
              _searchQuery.isNotEmpty
                  ? IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: l10n.clearSearch,
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                  : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  Widget _buildDimensionSelector(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final horizontalPadding = context.responsive<double>(
      mobile: AppSpacing.md,
      tablet: AppSpacing.lg,
      desktop: AppSpacing.xl,
      tv: AppSpacing.xxl,
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          for (var i = 0; i < categoryFields.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            FilterPill(
              label: categoryFieldLabel(l10n, categoryFields[i]),
              isSelected: _field == categoryFields[i],
              onTap: () => _onFieldChanged(categoryFields[i]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFacetGrid(BuildContext context, List<SongFacet> facets) {
    if (facets.isEmpty) {
      return _buildEmpty(context);
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
      onRefresh: () async => ref.invalidate(facetsProvider(_field)),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: GridView.builder(
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
              // 固定卡片高度而非宽高比：宽高比会让窄列卡片变矮，
              // 导致标题下方的「N 首」被裁掉。固定高度对各列宽稳定。
              mainAxisExtent: 84,
            ),
            itemCount: facets.length,
            itemBuilder: (context, index) {
              final facet = facets[index];
              return _FacetCard(
                field: _field,
                facet: facet,
                onTap: () {
                  // value 走 query 参数：Uri 负责正确编码，避免路径段里
                  // 的 % / 等字符引发 go_router 编解码问题。
                  context.push(
                    Uri(
                      path: '/library/categories/$_field',
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

  Widget _buildEmpty(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fieldLabel = categoryFieldLabel(l10n, _field);
    // 有关键词但过滤后为空 → 无匹配结果；否则该维度本身无数据。
    if (_searchQuery.trim().isNotEmpty) {
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

  Widget _buildError(BuildContext context, String error) {
    return ErrorView(
      message: error,
      onRetry: () => ref.invalidate(facetsProvider(_field)),
    );
  }
}

/// 取值卡片：展示分类取值名称与歌曲数量。
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
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
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
                    const SizedBox(height: 4),
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
