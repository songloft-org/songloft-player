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
/// 歌单 type（null=全部）。**工具栏由曲库顶部 AppBar 驱动**：本视图仅渲染搜索 + 内容
/// （多选/排序模式下切换内容形态），通过公共方法/getter 暴露操作，模式变化经
/// [onModeChanged] 通知父级重建 AppBar。
class PlaylistBrowseView extends ConsumerStatefulWidget {
  final String? typeFilter;

  /// 多选/排序等模式或选中数变化时回调，供父级(曲库页)重建顶部 AppBar。
  final VoidCallback? onModeChanged;

  const PlaylistBrowseView({super.key, this.typeFilter, this.onModeChanged});

  @override
  ConsumerState<PlaylistBrowseView> createState() => PlaylistBrowseViewState();
}

class PlaylistBrowseViewState extends ConsumerState<PlaylistBrowseView> {
  static const double _loadMoreThreshold = 300.0;

  late final ScrollController _scrollController;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _searchKeyword = '';

  bool _isSelectionMode = false;
  final Set<int> _selectedPlaylistIds = {};

  bool _isSortMode = false;
  List<Playlist> _sortablePlaylists = [];

  bool _showHiddenState = false;

  String? get _type => widget.typeFilter;

  // ---------- 供父级 AppBar 读取的状态 ----------
  bool get isSelectionMode => _isSelectionMode;
  bool get isSortMode => _isSortMode;
  int get selectedCount => _selectedPlaylistIds.length;
  bool get showHidden => _showHiddenState;

  void _notify() => widget.onModeChanged?.call();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant PlaylistBrowseView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 切换歌单子视图（全部/普通/电台）时重置交互态与搜索。
    if (oldWidget.typeFilter != widget.typeFilter) {
      _searchDebounce?.cancel();
      _searchController.clear();
      _searchKeyword = '';
      _isSelectionMode = false;
      _selectedPlaylistIds.clear();
      _isSortMode = false;
      _sortablePlaylists = [];
      _notify();
    }
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
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: _buildSortModeBody(context),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          children: [
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
        void onTap() => context.push('/playlists/${playlist.id}');
        void onEdit() => _showEditDialog(playlist);
        final VoidCallback? onDelete =
            playlist.isBuiltIn ? null : () => _confirmDelete(playlist);
        void onToggleVisibility() => _togglePlaylistVisibility(playlist);
        void onPlayAll() => _playAll(playlist);
        void onLongPress() {
          setState(() {
            _isSelectionMode = true;
            _selectedPlaylistIds.clear();
          });
          _togglePlaylistSelection(playlist);
        }

        void onSelect() => _togglePlaylistSelection(playlist);
        final isSelected = _selectedPlaylistIds.contains(playlist.id);
        final isCurrent = playlist.id == currentPlaylistId;

        if (layout == BrowseCardLayout.list) {
          return PlaylistListItem(
            playlist: playlist,
            onTap: onTap,
            onEdit: onEdit,
            onDelete: onDelete,
            onToggleVisibility: onToggleVisibility,
            onPlayAll: onPlayAll,
            onLongPress: onLongPress,
            isSelectionMode: _isSelectionMode,
            isSelected: isSelected,
            onSelect: onSelect,
            isCurrentPlaylist: isCurrent,
            isPlaying: isPlaying,
          );
        }
        return PlaylistCard(
          playlist: playlist,
          onTap: onTap,
          onEdit: onEdit,
          onDelete: onDelete,
          onToggleVisibility: onToggleVisibility,
          onPlayAll: onPlayAll,
          onLongPress: onLongPress,
          isSelectionMode: _isSelectionMode,
          isSelected: isSelected,
          onSelect: onSelect,
          isCurrentPlaylist: isCurrent,
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

  // ---------- 排序模式内容 ----------

  Widget _buildSortModeBody(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_sortablePlaylists.isEmpty) {
      return Center(child: Text(l10n.noPlaylists));
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

  // ---------- 公共操作（由父级 AppBar 调用） ----------

  void enterSelectionMode() {
    setState(() {
      _isSelectionMode = true;
      _selectedPlaylistIds.clear();
    });
    _notify();
  }

  void exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedPlaylistIds.clear();
    });
    _notify();
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
    _notify();
  }

  Future<void> selectAllInSelection() async {
    await ref.read(playlistListProvider(_type).notifier).loadAll();
    if (!mounted) return;
    final playlists = ref.read(playlistListProvider(_type)).value?.items ?? [];
    setState(() {
      final selectableIds =
          playlists.where((p) => !p.isBuiltIn).map((p) => p.id).toSet();
      if (_selectedPlaylistIds.containsAll(selectableIds)) {
        _selectedPlaylistIds.clear();
      } else {
        _selectedPlaylistIds.addAll(selectableIds);
      }
    });
    _notify();
  }

  Future<void> enterSortMode() async {
    await ref.read(playlistListProvider(_type).notifier).loadAll();
    if (!mounted) return;
    final full = ref.read(playlistListProvider(_type)).value?.items ?? [];
    setState(() {
      _isSortMode = true;
      _isSelectionMode = false;
      _selectedPlaylistIds.clear();
      _sortablePlaylists = List.from(full);
    });
    _notify();
  }

  Future<void> saveSortMode() async {
    final playlistIds = _sortablePlaylists.map((p) => p.id).toList();
    setState(() => _isSortMode = false);
    _notify();
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

  void cancelSortMode() {
    setState(() {
      _isSortMode = false;
      _sortablePlaylists = [];
    });
    _notify();
  }

  Future<void> autoSortByName({bool ascending = true}) async {
    await ref.read(playlistListProvider(_type).notifier).loadAll();
    if (!mounted) return;
    final full = ref.read(playlistListProvider(_type)).value?.items ?? [];
    final sorted = List<Playlist>.from(full)..sort((a, b) {
      final r = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return ascending ? r : -r;
    });
    await _applyReorder(sorted, full, ascending ? _L.nameAsc : _L.nameDesc);
  }

  int? _extractFirstNumber(String title) {
    final match = RegExp(r'(\d+)').firstMatch(title);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  Future<void> autoSortByNumberPrefix() async {
    await ref.read(playlistListProvider(_type).notifier).loadAll();
    if (!mounted) return;
    final full = ref.read(playlistListProvider(_type)).value?.items ?? [];
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

  void toggleShowHidden() {
    setState(() => _showHiddenState = !_showHiddenState);
    _notify();
    ref
        .read(playlistListProvider(_type).notifier)
        .setExcludeLabels(_showHiddenState ? 'none' : null);
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

  Future<void> createPlaylist() async {
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

  Future<void> deleteSelected() async {
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
        _notify();
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

  Future<void> playSelected() async {
    final ids = _selectedPlaylistIds.toList();
    exitSelectionMode();
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
