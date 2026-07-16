import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/responsive.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/utils/responsive_snackbar.dart';
import '../../../../shared/widgets/browse_card.dart';
import '../../../../shared/widgets/browse_collection_view.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../playlist/presentation/providers/playlist_view_provider.dart';
import '../providers/category_provider.dart';
import 'library_view_switcher.dart';

/// 某分类维度的 facet 浏览视图：顶部服务端搜索 + 通用 [BrowseCard] 卡片（grid/list 可切换）
/// + 触底分页，点卡片 push 到 `/library/categories/:field?value=` 下钻页。
///
/// 视图模式复用 [playlistViewModeProvider]（与歌单页共享同一 grid/list 偏好）。
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

  /// 播放某分类取值下的全部歌曲（先加载全部再播放），与歌单卡片的「播放全部」一致。
  Future<void> _playFacet(String value) async {
    final key = (field: widget.field, value: value);
    await ref.read(categorySongsProvider(key).notifier).loadAll();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final songs = ref.read(categorySongsProvider(key)).value?.items ?? [];
    if (songs.isEmpty) {
      ResponsiveSnackBar.show(context, message: l10n.libraryNoPlayableSongs);
      return;
    }
    ref.read(playerStateProvider.notifier).playPlaylist(songs, startIndex: 0);
    if (!mounted) return;
    ResponsiveSnackBar.show(
      context,
      message: l10n.libraryPlayingAllSongs(songs.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(facetListProvider(widget.field));

    return Column(
      children: [
        _buildSearchBar(context),
        Expanded(
          child: asyncState.when(
            data: (state) => _buildContent(context, state),
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

  Widget _buildContent(BuildContext context, FacetListState state) {
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

    final layout = ref.watch(playlistViewModeProvider) == PlaylistViewMode.list
        ? BrowseCardLayout.list
        : BrowseCardLayout.grid;

    return BrowseCollectionView(
      layout: layout,
      itemCount: state.items.length,
      scrollController: _scrollController,
      isLoadingMore: state.isLoadingMore,
      onRefresh: () async => ref.invalidate(facetListProvider(widget.field)),
      cardBuilder: (context, index) {
        final facet = state.items[index];
        return BrowseCard(
          layout: layout,
          coverUrl: facet.coverUrl,
          placeholderIcon: libraryViewIcon(widget.field),
          title: categoryValueLabel(l10n, widget.field, facet.value),
          subtitle: l10n.categorySongCount(facet.count),
          onPlayAll: () => _playFacet(facet.value),
          playAllTooltip: l10n.libraryPlayAll,
          onTap: () {
            // value / cover 走 query 参数：Uri 负责编码，避免路径段里的 % / 等
            // 字符引发 go_router 编解码问题（沿用原 categories_page 做法）。
            context.push(
              Uri(
                path: '/library/categories/${widget.field}',
                queryParameters: {
                  'value': facet.value,
                  if (facet.coverUrl.isNotEmpty) 'cover': facet.coverUrl,
                },
              ).toString(),
            );
          },
        );
      },
    );
  }
}
