import '../../../../shared/widgets/scrolling_text.dart';
import '../../../playlist/presentation/widgets/playlist_browse_adapters.dart'
    show PlaylistCustomTags;
import '../../../../shared/widgets/network_cover_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/responsive.dart';
import '../../../../core/utils/url_helper.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../playlist/domain/playlist.dart';

/// 横向歌单轮播组件
class PlaylistCarousel extends StatelessWidget {
  final List<Playlist> playlists;
  final ValueChanged<Playlist> onPlaylistTap;
  final int? currentPlaylistId;
  final bool isPlaying;

  const PlaylistCarousel({
    super.key,
    required this.playlists,
    required this.onPlaylistTap,
    this.currentPlaylistId,
    this.isPlaying = false,
  });

  @override
  Widget build(BuildContext context) {
    if (playlists.isEmpty) {
      return const SizedBox.shrink();
    }

    final cardWidth = context.responsive<double>(
      mobile: 140,
      tablet: 160,
      desktop: 180,
    );
    final scaler = MediaQuery.textScalerOf(context);
    final cardHeight = cardWidth + 8 + scaler.scale(40) + scaler.scale(20);

    return SizedBox(
      height: cardHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: playlists.length,
        itemBuilder: (context, index) {
          final playlist = playlists[index];
          return Padding(
            padding: EdgeInsets.only(
              right: index == playlists.length - 1 ? 0 : 12,
            ),
            child: _PlaylistCarouselItem(
              playlist: playlist,
              width: cardWidth,
              onTap: () => onPlaylistTap(playlist),
              isCurrentPlaylist: playlist.id == currentPlaylistId,
              isPlaying: isPlaying,
            ),
          );
        },
      ),
    );
  }
}

class _PlaylistCarouselItem extends StatelessWidget {
  final Playlist playlist;
  final double width;
  final VoidCallback onTap;
  final bool isCurrentPlaylist;
  final bool isPlaying;

  const _PlaylistCarouselItem({
    required this.playlist,
    required this.width,
    required this.onTap,
    this.isCurrentPlaylist = false,
    this.isPlaying = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: AppLocalizations.of(context).homeOpenPlaylistNamed(playlist.name),
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 方形封面
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: colorScheme.surfaceContainerHighest,
                    border:
                        isCurrentPlaylist
                            ? Border.all(color: colorScheme.primary, width: 2)
                            : null,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      playlist.coverImageUrl != null
                          ? ExcludeSemantics(
                            child: NetworkCoverImage(
                              imageUrl: UrlHelper.buildCoverUrl(
                                playlist.coverImageUrl!,
                              ),
                              fit: BoxFit.cover,
                              placeholder:
                                  (context, url) =>
                                      _buildPlaceholder(colorScheme),
                              errorWidget:
                                  (context, url, error) =>
                                      _buildPlaceholder(colorScheme),
                            ),
                          )
                          : _buildPlaceholder(colorScheme),
                      if (isCurrentPlaylist && isPlaying)
                        Container(
                          color: Colors.black54,
                          child: Center(
                            child: Icon(
                              Icons.equalizer_rounded,
                              size: 32,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // 歌单名称
              Expanded(
                child: ScrollingText(
                  text: playlist.name,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: isCurrentPlaylist ? colorScheme.primary : null,
                  ),
                ),
              ),
              PlaylistCustomTags(labels: playlist.labels),
              Text(
                AppLocalizations.of(
                  context,
                ).homeSongCountShort(playlist.songCount),
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Center(
      child: Icon(
        Icons.queue_music,
        size: 48,
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
      ),
    );
  }
}
