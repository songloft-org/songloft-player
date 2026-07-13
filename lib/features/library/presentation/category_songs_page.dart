import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/song.dart';
import '../../../shared/utils/responsive_snackbar.dart';
import '../../../shared/widgets/add_to_playlist_modal.dart';
import '../../../shared/widgets/delete_song_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/mixins/song_list_actions.dart';
import '../../player/presentation/providers/player_provider.dart';
import '../../playlist/presentation/providers/playlist_provider.dart'
    show PaginatedSongsState;
import 'providers/category_provider.dart';
import 'providers/songs_provider.dart';
import 'song_edit_page.dart';
import 'widgets/song_list_tile.dart';

/// 某分类下的歌曲列表页：复用 SongListTile、分页、可播放，
/// 顶部提供「播放全部」与「多选」（批量删除 / 加入歌单），参考曲库实现。
class CategorySongsPage extends ConsumerStatefulWidget {
  final String field;
  final String value;

  const CategorySongsPage({
    super.key,
    required this.field,
    required this.value,
  });

  @override
  ConsumerState<CategorySongsPage> createState() => _CategorySongsPageState();
}

class _CategorySongsPageState extends ConsumerState<CategorySongsPage>
    with SongListActions {
  final _scrollController = ScrollController();

  /// 多选模式
  bool _isSelectMode = false;

  /// 多选模式下选中的歌曲 ID
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
    if (_isSelectMode) return; // 多选模式下不触发分页加载
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(categorySongsProvider(_key).notifier).loadMore();
    }
  }

  void _onSongTap(List<Song> songs, int index) {
    ref
        .read(playerStateProvider.notifier)
        .playPlaylist(songs, startIndex: index);
  }

  /// 播放当前分类下的全部歌曲（先加载全部再播放）
  Future<void> _playAll() async {
    await ref.read(categorySongsProvider(_key).notifier).loadAll();
    if (!mounted) return;
    final songs = ref.read(categorySongsProvider(_key)).value?.items ?? [];
    if (songs.isEmpty) {
      ResponsiveSnackBar.show(context, message: '该分类下暂无歌曲');
      return;
    }
    ref.read(playerStateProvider.notifier).playPlaylist(songs, startIndex: 0);
    if (!mounted) return;
    ResponsiveSnackBar.show(context, message: '开始播放 ${songs.length} 首歌曲');
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

  /// 全选 / 取消全选（需要整个分类在内存中）
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
    final count = _selectedIds.length;
    final ids = _selectedIds.toList();
    final result = await DeleteSongDialog.show(
      context,
      title: '批量删除歌曲',
      content: '确定要删除选中的 $count 首歌曲吗？',
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
        ResponsiveSnackBar.showSuccess(context, message: '已删除 $deleted 首歌曲');
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(context, message: '删除失败');
      }
    }
  }

  void _addSelectedToPlaylist() {
    if (_selectedIds.isEmpty) return;
    AddToPlaylistModal.show(context, songIds: _selectedIds.toList());
  }

  Future<void> _deleteSong(int songId) async {
    final result = await DeleteSongDialog.show(
      context,
      title: '删除歌曲',
      content: '确定要删除这首歌曲吗？',
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
        ResponsiveSnackBar.showSuccess(context, message: '已删除');
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(context, message: '删除失败');
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
    final songsAsync = ref.watch(categorySongsProvider(_key));

    return Scaffold(
      appBar: _buildAppBar(context, songsAsync.value),
      body: songsAsync.when(
        data: (state) => _buildList(context, state),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildError(context, error.toString()),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    PaginatedSongsState? state,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final songCount = state?.items.length ?? 0;
    final total = state?.total ?? songCount;

    if (_isSelectMode) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: '退出多选',
          onPressed: _exitSelectMode,
        ),
        title: Text('已选 ${_selectedIds.length} 首'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.playlist_add),
            label: const Text('加入歌单'),
            onPressed: _selectedIds.isEmpty ? null : _addSelectedToPlaylist,
          ),
          TextButton.icon(
            icon: Icon(
              Icons.delete,
              color: _selectedIds.isEmpty ? null : colorScheme.error,
            ),
            label: Text(
              '删除',
              style: TextStyle(
                color: _selectedIds.isEmpty ? null : colorScheme.error,
              ),
            ),
            onPressed: _selectedIds.isEmpty ? null : _batchDelete,
          ),
          TextButton(
            onPressed: _toggleSelectAll,
            child: Text(
              (total > 0 && _selectedIds.length >= total) ? '取消全选' : '全选',
            ),
          ),
        ],
      );
    }

    final title =
        '${categoryFieldLabel(widget.field)} · '
        '${categoryValueLabel(widget.field, widget.value)}';
    return AppBar(
      title: Text(title),
      actions: [
        // 播放全部
        IconButton(
          icon: const Icon(Icons.play_circle_outline),
          tooltip: '播放全部',
          onPressed: songCount == 0 ? null : _playAll,
        ),
        // 多选
        IconButton(
          icon: const Icon(Icons.checklist),
          tooltip: '多选',
          onPressed: songCount == 0 ? null : _enterSelectMode,
        ),
      ],
    );
  }

  Widget _buildList(BuildContext context, PaginatedSongsState state) {
    if (state.items.isEmpty) {
      return _buildEmpty(context);
    }

    final currentSong = ref.watch(currentSongProvider);
    final songs = state.items;

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(categorySongsProvider(_key)),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: songs.length + (state.isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= songs.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              final song = songs[index];
              return SongListTile(
                song: song,
                index: index,
                isSelected: _selectedIds.contains(song.id),
                isSelectionMode: _isSelectMode,
                isCurrentSong: currentSong?.id == song.id,
                onTap:
                    _isSelectMode
                        ? () => _toggleSelection(song.id)
                        : () => _onSongTap(songs, index),
                onLongPress: () {
                  if (!_isSelectMode) _enterSelectMode();
                  _toggleSelection(song.id);
                },
                onSelect: () => _toggleSelection(song.id),
                onDelete: () => _deleteSong(song.id),
                onEdit: () => _navigateToEditSong(song),
                onAddToPlaylist:
                    () => AddToPlaylistModal.show(context, songIds: [song.id]),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return const EmptyState(
      icon: Icons.music_off_outlined,
      title: '该分类下暂无歌曲',
    );
  }

  Widget _buildError(BuildContext context, String error) {
    return ErrorView(
      message: error,
      onRetry: () => ref.invalidate(categorySongsProvider(_key)),
    );
  }
}
