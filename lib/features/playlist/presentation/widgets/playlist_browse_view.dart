import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/responsive.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/utils/responsive_snackbar.dart';
import '../../../../shared/widgets/browse_card.dart';
import '../../../../shared/widgets/browse_collection_view.dart';
import '../../../../shared/widgets/cover_image.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../domain/playlist.dart';
import '../providers/playlist_provider.dart';
import '../providers/playlist_view_provider.dart';
import 'playlist_card.dart';
import 'playlist_list_item.dart';
import 'playlist_form_dialog.dart';

/// 可嵌入的歌单浏览视图：搜索 + 通用卡片（grid/list）+ 分页 + 多选/排序/新建。
///
/// 由曲库页在「全部歌单 / 普通歌单 / 电台歌单」视图下嵌入使用，[typeFilter] 固定该视图的
/// 歌单 type（null=全部）。自带内容区顶部工具栏（不依赖外层 AppBar）。
class PlaylistBrowseView extends ConsumerStatefulWidget {
  final String? typeFilter;

  const PlaylistBrowseView({super.key, this.typeFilter});

  @override
  ConsumerState<PlaylistBrowseView> createState() => _PlaylistBrowseViewState();
}

class _PlaylistBrowseViewState extends ConsumerState<PlaylistBrowseView> {
  static const double _loadMoreThreshold = 300.0;

  late final ScrollController _scrollController;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _searchKeyword = '';

  bool _isSelectionMode = false;
  final Set<int> _selectedPlaylistIds = {};

  bool _isSortMode = false;
  List<Playlist> _sortablePlaylists = [];

  bool _showHidden = false;

  String? get _type => widget.typeFilter;

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

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _loadMoreThreshold) {
      ref.read(playlistListProvider(_type).notifier).loadMore();
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _searchKeyword = value.trim();
      ref.read(playlistListProvider(_type).notifier).search(_searchKeyword);
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    _searchKeyword = '';
    ref.read(playlistListProvider(_type).notifier).search('');
  }

  @override
  Widget build(BuildContext context) {
    final playlistsAsync = ref.watch(playlistListProvider(_type));

    if (_isSortMode) {
      return Column(
        children: [
          _buildSortToolbar(context),
          Expanded(child: _buildSortModeBody(context)),
        ],
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          children: [
            _buildToolbar(context, playlistsAsync.value),
            _buildSearchBar(context),
            Expanded(
              child: playlistsAsync.when(
                data: (state) => _buildContent(context, state),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (error, _) => ErrorView(
                  message: error.toString(),
                  onRetry: () => ref.invalidate(playlistListProvider(_type)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- 工具栏 ----------

  Widget _buildToolbar(BuildContext context, PaginatedPlaylistsState? state) {
    final l10n = AppLocalizations.of(context);
    final hp = context.responsive<double>(
      mobile: AppSpacing.md,
      tablet: AppSpacing.lg,
      desktop: AppSpacing.xl,
      tv: AppSpacing.xxl,
    );

    if (_isSelectionMode) {
      return Padding(
        padding: EdgeInsets.fromLTRB(hp, AppSpacing.sm, hp, 0),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: l10n.playlistExitMultiSelect,
              onPressed: _toggleSelectMode,
            ),
            Expanded(
              child: Text(
                l10n.playlistSelectedCount(_selectedPlaylistIds.length),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.play_arrow),
              tooltip: l10n.playlistPlayCount(_selectedPlaylistIds.length),
              onPressed:
                  _selectedPlaylistIds.isEmpty ? null : _playSelectedPlaylists,
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
              tooltip: l10n.playlistDeleteCount(_selectedPlaylistIds.length),
              onPressed: _selectedPlaylistIds.isEmpty ? null : _confirmBatchDelete,
            ),
            TextButton(
              onPressed: () async {
                await ref.read(playlistListProvider(_type).notifier).loadAll();
                final s = ref.read(playlistListProvider(_type)).value;
                if (s != null) _selectAll(s.items);
              },
              child: Text(l10n.selectAll),
            ),
          ],
        ),
      );
    }

    final playlists = state?.items ?? [];
    return Padding(
      padding: EdgeInsets.fromLTRB(hp, AppSpacing.sm, hp, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            icon: Icon(
              ref.watch(playlistViewModeProvider) == PlaylistViewMode.grid
                  ? Icons.view_list
                  : Icons.grid_view,
            ),
            tooltip: ref.watch(playlistViewModeProvider) == PlaylistViewMode.grid
                ? l10n.playlistSwitchToListView
                : l10n.playlistSwitchToGridView,
            onPressed: () =>
                ref.read(playlistViewModeProvider.notifier).toggleViewMode(),
          ),
          IconButton(
            icon: const Icon(Icons.checklist),
            tooltip: l10n.playlistMultiSelect,
            onPressed: _toggleSelectMode,
          ),
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
            itemBuilder: (context) => [
              _sortItem('name_asc', Icons.sort_by_alpha, l10n.playlistSortNameAsc),
              _sortItem(
                'name_desc',
                Icons.sort_by_alpha,
                l10n.playlistSortNameDesc,
              ),
              _sortItem(
                'number_asc',
                Icons.format_list_numbered,
                l10n.playlistSortNumberPrefix,
              ),
              _sortItem('manual', Icons.drag_handle, l10n.playlistSortManual),
            ],
          ),
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
                  leading: Icon(
                    _showHidden ? Icons.visibility_off : Icons.visibility,
                  ),
                  title: Text(
                    _showHidden ? l10n.playlistHideHidden : l10n.playlistShowHidden,
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _sortItem(String value, IconData icon, String title) {
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

  Widget _buildSortToolbar(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: l10n.commonCancel,
            onPressed: _cancelSortMode,
          ),
          Expanded(
            child: Text(
              l10n.playlistSortModeTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          TextButton(onPressed: _exitSortMode, child: Text(l10n.playlistDone)),
        ],
      ),
    );
  }

  // ---------- 搜索栏 ----------

  Widget _buildSearchBar(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hp = context.responsive<double>(
      mobile: AppSpacing.md,
      tablet: AppSpacing.lg,
      desktop: AppSpacing.xl,
      tv: AppSpacing.xxl,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(hp, AppSpacing.sm, hp, 0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: l10n.playlistListSearchHint,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
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
          setState(() {});
          _onSearchChanged(value);
        },
      ),
    );
  }

  // ---------- 内容 ----------

  Widget _buildContent(BuildContext context, PaginatedPlaylistsState state) {
    if (state.items.isEmpty) return _buildEmpty(context);

    final layout = ref.watch(playlistViewModeProvider) == PlaylistViewMode.list
        ? BrowseCardLayout.list
        : BrowseCardLayout.grid;
    final currentPlaylistId = ref.watch(sourcePlaylistIdProvider);
    final isPlaying = ref.watch(isPlayingProvider);

    return BrowseCollectionView(
      layout: layout,
      itemCount: state.items.length,
      scrollController: _scrollController,
      isLoadingMore: state.isLoadingMore,
      onRefresh: () async => ref.invalidate(playlistListProvider(_type)),
      cardBuilder: (context, index) {
        final playlist = state.items[index];
        final common = _PlaylistCardCallbacks(
          onTap: () => context.push('/playlists/${playlist.id}'),
          onEdit: () => _showEditDialog(playlist),
          onDelete: playlist.isBuiltIn ? null : () => _confirmDelete(playlist),
          onToggleVisibility: () => _togglePlaylistVisibility(playlist),
          onPlayAll: () => _playAll(playlist),
          onLongPress: () {
            setState(() {
              _isSelectionMode = true;
              _selectedPlaylistIds.clear();
            });
            _togglePlaylistSelection(playlist);
          },
          onSelect: () => _togglePlaylistSelection(playlist),
        );
        if (layout == BrowseCardLayout.list) {
          return PlaylistListItem(
            playlist: playlist,
            onTap: common.onTap,
            onEdit: common.onEdit,
            onDelete: common.onDelete,
            onToggleVisibility: common.onToggleVisibility,
            onPlayAll: common.onPlayAll,
            onLongPress: common.onLongPress,
            isSelectionMode: _isSelectionMode,
            isSelected: _selectedPlaylistIds.contains(playlist.id),
            onSelect: common.onSelect,
            isCurrentPlaylist: playlist.id == currentPlaylistId,
            isPlaying: isPlaying,
          );
        }
        return PlaylistCard(
          playlist: playlist,
          onTap: common.onTap,
          onEdit: common.onEdit,
          onDelete: common.onDelete,
          onToggleVisibility: common.onToggleVisibility,
          onPlayAll: common.onPlayAll,
          onLongPress: common.onLongPress,
          isSelectionMode: _isSelectionMode,
          isSelected: _selectedPlaylistIds.contains(playlist.id),
          onSelect: common.onSelect,
          isCurrentPlaylist: playlist.id == currentPlaylistId,
          isPlaying: isPlaying,
        );
      },
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isSearching = _searchKeyword.isNotEmpty;
    return EmptyState(
      icon: isSearching ? Icons.search_off : Icons.queue_music_outlined,
      title: isSearching ? l10n.playlistNoMatching : l10n.noPlaylists,
      subtitle:
          isSearching ? l10n.playlistTryOtherKeywords : l10n.playlistEmptyHint,
    );
  }

  // ---------- 排序模式 ----------

  Widget _buildSortModeBody(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
                CoverImage(
                  coverUrl: playlist.coverImageUrl,
                  size: 48,
                  placeholderIcon:
                      playlist.type == 'radio' ? Icons.radio : Icons.queue_music,
                ),
                const SizedBox(width: 12),
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

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _sortablePlaylists.removeAt(oldIndex);
      _sortablePlaylists.insert(newIndex, item);
    });
  }

  // ---------- 选择 / 排序 / CRUD 逻辑（自 PlaylistsPage 迁移） ----------

  void _toggleSelectMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) _selectedPlaylistIds.clear();
    });
  }

  void _togglePlaylistSelection(Playlist playlist) {
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

  Future<void> _enterSortMode(List<Playlist> playlists) async {
    await ref.read(playlistListProvider(_type).notifier).loadAll();
    if (!mounted) return;
    final full = ref.read(playlistListProvider(_type)).value?.items ?? playlists;
    setState(() {
      _isSortMode = true;
      _isSelectionMode = false;
      _selectedPlaylistIds.clear();
      _sortablePlaylists = List.from(full);
    });
  }

  Future<void> _exitSortMode() async {
    final playlistIds = _sortablePlaylists.map((p) => p.id).toList();
    setState(() => _isSortMode = false);
    final success = await ref
        .read(playlistNotifierProvider.notifier)
        .reorderPlaylists(playlistIds);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    if (success) {
      ResponsiveSnackBar.showSuccess(context, message: l10n.playlistSortSaved);
    } else {
      ResponsiveSnackBar.showError(
        context,
        message: l10n.playlistSortSaveFailed,
      );
    }
  }

  void _cancelSortMode() {
    setState(() {
      _isSortMode = false;
      _sortablePlaylists = [];
    });
  }

  Future<void> _autoSortByName(
    List<Playlist> playlists, {
    bool ascending = true,
  }) async {
    await ref.read(playlistListProvider(_type).notifier).loadAll();
    if (!mounted) return;
    final full = ref.read(playlistListProvider(_type)).value?.items ?? playlists;
    final sorted = List<Playlist>.from(full)..sort((a, b) {
      final r = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return ascending ? r : -r;
    });
    await _applyReorder(
      sorted,
      full,
      ascending ? _L.nameAsc : _L.nameDesc,
    );
  }

  int? _extractFirstNumber(String title) {
    final match = RegExp(r'(\d+)').firstMatch(title);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  Future<void> _autoSortByNumberPrefix(List<Playlist> playlists) async {
    await ref.read(playlistListProvider(_type).notifier).loadAll();
    if (!mounted) return;
    final full = ref.read(playlistListProvider(_type)).value?.items ?? playlists;
    final sorted = List<Playlist>.from(full)..sort((a, b) {
      final numA = _extractFirstNumber(a.name);
      final numB = _extractFirstNumber(b.name);
      if (numA != null && numB != null) {
        final cmp = numA.compareTo(numB);
        if (cmp != 0) return cmp;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      if (numA != null) return -1;
      if (numB != null) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    await _applyReorder(sorted, full, _L.number);
  }

  Future<void> _applyReorder(
    List<Playlist> sorted,
    List<Playlist> original,
    _L kind,
  ) async {
    final playlistIds = sorted.map((p) => p.id).toList();
    final l10n = AppLocalizations.of(context);
    if (listEquals(playlistIds, original.map((p) => p.id).toList())) {
      ResponsiveSnackBar.show(
        context,
        message: l10n.playlistAlreadySortedPlaylists,
      );
      return;
    }
    final success = await ref
        .read(playlistNotifierProvider.notifier)
        .reorderPlaylists(playlistIds);
    if (!mounted) return;
    if (success) {
      final msg = switch (kind) {
        _L.nameAsc => l10n.playlistSortedByNameAsc,
        _L.nameDesc => l10n.playlistSortedByNameDesc,
        _L.number => l10n.playlistSortedByNumber,
      };
      ResponsiveSnackBar.showSuccess(context, message: msg);
    } else {
      ResponsiveSnackBar.showError(context, message: l10n.playlistSortFailed);
    }
  }

  void _toggleShowHidden() {
    setState(() => _showHidden = !_showHidden);
    ref
        .read(playlistListProvider(_type).notifier)
        .setExcludeLabels(_showHidden ? 'none' : null);
  }

  Future<void> _togglePlaylistVisibility(Playlist playlist) async {
    final hidden = !playlist.isHidden;
    final success = await ref
        .read(playlistNotifierProvider.notifier)
        .setPlaylistVisibility(playlist.id, hidden: hidden);
    if (success && mounted) {
      final l10n = AppLocalizations.of(context);
      ResponsiveSnackBar.showSuccess(
        context,
        message: hidden ? l10n.playlistHidden : l10n.playlistUnhidden,
      );
    }
  }

  Future<void> _showCreateDialog() async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => PlaylistFormDialog(title: l10n.playlistCreate),
    );
    if (result != null && mounted) {
      final playlist = await ref
          .read(playlistNotifierProvider.notifier)
          .createPlaylist(
            type: result['type'] as String,
            name: result['name'] as String,
            description: result['description'] as String?,
          );
      if (playlist != null && mounted) {
        ResponsiveSnackBar.showSuccess(context, message: l10n.playlistCreated);
      }
    }
  }

  Future<void> _showEditDialog(Playlist playlist) async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => PlaylistFormDialog(
        title: playlist.isBuiltIn
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
    if (result == null || !mounted) return;

    final notifier = ref.read(playlistNotifierProvider.notifier);
    final coverMode = result['coverMode'] as String?;
    final localFile = result['localFile'] as PlatformFile?;
    final selectedCoverSongId = result['selectedCoverSongId'] as int?;

    if (coverMode == 'local' && localFile != null) {
      final uploaded = await notifier.uploadPlaylistCover(
        playlist.id,
        bytes: localFile.bytes,
        filePath: localFile.path,
        fileName: localFile.name,
      );
      if (uploaded == null && mounted) {
        ResponsiveSnackBar.showError(
          context,
          message: l10n.playlistCoverUploadFailed,
        );
        return;
      }
      final updated = await notifier.updatePlaylist(
        playlist.id,
        name: result['name'] as String,
        description: result['description'] as String?,
        coverUrl: uploaded?.coverUrl,
      );
      if (updated != null && mounted) {
        ResponsiveSnackBar.showSuccess(context, message: l10n.playlistUpdated);
      }
    } else if (coverMode == 'song' && selectedCoverSongId != null) {
      final updated = await notifier.updatePlaylist(
        playlist.id,
        name: result['name'] as String,
        description: result['description'] as String?,
        coverSongId: selectedCoverSongId,
      );
      if (updated != null && mounted) {
        ResponsiveSnackBar.showSuccess(context, message: l10n.playlistUpdated);
      }
    } else if (coverMode == 'clear') {
      final updated = await notifier.updatePlaylist(
        playlist.id,
        name: result['name'] as String,
        description: result['description'] as String?,
        coverPath: '',
        coverUrl: '',
      );
      if (updated != null && mounted) {
        ResponsiveSnackBar.showSuccess(context, message: l10n.playlistUpdated);
      }
    } else {
      final updated = await notifier.updatePlaylist(
        playlist.id,
        name: result['name'] as String,
        description: result['description'] as String?,
      );
      if (updated != null && mounted) {
        ResponsiveSnackBar.showSuccess(context, message: l10n.playlistUpdated);
      }
    }
  }

  Future<void> _confirmBatchDelete() async {
    final count = _selectedPlaylistIds.length;
    if (count == 0) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
      final deleted = await ref
          .read(playlistNotifierProvider.notifier)
          .batchDeletePlaylists(_selectedPlaylistIds.toList());
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

  Future<void> _confirmDelete(Playlist playlist) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
      final success = await ref
          .read(playlistNotifierProvider.notifier)
          .deletePlaylist(playlist.id);
      if (success && mounted) {
        ResponsiveSnackBar.showSuccess(context, message: l10n.playlistDeleted);
      }
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

/// 自动排序类型（决定成功提示文案）。
enum _L { nameAsc, nameDesc, number }

/// 一组卡片回调，减少 grid/list 两分支的重复。
class _PlaylistCardCallbacks {
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;
  final VoidCallback onToggleVisibility;
  final VoidCallback onPlayAll;
  final VoidCallback onLongPress;
  final VoidCallback onSelect;

  const _PlaylistCardCallbacks({
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleVisibility,
    required this.onPlayAll,
    required this.onLongPress,
    required this.onSelect,
  });
}
