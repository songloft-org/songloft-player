import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/responsive.dart';
import '../../../../core/utils/url_helper.dart';
import '../../../playlist/domain/playlist.dart';

/// 横向歌单轮播组件
class PlaylistCarousel extends StatelessWidget {
  final List<Playlist> playlists;
  final ValueChanged<Playlist> onPlaylistTap;

  const PlaylistCarousel({
    super.key,
    required this.playlists,
    required this.onPlaylistTap,
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
    final cardHeight = cardWidth + 48; // 封面高度 + 标题区域

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

  const _PlaylistCarouselItem({
    required this.playlist,
    required this.width,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final coverUrl = playlist.coverUrl;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
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
                ),
                clipBehavior: Clip.antiAlias,
                child:
                    coverUrl != null && coverUrl.isNotEmpty
                        ? CachedNetworkImage(
                          imageUrl: UrlHelper.buildCoverUrl(coverUrl),
                          fit: BoxFit.cover,
                          placeholder:
                              (context, url) => _buildPlaceholder(colorScheme),
                          errorWidget:
                              (context, url, error) =>
                                  _buildPlaceholder(colorScheme),
                        )
                        : _buildPlaceholder(colorScheme),
              ),
            ),
            const SizedBox(height: 8),
            // 歌单名称
            Expanded(
              child: Text(
                playlist.name,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
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
