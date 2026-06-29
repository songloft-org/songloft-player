import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:smtc_windows/smtc_windows.dart';

import 'audio_service.dart';

class SmtcService {
  final SongloftAudioHandler _audioHandler;
  late final SMTCWindows _smtc;
  StreamSubscription<PlaybackState>? _playbackSub;
  StreamSubscription<MediaItem?>? _mediaItemSub;
  StreamSubscription<PressedButton>? _buttonSub;
  StreamSubscription<Duration>? _positionSub;

  SmtcService(this._audioHandler) {
    _smtc = SMTCWindows(
      config: const SMTCConfig(
        playEnabled: true,
        pauseEnabled: true,
        nextEnabled: true,
        prevEnabled: true,
        stopEnabled: true,
        fastForwardEnabled: false,
        rewindEnabled: false,
      ),
    );

    _listenButtons();
    _listenPlaybackState();
    _listenMediaItem();
    _listenPosition();
  }

  void _listenButtons() {
    _buttonSub = _smtc.buttonPressStream.listen((button) {
      switch (button) {
        case PressedButton.play:
          _audioHandler.play();
        case PressedButton.pause:
          _audioHandler.pause();
        case PressedButton.next:
          _audioHandler.skipToNext();
        case PressedButton.previous:
          _audioHandler.skipToPrevious();
        case PressedButton.stop:
          _audioHandler.stop();
        default:
          break;
      }
    });
  }

  void _listenPlaybackState() {
    _playbackSub = _audioHandler.playbackState.listen((state) {
      PlaybackStatus status;
      if (state.playing) {
        status = PlaybackStatus.playing;
      } else if (state.processingState == AudioProcessingState.idle) {
        status = PlaybackStatus.stopped;
      } else {
        status = PlaybackStatus.paused;
      }
      _smtc.setPlaybackStatus(status);
    });
  }

  void _listenMediaItem() {
    _mediaItemSub = _audioHandler.mediaItem.listen((item) {
      if (item == null) return;
      _smtc.updateMetadata(MusicMetadata(
        title: item.title,
        artist: item.artist,
        album: item.album,
        thumbnail: item.artUri?.toString(),
      ));
      if (item.duration != null) {
        _smtc.updateTimeline(PlaybackTimeline(
          startTimeMs: 0,
          endTimeMs: item.duration!.inMilliseconds,
          positionMs: _audioHandler.position.inMilliseconds,
        ));
      }
    });
  }

  void _listenPosition() {
    _positionSub = _audioHandler.positionStream.listen((position) {
      final duration = _audioHandler.duration;
      _smtc.updateTimeline(PlaybackTimeline(
        startTimeMs: 0,
        endTimeMs: duration?.inMilliseconds ?? 0,
        positionMs: position.inMilliseconds,
      ));
    });
  }

  Future<void> dispose() async {
    await _buttonSub?.cancel();
    await _playbackSub?.cancel();
    await _mediaItemSub?.cancel();
    await _positionSub?.cancel();
    await _smtc.clearMetadata();
    await _smtc.dispose();
    debugPrint('[SmtcService] disposed');
  }
}
