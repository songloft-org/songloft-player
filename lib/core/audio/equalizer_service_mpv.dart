import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

import '../../features/player/domain/equalizer_setting.dart';
import 'equalizer_service.dart';
import 'songloft_just_audio_platform.dart';

class MpvEqualizerService implements EqualizerService {
  NativePlayer? _nativePlayer;
  bool _enabled = false;
  List<double> _currentBands = List.filled(EqualizerSetting.bandCount, 0);

  @override
  Future<void> initialize() async {
    _tryAttachPlayer();
  }

  void _tryAttachPlayer() {
    final player = SongloftJustAudioPlatform.instance.firstPlayer;
    if (player != null) {
      final platform = player.platform;
      if (platform is NativePlayer) {
        _nativePlayer = platform;
        debugPrint('[EQ-MPV] Attached to NativePlayer');
      }
    }
  }

  @override
  Future<void> apply(EqualizerSetting setting) async {
    _enabled = setting.enabled;
    _currentBands = List.of(setting.bands);
    await _updateFilter();
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    await _updateFilter();
  }

  @override
  Future<void> setBandGain(int bandIndex, double gainDB) async {
    _currentBands[bandIndex] = gainDB;
    await _updateFilter();
  }

  @override
  bool get isSupported => true;

  @override
  void dispose() {
    _nativePlayer = null;
  }

  Future<void> _updateFilter() async {
    if (_nativePlayer == null) _tryAttachPlayer();
    final np = _nativePlayer;
    if (np == null) return;

    try {
      final eqFilter = _buildEqFilter();
      final currentAf = await np.getProperty('af');

      if (!_enabled) {
        if (currentAf.contains('superequalizer')) {
          final cleaned = _removeSuperequalizer(currentAf);
          await np.setProperty('af', cleaned);
        }
        return;
      }

      if (currentAf.isEmpty) {
        await np.setProperty('af', eqFilter);
      } else if (currentAf.contains('superequalizer')) {
        final cleaned = _removeSuperequalizer(currentAf);
        final newAf = cleaned.isEmpty ? eqFilter : '$cleaned,$eqFilter';
        await np.setProperty('af', newAf);
      } else {
        await np.setProperty('af', '$currentAf,$eqFilter');
      }
    } catch (e) {
      debugPrint('[EQ-MPV] Failed to update filter: $e');
    }
  }

  String _buildEqFilter() {
    final mapped = _mapTo18Bands(_currentBands);
    final parts = <String>[];
    for (var i = 0; i < 18; i++) {
      parts.add('${i + 1}=${mapped[i].toStringAsFixed(1)}');
    }
    return 'superequalizer=${parts.join(':')}';
  }

  static String _removeSuperequalizer(String af) {
    return af
        .split(',')
        .where((f) => !f.startsWith('superequalizer'))
        .join(',');
  }

  static List<double> _mapTo18Bands(List<double> tenBands) {
    const mpv18Freqs = [
      65.0, 92.0, 131.0, 185.0, 262.0, 370.0, 523.0, 740.0,
      1047.0, 1480.0, 2093.0, 2960.0, 4186.0, 5920.0, 8372.0,
      11840.0, 16744.0, 20000.0,
    ];
    final srcFreqs =
        EqualizerSetting.frequencies.map((f) => f.toDouble()).toList();
    final result = List<double>.filled(18, 0);
    for (var i = 0; i < 18; i++) {
      result[i] = _interpolate(mpv18Freqs[i], srcFreqs, tenBands);
    }
    return result;
  }

  static double _interpolate(
    double freq,
    List<double> srcFreqs,
    List<double> srcGains,
  ) {
    final logFreq = log(freq);
    if (logFreq <= log(srcFreqs.first)) return srcGains.first;
    if (logFreq >= log(srcFreqs.last)) return srcGains.last;
    for (var i = 0; i < srcFreqs.length - 1; i++) {
      final logLow = log(srcFreqs[i]);
      final logHigh = log(srcFreqs[i + 1]);
      if (logFreq >= logLow && logFreq <= logHigh) {
        final t = (logFreq - logLow) / (logHigh - logLow);
        return srcGains[i] + t * (srcGains[i + 1] - srcGains[i]);
      }
    }
    return 0;
  }
}
