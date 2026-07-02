import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/audio_service.dart';
import '../../../../core/utils/url_helper.dart';
import '../../../../main.dart';
import '../../../player/domain/player_state.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../data/dlna_service.dart';
import '../../domain/dlna_state.dart';

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
      final url = UrlHelper.buildSongUrl(song.url!, songFormat: song.format);
      await _service.castTo(device.id, url, title: song.title);

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
        final url = UrlHelper.buildSongUrl(next.url!, songFormat: next.format);
        unawaited(_safeCast(url, next.title));
      }
    });
  }

  /// 带错误兜底的投歌（castTo 内部已带 HttpException 重试）
  Future<void> _safeCast(String url, String title) async {
    final device = state.activeDevice;
    if (device == null) return;
    try {
      await _service.castTo(device.id, url, title: title);
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
          final url =
              UrlHelper.buildSongUrl(song!.url!, songFormat: song.format);
          unawaited(_safeCast(url, song.title));
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
