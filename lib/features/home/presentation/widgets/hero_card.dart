import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/responsive.dart';
import '../../../../core/utils/url_helper.dart';
import '../../../playlist/domain/playlist.dart';

/// Hero 推荐卡片
///
/// 取第一个歌单作为推荐展示，大图封面 + 渐变遮罩 + 标题 + 播放按钮。
/// 在不同屏幕尺寸下自适应高度和排版。
class HeroCard extends StatelessWidget {
  /// 展示的歌单
  final Playlist playlist;

  /// 点击播放按钮
  final VoidCallback onPlay;

  /// 点击卡片（进入歌单详情）
  final VoidCallback onTap;

  /// 是否正在播放此歌单
  final bool isPlaying;

  const HeroCard({
    super.key,
    required this.playlist,
    required this.onPlay,
    required this.onTap,
    this.isPlaying = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final heroHeight = context.responsive<double>(
      mobile: 180,
      tablet: 240,
      desktop: 280,
      auto_: 150,
    );

    final borderRadius = context.responsive<double>(
      mobile: AppRadius.lg,
      tablet: AppRadius.xl,
      desktop: AppRadius.xl,
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.responsive<double>(
          mobile: AppSpacing.md,
          tablet: AppSpacing.lg,
          desktop: AppSpacing.lg,
        ),
      ),
      child: Semantics(
        button: true,
        label: '${playlist.name} - ${playlist.songCount} 首歌曲',
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: heroHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              color: colorScheme.surfaceContainerHighest,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 封面背景
                _buildCoverImage(colorScheme),

                // 渐变遮罩
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [
                        Colors.black.withValues(alpha: 0.0),
                        Colors.black.withValues(alpha: 0.35),
                        Colors.black.withValues(alpha: 0.75),
                      ],
                      stops: const [0.0, 0.4, 1.0],
                    ),
                  ),
                ),

                // 内容
                Positioned(
                  left: context.responsive<double>(
                    mobile: AppSpacing.md + 4,
                    tablet: AppSpacing.lg,
                    desktop: AppSpacing.lg + 4,
                  ),
                  right: context.responsive<double>(
                    mobile: AppSpacing.md + 4,
                    tablet: AppSpacing.lg,
                    desktop: AppSpacing.lg + 4,
                  ),
                  bottom: context.responsive<double>(
                    mobile: AppSpacing.md + 4,
                    tablet: AppSpacing.lg,
                    desktop: AppSpacing.lg + 4,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 小标签
                      Text(
                        isPlaying ? '正在播放' : '推荐歌单',
                        style: textTheme.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                          letterSpacing: 2,
                          fontSize: context.responsive<double>(
                            mobile: 10,
                            tablet: 11,
                            desktop: 12,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: context.responsive<double>(
                          mobile: 4,
                          tablet: 6,
                          desktop: 8,
                        ),
                      ),
                      // 歌单标题
                      Text(
                        playlist.name,
                        style: textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: context.responsive<double>(
                            mobile: 22,
                            tablet: 28,
                            desktop: 32,
                          ),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(
                        height: context.responsive<double>(
                          mobile: 2,
                          tablet: 4,
                          desktop: 4,
                        ),
                      ),
                      // 歌曲数
                      Text(
                        '${playlist.songCount} 首歌曲',
                        style: textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: context.responsive<double>(
                            mobile: 12,
                            tablet: 13,
                            desktop: 14,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: context.responsive<double>(
                          mobile: 12,
                          tablet: 16,
                          desktop: 20,
                        ),
                      ),
                      // 播放按钮
                      _PlayButton(
                        isPlaying: isPlaying,
                        onPressed: onPlay,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoverImage(ColorScheme colorScheme) {
    final coverUrl = playlist.coverImageUrl;
    if (coverUrl != null && coverUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: UrlHelper.buildCoverUrl(coverUrl),
        fit: BoxFit.cover,
        placeholder:
            (context, url) => Container(
              color: colorScheme.surfaceContainerHighest,
              child: Center(
                child: Icon(
                  Icons.queue_music_rounded,
                  size: 64,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                ),
              ),
            ),
        errorWidget:
            (context, url, error) => Container(
              color: colorScheme.surfaceContainerHighest,
              child: Center(
                child: Icon(
                  Icons.queue_music_rounded,
                  size: 64,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                ),
              ),
            ),
      );
    }
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.queue_music_rounded,
          size: 64,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

/// 播放按钮
class _PlayButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPressed;

  const _PlayButton({
    required this.isPlaying,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xxl),
        ),
      ),
      icon: Icon(
        isPlaying ? Icons.equalizer_rounded : Icons.play_arrow_rounded,
        size: 20,
      ),
      label: Text(isPlaying ? '正在播放' : '立即播放'),
    );
  }
}
