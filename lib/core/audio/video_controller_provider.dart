import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'audio_backend.dart';
import 'songloft_just_audio_platform.dart';

/// 当前平台是否支持应用内视频画面渲染（基于 media_kit 后端派生 [VideoController]）。
///
/// 与音频后端绑定：只有实际使用 media_kit(libmpv) 后端的平台才能渲染画面。
/// Windows/Linux 恒支持；macOS/Android/iOS 跟随 [AudioBackend] 的编译期开关
/// （默认开，可传 `=false` 回退原生后端 → 画面不可用，回退封面）；Web 走独立的
/// `<video>` 分流（见 features/player 的 web 视频组件），这里返回 false。
bool get isInAppVideoSupported => AudioBackend.usesMediaKit;

/// 视频画面控制器：暴露 media_kit [Player] 在**创建时即派生好**的 [VideoController]
/// 供 `Video` widget 渲染。
///
/// 关键点：
/// - 复用 audio_service 正在用的**同一个** Player（音画同源，天然同步）。
/// - VideoController 由 [SongloftMediaKitPlayer] 在构造时（任何 `open()` 之前）就建好，
///   保证 libmpv 的 render context 在打开媒体时已就绪，避免 "No render context set"
///   导致视频输出被永久禁用（songloft-org/songloft#76）。这里只做“取用 + 跟随 Player
///   重建时重新指向”，不再负责创建。
class VideoControllerNotifier extends Notifier<VideoController?> {
  Player? _boundPlayer;

  @override
  VideoController? build() {
    ref.onDispose(() => _boundPlayer = null);
    return _sync();
  }

  /// 依据当前 firstPlayer 取其预建的 VideoController；Player 换实例时同步指向新的。
  VideoController? _sync() {
    if (!isInAppVideoSupported) return null;
    final player = SongloftJustAudioPlatform.instance.firstPlayer;
    if (player == null) return null;
    if (identical(player, _boundPlayer) && state != null) return state;
    _boundPlayer = player;
    return SongloftJustAudioPlatform.instance.firstVideoController;
  }

  /// 供 UI 在渲染画面前调用：确保 state 指向当前 Player 的控制器。
  /// Player 在首次播放后才存在，页面构建时可能尚未就绪，返回 null 时 UI 回退到封面。
  VideoController? ensure() {
    final controller = _sync();
    if (!identical(controller, state)) {
      state = controller;
    }
    return controller;
  }
}

/// 应用内视频画面控制器 Provider（实际使用 media_kit 后端的平台有效，其它恒为 null）。
final videoControllerProvider =
    NotifierProvider<VideoControllerNotifier, VideoController?>(
  VideoControllerNotifier.new,
);
