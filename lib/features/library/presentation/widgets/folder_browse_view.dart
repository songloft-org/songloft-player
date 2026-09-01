import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/responsive.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/utils/responsive_snackbar.dart';
import '../../../../shared/widgets/browse_card.dart';
import '../../../../shared/widgets/browse_collection_view.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../playlist/presentation/providers/playlist_view_provider.dart';
import '../providers/folder_provider.dart';
import '../providers/songs_provider.dart';

class FolderBrowseView extends ConsumerStatefulWidget {
  const FolderBrowseView({super.key});

  @override
  ConsumerState<FolderBrowseView> createState() => _FolderBrowseViewState();
}

class _FolderBrowseViewState extends ConsumerState<FolderBrowseView> {
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

    return BrowseCollectionView(
      layout: layout,
      itemCount: state.folders.length,
      scrollController: _scrollController,
      onRefresh: () async => ref.invalidate(folderContentProvider('')),
      cardBuilder: (context, index) {
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
  }
}
