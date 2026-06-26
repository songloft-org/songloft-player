import 'package:just_audio/just_audio.dart';

import 'equalizer_service.dart';
import 'equalizer_service_web.dart';

EqualizerService createEqualizerService({
  required AndroidEqualizer androidEqualizer,
}) {
  return WebEqualizerService();
}
