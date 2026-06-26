import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import '../../features/player/domain/equalizer_setting.dart';
import 'equalizer_service.dart';

@JS('SongloftEqualizer.init')
external void _jsInit();

@JS('SongloftEqualizer.attach')
external void _jsAttach(web.HTMLAudioElement element);

@JS('SongloftEqualizer.setEnabled')
external void _jsSetEnabled(bool enabled);

@JS('SongloftEqualizer.setBands')
external void _jsSetBands(JSArray<JSNumber> gains);

@JS('SongloftEqualizer.setGain')
external void _jsSetGain(int bandIndex, double gainDB);

class WebEqualizerService implements EqualizerService {
  bool _initialized = false;
  web.MutationObserver? _observer;

  @override
  Future<void> initialize() async {
    try {
      _jsInit();
      _initialized = true;
      _attachToCurrentAudio();
      _startObservingDOM();
    } catch (e) {
      debugPrint('[EQ-Web] Failed to initialize: $e');
    }
  }

  @override
  Future<void> apply(EqualizerSetting setting) async {
    if (!_initialized) return;
    _jsSetEnabled(setting.enabled);
    if (setting.enabled) {
      final jsArray =
          setting.bands.map((g) => g.toJS).toList().toJS;
      _jsSetBands(jsArray);
    }
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    if (!_initialized) return;
    _jsSetEnabled(enabled);
  }

  @override
  Future<void> setBandGain(int bandIndex, double gainDB) async {
    if (!_initialized) return;
    _jsSetGain(bandIndex, gainDB);
  }

  @override
  bool get isSupported => true;

  @override
  void dispose() {
    _observer?.disconnect();
    _observer = null;
  }

  void _attachToCurrentAudio() {
    final audio = web.document.querySelector('audio') as web.HTMLAudioElement?;
    if (audio != null) {
      _jsAttach(audio);
    }
  }

  void _startObservingDOM() {
    _observer = web.MutationObserver(
      ((JSArray<web.MutationRecord> mutations, web.MutationObserver observer) {
        for (final mutation in mutations.toDart) {
          final nodes = mutation.addedNodes;
          for (var i = 0; i < nodes.length; i++) {
            final node = nodes.item(i);
            if (node != null && node.nodeName.toLowerCase() == 'audio') {
              _jsAttach(node as web.HTMLAudioElement);
            }
          }
        }
      }).toJS,
    );
    _observer!.observe(
      web.document.body!,
      web.MutationObserverInit(childList: true, subtree: true),
    );
  }
}
