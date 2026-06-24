import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimensions.dart';

/// 播放控制按钮组
class PlayControls extends StatelessWidget {
  final bool isPlaying;
  final bool hasPrev;
  final bool hasNext;
  final VoidCallback? onPlay;
  final VoidCallback? onPause;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final double size;
  final bool isBuffering;
  final bool showGlow;
  final bool useRoundedRect;

  const PlayControls({
    super.key,
    required this.isPlaying,
    this.hasPrev = true,
    this.hasNext = true,
    this.onPlay,
    this.onPause,
    this.onPrev,
    this.onNext,
    this.size = 48,
    this.isBuffering = false,
    this.showGlow = false,
    this.useRoundedRect = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconSize = size * 0.5;
    final playIconSize = size * 0.6;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 上一首
        IconButton(
          onPressed: hasPrev ? onPrev : null,
          icon: Icon(Icons.skip_previous_rounded, size: iconSize),
          tooltip: '上一首',
          style: IconButton.styleFrom(
            foregroundColor: theme.colorScheme.onSurface,
            disabledForegroundColor: theme.colorScheme.onSurface.withValues(
              alpha: 0.38,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // 播放/暂停（最大按钮）
        _buildPlayPauseButton(context, playIconSize),
        const SizedBox(width: 8),
        // 下一首
        IconButton(
          onPressed: hasNext ? onNext : null,
          icon: Icon(Icons.skip_next_rounded, size: iconSize),
          tooltip: '下一首',
          style: IconButton.styleFrom(
            foregroundColor: theme.colorScheme.onSurface,
            disabledForegroundColor: theme.colorScheme.onSurface.withValues(
              alpha: 0.38,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayPauseButton(BuildContext context, double iconSize) {
    final theme = Theme.of(context);
    final borderRadius =
        useRoundedRect ? AppRadius.xxlAll : BorderRadius.circular(size);

    Widget button;

    if (isBuffering) {
      button = Semantics(
        label: '正在缓冲',
        child: Material(
          color: theme.colorScheme.primary,
          borderRadius: borderRadius,
          child: SizedBox(
            width: size,
            height: size,
            child: Padding(
              padding: EdgeInsets.all(size * 0.25),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.onPrimary,
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      button = Semantics(
        button: true,
        label: isPlaying ? '暂停' : '播放',
        child: Material(
          color: theme.colorScheme.primary,
          borderRadius: borderRadius,
          child: InkWell(
            onTap: isPlaying ? onPause : onPlay,
            borderRadius: borderRadius,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: iconSize,
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ),
        ),
      );
    }

    if (!showGlow) return ClipRRect(borderRadius: borderRadius, child: button);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: isPlaying
            ? AppEffects.primaryGlow(theme.colorScheme.primary)
            : [],
      ),
      child: button,
    );
  }
}

/// 紧凑版播放控制按钮（仅播放/暂停）
class CompactPlayButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback? onPlay;
  final VoidCallback? onPause;
  final double size;
  final bool isBuffering;

  const CompactPlayButton({
    super.key,
    required this.isPlaying,
    this.onPlay,
    this.onPause,
    this.size = 40,
    this.isBuffering = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isBuffering) {
      return Semantics(
        label: '正在缓冲',
        child: SizedBox(
          width: size,
          height: size,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.primary,
              ),
            ),
          ),
        ),
      );
    }

    return IconButton(
      onPressed: isPlaying ? onPause : onPlay,
      icon: Icon(
        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
        size: size * 0.6,
      ),
      tooltip: isPlaying ? '暂停' : '播放',
      style: IconButton.styleFrom(foregroundColor: theme.colorScheme.primary),
    );
  }
}
