import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../core/audio/video_controller_provider.dart';
import '../../../../shared/models/song.dart';
import '../providers/player_provider.dart';
import 'web_video_view.dart';

/// 视频画面舞台：视频歌曲在支持的平台（桌面 Win/Linux）渲染 media_kit 的 [Video] 画面，
/// 否则回退到 [fallback]（通常是封面 / 唱片环）。
///
/// 画面与音频复用同一个 media_kit Player，天然音画同步；控制器尚未就绪
/// （Player 在首次播放后才创建）时同样回退 [fallback]。
class VideoStage extends ConsumerStatefulWidget {
  const VideoStage({
    super.key,
    required this.song,
    required this.fallback,
    this.width,
    this.height,
    this.borderRadius,
  });

  final Song song;
  final Widget fallback;

  /// 视频画面尺寸约束（video 在 Column 等无界高度容器中必须有界）。fallback 不受此约束。
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  @override
  ConsumerState<VideoStage> createState() => _VideoStageState();
}

class _VideoStageState extends ConsumerState<VideoStage> {
  @override
  void initState() {
    super.initState();
    _ensureIfVideo();
  }

  @override
  void didUpdateWidget(covariant VideoStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.song.id != oldWidget.song.id) {
      _ensureIfVideo();
    }
  }

  // Player 在首次播放后才存在，页面构建时可能尚未就绪；放到帧后再 ensure，
  // 避免在 build 期间改动 Provider 状态。
  void _ensureIfVideo() {
    if (!widget.song.isVideo || !isInAppVideoSupported) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(videoControllerProvider.notifier).ensure();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.song.isVideo) return widget.fallback;

    // Web：走独立的 <video> 画面分流（静音，音频仍由 just_audio_web/hls.js 播放），
    // 不依赖 media_kit 后端，也不触碰电台路径。
    if (kIsWeb) {
      return WebVideoView(
        song: widget.song,
        fallback: widget.fallback,
        width: widget.width,
        height: widget.height,
        borderRadius: widget.borderRadius,
      );
    }

    // 原生：需实际使用 media_kit 后端的平台才能派生 VideoController。
    if (!isInAppVideoSupported) return widget.fallback;

    // Player 由 just_audio 惰性创建；切歌后 firstPlayer 可能指向新实例，
    // 跟随当前歌曲变化把 VideoController 同步到（可能重建的）Player。
    ref.listen(currentSongProvider, (_, _) {
      ref.read(videoControllerProvider.notifier).ensure();
    });

    final controller = ref.watch(videoControllerProvider);
    if (controller == null) return widget.fallback;

    final radius = widget.borderRadius ?? BorderRadius.circular(12);
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: ClipRRect(
        borderRadius: radius,
        child: ColoredBox(
          color: Colors.black,
          child: Video(
            controller: controller,
            // 播放控制沿用应用自身的控制条，不叠加 media_kit 默认控件。
            controls: NoVideoControls,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
