import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/song.dart';
import '../../../shared/widgets/add_to_playlist_modal.dart';
import '../../player/presentation/providers/player_provider.dart';
import '../../playlist/presentation/providers/playlist_provider.dart'
    show PaginatedSongsState;
import 'providers/category_provider.dart';
import 'widgets/song_list_tile.dart';

/// 某分类下的歌曲列表页：复用 SongListTile、分页、可播放。
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

class _CategorySongsPageState extends ConsumerState<CategorySongsPage> {
  final _scrollController = ScrollController();

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

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(categorySongsProvider(_key));
    final title =
        '${categoryFieldLabel(widget.field)} · '
        '${categoryValueLabel(widget.field, widget.value)}';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: songsAsync.when(
        data: (state) => _buildList(context, state),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildError(context, error.toString()),
      ),
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
                isCurrentSong: currentSong?.id == song.id,
                onTap: () => _onSongTap(songs, index),
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.music_off_outlined,
              size: 48,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '该分类下暂无歌曲',
            style: textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, String error) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: colorScheme.error),
            const SizedBox(height: 16),
            Text('加载失败', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              error,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => ref.invalidate(categorySongsProvider(_key)),
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
