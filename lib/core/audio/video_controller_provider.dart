import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'songloft_just_audio_platform.dart';

/// 当前平台是否支持应用内视频画面渲染。
///
/// 阶段二（songloft-org/songloft#76）：仅桌面 Windows/Linux —— 它们通过
/// [SongloftJustAudioPlatform] 使用 media_kit(libmpv) 后端，且已切换到含视频输出的
/// libmpv（Windows 用 media_kit_libs_windows_video，Linux 用系统 libmpv）。
/// macOS/Android/iOS/Web 走各自的纯音频后端，画面渲染在后续阶段接入，这里返回 false。
bool get isInAppVideoSupported {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;
}

/// 视频画面控制器：对现有 media_kit [Player] 派生一个 [VideoController] 供 `Video` widget 渲染。
///
/// 关键点：复用 audio_service 正在用的**同一个** Player（音频与画面同源，天然音画同步，
/// 无需第二个播放引擎）。Player 由 audio_service 在首次播放时惰性创建，故这里也惰性创建
/// VideoController，并在 Player 实例被重建时重新绑定。
class VideoControllerNotifier extends Notifier<VideoController?> {
  Player? _boundPlayer;

  @override
  VideoController? build() {
    ref.onDispose(() => _boundPlayer = null);
    return _sync();
  }

  /// 依据当前 firstPlayer 同步 VideoController：Player 可用且与已绑定的不同则重建。
  VideoController? _sync() {
    if (!isInAppVideoSupported) return null;
    final player = SongloftJustAudioPlatform.instance.firstPlayer;
    if (player == null) return null;
    if (identical(player, _boundPlayer) && state != null) return state;
    _boundPlayer = player;
    return VideoController(player);
  }

  /// 供 UI 在渲染画面前调用：确保控制器已针对当前 Player 建好并同步到 state。
  /// Player 在首次播放后才存在，页面构建时可能尚未就绪，返回 null 时 UI 回退到封面。
  VideoController? ensure() {
    final controller = _sync();
    if (!identical(controller, state)) {
      state = controller;
    }
    return controller;
  }
}

/// 应用内视频画面控制器 Provider（桌面 Win/Linux 有效，其它平台恒为 null）。
final videoControllerProvider =
    NotifierProvider<VideoControllerNotifier, VideoController?>(
  VideoControllerNotifier.new,
);
