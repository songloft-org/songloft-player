import '../../features/player/domain/equalizer_setting.dart';
import 'equalizer_service.dart';

class NoopEqualizerService implements EqualizerService {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> apply(EqualizerSetting setting) async {}

  @override
  Future<void> setEnabled(bool enabled) async {}

  @override
  Future<void> setBandGain(int bandIndex, double gainDB) async {}

  @override
  bool get isSupported => false;

  @override
  void dispose() {}
}
