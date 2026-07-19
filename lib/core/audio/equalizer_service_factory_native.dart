import 'equalizer_service.dart';
import 'equalizer_service_mpv.dart';

/// 原生平台统一 media_kit(libmpv) 后端，EQ 走 mpv `af`（superequalizer）。
EqualizerService createEqualizerService() => MpvEqualizerService();
