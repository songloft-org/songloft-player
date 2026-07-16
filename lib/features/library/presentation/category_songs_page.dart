import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../shared/models/song.dart';
import '../../../shared/utils/responsive_snackbar.dart';
import '../../../shared/widgets/add_to_playlist_modal.dart';
import '../../../shared/widgets/delete_song_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/entity_detail_scaffold.dart';
import '../../../shared/mixins/song_list_actions.dart';
import '../../../l10n/app_localizations.dart';
import '../../player/presentation/providers/player_provider.dart';
import '../../playlist/presentation/providers/playlist_provider.dart'
    show PaginatedSongsState;
import 'providers/category_provider.dart';
import 'providers/songs_provider.dart';
import 'song_edit_page.dart';
import 'widgets/library_view_switcher.dart';
import 'widgets/song_list_tile.dart';

/// 某分类（歌手 / 专辑 / 流派…）下的歌曲详情页：复用通用 [EntityDetailScaffold]，
/// 呈现封面 header + 调色板渐变 + 「播放全部」+ 歌曲列表，风格对齐歌单详情页。
class CategorySongsPage extends ConsumerStatefulWidget {
  final String field;
  final String value;
  final String? coverUrl;

  const CategorySongsPage({
    super.key,
    required this.field,
    required this.value,
    this.coverUrl,
  });

  @override
  ConsumerState<CategorySongsPage> createState() => _CategorySongsPageState();
}

class _CategorySongsPageState extends ConsumerState<CategorySongsPage>
    with SongListActions {
  final _scrollController = ScrollController();

  bool _isSelectMode = false;
  final Set<int> _selectedIds = {};

  ({String field, String value}) get _key =>
      (field: widget.field, value: widget.value);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isSelectMode) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(categorySongsProvider(_key).notifier).loadMore();
    }
  }

  void _onSongTap(List<Song> songs, int index) {
    ref.read(playerStateProvider.notifier).playPlaylist(songs, startIndex: index);
  }

  Future<void> _playAll() async {
    final l10n = AppLocalizations.of(context);
    await ref.read(categorySongsProvider(_key).notifier).loadAll();
    if (!mounted) return;
    final songs = ref.read(categorySongsProvider(_key)).value?.items ?? [];
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

  void _enterSelectMode() {
    setState(() {
      _isSelectMode = true;
      _selectedIds.clear();
    });
  }

  void _exitSelectMode() {
    setState(() {
      _isSelectMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(int songId) {
    setState(() {
      if (_selectedIds.contains(songId)) {
        _selectedIds.remove(songId);
      } else {
        _selectedIds.add(songId);
      }
    });
  }

  Future<void> _toggleSelectAll() async {
    await ref.read(categorySongsProvider(_key).notifier).loadAll();
    if (!mounted) return;
    final songs = ref.read(categorySongsProvider(_key)).value?.items ?? [];
    setState(() {
      if (_selectedIds.length >= songs.length) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(songs.map((s) => s.id));
      }
    });
  }

  Future<void> _batchDelete() async {
    if (_selectedIds.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final count = _selectedIds.length;
    final ids = _selectedIds.toList();
    final result = await DeleteSongDialog.show(
      context,
      title: l10n.libraryBatchDeleteTitle,
      content: l10n.libraryBatchDeleteContent(count),
    );
    if (result == null || !mounted) return;

    try {
      final deleted = await ref
          .read(songsApiProvider)
          .batchDeleteSongs(ids, deleteFiles: result.deleteFiles);
      ref.invalidate(categorySongsProvider(_key));
      ref.invalidate(songsListProvider);
      removeDeletedSongsFromPlayerQueue(ids.toSet());
      _exitSelectMode();
      if (mounted) {
        ResponsiveSnackBar.showSuccess(
          context,
          message: l10n.libraryDeletedCount(deleted),
        );
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(context, message: l10n.libraryDeleteFailed);
      }
    }
  }

  void _addSelectedToPlaylist() {
    if (_selectedIds.isEmpty) return;
    AddToPlaylistModal.show(context, songIds: _selectedIds.toList());
  }

  Future<void> _deleteSong(int songId) async {
    final l10n = AppLocalizations.of(context);
    final result = await DeleteSongDialog.show(
      context,
      title: l10n.libraryDeleteConfirmTitle,
      content: l10n.libraryDeleteConfirmContent,
    );
    if (result == null || !mounted) return;
    try {
      await ref
          .read(songsApiProvider)
          .deleteSong(songId, deleteFiles: result.deleteFiles);
      ref.invalidate(categorySongsProvider(_key));
      ref.invalidate(songsListProvider);
      removeDeletedSongsFromPlayerQueue({songId});
      if (mounted) {
        ResponsiveSnackBar.showSuccess(context, message: l10n.playlistSongDeleted);
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(context, message: l10n.libraryDeleteFailed);
      }
    }
  }

  Future<void> _navigateToEditSong(Song song) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => SongEditPage(song: song, songType: song.type),
      ),
    );
    if (result == true) {
      ref.invalidate(categorySongsProvider(_key));
      ref.invalidate(songsListProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final songsAsync = ref.watch(categorySongsProvider(_key));
    final state = songsAsync.value;
    final songCount = state?.items.length ?? 0;
    final total = state?.total ?? songCount;
    final colorScheme = Theme.of(context).colorScheme;

    return EntityDetailScaffold(
      scrollController: _scrollController,
      coverUrl: widget.coverUrl,
      placeholderIcon: libraryViewIcon(widget.field),
      onBack: () => Navigator.of(context).maybePop(),
      onRefresh: () async => ref.invalidate(categorySongsProvider(_key)),
      titleWidget: Text(
        _isSelectMode
            ? l10n.librarySelectedCount(_selectedIds.length)
            : categoryValueLabel(l10n, widget.field, widget.value),
      ),
      leading: _isSelectMode
          ? IconButton(
              icon: const Icon(Icons.close),
              tooltip: l10n.libraryExitSelection,
              onPressed: _exitSelectMode,
            )
          : null,
      subtitle: _isSelectMode
          ? null
          : '${categoryFieldLabel(l10n, widget.field)} · '
              '${l10n.categorySongCount(total)}',
      appBarActions: _isSelectMode
          ? [
              TextButton.icon(
                icon: const Icon(Icons.playlist_add),
                label: Text(l10n.addToPlaylist),
                onPressed:
                    _selectedIds.isEmpty ? null : _addSelectedToPlaylist,
              ),
              TextButton.icon(
                icon: Icon(
                  Icons.delete,
                  color: _selectedIds.isEmpty ? null : colorScheme.error,
                ),
                label: Text(
                  l10n.libraryDeleteWithCount(_selectedIds.length),
                  style: TextStyle(
                    color: _selectedIds.isEmpty ? null : colorScheme.error,
                  ),
                ),
                onPressed: _selectedIds.isEmpty ? null : _batchDelete,
              ),
              TextButton(
                onPressed: _toggleSelectAll,
                child: Text(
                  (total > 0 && _selectedIds.length >= total)
                      ? l10n.libraryDeselectAll
                      : l10n.selectAll,
                ),
              ),
            ]
          : [
              IconButton(
                icon: const Icon(Icons.checklist),
                tooltip: l10n.librarySelectMode,
                onPressed: songCount == 0 ? null : _enterSelectMode,
              ),
            ],
      actionButtons: _isSelectMode
          ? null
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: songCount == 0 ? null : _playAll,
                      icon: const Icon(Icons.play_arrow),
                      label: Text(l10n.libraryPlayAll),
                    ),
                  ),
                ],
              ),
            ),
      bodySlivers: _buildBodySlivers(context, songsAsync),
    );
  }

  List<Widget> _buildBodySlivers(
    BuildContext context,
    AsyncValue<PaginatedSongsState> songsAsync,
  ) {
    return songsAsync.when(
      data: (state) {
        if (state.items.isEmpty) {
          return [
            SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.music_off_outlined,
                title: AppLocalizations.of(context).categorySongsEmpty,
              ),
            ),
          ];
        }
        final currentSong = ref.watch(currentSongProvider);
        final songs = state.items;
        return [
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final song = songs[index];
              return SongListTile(
                song: song,
                index: index,
                isSelected: _selectedIds.contains(song.id),
                isSelectionMode: _isSelectMode,
                isCurrentSong: currentSong?.id == song.id,
                onTap: _isSelectMode
                    ? () => _toggleSelection(song.id)
                    : () => _onSongTap(songs, index),
                onLongPress: () {
                  if (!_isSelectMode) _enterSelectMode();
                  _toggleSelection(song.id);
                },
                onSelect: () => _toggleSelection(song.id),
                onDelete: () => _deleteSong(song.id),
                onEdit: () => _navigateToEditSong(song),
                onAddToPlaylist: () =>
                    AddToPlaylistModal.show(context, songIds: [song.id]),
              );
            }, childCount: songs.length),
          ),
          if (state.isLoadingMore)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.of(context).padding.bottom + 80),
          ),
        ];
      },
      loading: () => const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ],
      error: (error, _) => [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Center(child: Text(error.toString())),
          ),
        ),
      ],
    );
  }
}
