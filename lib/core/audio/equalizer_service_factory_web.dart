import 'equalizer_service.dart';
import 'equalizer_service_web.dart';

/// Web 平台 EQ（WebAudio）。
EqualizerService createEqualizerService() => WebEqualizerService();
