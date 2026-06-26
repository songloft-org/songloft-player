import '../../features/player/domain/equalizer_setting.dart';

abstract class EqualizerService {
  Future<void> initialize();

  Future<void> apply(EqualizerSetting setting);

  Future<void> setEnabled(bool enabled);

  Future<void> setBandGain(int bandIndex, double gainDB);

  bool get isSupported;

  void dispose();
}
