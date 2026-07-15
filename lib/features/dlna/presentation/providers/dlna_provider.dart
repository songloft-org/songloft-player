import 'dart:async';
import 'package:dlna_dart/xmlParser.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/audio_service.dart';
import '../../../../core/utils/audio_format_helper.dart';
import '../../../../core/utils/url_helper.dart';
import '../../../../main.dart';
import '../../../../shared/models/song.dart';
import '../../../player/domain/player_state.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../data/dlna_service.dart';
import '../../domain/dlna_state.dart';

/// 一次投屏所需的参数：资源 URL + DIDL mime 类型。
typedef _CastArgs = ({String url, PlayType mime});

/// 按歌曲真实格式挑选投屏参数。
///
/// 视频歌曲：用 media=video URL（后端直出原容器，保留画面）+ 对应 VideoMime；
/// 音频歌曲：用普通播放 URL（可能带平台转码）+ 与最终格式匹配的 AudioMime。
/// 不再一律硬编码 audio/mp3，避免非 mp3/视频在严格渲染器上被拒。
_CastArgs _castArgsFor(Song song) {
  if (song.isVideo) {
    return (url: UrlHelper.buildVideoUrl(song.url!), mime: _videoMime(song));
  }
  // 音频投屏若发生平台转码（如 wma→mp3），mime 应反映转码后的最终格式。
  final effective =
      AudioFormatHelper.getTranscodeFormat(song.format) ??
      (song.format ?? '').toLowerCase();
  return (
    url: UrlHelper.buildSongUrl(song.url!, songFormat: song.format),
    mime: _audioMime(effective),
  );
}

/// 视频 mime：优先按文件扩展名判断真实容器（视频 mp4 的 song.format 会被后端归一化为 m4a，不可靠）。
VideoMime _videoMime(Song song) {
  var ext = (song.format ?? '').toLowerCase();
  final path = song.filePath;
  if (path != null && path.contains('.')) {
    ext = path.split('.').last.toLowerCase();
  }
  switch (ext) {
    case 'mp4':
    case 'm4v':
      return VideoMime.mp4;
    case 'mkv':
    case 'matroska':
      return VideoMime.xMatroska;
    case 'webm': // webm 是 matroska 子集，多数渲染器按 x-matroska 处理
      return VideoMime.xMatroska;
    case 'mov':
    case 'quicktime':
      return VideoMime.quicktime;
    case 'avi':
      return VideoMime.avi;
    case 'wmv':
      return VideoMime.xMsWmv;
    case 'ts':
    case 'mpegts':
    case 'mp2t':
      return VideoMime.ts;
    default:
      return VideoMime.any;
  }
}

/// 音频 mime：按最终音频格式匹配，未知回退 mp3（兼容历史默认行为）。
AudioMime _audioMime(String fmt) {
  switch (fmt.toLowerCase()) {
    case 'mp3':
    case 'mpeg':
      return AudioMime.mp3;
    case 'm4a':
    case 'mp4':
    case 'aac':
      return AudioMime.mp4;
    case 'flac':
      return AudioMime.xFlac;
    case 'wav':
    case 'wave':
      return AudioMime.wav;
    case 'wma':
      return AudioMime.wma;
    case 'ape':
      return AudioMime.xApe;
    default:
      return AudioMime.mp3;
  }
}

final dlnaServiceProvider = Provider<DlnaService>((ref) {
  final service = DlnaService();
  ref.onDispose(() => service.dispose());
  return service;
});

final dlnaStateProvider =
    NotifierProvider<DlnaNotifier, DlnaState>(DlnaNotifier.new);

class DlnaNotifier extends Notifier<DlnaState> {
  StreamSubscription? _devicesSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _completionSub;

  @override
  DlnaState build() {
    ref.onDispose(() {
      _devicesSub?.cancel();
      _positionSub?.cancel();
      _completionSub?.cancel();
    });
    return const DlnaState();
  }

  DlnaService get _service => ref.read(dlnaServiceProvider);
  SongloftAudioHandler get _audioHandler => ref.read(audioHandlerProvider);

  Future<void> startDiscovery() async {
    if (state.isDiscovering) return;
    state = state.copyWith(isDiscovering: true, error: () => null);

    try {
      await _service.startDiscovery();
      _devicesSub?.cancel();
      _devicesSub = _service.devicesStream.listen((devices) {
        state = state.copyWith(devices: devices);
      });
    } catch (e) {
      state = state.copyWith(
        isDiscovering: false,
        error: () => e.toString(),
      );
    }
  }

  void stopDiscovery() {
    _devicesSub?.cancel();
    _service.stopDiscovery();
    state = state.copyWith(isDiscovering: false);
  }

  Future<void> castToDevice(DlnaDeviceInfo device) async {
    final playerState = ref.read(playerStateProvider);
    final song = playerState.currentSong;
    if (song == null || song.url == null) return;

    state = state.copyWith(error: () => null);

    try {
      final args = _castArgsFor(song);
      await _service.castTo(
        device.id,
        args.url,
        title: song.title,
        mime: args.mime,
      );

      await _audioHandler.pause();

      _positionSub?.cancel();
      _positionSub = _service.positionStream.listen((pos) {
        state = state.copyWith(
          position: Duration(seconds: pos.RelTimeInt),
          duration: Duration(seconds: pos.TrackDurationInt),
        );
      });

      _completionSub?.cancel();
      _completionSub =
          _service.completionStream.listen((_) => _onDeviceCompleted());

      _listenSongChanges();

      state = state.copyWith(
        activeDevice: () => device,
        isCasting: true,
        isPlaying: true,
      );
    } catch (e) {
      state = state.copyWith(error: () => e.toString());
    }
  }

  int? _lastSongId;

  void _listenSongChanges() {
    _lastSongId = ref.read(playerStateProvider).currentSong?.id;
    ref.listen(currentSongProvider, (prev, next) {
      if (!state.isCasting || next == null) return;
      if (next.id == _lastSongId) return;
      _lastSongId = next.id;
      if (next.url != null) {
        unawaited(_safeCast(next));
      }
    });
  }

  /// 带错误兜底的投歌（castTo 内部已带 HttpException 重试）
  Future<void> _safeCast(Song song) async {
    final device = state.activeDevice;
    if (device == null) return;
    try {
      final args = _castArgsFor(song);
      await _service.castTo(
        device.id,
        args.url,
        title: song.title,
        mime: args.mime,
      );
      state = state.copyWith(isPlaying: true, error: () => null);
    } catch (e) {
      state = state.copyWith(error: () => e.toString());
    }
  }

  /// 设备端当前曲播放完成：按播放模式推进歌单。
  /// order/loop/random 推进队列后由 [_listenSongChanges] 自动投下一首；
  /// single 循环重投当前曲；singlePlay 与顺序模式末尾则停止。
  void _onDeviceCompleted() {
    if (!state.isCasting) return;
    final playerNotifier = ref.read(playerStateProvider.notifier);
    final playerState = ref.read(playerStateProvider);

    switch (playerState.playMode) {
      case PlayMode.singlePlay:
        state = state.copyWith(isPlaying: false);
        return;
      case PlayMode.single:
        final song = playerState.currentSong;
        if (song?.url != null) {
          unawaited(_safeCast(song!));
        }
        return;
      case PlayMode.order:
      case PlayMode.loop:
      case PlayMode.random:
        final next = playerNotifier.advanceForCasting();
        if (next == null) {
          // 顺序模式已到末尾
          state = state.copyWith(isPlaying: false);
        }
        // next 非空：currentSong 变化 → _listenSongChanges 自动投下一首
        return;
    }
  }

  Future<void> togglePlay() async {
    if (!state.isCasting) return;
    try {
      if (state.isPlaying) {
        await _service.pause();
      } else {
        await _service.play();
      }
      state = state.copyWith(isPlaying: !state.isPlaying);
    } catch (e) {
      state = state.copyWith(error: () => e.toString());
    }
  }

  Future<void> seekTo(Duration position) async {
    if (!state.isCasting) return;
    await _service.seek(position);
  }

  Future<void> setVolume(int volume) async {
    if (!state.isCasting) return;
    await _service.setVolume(volume);
  }

  void disconnect() {
    _positionSub?.cancel();
    _completionSub?.cancel();
    _service.disconnect();
    state = state.copyWith(
      activeDevice: () => null,
      isCasting: false,
      isPlaying: false,
      position: Duration.zero,
      duration: Duration.zero,
    );
  }
}
