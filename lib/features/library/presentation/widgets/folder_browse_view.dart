import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/responsive.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/models/song.dart';
import '../../../../shared/utils/responsive_snackbar.dart';
import '../../../../shared/widgets/add_to_playlist_modal.dart';
import '../../../../shared/widgets/browse_card.dart';
import '../../../../shared/widgets/delete_song_dialog.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/manage_tags_modal.dart';
import '../../../../shared/mixins/song_list_actions.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../playlist/presentation/providers/playlist_view_provider.dart';
import '../providers/folder_provider.dart';
import '../providers/songs_provider.dart';
import '../song_edit_page.dart';
import 'song_list_tile.dart';

class FolderBrowseView extends ConsumerStatefulWidget {
  const FolderBrowseView({super.key});

  @override
  ConsumerState<FolderBrowseView> createState() => _FolderBrowseViewState();
}

class _FolderBrowseViewState extends ConsumerState<FolderBrowseView>
    with SongListActions {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController.text =
        ref.read(folderContentProvider('')).value?.keyword ?? '';
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      ref.read(folderContentProvider('').notifier).search(value);
    });
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
      ref.invalidate(folderContentProvider(''));
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
      ref.invalidate(folderContentProvider(''));
      ref.invalidate(songsListProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(folderContentProvider(''));

    return Column(
      children: [
        _buildSearchBar(context),
        Expanded(
          child: asyncState.when(
            data: (state) => _buildContent(context, state),
            loading: () => const Center(child: CircularProgressIndicator()),
            error:
                (error, _) => ErrorView(
                  message: error.toString(),
                  onRetry: () => ref.invalidate(folderContentProvider('')),
                ),
          ),
        ),
      ],
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
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        AppSpacing.sm,
        horizontalPadding,
        0,
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: l10n.categorySearchHint(l10n.categoryFieldFolder),
          prefixIcon: const Icon(Icons.search),
          suffixIcon:
              _searchController.text.isNotEmpty
                  ? IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: l10n.clearSearch,
                    onPressed: () {
                      _searchController.clear();
                      ref.read(folderContentProvider('').notifier).search('');
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

  Widget _buildContent(BuildContext context, FolderContentState state) {
    final l10n = AppLocalizations.of(context);

    if (state.musicPath.isEmpty && state.folders.isEmpty) {
      return EmptyState(
        icon: Icons.folder_off_outlined,
        title: l10n.folderBrowseNoMusicPath,
      );
    }

    if (state.folders.isEmpty && state.songs.isEmpty) {
      if (state.keyword.trim().isNotEmpty) {
        return EmptyState(
          icon: Icons.search_off,
          title: l10n.categoryNoMatch(l10n.categoryFieldFolder),
          subtitle: l10n.libraryTryOtherKeywords,
        );
      }
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
      onRefresh: () async => ref.invalidate(folderContentProvider('')),
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
