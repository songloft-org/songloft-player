import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/browse_card.dart';
import '../../domain/playlist.dart';
import 'playlist_browse_adapters.dart';

/// 歌单列表项：通用 [BrowseCard]（list 形态）的歌单适配封装。
class PlaylistListItem extends StatelessWidget {
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

  const PlaylistListItem({
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
      layout: BrowseCardLayout.list,
      coverUrl: playlist.coverImageUrl,
      placeholderIcon:
          playlist.type == 'radio' ? Icons.radio : Icons.queue_music,
      title: playlist.name,
      subtitle: _subtitle(l10n),
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

  /// 副标题：歌曲数量 · 描述。
  String _subtitle(AppLocalizations l10n) {
    final parts = <String>[l10n.songsCount(playlist.songCount)];
    if (playlist.description?.isNotEmpty == true) {
      parts.add(playlist.description!);
    }
    return parts.join(' · ');
  }
}
