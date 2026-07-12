import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

import 'songloft_web_audio_player.dart';

/// 在 web 上把 just_audio 的平台实现替换为接入 hls.js 的 [SongloftWebJustAudioPlugin]，
/// 使桌面 Chrome/Edge 也能播放 HLS(.m3u8) 电台（songloft-org/songloft#275）。
/// 覆盖 just_audio_web 插件注册器自动设置的默认实例，须在 AudioService.init() 之前调用。
void registerSongloftWebAudioPlatform() {
  JustAudioPlatform.instance = SongloftWebJustAudioPlugin();
}
