import 'dart:async';

import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:media_kit/media_kit.dart';

/// [MediaKitPlayer] 的本地重新实现，唯一区别是 [player] 字段为 public。
/// 用于 Windows/Linux 平台的 EQ 均衡器——需要通过 [NativePlayer.setProperty]
/// 设置 mpv 的 `af` 音频滤镜。
class SongloftMediaKitPlayer extends AudioPlayerPlatform {
  late final Player player;

  late final List<StreamSubscription> _streamSubscriptions;
  final _readyCompleter = Completer<void>();

  Future<void> ready() => _readyCompleter.future;

  final _eventController = StreamController<PlaybackEventMessage>.broadcast();
  final _dataController = StreamController<PlayerDataMessage>.broadcast();

  ProcessingStateMessage _processingState = ProcessingStateMessage.idle;
  Duration _bufferedPosition = Duration.zero;
  Duration _position = Duration.zero;
  Duration? _duration;
  bool _playing = false;
  bool _mediaOpened = false;
  int? _errorCode;
  String? _errorMessage;
  Completer<Duration?>? _loadCompleter;
  int _currentIndex = 0;
  Duration? _setPosition;

  Media? get _currentMedia {
    var medias = player.state.playlist.medias;
    if (medias.isEmpty) return null;
    return medias[player.state.playlist.index];
  }

  SongloftMediaKitPlayer(super.id) {
    player = Player(
      configuration: PlayerConfiguration(
        pitch: JustAudioMediaKit.pitch,
        protocolWhitelist: JustAudioMediaKit.protocolWhitelist,
        title: JustAudioMediaKit.title,
        bufferSize: JustAudioMediaKit.bufferSize,
        logLevel: JustAudioMediaKit.mpvLogLevel,
        ready: () => _readyCompleter.complete(),
      ),
    );

    if (JustAudioMediaKit.prefetchPlaylist) {
      _setMpvProperty('prefetch-playlist', 'yes');
    }

    _streamSubscriptions = [
      player.stream.duration.listen((duration) {
        if (_currentMedia?.extras?['overrideDuration'] != null) return;
        if (_setPosition != null && duration.inSeconds > 0) {
          unawaited(player.seek(_setPosition!));
          _setPosition = null;
        }
        _updateDuration(duration);
        _updatePlaybackEvent();
      }),
      player.stream.position.listen((position) {
        _position = position;
        final start = _currentMedia?.start;
        if (start != null) _position -= start;
        if (_position < Duration.zero) _position = Duration.zero;
        _updatePlaybackEvent();
      }),
      player.stream.buffering.listen((isBuffering) {
        final start = _currentMedia?.start;
        if (!isBuffering && start != null && _bufferedPosition <= start) return;
        if (_processingState == ProcessingStateMessage.loading) {
          if (!isBuffering && _mediaOpened) {
            _processingState = ProcessingStateMessage.ready;
            if (_loadCompleter?.isCompleted != true) {
              _loadCompleter?.complete(_duration);
            }
          }
        } else if (_processingState != ProcessingStateMessage.completed ||
            isBuffering) {
          _processingState = isBuffering
              ? ProcessingStateMessage.buffering
              : ProcessingStateMessage.ready;
          if (_duration == null) _updateDuration(player.state.duration);
        }
        _errorCode = null;
        _errorMessage = null;
        _updatePlaybackEvent();
      }),
      player.stream.buffer.listen((buffer) {
        _bufferedPosition = buffer;
        final start = _currentMedia?.start;
        if (!player.state.buffering &&
            _mediaOpened &&
            start != null &&
            _bufferedPosition > start) {
          _processingState = ProcessingStateMessage.ready;
          if (_loadCompleter?.isCompleted != true) {
            _loadCompleter?.complete(_duration);
          }
        }
        _updatePlaybackEvent();
      }),
      player.stream.volume.listen((volume) {
        _dataController.add(PlayerDataMessage(volume: volume / 100.0));
      }),
      player.stream.completed.listen((completed) {
        _bufferedPosition = _position = Duration.zero;
        if (completed &&
            _currentIndex == player.state.playlist.medias.length - 1 &&
            player.state.playlistMode == PlaylistMode.none) {
          _processingState = ProcessingStateMessage.completed;
        }
        _errorCode = null;
        _errorMessage = null;
        _updatePlaybackEvent();
      }),
      player.stream.error.listen((error) {
        final errorUri = RegExp(r'Failed to open (.*)\.').firstMatch(error)?[1];
        if (errorUri == null || errorUri == _currentMedia?.uri) {
          _processingState = ProcessingStateMessage.idle;
          _errorCode = 1;
          _errorMessage = error;
          _updatePlaybackEvent();
        }
      }),
      player.stream.playlist.listen((playlist) {
        if (_currentIndex != playlist.index) {
          _bufferedPosition = _position = Duration.zero;
          _currentIndex = playlist.index;
        }
        _duration = _currentMedia?.extras?['overrideDuration'];
        _updatePlaybackEvent();
      }),
      player.stream.playlistMode.listen((playlistMode) {
        _dataController.add(
          PlayerDataMessage(loopMode: _playlistModeToLoopMode(playlistMode)),
        );
      }),
      player.stream.pitch.listen((pitch) {
        _dataController.add(PlayerDataMessage(pitch: pitch));
      }),
      player.stream.rate.listen((rate) {
        _dataController.add(PlayerDataMessage(speed: rate));
      }),
      player.stream.log.listen((event) {
        // ignore: avoid_print
        print('MPV: [${event.level}] ${event.prefix}: ${event.text}');
      }),
    ];
  }

  void _updateDuration(Duration duration) {
    final start = _currentMedia?.start;
    final end = _currentMedia?.end;
    if (end != null) duration = end;
    if (start != null) duration -= start;
    _duration = duration;
  }

  void _updatePlaybackEvent() {
    _eventController.add(PlaybackEventMessage(
      processingState: _processingState,
      updateTime: DateTime.now(),
      updatePosition: _position,
      bufferedPosition: _bufferedPosition,
      duration: _duration,
      icyMetadata: null,
      currentIndex: _currentIndex,
      androidAudioSessionId: null,
      errorCode: _errorCode,
      errorMessage: _errorMessage,
    ));
  }

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream =>
      _eventController.stream;

  @override
  Stream<PlayerDataMessage> get playerDataMessageStream =>
      _dataController.stream;

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    _mediaOpened = false;
    _loadCompleter = Completer();
    _currentIndex = request.initialIndex ?? 0;
    _bufferedPosition = Duration.zero;
    _position = Duration.zero;
    _duration = null;
    _processingState = ProcessingStateMessage.loading;
    _errorCode = null;
    _errorMessage = null;
    _updatePlaybackEvent();

    if (request.audioSourceMessage is ConcatenatingAudioSourceMessage) {
      final audioSource =
          request.audioSourceMessage as ConcatenatingAudioSourceMessage;
      final playable = Playlist(
        audioSource.children.map(_convertAudioSource).toList(),
        index: _currentIndex,
      );
      await player.open(playable, play: _playing);
    } else {
      final playable = _convertAudioSource(request.audioSourceMessage);
      await player.open(playable, play: _playing);
    }
    _mediaOpened = true;

    if (request.initialPosition != null) {
      _setPosition = _position = request.initialPosition!;
    }

    _updatePlaybackEvent();
    final duration = await _loadCompleter?.future;
    return LoadResponse(duration: duration);
  }

  @override
  Future<PlayResponse> play(PlayRequest request) async {
    _playing = true;
    if (_mediaOpened) await player.play();
    return PlayResponse();
  }

  @override
  Future<PauseResponse> pause(PauseRequest request) async {
    _playing = false;
    if (_mediaOpened) await player.pause();
    return PauseResponse();
  }

  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) =>
      player.setVolume(request.volume * 100.0).then((_) => SetVolumeResponse());

  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) =>
      player.setRate(request.speed).then((_) => SetSpeedResponse());

  @override
  Future<SetPitchResponse> setPitch(SetPitchRequest request) =>
      player.setPitch(request.pitch).then((_) => SetPitchResponse());

  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async {
    await player.setPlaylistMode(_loopModeToPlaylistMode(request.loopMode));
    return SetLoopModeResponse();
  }

  @override
  Future<SetShuffleModeResponse> setShuffleMode(
      SetShuffleModeRequest request) async {
    bool shuffling = request.shuffleMode != ShuffleModeMessage.none;
    await player.setShuffle(shuffling);
    _dataController.add(PlayerDataMessage(
      shuffleMode:
          shuffling ? ShuffleModeMessage.all : ShuffleModeMessage.none,
    ));
    return SetShuffleModeResponse();
  }

  @override
  Future<SeekResponse> seek(SeekRequest request) async {
    if (request.index != null) {
      await player.jump(request.index!);
      if (!_playing) await player.pause();
    }
    final position = request.position;
    if (position != null) {
      _position = position;
      final start = _currentMedia?.start;
      var nativePosition = position;
      if (start != null) nativePosition += start;
      if (player.state.duration.inSeconds > 0) {
        await player.seek(nativePosition);
      } else {
        _setPosition = nativePosition;
      }
    } else {
      _position = Duration.zero;
    }
    _updatePlaybackEvent();
    return SeekResponse();
  }

  @override
  Future<ConcatenatingInsertAllResponse> concatenatingInsertAll(
      ConcatenatingInsertAllRequest request) async {
    for (final source in request.children) {
      await player.add(_convertAudioSource(source));
      final length = player.state.playlist.medias.length;
      if (length == 0 || length == 1) continue;
      if (request.index < (length - 1) && request.index >= 0) {
        await player.move(length, request.index);
      }
    }
    return ConcatenatingInsertAllResponse();
  }

  @override
  Future<ConcatenatingRemoveRangeResponse> concatenatingRemoveRange(
      ConcatenatingRemoveRangeRequest request) async {
    for (var i = request.startIndex; i < request.endIndex; i++) {
      await player.remove(request.startIndex);
    }
    return ConcatenatingRemoveRangeResponse();
  }

  @override
  Future<ConcatenatingMoveResponse> concatenatingMove(
      ConcatenatingMoveRequest request) =>
      player
          .move(
            request.currentIndex,
            request.currentIndex > request.newIndex
                ? request.newIndex
                : request.newIndex + 1,
          )
          .then((_) => ConcatenatingMoveResponse());

  Future<void> release() async {
    _mediaOpened = false;
    await player.dispose();
    for (final sub in _streamSubscriptions) {
      unawaited(sub.cancel());
    }
    _streamSubscriptions.clear();
  }

  Future<void> _setMpvProperty(String key, dynamic value) async {
    if (player.platform is! NativePlayer) return;
    // dynamic 避免 Web stub 编译时缺少 setProperty 方法
    await (player.platform as dynamic).setProperty(key, value);
  }

  PlaylistMode _loopModeToPlaylistMode(LoopModeMessage loopMode) =>
      switch (loopMode) {
        LoopModeMessage.off => PlaylistMode.none,
        LoopModeMessage.one => PlaylistMode.single,
        LoopModeMessage.all => PlaylistMode.loop,
      };

  LoopModeMessage _playlistModeToLoopMode(PlaylistMode mode) =>
      switch (mode) {
        PlaylistMode.none => LoopModeMessage.off,
        PlaylistMode.single => LoopModeMessage.one,
        PlaylistMode.loop => LoopModeMessage.all,
      };

  Media _convertAudioSource(AudioSourceMessage source) => switch (source) {
    UriAudioSourceMessage(:final uri, :final headers) =>
        Media(uri, httpHeaders: headers),
    ClippingAudioSourceMessage(:final child, :final start, :final end) =>
        Media(child.uri, start: start, end: end),
    _ => throw UnsupportedError(
        '${source.runtimeType} is currently not supported'),
  };
}
