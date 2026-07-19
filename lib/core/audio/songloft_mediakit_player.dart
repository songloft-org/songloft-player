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

  /// 视频画面控制器。
  ///
  /// **桌面（Win/Linux/macOS）**：在 [player] 创建后、任何 `open()` 之前**立即**建好，
  /// 使 libmpv render context 在打开媒体时已就绪；否则推迟到首次渲染视频才建会触发
  /// "No render context set" fatal 并永久禁用视频输出（songloft-org/songloft#76）。
  ///
  /// **移动端（Android/iOS）**：**不在构造时预建**。VideoController 一经构造即把 player
  /// 标记为 `isVideoControllerAttached=true`，此后 libmpv 的每个 `open()/play()/seek()`
  /// 都要先 `await` 视频初始化 Future——而 Android 在无 `Video` widget 挂载时该 Future
  /// 可能迟迟不完成，导致**所有歌曲（含纯音频）`open()` 被挂住而播放失败**（6d7110c 把
  /// 移动端默认后端翻成 media_kit 后 Android 全曲无法播放的根因）。故移动端改为惰性：仅在
  /// [load] 判定为视频源（URL 带 `media=video`）时，于 `open()` 之前才创建
  /// （见 [_ensureVideoControllerForVideo]），纯音频永不 attach → 不触发该门闩。
  ///
  /// Web 及回退到原生后端的平台不支持派生 VideoController，恒为 null。
  VideoController? videoController;

  late final List<StreamSubscription> _streamSubscriptions;
  final _readyCompleter = Completer<void>();

  /// 视频纹理（render context）就绪等待超时：VideoController 构造同步返回，但其原生
  /// render context + 纹理是**异步**建立的；首次 `open()` 前等待纹理 id 变为非 null，
  /// 加此超时兜底（音频优先，不因纹理迟迟不就绪而卡住）。
  static const Duration _videoReadyTimeout = Duration(seconds: 3);

  /// Android ao/cache 兜底是否已配置（只需设一次）。
  bool _androidAudioConfigured = false;

  static bool get _isMobilePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

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

    // 桌面（Win/Linux/macOS）立即派生 VideoController（在任何 open() 之前），让 libmpv 的
    // render context 在打开媒体时已就绪，避免视频输出因 "No render context set" 被永久禁用。
    // 移动端刻意不预建（见 videoController 字段文档）：避免 isVideoControllerAttached 的
    // open() 门闩在 Android 无 Video widget 时挂住全部播放；改由 load() 惰性按视频源创建。
    if (AudioBackend.usesMediaKit && !_isMobilePlatform) {
      videoController = VideoController(player);
    }

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

  /// 移动端惰性创建 VideoController：仅当本次确为视频源时，于 `open()` 之前建好，
  /// 保证 render context 就绪（避免 "No render context set"）。桌面已在构造时建好，
  /// 此处 no-op；纯音频（videoController 保持 null）不 attach → 不触发 open() 门闩。
  void _ensureVideoControllerForVideo() {
    if (videoController != null || !AudioBackend.usesMediaKit) return;
    videoController = VideoController(player);
  }

  /// 首次 `open()` 前等待**当前** VideoController 的纹理就绪，避免 render context 未挂上
  /// 就打开媒体导致视频输出被永久禁用。无控制器（纯音频）或已就绪则立即返回；超时兜底
  /// （音频优先，不因纹理迟迟不就绪而卡住）。
  Future<void> _awaitVideoTextureReady() async {
    final controller = videoController;
    if (controller == null || controller.id.value != null) return;
    final completer = Completer<void>();
    void listener() {
      if (controller.id.value != null && !completer.isCompleted) {
        completer.complete();
        controller.id.removeListener(listener);
      }
    }

    controller.id.addListener(listener);
    try {
      await completer.future.timeout(_videoReadyTimeout);
    } on TimeoutException {
      controller.id.removeListener(listener);
      debugPrint('[SongloftMediaKitPlayer] 视频纹理就绪超时，继续打开媒体');
    }
  }

  /// 判定一次加载请求是否为视频源（URL 带 `media=video`，由 UrlHelper.buildVideoUrl 追加）。
  bool _isVideoRequest(AudioSourceMessage message) => switch (message) {
    UriAudioSourceMessage(:final uri) => uri.contains('media=video'),
    ClippingAudioSourceMessage(:final child) => child.uri.contains(
      'media=video',
    ),
    ConcatenatingAudioSourceMessage(:final children) => children.any(
      _isVideoRequest,
    ),
    _ => false,
  };

  /// Android 音频输出/缓存兜底（只配置一次，首次 open 前）：
  /// - `ao=audiotrack,opensles`：media_kit 在 Android 硬编码 `ao=opensles`，个别设备
  ///   OpenSL ES 输出异常会「有进度、无 error、但完全无声」；优先 AudioTrack（旧 ExoPlayer
  ///   后端亦走它），opensles 兜底。
  /// - `cache-on-disk=no`：libmpv 磁盘缓存目录默认取 CWD/XDG_CACHE_HOME，Android（尤其
  ///   Bundle 本地模式 CWD=`/`）常不可写；just_audio 的 LockCaching 已自带边播边缓存，
  ///   libmpv 无需再落盘。
  Future<void> _configureAndroidAudioOnce() async {
    if (_androidAudioConfigured || !_isAndroid) return;
    _androidAudioConfigured = true;
    try {
      await _setMpvProperty('ao', 'audiotrack,opensles');
      await _setMpvProperty('cache-on-disk', 'no');
    } catch (e) {
      debugPrint('[SongloftMediaKitPlayer] Android ao/cache 配置失败 (ignored): $e');
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

    // 移动端惰性创建 VideoController：仅视频源在 open() 之前建（纯音频不 attach，
    // 规避 isVideoControllerAttached 对 open() 的门闩）。桌面已在构造时建好，此处 no-op。
    if (_isVideoRequest(request.audioSourceMessage)) {
      _ensureVideoControllerForVideo();
    }

    // Android 音频输出/缓存兜底（首次 open 前配置一次）。
    await _configureAndroidAudioOnce();

    // 打开媒体前确保视频 render context 已就绪（无 VideoController 时立即返回，无开销），
    // 消除 open() 抢跑于纹理建立之前导致的偶发黑屏。
    await _awaitVideoTextureReady();

    // 用户开启「忽略 SSL 证书校验」时设 mpv 的 tls-verify=no，作为未经本地代理的直连
    // 路径（AudioSource.uri）的兜底——正常情况下 audio_service 已在开关开启时把这些源
    // 导向 just_audio 本地明文代理，libmpv 只连 127.0.0.1、无需 TLS；此处再设一层以防
    // 有遗漏的直连路径（songloft-org/songloft#272）。
    // **关闭开关时刻意不设 tls-verify=yes**：media_kit 内置 libmpv 多数未打包 CA 证书，
    // 强制开启校验会导致连有效证书（如 Let's Encrypt）也校验失败而无法播放；保持 mpv
    // 构建默认值最安全。try-catch 兜底：旧版 mpv 不支持该属性时不能阻塞播放主路径。
    if (AppConfig.insecureTls) {
      try {
        await _setMpvProperty('tls-verify', 'no');
      } catch (e) {
        debugPrint('[SongloftMediaKitPlayer] tls-verify 设置失败 (ignored): $e');
      }
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

  /// Android 专属：just_audio 在 Android 上（经 audio_session 配置）会对平台 player 调用
  /// 此方法设置原生 AudioAttributes。基类默认实现直接 `throw UnimplementedError`，而
  /// media_kit 后端未重写它 —— 于是 6d7110c 把移动端默认后端翻成 media_kit 后，Android
  /// 上每次 `setAudioSource` 都抛 "setAndroidAudioAttributes() has not been implemented."
  /// 导致**全部歌曲无法播放**（桌面从不调用此方法，故只在 Android 复现）。
  /// libmpv 自管音频输出（ao=audiotrack/opensles），AudioAttributes 不经此通道下发，
  /// 故实现为安全 no-op：吞掉调用、返回空响应，让加载/播放继续（songloft-org/songloft#76）。
  @override
  Future<SetAndroidAudioAttributesResponse> setAndroidAudioAttributes(
    SetAndroidAudioAttributesRequest request,
  ) async => SetAndroidAudioAttributesResponse();

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
