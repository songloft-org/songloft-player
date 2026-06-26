import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../features/player/domain/equalizer_setting.dart';
import 'equalizer_service.dart';

class DarwinEqualizerService implements EqualizerService {
  static const _channel = MethodChannel('com.songloft.equalizer');
  bool _supported = false;

  @override
  Future<void> initialize() async {
    try {
      _supported = await _channel.invokeMethod<bool>('initialize') ?? false;
    } catch (e) {
      debugPrint('[EQ-Darwin] Failed to initialize: $e');
      _supported = false;
    }
  }

  @override
  Future<void> apply(EqualizerSetting setting) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod('apply', {
        'enabled': setting.enabled,
        'bands': setting.bands,
      });
    } catch (e) {
      debugPrint('[EQ-Darwin] Failed to apply: $e');
    }
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod('setEnabled', {'enabled': enabled});
    } catch (e) {
      debugPrint('[EQ-Darwin] Failed to setEnabled: $e');
    }
  }

  @override
  Future<void> setBandGain(int bandIndex, double gainDB) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod('setBandGain', {
        'index': bandIndex,
        'gain': gainDB,
      });
    } catch (e) {
      debugPrint('[EQ-Darwin] Failed to setBandGain: $e');
    }
  }

  @override
  bool get isSupported => _supported;

  @override
  void dispose() {}
}
