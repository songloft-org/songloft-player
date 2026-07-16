import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/responsive.dart';
import '../../../shared/models/song.dart';
import '../../../shared/utils/responsive_snackbar.dart';
import '../../../shared/widgets/add_to_playlist_modal.dart';
import '../../../shared/widgets/delete_song_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../settings/data/settings_api.dart';
import '../../settings/presentation/providers/settings_provider.dart';
import '../../player/presentation/providers/player_provider.dart';
import '../../playlist/presentation/providers/playlist_view_provider.dart';
import '../../playlist/presentation/widgets/playlist_browse_view.dart';
import 'providers/songs_provider.dart';
import 'song_edit_page.dart';
import 'widgets/facet_grid_view.dart';
import 'widgets/library_view_switcher.dart';
import 'widgets/song_list_tile.dart';

/// 曲库统一浏览页。
///
/// 把「本地/网络/电台/全部」的扁平歌曲列表与「歌手/专辑/流派/年份/年代/语种/风格」的
/// 分类聚合浏览合并到同一页面：
/// - 宽屏（[BuildContext.useWideLayout]）用左侧视图导航栏 + 右侧内容区；
/// - 窄屏用顶部横向 [LibraryViewSwitcher] 切换条 + 下方内容区。
/// 视图的「显示 + 顺序」由 [libraryBrowseConfigProvider] 驱动，AppBar「编辑」进入页内编辑模式。
class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _debounceTimer;

  /// 当前选中的视图 key（null 时在 build 里回退到第一个可见视图）。
  String? _selectedViewKey;

  /// 已为扁平视图同步过 type 过滤的 key，避免在 build 里重复触发加载。
  String? _syncedFlatKey;

  /// 编辑模式：页内拖拽排序 + 开关（仿 playlists 手动排序模式）。
  bool _editMode = false;
  List<LibraryViewEntry> _draftViews = [];

  /// 歌单视图的内嵌 View，供顶部 AppBar 驱动其多选/排序/新建等操作。
  final GlobalKey<PlaylistBrowseViewState> _playlistViewKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
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
      ref.read(songsListProvider.notifier).loadMore();
    }
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      ref.read(songsListProvider.notifier).search(value);
    });
  }

  /// 切换视图。扁平视图会（经 build 的 post-frame）同步歌曲列表 type 过滤。
  void _selectView(String key) {
    if (key == _selectedViewKey) return;
    // 离开扁平视图时若处于多选态，先退出。
    if (ref.read(songsListProvider).isSelectionMode) {
      ref.read(songsListProvider.notifier).toggleSelectMode();
    }
    setState(() => _selectedViewKey = key);
  }

  /// 扁平视图首次进入 / 切换时，把 type 过滤同步到共享的 songsListProvider。
  void _scheduleFlatSync(String key) {
    if (!isFlatLibraryView(key)) return;
    if (_syncedFlatKey == key) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncedFlatKey = key;
      ref.read(songsListProvider.notifier).setTypeFilter(flatViewType(key));
    });
  }

  void _enterEditMode(LibraryBrowseConfig config) {
    setState(() {
      _editMode = true;
      // 规整为按组连续的顺序（组内保留配置相对顺序），保证编辑与保存都是分组视图。
      _draftViews = _groupedFlatten(config.views);
    });
  }

  /// 按固定组顺序（歌曲→分类→歌单）铺平，组内保留传入相对顺序。
  List<LibraryViewEntry> _groupedFlatten(List<LibraryViewEntry> entries) {
    final buckets = _groupDrafts(entries);
    return [
      for (final g in LibraryViewGroup.values) ...buckets[g]!,
    ];
  }

  Map<LibraryViewGroup, List<LibraryViewEntry>> _groupDrafts(
    List<LibraryViewEntry> entries,
  ) {
    final buckets = <LibraryViewGroup, List<LibraryViewEntry>>{
      LibraryViewGroup.songs: [],
      LibraryViewGroup.facets: [],
      LibraryViewGroup.playlists: [],
    };
    for (final e in entries) {
      buckets[libraryViewGroup(e.key)]!.add(e);
    }
    return buckets;
  }

  String _groupLabel(AppLocalizations l10n, LibraryViewGroup group) {
    switch (group) {
      case LibraryViewGroup.songs:
        return l10n.libraryViewGroupSongs;
      case LibraryViewGroup.facets:
        return l10n.libraryViewGroupCategories;
      case LibraryViewGroup.playlists:
        return l10n.libraryViewGroupPlaylists;
    }
  }

  Future<void> _saveEdit() async {
    final l10n = AppLocalizations.of(context);
    if (!_draftViews.any((v) => v.visible)) {
      ResponsiveSnackBar.showError(context, message: l10n.libraryViewsMinOne);
      return;
    }
    try {
      await ref
          .read(libraryBrowseConfigProvider.notifier)
          .updateConfig(LibraryBrowseConfig(views: _draftViews));
    } catch (_) {
      // updateConfig 已乐观更新本地状态；失败仅提示，不阻塞退出。
    }
    if (!mounted) return;
    setState(() => _editMode = false);
  }

  Future<void> _playAll(SongsListState state) async {
    final total = await ref
        .read(playerStateProvider.notifier)
        .playAllSongs(keyword: state.keyword, type: state.type);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    if (total < 0) {
      ResponsiveSnackBar.showError(context, message: l10n.libraryPlayFailed);
    } else if (total == 0) {
      ResponsiveSnackBar.show(context, message: l10n.libraryNoPlayableSongs);
    } else {
      ResponsiveSnackBar.show(
        context,
        message: l10n.libraryPlayingAllSongs(total),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(songsListProvider);
    final config =
        ref.watch(libraryBrowseConfigProvider).value ??
        LibraryBrowseConfig.defaultConfig();

    final visibleKeys = config.visibleViews.map((v) => v.key).toList();
    String? selected = _selectedViewKey;
    if (selected == null || !visibleKeys.contains(selected)) {
      selected = visibleKeys.isNotEmpty ? visibleKeys.first : null;
    }
    if (selected != null) {
      _scheduleFlatSync(selected);
    }

    return Scaffold(
      appBar: _buildAppBar(context, state, config, selected),
      body: _buildBody(context, state, visibleKeys, selected),
    );
  }

  Widget _buildBody(
    BuildContext context,
    SongsListState state,
    List<String> visibleKeys,
    String? selected,
  ) {
    if (_editMode) {
      return _buildEditor(context);
    }

    final content = _buildContent(context, state, selected);

    if (context.useWideLayout) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 240,
            child: LibraryViewRail(
              viewKeys: visibleKeys,
              selectedKey: selected ?? '',
              onSelected: _selectView,
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: content),
        ],
      );
    }

    return Column(
      children: [
        LibraryViewSwitcher(
          viewKeys: visibleKeys,
          selectedKey: selected ?? '',
          onSelected: _selectView,
        ),
        const Divider(height: 1),
        Expanded(child: content),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context,
    SongsListState state,
    String? selected,
  ) {
    if (selected == null) {
      final l10n = AppLocalizations.of(context);
      return EmptyState(
        icon: Icons.visibility_off_outlined,
        title: l10n.libraryViewsMinOne,
        subtitle: l10n.libraryCustomizeViewsTooltip,
      );
    }
    if (isFlatLibraryView(selected)) {
      return _buildFlatContent(context, state);
    }
    if (isPlaylistLibraryView(selected)) {
      // 歌单视图：嵌入歌单浏览视图（type 由视图 key 决定）；工具栏由顶部 AppBar 驱动，
      // 模式变化经 onModeChanged 通知本页重建 AppBar。
      return PlaylistBrowseView(
        key: _playlistViewKey,
        typeFilter: playlistViewType(selected),
        onModeChanged: () {
          if (mounted) setState(() {});
        },
      );
    }
    // 分类聚合视图：facet 卡片网格（key 按维度隔离，切换维度重建为全新状态）。
    return FacetGridView(key: ValueKey('facet-$selected'), field: selected);
  }

  // ---------- 扁平歌曲列表内容 ----------

  Widget _buildFlatContent(BuildContext context, SongsListState state) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        _buildSearchBar(context),
        if (state.error != null && state.songs.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: colorScheme.errorContainer,
            child: Row(
              children: [
                Icon(Icons.error, color: colorScheme.onErrorContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.error!,
                    style: TextStyle(color: colorScheme.onErrorContainer),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: colorScheme.onErrorContainer),
                  tooltip: AppLocalizations.of(context).libraryDismissError,
                  onPressed: () {
                    ref.read(songsListProvider.notifier).clearError();
                  },
                ),
              ],
            ),
          ),
        Expanded(child: _buildSongList(context, state)),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    SongsListState state,
    LibraryBrowseConfig config,
    String? selected,
  ) {
    final l10n = AppLocalizations.of(context);

    // 编辑模式：独立 AppBar（取消 + 保存）。
    if (_editMode) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.commonCancel,
          onPressed: () => setState(() => _editMode = false),
        ),
        title: Text(l10n.libraryCustomizeViews),
        actions: [
          TextButton(onPressed: _saveEdit, child: Text(l10n.librarySave)),
        ],
      );
    }

    // 多选态（仅扁平视图可进入）：整条 AppBar 替换。
    if (state.isSelectionMode) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.libraryExitSelection,
          onPressed: () {
            ref.read(songsListProvider.notifier).toggleSelectMode();
          },
        ),
        title: Text(l10n.librarySelectedCount(state.selectedSongIds.length)),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.playlist_add),
            label: Text(l10n.addToPlaylist),
            onPressed: state.selectedSongIds.isEmpty
                ? null
                : () => _showAddToPlaylistDialog(
                    context,
                    state.selectedSongIds.toList(),
                  ),
          ),
          TextButton.icon(
            icon: Icon(
              Icons.delete,
              color: state.selectedSongIds.isEmpty
                  ? null
                  : Theme.of(context).colorScheme.error,
            ),
            label: Text(
              l10n.libraryDeleteWithCount(state.selectedSongIds.length),
              style: TextStyle(
                color: state.selectedSongIds.isEmpty
                    ? null
                    : Theme.of(context).colorScheme.error,
              ),
            ),
            onPressed: state.selectedSongIds.isEmpty
                ? null
                : () => _showBatchDeleteConfirmDialog(context),
          ),
          TextButton(
            onPressed: state.isSelectingAll
                ? null
                : () {
                    ref.read(songsListProvider.notifier).toggleSelectAll();
                  },
            child: state.isSelectingAll
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    (state.total > 0 &&
                            state.selectedSongIds.length >= state.total)
                        ? l10n.libraryDeselectAll
                        : l10n.selectAll,
                  ),
          ),
        ],
      );
    }

    // 歌单视图：工具栏(视图切换/多选/排序/更多)统一放到顶部 AppBar。
    if (selected != null && isPlaylistLibraryView(selected)) {
      return _buildPlaylistAppBar(context, config);
    }

    final isFlat = selected != null && isFlatLibraryView(selected);
    final isFacet = selected != null &&
        !isFlatLibraryView(selected) &&
        !isPlaylistLibraryView(selected);

    return AppBar(
      title: Text(l10n.libraryTitle),
      actions: [
        if (isFlat) ...[
          IconButton(
            icon: const Icon(Icons.play_circle_outline),
            tooltip: l10n.libraryPlayAll,
            onPressed: state.songs.isEmpty ? null : () => _playAll(state),
          ),
          _buildSortMenu(context, state),
          IconButton(
            icon: const Icon(Icons.checklist),
            tooltip: l10n.librarySelectMode,
            onPressed: () {
              ref.read(songsListProvider.notifier).toggleSelectMode();
            },
          ),
        ],
        // 分类视图（歌手/专辑等）：grid/list 切换（与歌单页共享视图模式偏好）。
        if (isFacet) _buildViewModeToggle(context),
        _buildMoreMenu(context, state, config, isFlat),
      ],
    );
  }

  Widget _buildViewModeToggle(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isGrid = ref.watch(playlistViewModeProvider) == PlaylistViewMode.grid;
    return IconButton(
      icon: Icon(isGrid ? Icons.view_list : Icons.grid_view),
      tooltip: isGrid
          ? l10n.playlistSwitchToListView
          : l10n.playlistSwitchToGridView,
      onPressed: () =>
          ref.read(playlistViewModeProvider.notifier).toggleViewMode(),
    );
  }

  // ---------- 歌单视图的顶部 AppBar（正常/多选/排序三态） ----------

  PreferredSizeWidget _buildPlaylistAppBar(
    BuildContext context,
    LibraryBrowseConfig config,
  ) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final vs = _playlistViewKey.currentState;

    // 排序模式
    if (vs?.isSortMode ?? false) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.commonCancel,
          onPressed: () => _playlistViewKey.currentState?.cancelSortMode(),
        ),
        title: Text(l10n.playlistSortModeTitle),
        actions: [
          TextButton(
            onPressed: () => _playlistViewKey.currentState?.saveSortMode(),
            child: Text(l10n.playlistDone),
          ),
        ],
      );
    }

    // 多选模式
    if (vs?.isSelectionMode ?? false) {
      final count = vs?.selectedCount ?? 0;
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.playlistExitMultiSelect,
          onPressed: () => _playlistViewKey.currentState?.exitSelectionMode(),
        ),
        title: Text(l10n.playlistSelectedCount(count)),
        actions: [
          TextButton.icon(
            icon: Icon(
              Icons.play_arrow,
              color: count == 0 ? null : colorScheme.primary,
            ),
            label: Text(l10n.playlistPlayCount(count)),
            onPressed: count == 0
                ? null
                : () => _playlistViewKey.currentState?.playSelected(),
          ),
          TextButton.icon(
            icon: Icon(
              Icons.delete,
              color: count == 0 ? null : colorScheme.error,
            ),
            label: Text(
              l10n.playlistDeleteCount(count),
              style: TextStyle(color: count == 0 ? null : colorScheme.error),
            ),
            onPressed: count == 0
                ? null
                : () => _playlistViewKey.currentState?.deleteSelected(),
          ),
          TextButton(
            onPressed: () =>
                _playlistViewKey.currentState?.selectAllInSelection(),
            child: Text(l10n.selectAll),
          ),
        ],
      );
    }

    // 正常模式
    return AppBar(
      title: Text(l10n.libraryTitle),
      actions: [
        _buildViewModeToggle(context),
        IconButton(
          icon: const Icon(Icons.checklist),
          tooltip: l10n.playlistMultiSelect,
          onPressed: () => _playlistViewKey.currentState?.enterSelectionMode(),
        ),
        _buildPlaylistSortMenu(context),
        _buildPlaylistMoreMenu(context, config),
      ],
    );
  }

  Widget _buildPlaylistSortMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      icon: const Icon(Icons.sort),
      tooltip: l10n.playlistSort,
      onSelected: (value) {
        final vs = _playlistViewKey.currentState;
        switch (value) {
          case 'name_asc':
            vs?.autoSortByName(ascending: true);
          case 'name_desc':
            vs?.autoSortByName(ascending: false);
          case 'number_asc':
            vs?.autoSortByNumberPrefix();
          case 'manual':
            vs?.enterSortMode();
        }
      },
      itemBuilder: (context) => [
        _playlistSortItem('name_asc', Icons.sort_by_alpha, l10n.playlistSortNameAsc),
        _playlistSortItem(
          'name_desc',
          Icons.sort_by_alpha,
          l10n.playlistSortNameDesc,
        ),
        _playlistSortItem(
          'number_asc',
          Icons.format_list_numbered,
          l10n.playlistSortNumberPrefix,
        ),
        _playlistSortItem('manual', Icons.drag_handle, l10n.playlistSortManual),
      ],
    );
  }

  PopupMenuItem<String> _playlistSortItem(
    String value,
    IconData icon,
    String title,
  ) {
    return PopupMenuItem(
      value: value,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        dense: true,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  /// 歌单视图的「更多」菜单：合并歌单专属项(新建/显隐)与曲库项(自定义视图)。
  Widget _buildPlaylistMoreMenu(
    BuildContext context,
    LibraryBrowseConfig config,
  ) {
    final l10n = AppLocalizations.of(context);
    final showHidden = _playlistViewKey.currentState?.showHidden ?? false;
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      tooltip: l10n.libraryMore,
      onSelected: (value) {
        switch (value) {
          case 'create':
            _playlistViewKey.currentState?.createPlaylist();
          case 'toggle_hidden':
            _playlistViewKey.currentState?.toggleShowHidden();
          case 'customize_views':
            _enterEditMode(config);
        }
      },
      itemBuilder: (context) => [
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
            leading: Icon(showHidden ? Icons.visibility_off : Icons.visibility),
            title: Text(
              showHidden ? l10n.playlistHideHidden : l10n.playlistShowHidden,
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'customize_views',
          child: ListTile(
            leading: const Icon(Icons.tune),
            title: Text(l10n.libraryCustomizeViews),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Widget _buildSortMenu(BuildContext context, SongsListState state) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      icon: const Icon(Icons.sort),
      tooltip: l10n.librarySort,
      onSelected: (value) {
        final (sort, order) = switch (value) {
          'added_at' => ('added_at', 'desc'),
          'file_modified_at' => ('file_modified_at', 'desc'),
          'title' => ('title', 'asc'),
          'artist' => ('artist', 'asc'),
          'duration' => ('duration', 'asc'),
          _ => ('added_at', 'desc'),
        };
        ref.read(songsListProvider.notifier).setSort(sort, order);
      },
      itemBuilder: (context) => [
        _buildLibrarySortItem(
          value: 'added_at',
          icon: Icons.schedule,
          title: l10n.librarySortAddedAt,
          isSelected: state.sort == 'added_at',
        ),
        _buildLibrarySortItem(
          value: 'file_modified_at',
          icon: Icons.insert_drive_file_outlined,
          title: l10n.librarySortFileTime,
          isSelected: state.sort == 'file_modified_at',
        ),
        _buildLibrarySortItem(
          value: 'title',
          icon: Icons.sort_by_alpha,
          title: l10n.libraryColumnTitle,
          isSelected: state.sort == 'title',
        ),
        _buildLibrarySortItem(
          value: 'artist',
          icon: Icons.person,
          title: l10n.libraryColumnArtist,
          isSelected: state.sort == 'artist',
        ),
        _buildLibrarySortItem(
          value: 'duration',
          icon: Icons.timer,
          title: l10n.libraryColumnDuration,
          isSelected: state.sort == 'duration',
        ),
      ],
    );
  }

  Widget _buildMoreMenu(
    BuildContext context,
    SongsListState state,
    LibraryBrowseConfig config,
    bool isFlat,
  ) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      tooltip: l10n.libraryMore,
      onSelected: (value) {
        switch (value) {
          case 'add_remote':
            _navigateToAddSong(context, AppConstants.songTypeRemote);
          case 'add_radio':
            _navigateToAddSong(context, AppConstants.songTypeRadio);
          case 'toggle_hidden':
            ref
                .read(songsListProvider.notifier)
                .setShowHidden(!state.showHidden);
          case 'clean':
            _showCleanConfirmDialog(context);
          case 'customize_views':
            _enterEditMode(config);
        }
      },
      itemBuilder: (context) => [
        // 歌曲管理项仅在扁平歌曲视图下有意义。
        if (isFlat) ...[
          PopupMenuItem(
            value: 'add_remote',
            child: ListTile(
              leading: const Icon(Icons.cloud),
              title: Text(l10n.libraryAddRemoteSong),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: 'add_radio',
            child: ListTile(
              leading: const Icon(Icons.radio),
              title: Text(l10n.libraryAddRadio),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: 'toggle_hidden',
            child: ListTile(
              leading: Icon(
                state.showHidden ? Icons.visibility_off : Icons.visibility,
              ),
              title: Text(
                state.showHidden
                    ? l10n.libraryHideHiddenSongs
                    : l10n.libraryShowHiddenSongs,
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: 'clean',
            child: ListTile(
              leading: const Icon(Icons.cleaning_services),
              title: Text(l10n.libraryCleanInvalidSongs),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const PopupMenuDivider(),
        ],
        PopupMenuItem(
          value: 'customize_views',
          child: ListTile(
            leading: const Icon(Icons.tune),
            title: Text(l10n.libraryCustomizeViews),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  // ---------- 编辑模式：视图显隐 + 拖拽排序 ----------

  Widget _buildEditor(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final horizontalPadding = context.responsive<double>(
      mobile: AppSpacing.md,
      tablet: AppSpacing.lg,
      desktop: AppSpacing.xl,
    );
    final buckets = _groupDrafts(_draftViews);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: AppSpacing.sm,
          ),
          children: [
            for (final group in LibraryViewGroup.values) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.xs,
                ),
                child: Text(
                  _groupLabel(l10n, group),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: buckets[group]!.length,
                onReorder: (oldIndex, newIndex) =>
                    _reorderInGroup(group, oldIndex, newIndex),
                itemBuilder: (context, index) {
                  final v = buckets[group]![index];
                  return ListTile(
                    key: ValueKey(v.key),
                    leading: Icon(libraryViewIcon(v.key)),
                    title: Text(libraryViewLabel(l10n, v.key)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: v.visible,
                          onChanged: (val) => _setDraftVisible(v.key, val),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        ReorderableDragStartListener(
                          index: index,
                          child: const Icon(Icons.drag_handle),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _reorderInGroup(LibraryViewGroup group, int oldIndex, int newIndex) {
    setState(() {
      final buckets = _groupDrafts(_draftViews);
      final list = buckets[group]!;
      if (newIndex > oldIndex) newIndex--;
      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);
      _draftViews = [
        for (final g in LibraryViewGroup.values) ...buckets[g]!,
      ];
    });
  }

  void _setDraftVisible(String key, bool visible) {
    setState(() {
      _draftViews = [
        for (final e in _draftViews)
          if (e.key == key) e.copyWith(visible: visible) else e,
      ];
    });
  }

  PopupMenuItem<String> _buildLibrarySortItem({
    required String value,
    required IconData icon,
    required String title,
    required bool isSelected,
  }) {
    final color = isSelected ? Theme.of(context).colorScheme.primary : null;
    return PopupMenuItem<String>(
      value: value,
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: TextStyle(color: color)),
        trailing: isSelected ? Icon(Icons.check, color: color) : null,
        dense: true,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final horizontalPadding = context.responsive<double>(
      mobile: AppSpacing.md,
      tablet: AppSpacing.lg,
      desktop: AppSpacing.xl,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: l10n.librarySearchHint,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: l10n.clearSearch,
                  onPressed: () {
                    _searchController.clear();
                    ref.read(songsListProvider.notifier).search('');
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

  Widget _buildSongList(BuildContext context, SongsListState state) {
    if (state.isLoading && state.songs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.songs.isEmpty && state.error != null) {
      return ErrorView(
        message: state.error,
        onRetry: () => ref.read(songsListProvider.notifier).refresh(),
      );
    }

    if (state.songs.isEmpty) {
      return _buildEmptyState(context);
    }

    final contentPadding = context.responsive<double>(
      mobile: 0,
      tablet: AppSpacing.sm,
      desktop: AppSpacing.md,
    );

    return RefreshIndicator(
      onRefresh: () => ref.read(songsListProvider.notifier).refresh(),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: contentPadding),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (context.isMobile ||
                constraints.maxWidth < ResponsiveBreakpoints.tablet) {
              return _buildMobileList(context, state);
            } else {
              return _buildDesktopList(context, state);
            }
          },
        ),
      ),
    );
  }

  Widget _buildMobileList(BuildContext context, SongsListState state) {
    final currentSong = ref.watch(currentSongProvider);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: state.songs.length + (state.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= state.songs.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final song = state.songs[index];
        return SongListTile(
          song: song,
          index: index,
          isSelected: state.selectedSongIds.contains(song.id),
          isSelectionMode: state.isSelectionMode,
          isCurrentSong: currentSong?.id == song.id,
          onTap: () => _onSongTap(song, index),
          onLongPress: () {
            ref.read(songsListProvider.notifier).toggleSelectMode();
            ref.read(songsListProvider.notifier).toggleSongSelection(song.id);
          },
          onSelect: () {
            ref.read(songsListProvider.notifier).toggleSongSelection(song.id);
          },
          onDelete: () => _showDeleteConfirmDialog(context, song.id),
          onEdit: () => _navigateToEditSong(context, song),
          onAddToPlaylist: () => _showAddToPlaylistDialog(context, [song.id]),
        );
      },
    );
  }

  Widget _buildDesktopList(BuildContext context, SongsListState state) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final currentSong = ref.watch(currentSongProvider);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 700;

            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    border: Border(
                      bottom: BorderSide(color: colorScheme.outlineVariant),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (state.isSelectionMode)
                        const SizedBox(width: 48)
                      else
                        SizedBox(
                          width: 40,
                          child: Text(
                            '#',
                            style: textTheme.titleSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      const SizedBox(width: 64),
                      Expanded(
                        flex: 3,
                        child: Text(
                          l10n.libraryColumnTitle,
                          style: textTheme.titleSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: Text(
                          l10n.libraryColumnArtist,
                          style: textTheme.titleSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (!isNarrow) ...[
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: Text(
                            l10n.libraryColumnAlbum,
                            style: textTheme.titleSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 60,
                        child: Text(
                          l10n.libraryColumnType,
                          style: textTheme.titleSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 60,
                        child: Text(
                          l10n.libraryColumnDuration,
                          style: textTheme.titleSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const SizedBox(width: kDesktopActionsWidth),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount:
                        state.songs.length + (state.isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= state.songs.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final song = state.songs[index];
                      return SongListTile(
                        song: song,
                        index: index,
                        isSelected: state.selectedSongIds.contains(song.id),
                        isSelectionMode: state.isSelectionMode,
                        isNarrow: isNarrow,
                        isCurrentSong: currentSong?.id == song.id,
                        onTap: () => _onSongTap(song, index),
                        onLongPress: () {
                          ref
                              .read(songsListProvider.notifier)
                              .toggleSelectMode();
                          ref
                              .read(songsListProvider.notifier)
                              .toggleSongSelection(song.id);
                        },
                        onSelect: () {
                          ref
                              .read(songsListProvider.notifier)
                              .toggleSongSelection(song.id);
                        },
                        onDelete: () =>
                            _showDeleteConfirmDialog(context, song.id),
                        onEdit: () => _navigateToEditSong(context, song),
                        onAddToPlaylist: () =>
                            _showAddToPlaylistDialog(context, [song.id]),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(songsListProvider);
    final isSearching = state.keyword.isNotEmpty;

    return EmptyState(
      icon: isSearching ? Icons.search_off : Icons.library_music,
      title: isSearching ? l10n.libraryNoMatchingSongs : l10n.libraryEmpty,
      subtitle: isSearching
          ? l10n.libraryTryOtherKeywords
          : l10n.libraryEmptyHint,
    );
  }

  void _onSongTap(Song song, int index) {
    final state = ref.read(songsListProvider);
    final notifier = ref.read(playerStateProvider.notifier);
    notifier.playPlaylist(state.songs, startIndex: index);
    if (state.hasMore) {
      notifier.loadRemainingSongsForCurrentPlaylist(
        keyword: state.keyword,
        type: state.type,
        loadedCount: state.songs.length,
        total: state.total,
      );
    }
  }

  void _navigateToAddSong(BuildContext context, String songType) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => SongEditPage(songType: songType)),
    );
    if (result == true) {
      ref.read(songsListProvider.notifier).refresh();
    }
  }

  void _navigateToEditSong(BuildContext context, dynamic song) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => SongEditPage(song: song, songType: song.type),
      ),
    );
    if (result == true) {
      ref.read(songsListProvider.notifier).refresh();
    }
  }

  Future<void> _showDeleteConfirmDialog(
    BuildContext context,
    int songId,
  ) async {
    final l10n = AppLocalizations.of(context);
    final result = await DeleteSongDialog.show(
      context,
      title: l10n.libraryDeleteConfirmTitle,
      content: l10n.libraryDeleteConfirmContent,
    );
    if (result != null) {
      await ref
          .read(songsListProvider.notifier)
          .deleteSong(songId, deleteFiles: result.deleteFiles);
    }
  }

  void _showCleanConfirmDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.libraryCleanTitle),
        content: Text(l10n.libraryCleanContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final cleaned = await ref
                  .read(songsListProvider.notifier)
                  .cleanSongs();
              if (context.mounted) {
                ResponsiveSnackBar.show(
                  context,
                  message: l10n.libraryCleanedCount(cleaned),
                );
              }
            },
            child: Text(l10n.libraryClean),
          ),
        ],
      ),
    );
  }

  void _showAddToPlaylistDialog(BuildContext context, List<int> songIds) {
    AddToPlaylistModal.show(context, songIds: songIds);
  }

  Future<void> _showBatchDeleteConfirmDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final count = ref.read(songsListProvider).selectedSongIds.length;
    final result = await DeleteSongDialog.show(
      context,
      title: l10n.libraryBatchDeleteTitle,
      content: l10n.libraryBatchDeleteContent(count),
    );
    if (result != null) {
      final deleted = await ref
          .read(songsListProvider.notifier)
          .batchDeleteSongs(deleteFiles: result.deleteFiles);
      if (context.mounted) {
        if (deleted > 0) {
          ResponsiveSnackBar.showSuccess(
            context,
            message: l10n.libraryDeletedCount(deleted),
          );
        } else {
          ResponsiveSnackBar.showError(
            context,
            message: l10n.libraryDeleteFailed,
          );
        }
      }
    }
  }
}
