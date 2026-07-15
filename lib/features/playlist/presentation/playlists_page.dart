import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/constants.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/responsive.dart';
import '../../../core/utils/url_helper.dart';
import '../../../shared/utils/responsive_snackbar.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/filter_pill.dart';
import '../../player/presentation/providers/player_provider.dart';
import '../domain/playlist.dart';
import 'providers/playlist_provider.dart';
import 'providers/playlist_view_provider.dart';
import 'widgets/playlist_card.dart';
import 'widgets/playlist_list_item.dart';
import 'widgets/playlist_form_dialog.dart';
import '../../../l10n/app_localizations.dart';

/// 歌单列表页面
class PlaylistsPage extends ConsumerStatefulWidget {
  const PlaylistsPage({super.key});

  @override
  ConsumerState<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends ConsumerState<PlaylistsPage> {
  String? _selectedType;
  bool _isSelectionMode = false;
  final Set<int> _selectedPlaylistIds = {};

  /// 排序模式
  bool _isSortMode = false;
  List<Playlist> _sortablePlaylists = [];

  /// 是否显示隐藏歌单
  bool _showHidden = false;

  /// 触底加载预留距离（提前 300px 触发下一页加载）
  static const double _loadMoreThreshold = 300.0;

  late final ScrollController _scrollController;

  /// 搜索输入控制器与防抖
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  /// 当前搜索关键词（跨类型切换时保持）
  String _searchKeyword = '';

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// 搜索输入变化（防抖 300ms 后触发）
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _searchKeyword = value.trim();
      ref
          .read(playlistListProvider(_selectedType).notifier)
          .search(_searchKeyword);
    });
  }

  /// 清空搜索
  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    _searchKeyword = '';
    ref.read(playlistListProvider(_selectedType).notifier).search('');
  }

  /// 切换类型筛选
  void _onTypeChanged(String? type) {
    if (_selectedType == type) return;
    setState(() => _selectedType = type);
    // 切换类型后，新的 family Notifier 以空关键词构建，
    // 若当前处于搜索状态则重新应用关键词
    if (_searchKeyword.isNotEmpty) {
      ref
          .read(playlistListProvider(_selectedType).notifier)
          .search(_searchKeyword);
    }
  }

  /// 滚动监听：接近底部时触发分页加载
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _loadMoreThreshold) {
      ref.read(playlistListProvider(_selectedType).notifier).loadMore();
    }
  }

  void _toggleSelectMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedPlaylistIds.clear();
      }
    });
  }

  void _togglePlaylistSelection(Playlist playlist) {
    // 不允许选择内置歌单
    if (playlist.isBuiltIn) return;
    setState(() {
      if (_selectedPlaylistIds.contains(playlist.id)) {
        _selectedPlaylistIds.remove(playlist.id);
      } else {
        _selectedPlaylistIds.add(playlist.id);
      }
    });
  }

  void _selectAll(List<Playlist> playlists) {
    setState(() {
      final selectableIds =
          playlists.where((p) => !p.isBuiltIn).map((p) => p.id).toSet();
      if (_selectedPlaylistIds.containsAll(selectableIds)) {
        _selectedPlaylistIds.clear();
      } else {
        _selectedPlaylistIds.addAll(selectableIds);
      }
    });
  }

  /// 进入排序模式（确保所有歌单已加载）
  Future<void> _enterSortMode(List<Playlist> playlists) async {
    // 排序需要全部歌单在内存中，忽略类型筛选加载全部
    await ref.read(playlistListProvider(null).notifier).loadAll();
    if (!mounted) return;
    final fullPlaylists =
        ref.read(playlistListProvider(null)).value?.items ?? playlists;
    setState(() {
      _isSortMode = true;
      _isSelectionMode = false;
      _selectedPlaylistIds.clear();
      _sortablePlaylists = List.from(fullPlaylists);
    });
  }

  /// 退出排序模式并保存
  Future<void> _exitSortMode() async {
    final playlistIds = _sortablePlaylists.map((p) => p.id).toList();
    setState(() => _isSortMode = false);

    final notifier = ref.read(playlistNotifierProvider.notifier);
    final success = await notifier.reorderPlaylists(playlistIds);

    if (mounted) {
      final l10n = AppLocalizations.of(context);
      if (success) {
        ResponsiveSnackBar.showSuccess(
          context,
          message: l10n.playlistSortSaved,
        );
      } else {
        ResponsiveSnackBar.showError(
          context,
          message: l10n.playlistSortSaveFailed,
        );
      }
    }
  }

  /// 取消排序模式（不保存）
  void _cancelSortMode() {
    setState(() {
      _isSortMode = false;
      _sortablePlaylists = [];
    });
  }

  /// 自动按名称排序歌单
  Future<void> _autoSortByName(
    List<Playlist> playlists, {
    bool ascending = true,
  }) async {
    // 排序需要全部歌单在内存中
    await ref.read(playlistListProvider(null).notifier).loadAll();
    if (!mounted) return;
    final fullPlaylists =
        ref.read(playlistListProvider(null)).value?.items ?? playlists;

    final sorted = List<Playlist>.from(fullPlaylists);
    sorted.sort((a, b) {
      final result = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return ascending ? result : -result;
    });

    final playlistIds = sorted.map((p) => p.id).toList();

    // 检查排序前后是否有变化
    final originalIds = fullPlaylists.map((p) => p.id).toList();
    if (listEquals(playlistIds, originalIds)) {
      if (mounted) {
        ResponsiveSnackBar.show(
          context,
          message: AppLocalizations.of(context).playlistAlreadySortedPlaylists,
        );
      }
      return;
    }

    final notifier = ref.read(playlistNotifierProvider.notifier);
    final success = await notifier.reorderPlaylists(playlistIds);

    if (mounted) {
      final l10n = AppLocalizations.of(context);
      if (success) {
        ResponsiveSnackBar.showSuccess(
          context,
          message:
              ascending
                  ? l10n.playlistSortedByNameAsc
                  : l10n.playlistSortedByNameDesc,
        );
      } else {
        ResponsiveSnackBar.showError(context, message: l10n.playlistSortFailed);
      }
    }
  }

  /// 提取名称中第一个出现的数字
  int? _extractFirstNumber(String title) {
    final match = RegExp(r'(\d+)').firstMatch(title);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  /// 自动按数字前缀排序歌单
  Future<void> _autoSortByNumberPrefix(List<Playlist> playlists) async {
    // 排序需要全部歌单在内存中
    await ref.read(playlistListProvider(null).notifier).loadAll();
    if (!mounted) return;
    final fullPlaylists =
        ref.read(playlistListProvider(null)).value?.items ?? playlists;

    final sorted = List<Playlist>.from(fullPlaylists);
    sorted.sort((a, b) {
      final numA = _extractFirstNumber(a.name);
      final numB = _extractFirstNumber(b.name);

      // 都有数字前缀：按数值排序
      if (numA != null && numB != null) {
        final cmp = numA.compareTo(numB);
        if (cmp != 0) return cmp;
        // 数值相同时按名称字母序
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      // 有数字前缀的排在前面
      if (numA != null) return -1;
      if (numB != null) return 1;
      // 都没有数字前缀：按名称字母序
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    final playlistIds = sorted.map((p) => p.id).toList();

    // 检查排序前后是否有变化
    final originalIds = fullPlaylists.map((p) => p.id).toList();
    if (listEquals(playlistIds, originalIds)) {
      if (mounted) {
        ResponsiveSnackBar.show(
          context,
          message: AppLocalizations.of(context).playlistAlreadySortedPlaylists,
        );
      }
      return;
    }

    final notifier = ref.read(playlistNotifierProvider.notifier);
    final success = await notifier.reorderPlaylists(playlistIds);

    if (mounted) {
      final l10n = AppLocalizations.of(context);
      if (success) {
        ResponsiveSnackBar.showSuccess(
          context,
          message: l10n.playlistSortedByNumber,
        );
      } else {
        ResponsiveSnackBar.showError(context, message: l10n.playlistSortFailed);
      }
    }
  }

  /// 拖拽排序回调
  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _sortablePlaylists.removeAt(oldIndex);
      _sortablePlaylists.insert(newIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    final playlistsAsync = ref.watch(playlistListProvider(_selectedType));

    return Scaffold(
      appBar:
          _isSortMode
              ? _buildSortAppBar()
              : _isSelectionMode
              ? _buildSelectionAppBar(playlistsAsync)
              : _buildNormalAppBar(),
      body:
          _isSortMode
              ? _buildSortModeBody()
              : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    children: [
                      // 搜索栏（固定置顶，位于类型筛选上方，对齐曲库主页）
                      _buildSearchBar(context),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: () async {
                            ref.invalidate(playlistListProvider(_selectedType));
                          },
                          child: CustomScrollView(
                            controller: _scrollController,
                            slivers: [
                              // 类型筛选
                              SliverToBoxAdapter(
                                child: _buildTypeFilter(context),
                              ),

                              // 歌单列表
                              playlistsAsync.when(
                                data:
                                    (state) => _buildPlaylistContent(
                                      context,
                                      state.items,
                                    ),
                                loading:
                                    () => const SliverToBoxAdapter(
                                      child: Padding(
                                        padding: EdgeInsets.all(64),
                                        child: Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      ),
                                    ),
                                error:
                                    (error, stack) => SliverToBoxAdapter(
                                      child: _buildErrorContent(
                                        error.toString(),
                                      ),
                                    ),
                              ),

                              // 加载更多指示器（仅在 hasMore 或 isLoadingMore 时显示）
                              if (playlistsAsync.value != null)
                                SliverToBoxAdapter(
                                  child: _buildLoadMoreIndicator(
                                    playlistsAsync.value!,
                                  ),
                                ),

                              // 底部安全区域
                              SliverToBoxAdapter(
                                child: SizedBox(
                                  height:
                                      MediaQuery.of(context).padding.bottom +
                                      80,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  /// 构建搜索栏
  Widget _buildSearchBar(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final horizontalPadding = context.responsive<double>(
      mobile: AppSpacing.md,
      tablet: AppSpacing.lg,
      desktop: AppSpacing.xl,
      tv: AppSpacing.xxl,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        AppSpacing.md,
        horizontalPadding,
        0,
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: l10n.playlistListSearchHint,
          prefixIcon: const Icon(Icons.search),
          suffixIcon:
              _searchController.text.isNotEmpty
                  ? IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: l10n.clearSearch,
                    onPressed: _clearSearch,
                  )
                  : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        onChanged: (value) {
          // 更新 suffixIcon 显隐
          setState(() {});
          _onSearchChanged(value);
        },
      ),
    );
  }

  /// 构建类型筛选栏（药丸形 Chip，与曲库筛选栏一致）
  Widget _buildTypeFilter(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final horizontalPadding = context.responsive<double>(
      mobile: AppSpacing.md,
      tablet: AppSpacing.lg,
      desktop: AppSpacing.xl,
      tv: AppSpacing.xxl,
    );
    final types = <(String?, String)>[
      (null, l10n.filterAll),
      (AppConstants.playlistTypeNormal, l10n.playlistFilterNormal),
      (AppConstants.playlistTypeRadio, l10n.playlistFilterRadio),
    ];
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: AppSpacing.sm,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < types.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              FilterPill(
                label: types[i].$2,
                isSelected: _selectedType == types[i].$1,
                onTap: () => _onTypeChanged(types[i].$1),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建加载更多指示器（含错误重试）
  Widget _buildLoadMoreIndicator(PaginatedPlaylistsState state) {
    final l10n = AppLocalizations.of(context);
    if (state.loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: TextButton.icon(
            onPressed:
                () =>
                    ref
                        .read(playlistListProvider(_selectedType).notifier)
                        .loadMore(),
            icon: const Icon(Icons.refresh),
            label: Text(l10n.playlistLoadMoreRetry),
          ),
        ),
      );
    }
    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (!state.hasMore && state.items.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            l10n.playlistAllLoaded(state.items.length),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  AppBar _buildNormalAppBar() {
    final playlistsAsync = ref.watch(playlistListProvider(_selectedType));
    final playlists = playlistsAsync.value?.items ?? [];
    final l10n = AppLocalizations.of(context);

    return AppBar(
      title: Text(l10n.playlistTitle),
      actions: [
        // 视图模式切换按钮
        IconButton(
          icon: Icon(
            ref.watch(playlistViewModeProvider) == PlaylistViewMode.grid
                ? Icons.view_list
                : Icons.grid_view,
          ),
          tooltip:
              ref.watch(playlistViewModeProvider) == PlaylistViewMode.grid
                  ? l10n.playlistSwitchToListView
                  : l10n.playlistSwitchToGridView,
          onPressed: () {
            ref.read(playlistViewModeProvider.notifier).toggleViewMode();
          },
        ),
        // 多选模式按钮
        IconButton(
          icon: const Icon(Icons.checklist),
          tooltip: l10n.playlistMultiSelect,
          onPressed: _toggleSelectMode,
        ),
        // 排序按钮（含自动排序选项）
        PopupMenuButton<String>(
          icon: const Icon(Icons.sort),
          tooltip: l10n.playlistSort,
          onSelected: (value) {
            switch (value) {
              case 'name_asc':
                _autoSortByName(playlists, ascending: true);
              case 'name_desc':
                _autoSortByName(playlists, ascending: false);
              case 'number_asc':
                _autoSortByNumberPrefix(playlists);
              case 'manual':
                _enterSortMode(playlists);
            }
          },
          itemBuilder:
              (context) => [
                PopupMenuItem(
                  value: 'name_asc',
                  child: ListTile(
                    leading: const Icon(Icons.sort_by_alpha),
                    title: Text(l10n.playlistSortNameAsc),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'name_desc',
                  child: ListTile(
                    leading: const Icon(Icons.sort_by_alpha),
                    title: Text(l10n.playlistSortNameDesc),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'number_asc',
                  child: ListTile(
                    leading: const Icon(Icons.format_list_numbered),
                    title: Text(l10n.playlistSortNumberPrefix),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'manual',
                  child: ListTile(
                    leading: const Icon(Icons.drag_handle),
                    title: Text(l10n.playlistSortManual),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
        ),
        // 更多菜单
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          tooltip: l10n.playlistMore,
          onSelected: (value) {
            switch (value) {
              case 'create':
                _showCreateDialog();
              case 'toggle_hidden':
                _toggleShowHidden();
            }
          },
          itemBuilder:
              (context) => [
                PopupMenuItem(
                  value: 'create',
                  child: ListTile(
                    leading: const Icon(Icons.add),
                    title: Text(l10n.playlistCreate),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'toggle_hidden',
                  child: ListTile(
                    leading: Icon(
                      _showHidden ? Icons.visibility_off : Icons.visibility,
                    ),
                    title: Text(
                      _showHidden
                          ? l10n.playlistHideHidden
                          : l10n.playlistShowHidden,
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
        ),
      ],
    );
  }

  AppBar _buildSortAppBar() {
    final l10n = AppLocalizations.of(context);
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: l10n.commonCancel,
        onPressed: _cancelSortMode,
      ),
      title: Text(l10n.playlistSortModeTitle),
      actions: [
        TextButton(onPressed: _exitSortMode, child: Text(l10n.playlistDone)),
      ],
    );
  }

  /// 排序模式下的主体内容
  Widget _buildSortModeBody() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    if (_sortablePlaylists.isEmpty) {
      return Center(child: Text(l10n.noPlaylists));
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _sortablePlaylists.length,
      onReorder: _onReorder,
      itemBuilder: (context, index) {
        final playlist = _sortablePlaylists[index];
        return Card(
          key: ValueKey(playlist.id),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                // 序号
                SizedBox(
                  width: 32,
                  child: Text(
                    '${index + 1}',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 8),
                // 封面
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child:
                        playlist.coverImageUrl != null
                            ? ExcludeSemantics(
                              child: CachedNetworkImage(
                                imageUrl: UrlHelper.buildCoverUrl(
                                  playlist.coverImageUrl!,
                                ),
                                fit: BoxFit.cover,
                                placeholder:
                                    (context, url) => Container(
                                      color:
                                          colorScheme.surfaceContainerHighest,
                                      child: Icon(
                                        Icons.queue_music,
                                        size: 24,
                                        color: colorScheme.onSurfaceVariant
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                                errorWidget:
                                    (context, url, error) => Container(
                                      color:
                                          colorScheme.surfaceContainerHighest,
                                      child: Icon(
                                        Icons.queue_music,
                                        size: 24,
                                        color: colorScheme.onSurfaceVariant
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                              ),
                            )
                            : Container(
                              color: colorScheme.surfaceContainerHighest,
                              child: Center(
                                child: Icon(
                                  playlist.type == 'radio'
                                      ? Icons.radio
                                      : Icons.queue_music,
                                  size: 24,
                                  color: colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                  ),
                ),
                const SizedBox(width: 12),
                // 歌单信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        playlist.name,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.songsCount(playlist.songCount),
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // 拖拽手柄
                ReorderableDragStartListener(
                  index: index,
                  child: Icon(
                    Icons.drag_handle,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  AppBar _buildSelectionAppBar(
    AsyncValue<PaginatedPlaylistsState> playlistsAsync,
  ) {
    final l10n = AppLocalizations.of(context);
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: l10n.playlistExitMultiSelect,
        onPressed: _toggleSelectMode,
      ),
      title: Text(l10n.playlistSelectedCount(_selectedPlaylistIds.length)),
      actions: [
        // 播放按钮
        TextButton.icon(
          icon: Icon(
            Icons.play_arrow,
            color:
                _selectedPlaylistIds.isEmpty
                    ? null
                    : Theme.of(context).colorScheme.primary,
          ),
          label: Text(
            l10n.playlistPlayCount(_selectedPlaylistIds.length),
            style: TextStyle(
              color:
                  _selectedPlaylistIds.isEmpty
                      ? null
                      : Theme.of(context).colorScheme.primary,
            ),
          ),
          onPressed:
              _selectedPlaylistIds.isEmpty ? null : _playSelectedPlaylists,
        ),
        // 删除按钮
        TextButton.icon(
          icon: Icon(
            Icons.delete,
            color:
                _selectedPlaylistIds.isEmpty
                    ? null
                    : Theme.of(context).colorScheme.error,
          ),
          label: Text(
            l10n.playlistDeleteCount(_selectedPlaylistIds.length),
            style: TextStyle(
              color:
                  _selectedPlaylistIds.isEmpty
                      ? null
                      : Theme.of(context).colorScheme.error,
            ),
          ),
          onPressed: _selectedPlaylistIds.isEmpty ? null : _confirmBatchDelete,
        ),
        // 全选按钮（先确保全部歌单已加载，再全选）
        TextButton(
          onPressed: () async {
            await ref
                .read(playlistListProvider(_selectedType).notifier)
                .loadAll();
            final state = ref.read(playlistListProvider(_selectedType)).value;
            if (state != null) {
              _selectAll(state.items);
            }
          },
          child: Text(l10n.selectAll),
        ),
      ],
    );
  }

  Widget _buildPlaylistContent(BuildContext context, List<Playlist> playlists) {
    if (playlists.isEmpty) {
      return SliverToBoxAdapter(child: _buildEmptyContent());
    }

    final viewMode = ref.watch(playlistViewModeProvider);

    if (viewMode == PlaylistViewMode.list) {
      return _buildListView(context, playlists);
    } else {
      return _buildGridView(context, playlists);
    }
  }

  Widget _buildGridView(BuildContext context, List<Playlist> playlists) {
    final currentPlaylistId = ref.watch(sourcePlaylistIdProvider);
    final isPlaying = ref.watch(isPlayingProvider);
    final crossAxisCount = context.responsive<int>(
      mobile: 2,
      tablet: 3,
      desktop: 4,
      tv: 5,
    );
    final gridSpacing = context.responsive<double>(
      mobile: AppSpacing.md,
      tablet: AppSpacing.md,
      desktop: AppSpacing.lg,
      tv: AppSpacing.xl,
    );
    final horizontalPadding = context.responsive<double>(
      mobile: AppSpacing.md,
      tablet: AppSpacing.lg,
      desktop: AppSpacing.xl,
      tv: AppSpacing.xxl,
    );

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: gridSpacing,
          crossAxisSpacing: gridSpacing,
          childAspectRatio: 0.7,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final playlist = playlists[index];
          return PlaylistCard(
            playlist: playlist,
            onTap: () => context.push('/playlists/${playlist.id}'),
            onEdit: () => _showEditDialog(playlist),
            onDelete:
                playlist.isBuiltIn ? null : () => _confirmDelete(playlist),
            onToggleVisibility: () => _togglePlaylistVisibility(playlist),
            onPlayAll: () => _playAll(playlist),
            onLongPress: () {
              setState(() {
                _isSelectionMode = true;
                _selectedPlaylistIds.clear();
              });
              _togglePlaylistSelection(playlist);
            },
            isSelectionMode: _isSelectionMode,
            isSelected: _selectedPlaylistIds.contains(playlist.id),
            onSelect: () => _togglePlaylistSelection(playlist),
            isCurrentPlaylist: playlist.id == currentPlaylistId,
            isPlaying: isPlaying,
          );
        }, childCount: playlists.length),
      ),
    );
  }

  Widget _buildListView(BuildContext context, List<Playlist> playlists) {
    final currentPlaylistId = ref.watch(sourcePlaylistIdProvider);
    final isPlaying = ref.watch(isPlayingProvider);
    final horizontalPadding = context.responsive<double>(
      mobile: AppSpacing.md,
      tablet: AppSpacing.lg,
      desktop: AppSpacing.xl,
      tv: AppSpacing.xxl,
    );
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final playlist = playlists[index];
          return PlaylistListItem(
            playlist: playlist,
            onTap: () => context.push('/playlists/${playlist.id}'),
            onEdit: () => _showEditDialog(playlist),
            onDelete:
                playlist.isBuiltIn ? null : () => _confirmDelete(playlist),
            onToggleVisibility: () => _togglePlaylistVisibility(playlist),
            onPlayAll: () => _playAll(playlist),
            onLongPress: () {
              setState(() {
                _isSelectionMode = true;
                _selectedPlaylistIds.clear();
              });
              _togglePlaylistSelection(playlist);
            },
            isSelectionMode: _isSelectionMode,
            isSelected: _selectedPlaylistIds.contains(playlist.id),
            onSelect: () => _togglePlaylistSelection(playlist),
            isCurrentPlaylist: playlist.id == currentPlaylistId,
            isPlaying: isPlaying,
          );
        }, childCount: playlists.length),
      ),
    );
  }

  Widget _buildEmptyContent() {
    final l10n = AppLocalizations.of(context);
    final isSearching = _searchKeyword.isNotEmpty;
    return EmptyState(
      icon: isSearching ? Icons.search_off : Icons.queue_music_outlined,
      title: isSearching ? l10n.playlistNoMatching : l10n.noPlaylists,
      subtitle:
          isSearching ? l10n.playlistTryOtherKeywords : l10n.playlistEmptyHint,
    );
  }

  Widget _buildErrorContent(String error) {
    return ErrorView(
      message: error,
      onRetry: () => ref.invalidate(playlistListProvider(_selectedType)),
    );
  }

  /// 显示创建歌单对话框
  Future<void> _showCreateDialog() async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => PlaylistFormDialog(title: l10n.playlistCreate),
    );

    if (result != null && mounted) {
      final notifier = ref.read(playlistNotifierProvider.notifier);
      final playlist = await notifier.createPlaylist(
        type: result['type'] as String,
        name: result['name'] as String,
        description: result['description'] as String?,
      );

      if (playlist != null && mounted) {
        ResponsiveSnackBar.showSuccess(context, message: l10n.playlistCreated);
      }
    }
  }

  /// 显示编辑歌单对话框
  Future<void> _showEditDialog(Playlist playlist) async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (context) => PlaylistFormDialog(
            title:
                playlist.isBuiltIn
                    ? l10n.playlistEditCover
                    : l10n.playlistEditPlaylist,
            initialName: playlist.name,
            initialDescription: playlist.description,
            initialType: playlist.type,

            initialCoverUrl: playlist.coverUrl,
            playlistId: playlist.id,
            isEdit: true,
            isBuiltIn: playlist.isBuiltIn,
          ),
    );

    if (result != null && mounted) {
      final notifier = ref.read(playlistNotifierProvider.notifier);

      // 处理封面
      final coverMode = result['coverMode'] as String?;
      final localFile = result['localFile'] as PlatformFile?;
      final selectedCoverSongId = result['selectedCoverSongId'] as int?;

      if (coverMode == 'local' && localFile != null) {
        // 上传本地图片
        final uploadedPlaylist = await notifier.uploadPlaylistCover(
          playlist.id,
          bytes: localFile.bytes,
          filePath: localFile.path,
          fileName: localFile.name,
        );
        if (uploadedPlaylist == null && mounted) {
          ResponsiveSnackBar.showError(
            context,
            message: l10n.playlistCoverUploadFailed,
          );
          return;
        }
        // 更新其他信息，同时传递封面信息防止被后端覆盖
        final updated = await notifier.updatePlaylist(
          playlist.id,
          name: result['name'] as String,
          description: result['description'] as String?,

          coverUrl: uploadedPlaylist?.coverUrl,
        );

        if (updated != null && mounted) {
          ResponsiveSnackBar.showSuccess(
            context,
            message: l10n.playlistUpdated,
          );
        }
      } else if (coverMode == 'song' && selectedCoverSongId != null) {
        // 从歌曲选择的封面
        final updated = await notifier.updatePlaylist(
          playlist.id,
          name: result['name'] as String,
          description: result['description'] as String?,
          coverSongId: selectedCoverSongId,
        );

        if (updated != null && mounted) {
          ResponsiveSnackBar.showSuccess(
            context,
            message: l10n.playlistUpdated,
          );
        }
      } else if (coverMode == 'clear') {
        // 清除封面
        final updated = await notifier.updatePlaylist(
          playlist.id,
          name: result['name'] as String,
          description: result['description'] as String?,
          coverPath: '',
          coverUrl: '',
        );

        if (updated != null && mounted) {
          ResponsiveSnackBar.showSuccess(
            context,
            message: l10n.playlistUpdated,
          );
        }
      } else {
        // 未修改封面
        final updated = await notifier.updatePlaylist(
          playlist.id,
          name: result['name'] as String,
          description: result['description'] as String?,
        );

        if (updated != null && mounted) {
          ResponsiveSnackBar.showSuccess(
            context,
            message: l10n.playlistUpdated,
          );
        }
      }
    }
  }

  /// 批量删除确认弹窗
  Future<void> _confirmBatchDelete() async {
    final count = _selectedPlaylistIds.length;
    if (count == 0) return;

    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.playlistConfirmBatchDelete),
            content: Text(l10n.playlistBatchDeleteConfirm(count)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: Text(l10n.commonDelete),
              ),
            ],
          ),
    );

    if (confirmed == true && mounted) {
      final notifier = ref.read(playlistNotifierProvider.notifier);
      final deleted = await notifier.batchDeletePlaylists(
        _selectedPlaylistIds.toList(),
      );

      if (mounted) {
        if (deleted > 0) {
          ResponsiveSnackBar.showSuccess(
            context,
            message: l10n.playlistDeletedCount(deleted),
          );
        } else {
          ResponsiveSnackBar.showError(
            context,
            message: l10n.playlistDeleteFailed,
          );
        }
        setState(() {
          _isSelectionMode = false;
          _selectedPlaylistIds.clear();
        });
      }
    }
  }

  /// 确认删除歌单
  Future<void> _confirmDelete(Playlist playlist) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.playlistConfirmDelete),
            content: Text(l10n.playlistDeleteConfirm(playlist.name)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: Text(l10n.commonDelete),
              ),
            ],
          ),
    );

    if (confirmed == true && mounted) {
      final notifier = ref.read(playlistNotifierProvider.notifier);
      final success = await notifier.deletePlaylist(playlist.id);

      if (success && mounted) {
        ResponsiveSnackBar.showSuccess(context, message: l10n.playlistDeleted);
      }
    }
  }

  void _toggleShowHidden() {
    setState(() {
      _showHidden = !_showHidden;
    });
    ref
        .read(playlistListProvider(_selectedType).notifier)
        .setExcludeLabels(_showHidden ? 'none' : null);
  }

  Future<void> _togglePlaylistVisibility(Playlist playlist) async {
    final notifier = ref.read(playlistNotifierProvider.notifier);
    final hidden = !playlist.isHidden;
    final success = await notifier.setPlaylistVisibility(
      playlist.id,
      hidden: hidden,
    );
    if (success && mounted) {
      final l10n = AppLocalizations.of(context);
      ResponsiveSnackBar.showSuccess(
        context,
        message: hidden ? l10n.playlistHidden : l10n.playlistUnhidden,
      );
    }
  }

  Future<void> _playSelectedPlaylists() async {
    final ids = _selectedPlaylistIds.toList();
    _toggleSelectMode();
    final total = await ref
        .read(playerStateProvider.notifier)
        .playMultiplePlaylistsById(ids);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    if (total < 0) {
      ResponsiveSnackBar.showError(context, message: l10n.playlistPlayFailed);
    } else if (total == 0) {
      ResponsiveSnackBar.show(context, message: l10n.playlistEmpty);
    } else {
      ResponsiveSnackBar.show(
        context,
        message: l10n.playlistPlayingMultiple(ids.length),
      );
    }
  }

  /// 播放歌单全部歌曲（委托给 PlayerNotifier.playPlaylistById）
  Future<void> _playAll(Playlist playlist) async {
    final total = await ref
        .read(playerStateProvider.notifier)
        .playPlaylistById(playlist.id);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    if (total < 0) {
      ResponsiveSnackBar.showError(context, message: l10n.playlistPlayFailed);
    } else if (total == 0) {
      ResponsiveSnackBar.show(context, message: l10n.playlistEmpty);
    } else {
      ResponsiveSnackBar.show(
        context,
        message: l10n.playlistPlayingCount(total),
      );
    }
  }
}
