import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/responsive.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/song.dart';
import '../../../shared/utils/responsive_snackbar.dart';
import '../../../shared/widgets/add_to_playlist_modal.dart';
import '../../../shared/widgets/browse_card.dart';
import '../../../shared/widgets/delete_song_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/manage_tags_modal.dart';
import '../../../shared/mixins/song_list_actions.dart';
import '../../player/presentation/providers/player_provider.dart';
import '../../playlist/presentation/providers/playlist_view_provider.dart';
import 'providers/folder_provider.dart';
import 'providers/songs_provider.dart';
import 'song_edit_page.dart';
import 'widgets/song_list_tile.dart';

class FolderContentPage extends ConsumerStatefulWidget {
  final String path;

  const FolderContentPage({super.key, required this.path});

  @override
  ConsumerState<FolderContentPage> createState() => _FolderContentPageState();
}

class _FolderContentPageState extends ConsumerState<FolderContentPage>
    with SongListActions {
  final _scrollController = ScrollController();

  String get _folderName {
    final parts = widget.path.split('/');
    return parts.isNotEmpty ? parts.last : widget.path;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _playAll() async {
    final l10n = AppLocalizations.of(context);
    final state = ref.read(folderContentProvider(widget.path)).value;
    if (state == null) return;

    final pathPrefix =
        state.musicPath.isNotEmpty
            ? '${state.musicPath}/${widget.path}/'
            : '${widget.path}/';
    try {
      final api = ref.read(songsApiProvider);
      final response = await api.getSongs(pathPrefix: pathPrefix, limit: 10000);
      if (!mounted) return;
      final songs = response.songs;
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
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(context, message: e.toString());
      }
    }
  }

  void _onSongTap(List<Song> songs, int index) {
    ref
        .read(playerStateProvider.notifier)
        .playPlaylist(songs, startIndex: index);
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
      ref.invalidate(folderContentProvider(widget.path));
      ref.invalidate(songsListProvider);
      removeDeletedSongsFromPlayerQueue({songId});
      if (mounted) {
        ResponsiveSnackBar.showSuccess(
          context,
          message: l10n.playlistSongDeleted,
        );
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(
          context,
          message: l10n.libraryDeleteFailed,
        );
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
      ref.invalidate(folderContentProvider(widget.path));
      ref.invalidate(songsListProvider);
    }
  }

  Future<void> _playFolder(String folderPath, String musicPath) async {
    final l10n = AppLocalizations.of(context);
    final pathPrefix =
        musicPath.isNotEmpty ? '$musicPath/$folderPath/' : '$folderPath/';
    try {
      final api = ref.read(songsApiProvider);
      final response = await api.getSongs(pathPrefix: pathPrefix, limit: 10000);
      if (!mounted) return;
      final songs = response.songs;
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
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(context, message: e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final asyncState = ref.watch(folderContentProvider(widget.path));
    final isGrid = ref.watch(playlistViewModeProvider) == PlaylistViewMode.grid;

    return Scaffold(
      appBar: AppBar(
        title: Text(_folderName),
        actions: [
          IconButton(
            icon: Icon(isGrid ? Icons.view_list : Icons.grid_view),
            tooltip:
                isGrid
                    ? l10n.playlistSwitchToListView
                    : l10n.playlistSwitchToGridView,
            onPressed:
                () =>
                    ref
                        .read(playlistViewModeProvider.notifier)
                        .toggleViewMode(),
          ),
          IconButton(
            icon: const Icon(Icons.play_circle_outline),
            tooltip: l10n.libraryPlayAll,
            onPressed: _playAll,
          ),
        ],
      ),
      body: asyncState.when(
        data: (state) => _buildBody(context, state),
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => ErrorView(
              message: error.toString(),
              onRetry: () => ref.invalidate(folderContentProvider(widget.path)),
            ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, FolderContentState state) {
    final l10n = AppLocalizations.of(context);

    if (state.folders.isEmpty && state.songs.isEmpty) {
      return EmptyState(
        icon: Icons.folder_off_outlined,
        title: l10n.folderBrowseEmpty,
      );
    }

    final layout =
        ref.watch(playlistViewModeProvider) == PlaylistViewMode.list
            ? BrowseCardLayout.list
            : BrowseCardLayout.grid;

    final hasFolders = state.folders.isNotEmpty;
    final hasSongs = state.songs.isNotEmpty;
    final currentSong = ref.watch(currentSongProvider);

    final horizontalPadding = context.responsive<double>(
      mobile: AppSpacing.md,
      tablet: AppSpacing.lg,
      desktop: AppSpacing.xl,
    );

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(folderContentProvider(widget.path)),
      child: ListView(
        controller: _scrollController,
        padding: EdgeInsets.only(
          bottom: context.navScrollInset,
        ),
        children: [
          if (hasFolders)
            _buildFolderGrid(context, state, layout, horizontalPadding),
          if (hasFolders && hasSongs) const Divider(height: AppSpacing.lg),
          if (hasSongs)
            ...state.songs.asMap().entries.map((entry) {
              final index = entry.key;
              final song = entry.value;
              return SongListTile(
                song: song,
                index: index,
                isCurrentSong: currentSong?.id == song.id,
                onTap: () => _onSongTap(state.songs, index),
                onDelete: () => _deleteSong(song.id),
                onEdit: () => _navigateToEditSong(song),
                onAddToPlaylist:
                    () => AddToPlaylistModal.show(context, songIds: [song.id]),
                onManageTags:
                    () => ManageTagsModal.show(context, songIds: [song.id]),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildFolderGrid(
    BuildContext context,
    FolderContentState state,
    BrowseCardLayout layout,
    double horizontalPadding,
  ) {
    final l10n = AppLocalizations.of(context);

    if (layout == BrowseCardLayout.list) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final folder in state.folders)
              BrowseCard(
                layout: layout,
                placeholderIcon: Icons.folder_outlined,
                title: folder.name,
                subtitle: l10n.categorySongCount(folder.songCount),
                onPlayAll: () => _playFolder(folder.path, state.musicPath),
                playAllTooltip: l10n.libraryPlayAll,
                onTap: () {
                  context.push(
                    Uri(
                      path: '/library/folders',
                      queryParameters: {'path': folder.path},
                    ).toString(),
                  );
                },
              ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = context.responsive<int>(
            mobile: 2,
            tablet: 3,
            desktop: 4,
          );
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 0.85,
            ),
            itemCount: state.folders.length,
            itemBuilder: (context, index) {
              final folder = state.folders[index];
              return BrowseCard(
                layout: layout,
                placeholderIcon: Icons.folder_outlined,
                title: folder.name,
                subtitle: l10n.categorySongCount(folder.songCount),
                onPlayAll: () => _playFolder(folder.path, state.musicPath),
                playAllTooltip: l10n.libraryPlayAll,
                onTap: () {
                  context.push(
                    Uri(
                      path: '/library/folders',
                      queryParameters: {'path': folder.path},
                    ).toString(),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
