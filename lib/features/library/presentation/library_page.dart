import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/constants.dart';
import '../../../core/router/app_router.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/responsive.dart';
import '../../../shared/models/song.dart';
import '../../../shared/utils/responsive_snackbar.dart';
import '../../../shared/widgets/add_to_playlist_modal.dart';
import '../../../shared/widgets/delete_song_dialog.dart';
import '../../player/presentation/providers/player_provider.dart';
import 'providers/songs_provider.dart';
import 'song_edit_page.dart';
import 'widgets/song_filter_bar.dart';
import 'widgets/song_list_tile.dart';

/// 歌曲库页面
class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // 初始加载
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(songsListProvider.notifier).loadSongs();
    });
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
      ResponsiveSnackBar.show(context, message: l10n.libraryPlayingAllSongs(total));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(songsListProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: _buildAppBar(context, state),
      body: Column(
        children: [
          // 搜索栏
          _buildSearchBar(context),
          // 类型筛选栏
          SongFilterBar(
            currentType: state.type,
            onTypeChanged: (type) {
              ref.read(songsListProvider.notifier).setTypeFilter(type);
            },
            songCount: state.total,
          ),
          // 错误提示
          if (state.error != null)
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
                    icon: Icon(
                      Icons.close,
                      color: colorScheme.onErrorContainer,
                    ),
                    tooltip: AppLocalizations.of(context).libraryDismissError,
                    onPressed: () {
                      ref.read(songsListProvider.notifier).clearError();
                    },
                  ),
                ],
              ),
            ),
          // 歌曲列表
          Expanded(child: _buildSongList(context, state)),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, SongsListState state) {
    final l10n = AppLocalizations.of(context);
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
            onPressed:
                state.selectedSongIds.isEmpty
                    ? null
                    : () => _showAddToPlaylistDialog(
                      context,
                      state.selectedSongIds.toList(),
                    ),
          ),
          TextButton.icon(
            icon: Icon(
              Icons.delete,
              color:
                  state.selectedSongIds.isEmpty
                      ? null
                      : Theme.of(context).colorScheme.error,
            ),
            label: Text(
              l10n.libraryDeleteWithCount(state.selectedSongIds.length),
              style: TextStyle(
                color:
                    state.selectedSongIds.isEmpty
                        ? null
                        : Theme.of(context).colorScheme.error,
              ),
            ),
            onPressed:
                state.selectedSongIds.isEmpty
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

    return AppBar(
      title: Text(l10n.libraryTitle),
      actions: [
        // 分类浏览
        IconButton(
          icon: const Icon(Icons.category_outlined),
          tooltip: '分类浏览',
          onPressed: () => context.push(AppRoutes.libraryCategories),
        ),
        // 播放全部
        IconButton(
          icon: const Icon(Icons.play_circle_outline),
          tooltip: l10n.libraryPlayAll,
          onPressed: state.songs.isEmpty ? null : () => _playAll(state),
        ),
        // 排序
        PopupMenuButton<String>(
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
          itemBuilder:
              (context) => [
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
        ),
        // 多选按钮
        IconButton(
          icon: const Icon(Icons.checklist),
          tooltip: l10n.librarySelectMode,
          onPressed: () {
            ref.read(songsListProvider.notifier).toggleSelectMode();
          },
        ),
        // 更多菜单
        PopupMenuButton<String>(
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
          itemBuilder:
              (context) => [
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
                      state.showHidden
                          ? Icons.visibility_off
                          : Icons.visibility,
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
        ),
      ],
    );
  }

  PopupMenuItem<String> _buildLibrarySortItem({
    required String value,
    required IconData icon,
    required String title,
    required bool isSelected,
  }) {
    final color =
        isSelected ? Theme.of(context).colorScheme.primary : null;
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
          suffixIcon:
              _searchController.text.isNotEmpty
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
            // 使用实际可用宽度判断，避免在窄容器中溢出
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
            // 表头
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                  const SizedBox(width: 64), // 封面空间 (12+40+12 匹配数据行)
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
                  const SizedBox(
                    width: kDesktopActionsWidth,
                  ), // 操作按钮空间，与行内操作列对齐
                ],
              ),
            ),
            // 列表
            Expanded(
              child: ListView.builder(
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
                    onDelete: () => _showDeleteConfirmDialog(context, song.id),
                    onEdit: () => _navigateToEditSong(context, song),
                    onAddToPlaylist:
                        () => _showAddToPlaylistDialog(context, [song.id]),
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
    final colorScheme = Theme.of(context).colorScheme;
    final state = ref.watch(songsListProvider);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: AppRadius.xlAll,
            ),
            child: Icon(
              state.keyword.isNotEmpty ? Icons.search_off : Icons.library_music,
              size: 48,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            state.keyword.isNotEmpty
                ? l10n.libraryNoMatchingSongs
                : l10n.libraryEmpty,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            state.keyword.isNotEmpty
                ? l10n.libraryTryOtherKeywords
                : l10n.libraryEmptyHint,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
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

  Future<void> _showDeleteConfirmDialog(BuildContext context, int songId) async {
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
      builder:
          (context) => AlertDialog(
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
                  final cleaned =
                      await ref.read(songsListProvider.notifier).cleanSongs();
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
