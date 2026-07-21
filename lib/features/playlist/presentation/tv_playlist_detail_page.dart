import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tv_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/song.dart';
import '../../../shared/utils/responsive_snackbar.dart';
import '../../../shared/widgets/tv_entity_detail_view.dart';
import '../../../shared/widgets/tv_song_tile.dart';
import '../../player/presentation/providers/player_provider.dart';
import '../domain/playlist.dart';
import 'providers/playlist_provider.dart';

/// TV 版歌单详情页。
///
/// 复用 [TvEntityDetailView]：大封面 header + 「播放全部」焦点按钮 + 焦点歌曲列表。
/// TV 精简掉多选/拖拽排序/搜索，聚焦播放与浏览。
class TvPlaylistDetailPage extends ConsumerStatefulWidget {
  final String playlistId;

  const TvPlaylistDetailPage({super.key, required this.playlistId});

  @override
  ConsumerState<TvPlaylistDetailPage> createState() =>
      _TvPlaylistDetailPageState();
}

class _TvPlaylistDetailPageState extends ConsumerState<TvPlaylistDetailPage> {
  final _scrollController = ScrollController();

  int get _playlistIdInt => int.tryParse(widget.playlistId) ?? 0;

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
        _scrollController.position.maxScrollExtent - 400) {
      ref.read(playlistSongsProvider(_playlistIdInt).notifier).loadMore();
    }
  }

  Future<void> _playAll(Playlist playlist, List<Song> songs) async {
    final l10n = AppLocalizations.of(context);
    if (songs.isEmpty) {
      ResponsiveSnackBar.show(context, message: l10n.playlistEmpty);
      return;
    }
    final total = await ref
        .read(playerStateProvider.notifier)
        .playPlaylistById(playlist.id);
    if (!mounted) return;
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

  void _playSong(List<Song> songs, int index) {
    // 从已加载分页开始播放并后台补齐整个歌单队列，避免队列被截断到已加载页
    // （songloft-org/songloft#299）。
    final state = ref.read(playlistSongsProvider(_playlistIdInt)).value;
    ref.read(playerStateProvider.notifier).playPlaylistFromLoaded(
          loadedSongs: songs,
          startIndex: index,
          playlistId: _playlistIdInt,
          total: state?.total ?? songs.length,
          sort: state?.sort ?? 'position',
          order: state?.order ?? 'asc',
          keyword: state?.keyword ?? '',
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final playlistAsync = ref.watch(playlistDetailProvider(_playlistIdInt));

    return playlistAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        body: Center(
          child: Text(
            '${l10n.commonLoadFailed}\n$error',
            style: TvTheme.captionStyle(context),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (playlist) => _buildDetail(context, playlist),
    );
  }

  Widget _buildDetail(BuildContext context, Playlist playlist) {
    final l10n = AppLocalizations.of(context);
    final songsAsync = ref.watch(playlistSongsProvider(_playlistIdInt));
    final state = songsAsync.value;
    final loadedSongs = state?.items ?? const <Song>[];

    return TvEntityDetailView(
      scrollController: _scrollController,
      coverUrl: playlist.coverUrl,
      placeholderIcon: playlist.type == 'radio'
          ? Icons.radio_rounded
          : Icons.queue_music_rounded,
      title: playlist.name,
      subtitle: l10n.homeSongCount(playlist.songCount),
      description: playlist.description,
      onPlayAll: loadedSongs.isEmpty
          ? null
          : () => _playAll(playlist, loadedSongs),
      playAllLabel: l10n.playlistPlayAll,
      bodySlivers: _buildBodySlivers(context, songsAsync),
    );
  }

  List<Widget> _buildBodySlivers(
    BuildContext context,
    AsyncValue<PaginatedSongsState> songsAsync,
  ) {
    final l10n = AppLocalizations.of(context);
    return songsAsync.when(
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
            padding: const EdgeInsets.all(TvTheme.contentPadding),
            child: Center(
              child: Text(
                '${l10n.commonLoadFailed}\n$error',
                style: TvTheme.captionStyle(context),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
      data: (state) {
        if (state.items.isEmpty) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(TvTheme.contentPadding),
                child: Center(
                  child: Text(
                    l10n.playlistEmpty,
                    style: TvTheme.titleStyle(context),
                  ),
                ),
              ),
            ),
          ];
        }
        final currentSong = ref.watch(currentSongProvider);
        final isPlaying = ref.watch(isPlayingProvider);
        final songs = state.items;
        return [
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: TvTheme.contentPadding,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final song = songs[index];
                final isCurrent = currentSong?.id == song.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: TvTheme.spacingSmall),
                  child: TvSongTile(
                    song: song,
                    index: index + 1,
                    isCurrentSong: isCurrent,
                    isPlaying: isCurrent && isPlaying,
                    onSelect: () => _playSong(songs, index),
                  ),
                );
              }, childCount: songs.length),
            ),
          ),
          if (state.isLoadingMore)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(TvTheme.spacingLarge),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ];
      },
    );
  }
}
