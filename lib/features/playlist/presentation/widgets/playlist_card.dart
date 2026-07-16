import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/browse_card.dart';
import '../../domain/playlist.dart';
import 'playlist_browse_adapters.dart';

/// 歌单网格卡片：通用 [BrowseCard]（grid 形态）的歌单适配封装。
class PlaylistCard extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleVisibility;
  final VoidCallback? onPlayAll;
  final VoidCallback? onLongPress;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onSelect;
  final bool isCurrentPlaylist;
  final bool isPlaying;

  const PlaylistCard({
    super.key,
    required this.playlist,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onToggleVisibility,
    this.onPlayAll,
    this.onLongPress,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelect,
    this.isCurrentPlaylist = false,
    this.isPlaying = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BrowseCard(
      layout: BrowseCardLayout.grid,
      coverUrl: playlist.coverImageUrl,
      placeholderIcon:
          playlist.type == 'radio' ? Icons.radio : Icons.queue_music,
      title: playlist.name,
      subtitle: l10n.songsCount(playlist.songCount),
      detail: playlist.description,
      chips: playlistLabelChips(context, playlist),
      typeBadge: playlistTypeBadge(context, playlist),
      highlighted: (isSelectionMode && isSelected) || isCurrentPlaylist,
      highlightTitle: isCurrentPlaylist,
      isSelectionMode: isSelectionMode,
      isSelected: isSelected,
      onSelect: onSelect,
      isPlaying: isCurrentPlaylist && isPlaying,
      onTap: onTap,
      onLongPress: onLongPress,
      onPlayAll: onPlayAll,
      playAllTooltip: l10n.playlistPlayAll,
      menuTooltip: l10n.playlistMoreActions,
      menuActions: playlistMenuActions(
        context: context,
        playlist: playlist,
        onEdit: onEdit,
        onToggleVisibility: onToggleVisibility,
        onDelete: onDelete,
      ),
    );
  }
}
