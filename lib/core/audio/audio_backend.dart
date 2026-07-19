import 'package:flutter/foundation.dart';

/// 音频后端选择（songloft-org/songloft#76）。
///
/// **所有原生平台统一使用 media_kit(libmpv)**（Windows / Linux / macOS / Android / iOS），
/// Web 除外（走 hls.js / `<video>` 分流）。统一后端使 EQ（mpv `af` 滤镜）与应用内视频画面
/// （[VideoController]）在各原生平台一致可用。
///
/// 已移除原生 ExoPlayer / AVPlayer 回退与编译期 kill-switch：media_kit 是唯一后端。
///
/// 视频画面能力与音频后端绑定，故 [isInAppVideoSupported] 直接读 [usesMediaKit]。
class AudioBackend {
  AudioBackend._();

  /// 当前平台是否使用 media_kit(libmpv) 作为 just_audio 音频后端（Web 恒 false）。
  static bool get usesMediaKit => !kIsWeb;
}
