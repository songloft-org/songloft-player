import 'dart:async';
import 'package:dlna_dart/xmlParser.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/audio_service.dart';
import '../../../../core/network/lan_address.dart';
import '../../../../core/utils/audio_format_helper.dart';
import '../../../../core/utils/url_helper.dart';
import '../../../../main.dart';
import '../../../../shared/models/song.dart';
import '../../../player/domain/player_state.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../data/dlna_service.dart';
import '../../data/dlna_log.dart';
import '../../domain/dlna_state.dart';

/// 一次投屏所需的参数：资源 URL + DIDL mime 类型。
typedef _CastArgs = ({String url, PlayType mime});

/// 把投屏 URL 的 host 从回环地址换成局域网地址。
///
/// Bundle 本地模式下播放 URL 的 host 固定是 127.0.0.1（App 自己访问用，性能最优）；
/// 但投屏 URL 要交给局域网内的外部渲染器（DLNA 设备），回环地址对它们无意义，
/// 必须换成本机真正的局域网 IP。非本地模式（host 已是真实服务器地址）时原样返回。
Future<String> _toCastReachableUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || (uri.host != '127.0.0.1' && uri.host != 'localhost')) {
    return url;
  }
  final lanIp = await LanAddress.resolve();
  if (lanIp == null) return url;
  return uri.replace(host: lanIp).toString();
}

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
    case 'mpg':
    case 'mpeg':
      return VideoMime.mpeg;
    case 'flv':
      return VideoMime.flv;
    case '3gp':
      return VideoMime.any; // dlna_dart 无 3gpp 专用类型，用通用 MIME
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

final dlnaStateProvider = NotifierProvider<DlnaNotifier, DlnaState>(
  DlnaNotifier.new,
);

class DlnaNotifier extends Notifier<DlnaState> {
  Future<void> _commands = Future<void>.value();
  int _generation = 0;
  bool _isChangingSong = false;

  Future<void> _serialize(Future<void> Function() command) {
    final result = _commands.then((_) => command());
    _commands = result.catchError((Object _) {});
    return result;
  }

  StreamSubscription? _devicesSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _completionSub;

  @override
  DlnaState build() {
    ref.onDispose(() {
      ++_generation;
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
      state = state.copyWith(isDiscovering: false, error: () => e.toString());
    }
  }

  void stopDiscovery() {
    _devicesSub?.cancel();
    _service.stopDiscovery();
    state = state.copyWith(isDiscovering: false);
  }

  void clearError() => state = state.copyWith(error: () => null);

  Future<void> castToDevice(DlnaDeviceInfo device) async {
    final playerState = ref.read(playerStateProvider);
    final song = playerState.currentSong;
    if (song == null || song.url == null) return;
    final generation = ++_generation;

    state = state.copyWith(error: () => null);

    try {
      final args = _castArgsFor(song);
      final url = await _toCastReachableUrl(args.url);
      await _serialize(() async {
        if (generation != _generation) return;
        await _service.castTo(
          device.id,
          url,
          title: song.title,
          mime: args.mime,
        );
        if (generation != _generation) return;
        await _audioHandler.pause();
      });
      if (generation != _generation) return;

      _positionSub?.cancel();
      _positionSub = _service.positionStream.listen((pos) {
        state = state.copyWith(
          position: Duration(seconds: pos.RelTimeInt),
          duration: Duration(seconds: pos.TrackDurationInt),
        );
      });

      _completionSub?.cancel();
      _completionSub = _service.completionStream.listen(
        (_) => _onDeviceCompleted(),
      );

      state = state.copyWith(
        activeDevice: () => device,
        isCasting: true,
        isPlaying: true,
        position: Duration.zero,
        duration: Duration(milliseconds: (song.duration * 1000).round()),
      );
    } catch (e) {
      if (generation != _generation) return;
      dlnaLog('castToDevice failed device=${device.id} song=${song.id}: $e');
      state = state.copyWith(error: () => e.toString());
    }
  }

  /// 带错误兜底的投歌（castTo 内部已带 HttpException 重试）
  Future<void> castSong(Song song) async {
    final device = state.activeDevice;
    if (!state.isCasting || device == null || song.url == null) return;
    final generation = ++_generation;
    _isChangingSong = true;
    try {
      final args = _castArgsFor(song);
      final url = await _toCastReachableUrl(args.url);
      await _serialize(() async {
        if (generation != _generation || !state.isCasting) return;
        await _service.castTo(
          device.id,
          url,
          title: song.title,
          mime: args.mime,
        );
      });
      if (generation != _generation || !state.isCasting) return;
      state = state.copyWith(
        isPlaying: true,
        position: Duration.zero,
        duration: Duration(milliseconds: (song.duration * 1000).round()),
        error: () => null,
      );
    } catch (e) {
      if (generation != _generation) return;
      dlnaLog('castSong failed device=${device.id} song=${song.id}: $e');
      state = state.copyWith(error: () => e.toString());
    } finally {
      if (generation == _generation) _isChangingSong = false;
    }
  }

  /// 设备端当前曲播放完成：按播放模式推进歌单。
  /// order/loop/random 推进队列后直接投下一首；
  /// single 循环重投当前曲；singlePlay 与顺序模式末尾则停止。
  void _onDeviceCompleted() {
    if (!state.isCasting || _isChangingSong) return;
    final playerNotifier = ref.read(playerStateProvider.notifier);
    final playerState = ref.read(playerStateProvider);

    switch (playerState.playMode) {
      case PlayMode.singlePlay:
        state = state.copyWith(isPlaying: false);
        return;
      case PlayMode.single:
        final song = playerState.currentSong;
        if (song?.url != null) {
          unawaited(castSong(song!));
        }
        return;
      case PlayMode.order:
      case PlayMode.loop:
      case PlayMode.random:
        final next = playerNotifier.advanceForCasting();
        if (next == null) {
          // 顺序模式已到末尾
          state = state.copyWith(isPlaying: false);
        } else {
          unawaited(castSong(next));
        }
        return;
    }
  }

  Future<void> togglePlay() async {
    if (!state.isCasting) return;
    try {
      await _serialize(() async {
        if (!state.isCasting) return;
        final playing = state.isPlaying;
        if (playing) {
          await _service.pause();
        } else {
          await _service.play();
        }
        if (state.isCasting) state = state.copyWith(isPlaying: !playing);
      });
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
    ++_generation;
    _isChangingSong = false;
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
