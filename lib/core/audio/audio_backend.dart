import 'package:flutter/foundation.dart';

/// 音频后端选择（songloft-org/songloft#76 阶段三/四）。
///
/// 决定各原生平台的 just_audio 后端是否使用 media_kit(libmpv)：
/// - **Windows / Linux**：恒用 media_kit（现状，EQ 依赖它），且已含视频输出。
/// - **macOS / Android / iOS**：默认仍用**各自的原生后端**（AVPlayer / ExoPlayer），
///   通过编译期开关切到 media_kit。默认关 → 合入后这些平台音频行为零变化，无回归风险；
///   需真机验证音频（后台/锁屏/控制中心/Live Activity/打断）+ 视频画面后，再改默认或长期开启。
///
/// 开启方式（构建验证版）：
/// ```
/// flutter run   -d macos   --dart-define=SONGLOFT_MEDIAKIT_MACOS=true
/// flutter build apk        --dart-define=SONGLOFT_MEDIAKIT_MOBILE=true
/// flutter build ipa        --dart-define=SONGLOFT_MEDIAKIT_MOBILE=true
/// ```
///
/// 视频画面能力与音频后端绑定：只有实际使用 media_kit 后端的平台才能派生
/// [VideoController] 渲染画面，故 [isInAppVideoSupported] 直接读 [usesMediaKit]。
class AudioBackend {
  AudioBackend._();

  /// macOS 是否切到 media_kit 后端（默认 false，用原生 AVPlayer）。
  static const bool _macosMediaKit =
      bool.fromEnvironment('SONGLOFT_MEDIAKIT_MACOS');

  /// Android / iOS 是否切到 media_kit 后端（默认 false，用原生 ExoPlayer/AVPlayer）。
  /// 这是移动端的 kill-switch：默认回退原生，显式开启才用 media_kit。
  static const bool _mobileMediaKit =
      bool.fromEnvironment('SONGLOFT_MEDIAKIT_MOBILE');

  /// 当前平台是否使用 media_kit(libmpv) 作为 just_audio 音频后端。
  static bool get usesMediaKit {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return true;
      case TargetPlatform.macOS:
        return _macosMediaKit;
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return _mobileMediaKit;
      default:
        return false;
    }
  }
}
