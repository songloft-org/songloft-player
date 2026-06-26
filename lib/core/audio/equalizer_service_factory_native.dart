import 'dart:io';

import 'package:just_audio/just_audio.dart';

import 'equalizer_service.dart';
import 'equalizer_service_android.dart';
import 'equalizer_service_darwin.dart';
import 'equalizer_service_mpv.dart';
import 'equalizer_service_noop.dart';

EqualizerService createEqualizerService({
  required AndroidEqualizer androidEqualizer,
}) {
  if (Platform.isAndroid) {
    return AndroidEqualizerService(androidEqualizer);
  }
  if (Platform.isIOS || Platform.isMacOS) {
    // AVPlayer.audioOutputNode (iOS 15+ / macOS 12+) 集成待实现
    return DarwinEqualizerService();
  }
  if (Platform.isWindows || Platform.isLinux) {
    // mpv Player 实例获取待 fork just_audio_media_kit
    return MpvEqualizerService();
  }
  return NoopEqualizerService();
}
