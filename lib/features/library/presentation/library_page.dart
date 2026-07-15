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
      _draftViews = List.of(config.views);
    });
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

    final isFlat = selected != null && isFlatLibraryView(selected);

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
        _buildMoreMenu(context, state),
        IconButton(
          icon: const Icon(Icons.tune),
          tooltip: l10n.libraryCustomizeViewsTooltip,
          onPressed: () => _enterEditMode(config),
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

  Widget _buildMoreMenu(BuildContext context, SongsListState state) {
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
        }
      },
      itemBuilder: (context) => [
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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ReorderableListView.builder(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: AppSpacing.sm,
          ),
          buildDefaultDragHandles: false,
          itemCount: _draftViews.length,
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (newIndex > oldIndex) newIndex--;
              final item = _draftViews.removeAt(oldIndex);
              _draftViews.insert(newIndex, item);
            });
          },
          itemBuilder: (context, index) {
            final v = _draftViews[index];
            return ListTile(
              key: ValueKey(v.key),
              leading: Icon(libraryViewIcon(v.key)),
              title: Text(libraryViewLabel(l10n, v.key)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: v.visible,
                    onChanged: (val) {
                      setState(() {
                        _draftViews[index] = v.copyWith(visible: val);
                      });
                    },
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
      ),
    );
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
