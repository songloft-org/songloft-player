// 本文件 vendoring 自 just_audio_web 0.4.16（lib/just_audio_web.dart），
// 逐字复制上游实现，仅做一处外科式改动：在 [Html5AudioPlayer.loadUri] 内
// 为 HLS(.m3u8/.m3u) 源接入 hls.js（见 `web/hls_bridge.js` 的 SongloftHls）。
//
// 背景：桌面 Chrome/Edge 的 <audio> 元素原生不支持 HLS（仅 Safari 支持），
// 导致 web 端 m3u8 电台完全无法播放（songloft-org/songloft#275）。hls.js 用 MSE 解码后
// 会把 element.src 设为 blob 并驱动标准 media 事件，因此上游其余逻辑无需改动即可复用。
//
// 上游版权：
//   MIT License — Copyright (c) 2020 Ryan Heise and the project contributors.
//   https://pub.dev/packages/just_audio_web
//
// 注册见 lib/main.dart：web 平台将 JustAudioPlatform.instance 指向 SongloftWebJustAudioPlugin。
//
// 本文件为 vendoring 的上游代码，保留原有代码风格，豁免项目 lint（单引号 / super 参数）。
// ignore_for_file: prefer_single_quotes, use_super_parameters, invalid_runtime_check_with_js_interop_types
import 'dart:async';
import 'dart:js_interop';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:synchronized/synchronized.dart' as synch;
import 'package:web/web.dart';

// ============================================================
// hls.js 桥接（web/hls_bridge.js 暴露的 window.SongloftHls）
// ============================================================

@JS('SongloftHls.canUse')
external bool _hlsCanUse();

@JS('SongloftHls.attach')
external void _hlsAttach(HTMLAudioElement element, String url, JSFunction onError);

@JS('SongloftHls.destroy')
external void _hlsDestroy(HTMLAudioElement element);

/// The web implementation of [JustAudioPlatform].
class SongloftWebJustAudioPlugin extends JustAudioPlatform {
  final Map<String, JustAudioPlayer> players = {};

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    if (players.containsKey(request.id)) {
      throw PlatformException(
          code: "error",
          message: "Platform player ${request.id} already exists");
    }
    final player = Html5AudioPlayer(id: request.id);
    players[request.id] = player;
    return player;
  }

  @override
  Future<DisposePlayerResponse> disposePlayer(
      DisposePlayerRequest request) async {
    await players[request.id]?.release();
    players.remove(request.id);
    return DisposePlayerResponse();
  }

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(
      DisposeAllPlayersRequest request) async {
    for (var player in players.values) {
      await player.release();
    }
    players.clear();
    return DisposeAllPlayersResponse();
  }
}

/// The web impluementation of [AudioPlayerPlatform].
abstract class JustAudioPlayer extends AudioPlayerPlatform {
  final _eventController =
      StreamController<PlaybackEventMessage>.broadcast(sync: true);
  final _dataEventController =
      StreamController<PlayerDataMessage>.broadcast(sync: true);
  ProcessingStateMessage _processingState = ProcessingStateMessage.idle;
  bool _playing = false;
  int? _index;
  double _speed = 1.0;
  int? errorCode;
  String? errorMessage;

  /// Creates a platform player with the given [id].
  JustAudioPlayer({required String id}) : super(id);

  @mustCallSuper
  Future<void> release() async {
    _eventController.close();
    _dataEventController.close();
  }

  /// Returns the current position of the player.
  Duration getCurrentPosition();

  /// Returns the current buffered position of the player.
  Duration getBufferedPosition();

  /// Returns the duration of the current player item or `null` if unknown.
  Duration? getDuration();

  /// Broadcasts a playback event from the platform side to the plugin side.
  void broadcastPlaybackEvent() {
    var updateTime = DateTime.now();
    _eventController.add(PlaybackEventMessage(
      processingState: _processingState,
      updatePosition: getCurrentPosition(),
      updateTime: updateTime,
      bufferedPosition: getBufferedPosition(),
      // TODO: Icy Metadata
      icyMetadata: null,
      duration: getDuration(),
      currentIndex: _index,
      androidAudioSessionId: null,
      errorCode: errorCode,
      errorMessage: errorMessage,
    ));
  }

  /// Transitions to [processingState] and broadcasts a playback event.
  void transition(ProcessingStateMessage processingState) {
    _processingState = processingState;
    if (processingState != ProcessingStateMessage.idle) {
      errorCode = null;
      errorMessage = null;
    }
    broadcastPlaybackEvent();
  }
}

/// An HTML5-specific implementation of [JustAudioPlayer].
class Html5AudioPlayer extends JustAudioPlayer {
  // Uncomment after: https://github.com/dart-lang/web/issues/124
  //final _audioElement = HTMLAudioElement();
  final _audioElement = document.createElement('audio') as HTMLAudioElement;
  late final _audioElementQueue = _AudioElementQueue(_audioElement);
  Completer<dynamic>? _durationCompleter;
  AudioSourcePlayer? _audioSourcePlayer;
  LoopModeMessage _loopMode = LoopModeMessage.off;
  bool _shuffleModeEnabled = false;
  final Map<String, AudioSourcePlayer> _audioSourcePlayers = {};

  // 当前 <audio> 元素是否由 hls.js 接管（Songloft 新增）。
  bool _hlsAttached = false;

  /// Creates an [Html5AudioPlayer] with the given [id].
  Html5AudioPlayer({required String id}) : super(id: id) {
    _audioElement.addEventListener(
        'durationchange',
        (Event event) {
          _durationCompleter?.complete();
          _durationCompleter = null;
          broadcastPlaybackEvent();
        }.toJS);
    _audioElement.addEventListener(
        'error',
        (Event event) {
          // hls.js 接管/清理期间可能触发无 MediaError 的 error 事件，需防空指针（Songloft 新增）。
          final err = _audioElement.error;
          if (err == null) return;
          _eventController.addError(PlatformException(
            code: '${err.code}',
            message: err.message,
          ));
          errorCode = err.code;
          errorMessage = err.message;
          transition(ProcessingStateMessage.idle);
          _durationCompleter?.completeError(err);
          _durationCompleter = null;
        }.toJS);
    _audioElement.addEventListener(
        'ended',
        (Event event) {
          _currentAudioSourcePlayer?.complete().catchError((e, st) {});
        }.toJS);
    _audioElement.addEventListener(
        'timeupdate',
        (Event event) {
          _currentAudioSourcePlayer
              ?.timeUpdated(_audioElement.currentTime.toDouble());
        }.toJS);
    _audioElement.addEventListener(
        'loadstart',
        (Event event) {
          transition(ProcessingStateMessage.buffering);
        }.toJS);
    _audioElement.addEventListener(
        'waiting',
        (Event event) {
          transition(ProcessingStateMessage.buffering);
        }.toJS);
    _audioElement.addEventListener(
        'stalled',
        (Event event) {
          transition(ProcessingStateMessage.buffering);
        }.toJS);
    _audioElement.addEventListener(
        'canplaythrough',
        (Event event) {
          _audioElement.playbackRate = _speed;
          transition(ProcessingStateMessage.ready);
        }.toJS);
    _audioElement.addEventListener(
        'progress',
        (Event event) {
          broadcastPlaybackEvent();
        }.toJS);
  }

  /// The current playback order, depending on whether shuffle mode is enabled.
  List<int> get order {
    final sequence = _audioSourcePlayer!.sequence;
    return _shuffleModeEnabled
        ? _audioSourcePlayer!.shuffleIndices
        : List.generate(sequence.length, (i) => i);
  }

  /// gets the inverted order for the given order.
  List<int> getInv(List<int> order) {
    final orderInv = List<int>.filled(order.length, 0);
    for (var i = 0; i < order.length; i++) {
      orderInv[order[i]] = i;
    }
    return orderInv;
  }

  /// Called when playback reaches the end of an item.
  Future<void> onEnded() async {
    if (_loopMode == LoopModeMessage.one) {
      await _seek(0, null);
      _play();
    } else {
      final order = this.order;
      final orderInv = getInv(order);
      if (orderInv[_index!] + 1 < order.length) {
        // move to next item
        _index = order[orderInv[_index!] + 1];
        await _currentAudioSourcePlayer!.load();
        // Should always be true...
        if (_playing) {
          _play();
        }
      } else {
        // reached end of playlist
        if (_loopMode == LoopModeMessage.all) {
          // Loop back to the beginning
          if (order.length == 1) {
            await _seek(0, null);
            _play();
          } else {
            _index = order[0];
            await _currentAudioSourcePlayer!.load();
            // Should always be true...
            if (_playing) {
              _play();
            }
          }
        } else {
          await _currentAudioSourcePlayer?.pause();
          transition(ProcessingStateMessage.completed);
        }
      }
    }
  }

  // TODO: Improve efficiency.
  IndexedAudioSourcePlayer? get _currentAudioSourcePlayer =>
      _audioSourcePlayer != null &&
              _index != null &&
              _audioSourcePlayer!.sequence.isNotEmpty &&
              _index! < _audioSourcePlayer!.sequence.length
          ? _audioSourcePlayer!.sequence[_index!]
          : null;

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream =>
      _eventController.stream;

  @override
  Stream<PlayerDataMessage> get playerDataMessageStream =>
      _dataEventController.stream;

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    _currentAudioSourcePlayer?.pause();
    _audioSourcePlayer = getAudioSource(request.audioSourceMessage);
    _index = request.initialIndex ?? 0;
    final duration = await _currentAudioSourcePlayer!
        .load(request.initialPosition?.inMilliseconds);
    if (request.initialPosition != null) {
      await _currentAudioSourcePlayer!
          .seek(request.initialPosition!.inMilliseconds);
    }
    if (_playing) {
      _currentAudioSourcePlayer!.play();
    }
    return LoadResponse(duration: duration);
  }

  // ============================================================
  // Songloft 新增：HLS 检测与 hls.js 生命周期
  // ============================================================

  /// 判断 src 的路径部分（忽略 query）是否以 .m3u8 / .m3u 结尾。
  /// 后端 models.PlaybackURL() 对 HLS 电台把 song.url 设为 /play.m3u8，据此识别。
  static bool _looksLikeHls(String src) {
    final q = src.indexOf('?');
    final path = (q >= 0 ? src.substring(0, q) : src).toLowerCase();
    return path.endsWith('.m3u8') || path.endsWith('.m3u');
  }

  /// 浏览器 <audio> 是否原生支持 HLS（Safari 返回非空，命中则不用 hls.js）。
  bool _canPlayHlsNatively() =>
      _audioElement.canPlayType('application/vnd.apple.mpegurl').isNotEmpty;

  /// 销毁当前元素上的 hls.js 实例（幂等）。换源 / 释放时调用，防泄漏。
  void _detachHls() {
    if (!_hlsAttached) return;
    _hlsAttached = false;
    try {
      _hlsDestroy(_audioElement);
    } catch (_) {}
  }

  /// Loads audio from [uri] and returns the duration of the loaded audio if
  /// known.
  Future<Duration?> loadUri(
      final Uri uri, final Duration? initialPosition) async {
    transition(ProcessingStateMessage.loading);
    final src = uri.toString();

    // Songloft 新增：桌面浏览器无法原生解 HLS，改用 hls.js（MSE）接管。
    if (_looksLikeHls(src) && _hlsCanUse() && !_canPlayHlsNatively()) {
      _detachHls();
      _durationCompleter = Completer<dynamic>();
      _audioElement.playbackRate = _speed;
      _audioElement.preload = 'auto';
      _hlsAttached = true;
      // hls.js 会自行设置 element.src=MSE blob 并驱动标准 media 事件；
      // 复用构造器里 durationchange/error 监听来完成 _durationCompleter。
      _hlsAttach(_audioElement, src, ((JSString message) {
        // 不可恢复的 fatal 错误。加载阶段：让加载 Future 以异常收敛，
        // 由 audio_service 的直播加载超时/catch 分支处理；
        // 播放中途失效（无待完成 completer）：转 idle 并广播，让 UI 感知直播已断。
        final msg = message.toDart;
        if (_durationCompleter?.isCompleted == false) {
          _durationCompleter?.completeError(
              PlatformException(code: 'hls', message: msg));
        } else {
          _hlsAttached = false;
          errorCode = -1;
          errorMessage = msg;
          transition(ProcessingStateMessage.idle);
        }
      }).toJS);
      try {
        await _durationCompleter!.future;
      } finally {
        _durationCompleter = null;
      }
      transition(ProcessingStateMessage.ready);
      final seconds = _audioElement.duration;
      return seconds.isFinite
          ? Duration(milliseconds: (seconds * 1000).toInt())
          : null;
    }

    // 非 HLS：走上游原生逻辑。若上一源是 hls.js 接管的，先清理。
    if (_hlsAttached) _detachHls();
    if (src != _audioElement.src) {
      _durationCompleter = Completer<dynamic>();
      _audioElement.src = src;
      _audioElement.playbackRate = _speed;
      _audioElement.preload = 'auto';
      await _audioElementQueue.load();
      if (initialPosition != null) {
        _audioElement.currentTime = initialPosition.inMilliseconds / 1000.0;
      }
      try {
        await _durationCompleter!.future;
      } on MediaError catch (e) {
        throw PlatformException(
            code: "${e.code}", message: "Failed to load URL");
      } finally {
        _durationCompleter = null;
      }
    }
    transition(ProcessingStateMessage.ready);
    final seconds = _audioElement.duration;
    return seconds.isFinite
        ? Duration(milliseconds: (seconds * 1000).toInt())
        : null;
  }

  @override
  Future<PlayResponse> play(PlayRequest request) async {
    if (_playing) return PlayResponse();
    _playing = true;
    await _play();
    return PlayResponse();
  }

  Future<void> _play() async {
    await _currentAudioSourcePlayer?.play();
  }

  @override
  Future<PauseResponse> pause(PauseRequest request) async {
    if (!_playing) return PauseResponse();
    _playing = false;
    _currentAudioSourcePlayer?.pause();
    return PauseResponse();
  }

  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async {
    _audioElement.volume = request.volume;
    return SetVolumeResponse();
  }

  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async {
    _audioElement.playbackRate = _speed = request.speed;
    return SetSpeedResponse();
  }

  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async {
    _loopMode = request.loopMode;
    return SetLoopModeResponse();
  }

  @override
  Future<SetShuffleModeResponse> setShuffleMode(
      SetShuffleModeRequest request) async {
    _shuffleModeEnabled = request.shuffleMode == ShuffleModeMessage.all;
    return SetShuffleModeResponse();
  }

  @override
  Future<SetShuffleOrderResponse> setShuffleOrder(
      SetShuffleOrderRequest request) async {
    void internalSetShuffleOrder(AudioSourceMessage sourceMessage) {
      final audioSourcePlayer = _audioSourcePlayers[sourceMessage.id];
      if (audioSourcePlayer == null) return;
      if (sourceMessage is ConcatenatingAudioSourceMessage &&
          audioSourcePlayer is ConcatenatingAudioSourcePlayer) {
        audioSourcePlayer.setShuffleOrder(sourceMessage.shuffleOrder);
        for (var childMessage in sourceMessage.children) {
          internalSetShuffleOrder(childMessage);
        }
      } else if (sourceMessage is LoopingAudioSourceMessage) {
        internalSetShuffleOrder(sourceMessage.child);
      }
    }

    internalSetShuffleOrder(request.audioSourceMessage);
    return SetShuffleOrderResponse();
  }

  @override
  Future<SetWebCrossOriginResponse> setWebCrossOrigin(
      SetWebCrossOriginRequest request) async {
    _audioElement.crossOrigin = const {
      WebCrossOriginMessage.anonymous: 'anonymous',
      WebCrossOriginMessage.useCredentials: 'use-credentials',
    }[request.crossOrigin];
    return SetWebCrossOriginResponse();
  }

  /// Sets a specific device output id, null for default
  @override
  Future<SetWebSinkIdResponse> setWebSinkId(SetWebSinkIdRequest request) async {
    await _audioElementQueue.setSinkId(request.sinkId);
    return SetWebSinkIdResponse();
  }

  @override
  Future<SeekResponse> seek(SeekRequest request) async {
    await _seek(request.position?.inMilliseconds ?? 0, request.index);
    return SeekResponse();
  }

  Future<void> _seek(int position, int? newIndex) async {
    var index = newIndex ?? _index;
    if (index != _index) {
      _currentAudioSourcePlayer!.pause();
      _index = index;
      await _currentAudioSourcePlayer!.load(position);
      if (_playing) {
        _currentAudioSourcePlayer!.play();
      }
    } else {
      await _currentAudioSourcePlayer!.seek(position);
    }
  }

  ConcatenatingAudioSourcePlayer? _concatenating(String playerId) =>
      _audioSourcePlayers[playerId] as ConcatenatingAudioSourcePlayer?;

  @override
  Future<ConcatenatingInsertAllResponse> concatenatingInsertAll(
      ConcatenatingInsertAllRequest request) async {
    final wasNotEmpty = _audioSourcePlayer?.sequence.isNotEmpty ?? false;
    _concatenating(request.id)!.setShuffleOrder(request.shuffleOrder);
    _concatenating(request.id)!
        .insertAll(request.index, getAudioSources(request.children));
    if (_index != null && wasNotEmpty && request.index <= _index!) {
      _index = _index! + request.children.length;
    }
    await _currentAudioSourcePlayer!.load();
    broadcastPlaybackEvent();
    return ConcatenatingInsertAllResponse();
  }

  @override
  Future<ConcatenatingRemoveRangeResponse> concatenatingRemoveRange(
      ConcatenatingRemoveRangeRequest request) async {
    if (_index != null &&
        _index! >= request.startIndex &&
        _index! < request.endIndex &&
        _playing) {
      // Pause if removing current item
      _currentAudioSourcePlayer!.pause();
    }
    _concatenating(request.id)!.setShuffleOrder(request.shuffleOrder);
    _concatenating(request.id)!
        .removeRange(request.startIndex, request.endIndex);
    if (_index != null) {
      if (_index! >= request.startIndex && _index! < request.endIndex) {
        // Skip backward if there's nothing after this
        if (request.startIndex >= _audioSourcePlayer!.sequence.length) {
          _index = request.startIndex - 1;
          if (_index! < 0) _index = 0;
        } else {
          _index = request.startIndex;
        }
        // Resume playback at the new item (if it exists)
        if (_currentAudioSourcePlayer != null) {
          await _currentAudioSourcePlayer!.load();
          if (_playing) {
            _currentAudioSourcePlayer!.play();
          }
        }
      } else if (request.endIndex <= _index!) {
        // Reflect that the current item has shifted its position
        _index = _index! - (request.endIndex - request.startIndex);
      }
    }
    broadcastPlaybackEvent();
    return ConcatenatingRemoveRangeResponse();
  }

  @override
  Future<ConcatenatingMoveResponse> concatenatingMove(
      ConcatenatingMoveRequest request) async {
    _concatenating(request.id)!.setShuffleOrder(request.shuffleOrder);
    _concatenating(request.id)!.move(request.currentIndex, request.newIndex);
    if (_index != null) {
      if (request.currentIndex == _index) {
        _index = request.newIndex;
      } else if (request.currentIndex < _index! &&
          request.newIndex >= _index!) {
        _index = _index! - 1;
      } else if (request.currentIndex > _index! &&
          request.newIndex <= _index!) {
        _index = _index! + 1;
      }
    }
    broadcastPlaybackEvent();
    return ConcatenatingMoveResponse();
  }

  @override
  Future<SetAndroidAudioAttributesResponse> setAndroidAudioAttributes(
      SetAndroidAudioAttributesRequest request) async {
    return SetAndroidAudioAttributesResponse();
  }

  @override
  Future<SetAutomaticallyWaitsToMinimizeStallingResponse>
      setAutomaticallyWaitsToMinimizeStalling(
          SetAutomaticallyWaitsToMinimizeStallingRequest request) async {
    return SetAutomaticallyWaitsToMinimizeStallingResponse();
  }

  @override
  Future<SetCanUseNetworkResourcesForLiveStreamingWhilePausedResponse>
      setCanUseNetworkResourcesForLiveStreamingWhilePaused(
          SetCanUseNetworkResourcesForLiveStreamingWhilePausedRequest
              request) async {
    return SetCanUseNetworkResourcesForLiveStreamingWhilePausedResponse();
  }

  @override
  Future<SetPreferredPeakBitRateResponse> setPreferredPeakBitRate(
      SetPreferredPeakBitRateRequest request) async {
    return SetPreferredPeakBitRateResponse();
  }

  @override
  Duration getCurrentPosition() =>
      _currentAudioSourcePlayer?.position ?? Duration.zero;

  @override
  Duration getBufferedPosition() =>
      _currentAudioSourcePlayer?.bufferedPosition ?? Duration.zero;

  @override
  Duration? getDuration() => _currentAudioSourcePlayer?.duration;

  @override
  Future<void> release() async {
    _currentAudioSourcePlayer?.pause();
    _detachHls(); // Songloft 新增：释放前清理 hls.js 实例
    await _audioElementQueue.removeAttribute('src');
    await _audioElementQueue.load();
    transition(ProcessingStateMessage.idle);
    return await super.release();
  }

  /// Converts a list of audio source messages to players.
  List<AudioSourcePlayer> getAudioSources(List<AudioSourceMessage> messages) =>
      messages.map((message) => getAudioSource(message)).toList();

  /// Converts an audio source message to a player, using the cache if it is
  /// already cached.
  AudioSourcePlayer getAudioSource(AudioSourceMessage audioSourceMessage) {
    final id = audioSourceMessage.id;
    var audioSourcePlayer = _audioSourcePlayers[id];
    if (audioSourcePlayer == null) {
      audioSourcePlayer = decodeAudioSource(audioSourceMessage);
      _audioSourcePlayers[id] = audioSourcePlayer;
    }
    return audioSourcePlayer;
  }

  /// Converts an audio source message to a player.
  AudioSourcePlayer decodeAudioSource(AudioSourceMessage audioSourceMessage) {
    if (audioSourceMessage is ProgressiveAudioSourceMessage) {
      return ProgressiveAudioSourcePlayer(this, audioSourceMessage.id,
          Uri.parse(audioSourceMessage.uri), audioSourceMessage.headers);
    } else if (audioSourceMessage is DashAudioSourceMessage) {
      return DashAudioSourcePlayer(this, audioSourceMessage.id,
          Uri.parse(audioSourceMessage.uri), audioSourceMessage.headers);
    } else if (audioSourceMessage is HlsAudioSourceMessage) {
      return HlsAudioSourcePlayer(this, audioSourceMessage.id,
          Uri.parse(audioSourceMessage.uri), audioSourceMessage.headers);
    } else if (audioSourceMessage is ConcatenatingAudioSourceMessage) {
      return ConcatenatingAudioSourcePlayer(
          this,
          audioSourceMessage.id,
          getAudioSources(audioSourceMessage.children),
          audioSourceMessage.useLazyPreparation,
          audioSourceMessage.shuffleOrder);
    } else if (audioSourceMessage is ClippingAudioSourceMessage) {
      return ClippingAudioSourcePlayer(
          this,
          audioSourceMessage.id,
          getAudioSource(audioSourceMessage.child) as UriAudioSourcePlayer,
          audioSourceMessage.start,
          audioSourceMessage.end);
    } else if (audioSourceMessage is LoopingAudioSourceMessage) {
      return LoopingAudioSourcePlayer(this, audioSourceMessage.id,
          getAudioSource(audioSourceMessage.child), audioSourceMessage.count);
    } else {
      throw Exception("Unknown AudioSource type: $audioSourceMessage");
    }
  }
}

/// A player for a single audio source.
abstract class AudioSourcePlayer {
  /// The [Html5AudioPlayer] responsible for audio I/O.
  Html5AudioPlayer html5AudioPlayer;

  /// The ID of the underlying audio source.
  final String id;

  AudioSourcePlayer(this.html5AudioPlayer, this.id);

  /// The sequence of players for the indexed items nested in this player.
  List<IndexedAudioSourcePlayer> get sequence;

  /// The order to use over [sequence] when in shuffle mode.
  List<int> get shuffleIndices;
}

/// A player for an [IndexedAudioSourceMessage].
abstract class IndexedAudioSourcePlayer extends AudioSourcePlayer {
  IndexedAudioSourcePlayer(Html5AudioPlayer html5AudioPlayer, String id)
      : super(html5AudioPlayer, id);

  /// Loads the audio for the underlying audio source.
  Future<Duration?> load([int? initialPosition]);

  /// Plays the underlying audio source.
  Future<void> play();

  /// Pauses playback of the underlying audio source.
  Future<void> pause();

  /// Seeks to [position] milliseconds.
  Future<void> seek(int position);

  /// Called when playback reaches the end of the underlying audio source.
  Future<void> complete();

  /// Called when the playback position of the underlying HTML5 player changes.
  Future<void> timeUpdated(double seconds) async {}

  /// The duration of the underlying audio source.
  Duration? get duration;

  /// The current playback position.
  Duration get position;

  /// The current buffered position.
  Duration get bufferedPosition;

  /// The audio element that renders the audio.
  HTMLAudioElement get _audioElement => html5AudioPlayer._audioElement;

  _AudioElementQueue get _audioElementQueue =>
      html5AudioPlayer._audioElementQueue;

  @override
  String toString() => "$runtimeType";
}

/// A player for an [UriAudioSourceMessage].
abstract class UriAudioSourcePlayer extends IndexedAudioSourcePlayer {
  /// The URL to play.
  final Uri uri;

  /// The headers to include in the request (unsupported).
  final Map<String, String>? headers;
  double? _resumePos;
  Duration? _duration;
  Completer<dynamic>? _completer;
  int? _initialPos;

  UriAudioSourcePlayer(
      Html5AudioPlayer html5AudioPlayer, String id, this.uri, this.headers)
      : super(html5AudioPlayer, id);

  @override
  List<IndexedAudioSourcePlayer> get sequence => [this];

  @override
  List<int> get shuffleIndices => [0];

  @override
  Future<Duration?> load([int? initialPosition]) async {
    _initialPos = initialPosition;
    _resumePos = (initialPosition ?? 0) / 1000.0;
    _duration = await html5AudioPlayer.loadUri(
        uri,
        initialPosition != null
            ? Duration(milliseconds: initialPosition)
            : null);
    _initialPos = null;
    return _duration;
  }

  @override
  Future<void> play() async {
    _audioElement.currentTime = _resumePos!;
    await _audioElementQueue.play();
    _completer = Completer<dynamic>();
    await _completer!.future;
    _completer = null;
  }

  @override
  Future<void> pause() async {
    _resumePos = _audioElement.currentTime as double?;
    _audioElementQueue.pause();
    _interruptPlay();
  }

  @override
  Future<void> seek(int position) async {
    _audioElement.currentTime = _resumePos = position / 1000.0;
  }

  @override
  Future<void> complete() async {
    _interruptPlay();
    await html5AudioPlayer.onEnded().catchError((e, st) {});
  }

  void _interruptPlay() {
    if (_completer?.isCompleted == false) {
      _completer!.complete();
    }
  }

  @override
  Duration? get duration {
    return _duration;
    //final seconds = _audioElement.duration;
    //return seconds.isFinite
    //    ? Duration(milliseconds: (seconds * 1000).toInt())
    //    : null;
  }

  @override
  Duration get position {
    if (_initialPos != null) return Duration(milliseconds: _initialPos!);
    final seconds = _audioElement.currentTime;
    return Duration(milliseconds: (seconds * 1000).toInt());
  }

  @override
  Duration get bufferedPosition {
    if (_audioElement.buffered.length > 0) {
      return Duration(
          milliseconds:
              (_audioElement.buffered.end(_audioElement.buffered.length - 1) *
                      1000)
                  .toInt());
    } else {
      return Duration.zero;
    }
  }
}

/// A player for a [ProgressiveAudioSourceMessage].
class ProgressiveAudioSourcePlayer extends UriAudioSourcePlayer {
  ProgressiveAudioSourcePlayer(Html5AudioPlayer html5AudioPlayer, String id,
      Uri uri, Map<String, String>? headers)
      : super(html5AudioPlayer, id, uri, headers);
}

/// A player for a [DashAudioSourceMessage].
class DashAudioSourcePlayer extends UriAudioSourcePlayer {
  DashAudioSourcePlayer(Html5AudioPlayer html5AudioPlayer, String id, Uri uri,
      Map<String, String>? headers)
      : super(html5AudioPlayer, id, uri, headers);
}

/// A player for a [HlsAudioSourceMessage].
class HlsAudioSourcePlayer extends UriAudioSourcePlayer {
  HlsAudioSourcePlayer(Html5AudioPlayer html5AudioPlayer, String id, Uri uri,
      Map<String, String>? headers)
      : super(html5AudioPlayer, id, uri, headers);
}

/// A player for a [ConcatenatingAudioSourceMessage].
class ConcatenatingAudioSourcePlayer extends AudioSourcePlayer {
  /// The players for each child audio source.
  final List<AudioSourcePlayer> audioSourcePlayers;

  /// Whether audio should be loaded as late as possible. (Currently ignored.)
  final bool useLazyPreparation;
  List<int> _shuffleOrder;

  ConcatenatingAudioSourcePlayer(Html5AudioPlayer html5AudioPlayer, String id,
      this.audioSourcePlayers, this.useLazyPreparation, List<int> shuffleOrder)
      : _shuffleOrder = shuffleOrder,
        super(html5AudioPlayer, id);

  @override
  List<IndexedAudioSourcePlayer> get sequence =>
      audioSourcePlayers.expand((p) => p.sequence).toList();

  @override
  List<int> get shuffleIndices {
    final order = <int>[];
    var offset = order.length;
    final childOrders = <List<int>>[];
    for (var audioSourcePlayer in audioSourcePlayers) {
      final childShuffleIndices = audioSourcePlayer.shuffleIndices;
      childOrders.add(childShuffleIndices.map((i) => i + offset).toList());
      offset += childShuffleIndices.length;
    }
    for (var i = 0; i < childOrders.length; i++) {
      order.addAll(childOrders[_shuffleOrder[i]]);
    }
    return order;
  }

  /// Sets the current shuffle order.
  void setShuffleOrder(List<int> shuffleOrder) {
    _shuffleOrder = shuffleOrder;
  }

  /// Inserts [players] into this player at position [index].
  void insertAll(int index, List<AudioSourcePlayer> players) {
    audioSourcePlayers.insertAll(index, players);
    for (var i = 0; i < audioSourcePlayers.length; i++) {
      if (_shuffleOrder[i] >= index) {
        _shuffleOrder[i] += players.length;
      }
    }
  }

  /// Removes the child players in the specified range.
  void removeRange(int start, int end) {
    audioSourcePlayers.removeRange(start, end);
    for (var i = 0; i < audioSourcePlayers.length; i++) {
      if (_shuffleOrder[i] >= end) {
        _shuffleOrder[i] -= (end - start);
      }
    }
  }

  /// Moves a child player from [currentIndex] to [newIndex].
  void move(int currentIndex, int newIndex) {
    audioSourcePlayers.insert(
        newIndex, audioSourcePlayers.removeAt(currentIndex));
  }
}

/// A player for a [ClippingAudioSourceMessage].
class ClippingAudioSourcePlayer extends IndexedAudioSourcePlayer {
  final UriAudioSourcePlayer audioSourcePlayer;
  final Duration? start;
  final Duration? end;
  Completer<ClipInterruptReason>? _completer;
  double? _resumePos;
  Duration? _duration;
  int? _initialPos;

  ClippingAudioSourcePlayer(Html5AudioPlayer html5AudioPlayer, String id,
      this.audioSourcePlayer, this.start, this.end)
      : super(html5AudioPlayer, id);

  @override
  List<IndexedAudioSourcePlayer> get sequence => [this];

  @override
  List<int> get shuffleIndices => [0];

  Duration get effectiveStart => start ?? Duration.zero;

  @override
  Future<Duration?> load([int? initialPosition]) async {
    initialPosition ??= 0;
    _initialPos = initialPosition;
    final absoluteInitialPosition =
        effectiveStart.inMilliseconds + initialPosition;
    _resumePos = absoluteInitialPosition / 1000.0;
    final fullDuration = (await html5AudioPlayer.loadUri(audioSourcePlayer.uri,
        Duration(milliseconds: absoluteInitialPosition)));
    _initialPos = null;
    if (fullDuration != null) {
      _duration = Duration(
          milliseconds: min((end ?? fullDuration).inMilliseconds,
                  fullDuration.inMilliseconds) -
              effectiveStart.inMilliseconds);
    } else if (end != null) {
      _duration = Duration(
          milliseconds: end!.inMilliseconds - effectiveStart.inMilliseconds);
    }
    return _duration;
  }

  double get remaining =>
      end!.inMilliseconds / 1000 - _audioElement.currentTime;

  @override
  Future<void> play() async {
    if (_completer != null) return;
    _completer = Completer<ClipInterruptReason>();
    _audioElement.currentTime = _resumePos!;
    await _audioElementQueue.play();
    ClipInterruptReason reason;
    while ((reason = await _completer!.future) == ClipInterruptReason.seek) {
      _completer = Completer<ClipInterruptReason>();
    }
    if (reason == ClipInterruptReason.end) {
      await html5AudioPlayer.onEnded().catchError((e, st) {});
    }
    _completer = null;
  }

  @override
  Future<void> pause() async {
    _interruptPlay(ClipInterruptReason.pause);
    _resumePos = _audioElement.currentTime as double?;
    _audioElementQueue.pause();
  }

  @override
  Future<void> seek(int position) async {
    _interruptPlay(ClipInterruptReason.seek);
    _audioElement.currentTime =
        _resumePos = effectiveStart.inMilliseconds / 1000.0 + position / 1000.0;
  }

  @override
  Future<void> complete() async {
    _interruptPlay(ClipInterruptReason.end);
  }

  @override
  Future<void> timeUpdated(double seconds) async {
    if (end != null) {
      if (seconds >= end!.inMilliseconds / 1000) {
        _interruptPlay(ClipInterruptReason.end);
      }
    }
  }

  @override
  Duration? get duration {
    return _duration;
  }

  @override
  Duration get position {
    if (_initialPos != null) return Duration(milliseconds: _initialPos!);
    final seconds = _audioElement.currentTime;
    var position = Duration(milliseconds: (seconds * 1000).toInt());
    position -= effectiveStart;
    if (position < Duration.zero) {
      position = Duration.zero;
    }
    return position;
  }

  @override
  Duration get bufferedPosition {
    if (_audioElement.buffered.length > 0) {
      var seconds =
          _audioElement.buffered.end(_audioElement.buffered.length - 1);
      var position = Duration(milliseconds: (seconds * 1000).toInt());
      position -= effectiveStart;
      if (position < Duration.zero) {
        position = Duration.zero;
      }
      if (duration != null && position > duration!) {
        position = duration!;
      }
      return position;
    } else {
      return Duration.zero;
    }
  }

  void _interruptPlay(ClipInterruptReason reason) {
    if (_completer?.isCompleted == false) {
      _completer!.complete(reason);
    }
  }
}

/// Reasons why playback of a clipping audio source may be interrupted.
enum ClipInterruptReason { end, pause, seek }

/// A player for a [LoopingAudioSourceMessage].
class LoopingAudioSourcePlayer extends AudioSourcePlayer {
  /// The child audio source player to loop.
  final AudioSourcePlayer audioSourcePlayer;

  /// The number of times to loop.
  final int count;

  LoopingAudioSourcePlayer(Html5AudioPlayer html5AudioPlayer, String id,
      this.audioSourcePlayer, this.count)
      : super(html5AudioPlayer, id);

  @override
  List<IndexedAudioSourcePlayer> get sequence =>
      List.generate(count, (i) => audioSourcePlayer)
          .expand((p) => p.sequence)
          .toList();

  @override
  List<int> get shuffleIndices {
    final order = <int>[];
    var offset = order.length;
    for (var i = 0; i < count; i++) {
      final childShuffleOrder = audioSourcePlayer.shuffleIndices;
      order.addAll(childShuffleOrder.map((i) => i + offset).toList());
      offset += childShuffleOrder.length;
    }
    return order;
  }
}

class _AudioElementQueue {
  final _lock = synch.Lock();
  final HTMLAudioElement audioElement;

  _AudioElementQueue(this.audioElement);

  Future<void> pause() {
    return _lock.synchronized(() => audioElement.pause());
  }

  Future<JSAny?> play() {
    return _lock.synchronized(() => audioElement.play().toDart);
  }

  Future<void> load() {
    return _lock.synchronized(() => audioElement.load());
  }

  Future<void> removeAttribute(String qualifiedName) {
    return _lock
        .synchronized(() => audioElement.removeAttribute(qualifiedName));
  }

  Future<JSAny?> setSinkId(String sinkId) {
    return _lock.synchronized(() => audioElement.setSinkId(sinkId).toDart);
  }
}
