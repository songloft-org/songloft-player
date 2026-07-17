import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'audio_backend.dart';
import '../../config/app_config.dart';

/// [MediaKitPlayer] 的本地重新实现，唯一区别是 [player] 字段为 public。
/// 用于 Windows/Linux 平台的 EQ 均衡器——需要通过 [NativePlayer.setProperty]
/// 设置 mpv 的 `af` 音频滤镜。
class SongloftMediaKitPlayer extends AudioPlayerPlatform {
  static const Duration _mediaLoadTimeout = Duration(seconds: 18);

  late final Player player;

  /// 视频画面控制器：在 [Player] 创建后、任何 `open()` 之前**立即**建好，
  /// 使 media_kit 的 libmpv render context 在打开媒体时已就绪。
  ///
  /// 若推迟到 UI 首次渲染视频时才创建（旧做法），libmpv 会在 `open()` 时因
  /// "No render context set" 直接 fatal 并**永久禁用**该会话的视频输出——
  /// 表现为音频正常、画面全黑/回退封面（songloft-org/songloft#76）。
  /// 纯音频歌曲也会持有此控制器，仅多一个空闲纹理，无画面开销。
  /// Web 及回退到原生后端的平台不支持派生 VideoController，置空。
  ///
  /// 注意：必须在构造函数里 [player] 创建后**立即**（eagerly）赋值，
  /// 不能用 `late final = ...` 惰性初始化——否则仍会推迟到首次访问才建，
  /// 无法保证早于 `open()`。
  late final VideoController? videoController;

  late final List<StreamSubscription> _streamSubscriptions;
  final _readyCompleter = Completer<void>();

  /// 视频纹理（render context）就绪信号。VideoController 构造同步返回，但其原生
  /// render context + 纹理是**异步**建立的；若 `open()` 抢在其之前执行，libmpv 仍会
  /// 报 "No render context set" 而永久禁用视频输出（偶发黑屏）。故首次 `open()` 前
  /// 等待此信号（纹理 id 变为非 null 即表示 render context 已挂上），加超时兜底。
  /// videoController 为空（不支持视频的平台）时立即完成。
  final _videoTextureReady = Completer<void>();
  static const Duration _videoReadyTimeout = Duration(seconds: 3);

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
  bool _released = false;

  /// 是否曾修改过 mpv 的 tls-verify 属性（用于在用户关闭 insecureTls 后恢复默认值）。
  bool _tlsVerifyOverridden = false;

  Media? get _currentMedia {
    final playlist = player.state.playlist;
    final index = _validPlaylistIndex(playlist);
    if (index == null) return null;
    return playlist.medias[index];
  }

  int? _validPlaylistIndex(Playlist playlist) {
    final medias = playlist.medias;
    if (medias.isEmpty) return null;
    final index = playlist.index;
    if (index < 0 || index >= medias.length) return null;
    return index;
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

    // 立即派生 VideoController（在任何 open() 之前），让 libmpv 的 render context
    // 在打开媒体时已就绪，避免视频输出因 "No render context set" 被永久禁用。
    videoController =
        AudioBackend.usesMediaKit ? VideoController(player) : null;
    _watchVideoTextureReady();

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
        } else if (_processingState != ProcessingStateMessage.completed) {
          _processingState =
              isBuffering
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
        _addPlayerData(PlayerDataMessage(volume: volume / 100.0));
      }),
      player.stream.completed.listen((completed) {
        _bufferedPosition = _position = Duration.zero;
        if (completed &&
            _currentIndex == player.state.playlist.medias.length - 1 &&
            player.state.playlistMode == PlaylistMode.none) {
          _processingState = ProcessingStateMessage.completed;
        } else if (!completed &&
            _processingState == ProcessingStateMessage.completed) {
          // seek 从 completed 状态恢复时，允许过渡到 buffering
          _processingState = ProcessingStateMessage.buffering;
        }
        _errorCode = null;
        _errorMessage = null;
        _updatePlaybackEvent();
      }),
      player.stream.error.listen((error) {
        // 用 debugPrint 而非 print，使 libmpv/ffmpeg 的原始错误（如
        // "Failed to open <url>."）写入 FileLogger，便于排查桌面端 HLS 电台
        // 加载失败——否则最终只会在上层看到被 just_audio 掩盖的
        // "Loading interrupted"（songloft-org/songloft#249）。
        debugPrint('[MediaKit] player error: $error');
        final errorUri = RegExp(r'Failed to open (.*)\.').firstMatch(error)?[1];
        final currentMedia = _currentMedia;
        if (errorUri == null ||
            currentMedia == null ||
            errorUri == currentMedia.uri) {
          _mediaOpened = false;
          _completeLoadError(Exception(error));
        }
      }),
      player.stream.playlist.listen((playlist) {
        final index = _validPlaylistIndex(playlist);
        if (index != null && _currentIndex != index) {
          _bufferedPosition = _position = Duration.zero;
          _currentIndex = index;
        }
        _duration = _currentMedia?.extras?['overrideDuration'];
        _updatePlaybackEvent();
      }),
      player.stream.playlistMode.listen((playlistMode) {
        _addPlayerData(
          PlayerDataMessage(loopMode: _playlistModeToLoopMode(playlistMode)),
        );
      }),
      player.stream.pitch.listen((pitch) {
        _addPlayerData(PlayerDataMessage(pitch: pitch));
      }),
      player.stream.rate.listen((rate) {
        _addPlayerData(PlayerDataMessage(speed: rate));
      }),
      player.stream.log.listen((event) {
        // 用 debugPrint 写入 FileLogger（main.dart 只拦截 debugPrint，
        // 裸 print 只进控制台、不进用户可上传的日志文件），
        // 保证 libmpv 日志能随附件日志一起提交排查（songloft-org/songloft#249）。
        debugPrint('MPV: [${event.level}] ${event.prefix}: ${event.text}');
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
    if (_released || _eventController.isClosed) return;

    _eventController.add(
      PlaybackEventMessage(
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
      ),
    );
  }

  void _addPlayerData(PlayerDataMessage message) {
    if (_released || _dataController.isClosed) return;
    _dataController.add(message);
  }

  /// 监听 VideoController 纹理 id：非 null 即表示 render context 已建立，
  /// 完成 [_videoTextureReady]。videoController 为空则立即完成。
  void _watchVideoTextureReady() {
    final controller = videoController;
    if (controller == null || controller.id.value != null) {
      if (!_videoTextureReady.isCompleted) _videoTextureReady.complete();
      return;
    }
    void listener() {
      if (controller.id.value != null && !_videoTextureReady.isCompleted) {
        _videoTextureReady.complete();
        controller.id.removeListener(listener);
      }
    }

    controller.id.addListener(listener);
  }

  /// 首次 `open()` 前等待视频纹理就绪，避免 render context 未挂上就打开媒体导致
  /// 视频输出被永久禁用。超时兜底（音频优先，不因纹理迟迟不就绪而卡住）。
  Future<void> _awaitVideoTextureReady() async {
    if (_videoTextureReady.isCompleted) return;
    try {
      await _videoTextureReady.future.timeout(_videoReadyTimeout);
    } on TimeoutException {
      debugPrint('[SongloftMediaKitPlayer] 视频纹理就绪超时，继续打开媒体');
    }
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
    final loadCompleter = Completer<Duration?>();
    _loadCompleter = loadCompleter;
    _currentIndex = request.initialIndex ?? 0;
    _bufferedPosition = Duration.zero;
    _position = Duration.zero;
    _duration = null;
    _processingState = ProcessingStateMessage.loading;
    _errorCode = null;
    _errorMessage = null;
    _updatePlaybackEvent();

    // 打开媒体前确保视频 render context 已就绪（首次之后 completer 已完成，无开销），
    // 消除 open() 抢跑于纹理建立之前导致的偶发黑屏。
    await _awaitVideoTextureReady();

    // 用户开启「忽略 SSL 证书校验」时同步设置 mpv 的 tls-verify=no，
    // 使 AudioSource.uri 路径（Windows 普通歌曲、直播流、视频）也能连接自签证书服务器。
    // 关闭时恢复 tls-verify=yes（仅在之前改过的情况下才恢复，避免改变默认行为）。
    // try-catch 兜底：mpv 版本若不支持该属性，不能阻塞播放主路径。
    try {
      if (AppConfig.insecureTls) {
        await _setMpvProperty('tls-verify', 'no');
        _tlsVerifyOverridden = true;
      } else if (_tlsVerifyOverridden) {
        await _setMpvProperty('tls-verify', 'yes');
        _tlsVerifyOverridden = false;
      }
    } catch (e) {
      debugPrint('[SongloftMediaKitPlayer] tls-verify 设置失败 (ignored): $e');
    }

    if (request.audioSourceMessage is ConcatenatingAudioSourceMessage) {
      final audioSource =
          request.audioSourceMessage as ConcatenatingAudioSourceMessage;
      final playable = Playlist(
        audioSource.children.map(_convertAudioSource).toList(),
        index: _currentIndex,
      );
      await _openMedia(() => player.open(playable, play: _playing));
    } else {
      final playable = _convertAudioSource(request.audioSourceMessage);
      await _openMedia(() => player.open(playable, play: _playing));
    }
    _mediaOpened = true;

    if (request.initialPosition != null) {
      _setPosition = _position = request.initialPosition!;
    }

    _updatePlaybackEvent();
    try {
      final duration = await _waitForLoadReady(loadCompleter);
      return LoadResponse(duration: duration);
    } finally {
      if (_loadCompleter == loadCompleter) {
        _loadCompleter = null;
      }
    }
  }

  Future<void> _openMedia(Future<void> Function() open) async {
    try {
      await open().timeout(_mediaLoadTimeout);
    } on TimeoutException catch (error) {
      _loadCompleter = null;
      _mediaOpened = false;
      _setLoadError(error);
      unawaited(player.stop());
      rethrow;
    } catch (error) {
      _loadCompleter = null;
      _mediaOpened = false;
      _setLoadError(error);
      rethrow;
    }
  }

  Future<Duration?> _waitForLoadReady(
    Completer<Duration?> loadCompleter,
  ) async {
    try {
      return await loadCompleter.future.timeout(_mediaLoadTimeout);
    } on TimeoutException catch (error) {
      if (_loadCompleter == loadCompleter) {
        _loadCompleter = null;
      }
      _mediaOpened = false;
      _setLoadError(error);
      unawaited(player.stop());
      rethrow;
    }
  }

  void _completeLoadError(Object error) {
    _setLoadError(error);
    final completer = _loadCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.completeError(error);
    }
  }

  void _setLoadError(Object error) {
    _processingState = ProcessingStateMessage.idle;
    _errorCode = 1;
    _errorMessage = error.toString();
    _updatePlaybackEvent();
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
    SetShuffleModeRequest request,
  ) async {
    bool shuffling = request.shuffleMode != ShuffleModeMessage.none;
    await player.setShuffle(shuffling);
    _addPlayerData(
      PlayerDataMessage(
        shuffleMode:
            shuffling ? ShuffleModeMessage.all : ShuffleModeMessage.none,
      ),
    );
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
    ConcatenatingInsertAllRequest request,
  ) async {
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
    ConcatenatingRemoveRangeRequest request,
  ) async {
    for (var i = request.startIndex; i < request.endIndex; i++) {
      await player.remove(request.startIndex);
    }
    return ConcatenatingRemoveRangeResponse();
  }

  @override
  Future<ConcatenatingMoveResponse> concatenatingMove(
    ConcatenatingMoveRequest request,
  ) => player
      .move(
        request.currentIndex,
        request.currentIndex > request.newIndex
            ? request.newIndex
            : request.newIndex + 1,
      )
      .then((_) => ConcatenatingMoveResponse());

  Future<void> release() async {
    if (_released) return;
    debugPrint('[SongloftMediaKitPlayer] release 开始');
    _released = true;
    _mediaOpened = false;

    if (_loadCompleter?.isCompleted == false) {
      _loadCompleter?.complete(null);
    }

    for (final sub in _streamSubscriptions) {
      await sub.cancel();
    }
    _streamSubscriptions.clear();
    debugPrint('[SongloftMediaKitPlayer] subscriptions canceled');

    await player.dispose();
    debugPrint('[SongloftMediaKitPlayer] media_kit player disposed');
    await _eventController.close();
    await _dataController.close();
    debugPrint('[SongloftMediaKitPlayer] controllers closed');
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

  LoopModeMessage _playlistModeToLoopMode(PlaylistMode mode) => switch (mode) {
    PlaylistMode.none => LoopModeMessage.off,
    PlaylistMode.single => LoopModeMessage.one,
    PlaylistMode.loop => LoopModeMessage.all,
  };

  Media _convertAudioSource(AudioSourceMessage source) => switch (source) {
    UriAudioSourceMessage(:final uri, :final headers) => Media(
      uri,
      httpHeaders: headers,
    ),
    ClippingAudioSourceMessage(:final child, :final start, :final end) => Media(
      child.uri,
      start: start,
      end: end,
    ),
    _ =>
      throw UnsupportedError(
        '${source.runtimeType} is currently not supported',
      ),
  };
}
