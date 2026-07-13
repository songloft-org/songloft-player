import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/responsive.dart';
import '../../../shared/models/song.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
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

  @override
  Widget build(BuildContext context) {
    final facetsAsync = ref.watch(facetsProvider(_field));

    return Scaffold(
      appBar: AppBar(title: const Text('分类浏览')),
      body: Column(
        children: [
          // 维度切换（横向滚动 Chip 行）
          _buildDimensionSelector(context),
          const Divider(height: 1),
          // 取值清单
          Expanded(
            child: facetsAsync.when(
              data: (facets) => _buildFacetGrid(context, facets),
              loading:
                  () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _buildError(context, error.toString()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDimensionSelector(BuildContext context) {
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
          for (final field in categoryFields) ...[
            ChoiceChip(
              label: Text(categoryFieldLabel(field)),
              selected: _field == field,
              onSelected: (selected) {
                if (selected && _field != field) {
                  setState(() => _field = field);
                }
              },
            ),
            const SizedBox(width: AppSpacing.sm),
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
    return EmptyState(
      icon: Icons.label_off_outlined,
      title: '暂无「${categoryFieldLabel(_field)}」分类',
      subtitle: '该维度下还没有可归类的歌曲',
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
                      categoryValueLabel(field, facet.value),
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${facet.count} 首',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
