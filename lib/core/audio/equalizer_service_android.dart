import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../features/player/domain/equalizer_setting.dart';
import 'equalizer_service.dart';

class AndroidEqualizerService implements EqualizerService {
  final AndroidEqualizer _equalizer;
  AndroidEqualizerParameters? _params;
  EqualizerSetting? _pendingSetting;

  AndroidEqualizerService(this._equalizer);

  @override
  Future<void> initialize() async {
    // AndroidEqualizer.parameters 的 Completer 在首次加载 audio source 后才 complete。
    // 不 await，注册回调等 parameters 就绪后缓存，并自动 apply 之前挂起的 setting。
    _equalizer.parameters.then((params) {
      _params = params;
      debugPrint(
        '[EQ-Android] Parameters ready: ${params.bands.length} bands, '
        '${params.minDecibels}~${params.maxDecibels} dB',
      );
      final pending = _pendingSetting;
      if (pending != null) {
        _pendingSetting = null;
        apply(pending);
      }
    }).catchError((e) {
      debugPrint('[EQ-Android] Failed to get parameters: $e');
    });
  }

  @override
  Future<void> apply(EqualizerSetting setting) async {
    await setEnabled(setting.enabled);
    if (!setting.enabled) return;

    final params = _params;
    if (params == null) {
      _pendingSetting = setting;
      return;
    }

    final systemBands = params.bands;
    for (var i = 0; i < systemBands.length; i++) {
      final gain = _interpolateGain(
        systemBands[i].centerFrequency,
        setting.bands,
      );
      final scaled = _scaleGain(gain, params.minDecibels, params.maxDecibels);
      await systemBands[i].setGain(scaled);
    }
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    await _equalizer.setEnabled(enabled);
  }

  @override
  Future<void> setBandGain(int bandIndex, double gainDB) async {
    final params = _params;
    if (params == null) return;

    final targetFreq = EqualizerSetting.frequencies[bandIndex].toDouble();
    final systemBands = params.bands;

    var closest = 0;
    var minDist = double.infinity;
    for (var i = 0; i < systemBands.length; i++) {
      final dist =
          (log(systemBands[i].centerFrequency) - log(targetFreq)).abs();
      if (dist < minDist) {
        minDist = dist;
        closest = i;
      }
    }

    final scaled =
        _scaleGain(gainDB, params.minDecibels, params.maxDecibels);
    await systemBands[closest].setGain(scaled);
  }

  @override
  bool get isSupported => true;

  @override
  void dispose() {}

  double _interpolateGain(double systemFreq, List<double> configBands) {
    const freqs = EqualizerSetting.frequencies;
    final logFreq = log(systemFreq);

    if (logFreq <= log(freqs.first.toDouble())) return configBands.first;
    if (logFreq >= log(freqs.last.toDouble())) return configBands.last;

    for (var i = 0; i < freqs.length - 1; i++) {
      final logLow = log(freqs[i].toDouble());
      final logHigh = log(freqs[i + 1].toDouble());
      if (logFreq >= logLow && logFreq <= logHigh) {
        final t = (logFreq - logLow) / (logHigh - logLow);
        return configBands[i] + t * (configBands[i + 1] - configBands[i]);
      }
    }
    return 0;
  }

  double _scaleGain(
    double gainDB,
    double minDecibels,
    double maxDecibels,
  ) {
    final range = maxDecibels - minDecibels;
    final mid = (minDecibels + maxDecibels) / 2;
    final scaled = mid + (gainDB / EqualizerSetting.maxGain) * (range / 2);
    return scaled.clamp(minDecibels, maxDecibels);
  }
}
