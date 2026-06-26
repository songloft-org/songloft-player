import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/equalizer_service.dart';
import '../../../../core/audio/equalizer_service_factory.dart';
import '../../../../core/network/api_client.dart';
import '../../../../main.dart';
import '../../../settings/data/settings_api.dart';
import '../../domain/equalizer_setting.dart';

final equalizerServiceProvider = Provider<EqualizerService>((ref) {
  final audioHandler = ref.watch(audioHandlerProvider);
  return createEqualizerService(
    androidEqualizer: audioHandler.androidEqualizer,
  );
});

final equalizerProvider =
    NotifierProvider<EqualizerNotifier, EqualizerSetting>(
      EqualizerNotifier.new,
    );

class EqualizerNotifier extends Notifier<EqualizerSetting> {
  Timer? _pushTimer;

  @override
  EqualizerSetting build() {
    ref.onDispose(() {
      _pushTimer?.cancel();
    });
    return EqualizerSetting.defaults();
  }

  Future<void> loadFromServer() async {
    try {
      final dio = ref.read(dioProvider);
      final api = SettingsApi(dio: dio);
      final setting = await api.getEqualizer();
      state = setting;

      final service = ref.read(equalizerServiceProvider);
      await service.initialize();
      await service.apply(setting);
    } catch (e) {
      debugPrint('[EQ] Failed to load from server: $e');
    }
  }

  void setEnabled(bool enabled) {
    state = state.copyWith(enabled: enabled);
    _applyAndPush();
  }

  void setPreset(String preset) {
    final bands = EqualizerSetting.presets[preset];
    if (bands != null) {
      state = state.copyWith(
        preset: preset,
        bands: List<double>.from(bands),
      );
      _applyAndPush();
    }
  }

  void setBandGain(int index, double gain) {
    final newBands = List<double>.from(state.bands);
    newBands[index] = gain.clamp(
      EqualizerSetting.minGain,
      EqualizerSetting.maxGain,
    );
    state = state.copyWith(preset: 'custom', bands: newBands);

    final service = ref.read(equalizerServiceProvider);
    service.setBandGain(index, newBands[index]);
    _schedulePush();
  }

  void _applyAndPush() {
    final service = ref.read(equalizerServiceProvider);
    service.apply(state);
    _schedulePush();
  }

  void _schedulePush() {
    _pushTimer?.cancel();
    _pushTimer = Timer(const Duration(milliseconds: 500), () {
      _pushToServer();
    });
  }

  Future<void> _pushToServer() async {
    try {
      final dio = ref.read(dioProvider);
      final api = SettingsApi(dio: dio);
      await api.updateEqualizer(state);
    } catch (e) {
      debugPrint('[EQ] Failed to push to server: $e');
    }
  }

  bool get isSupported => ref.read(equalizerServiceProvider).isSupported;
}
