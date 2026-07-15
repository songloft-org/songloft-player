import 'dart:collection';

import 'package:flutter/services.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'songloft_mediakit_player.dart';

/// 自定义 [JustAudioPlatform]，替代 [JustAudioMediaKit] 在 Windows/Linux 上注册。
/// 唯一区别：创建 [SongloftMediaKitPlayer]（player 字段为 public），
/// 使 EQ 服务可以通过 [NativePlayer.setProperty] 设置 mpv 音频滤镜。
class SongloftJustAudioPlatform extends JustAudioPlatform {
  SongloftJustAudioPlatform._();

  static final instance = SongloftJustAudioPlatform._();

  final _players = HashMap<String, SongloftMediaKitPlayer>();
  final _disposingPlayers = HashMap<String, Future<void>>();

  static void register() {
    JustAudioPlatform.instance = instance;
    // Win/Linux 不调用 JustAudioMediaKit.ensureInitialized()，其静态配置保持
    // 默认值（mpvLogLevel=error）。SongloftMediaKitPlayer 会读取这些静态字段，
    // 这里将级别提到 warn，让 ffmpeg 的 HTTP 层告警（403/重定向等）也进入日志，
    // 便于排查桌面端 HLS 电台加载失败（songloft-org/songloft#249）。
    JustAudioMediaKit.mpvLogLevel = MPVLogLevel.warn;
    MediaKit.ensureInitialized();
  }

  Player? getPlayer(String id) => _players[id]?.player;

  Player? get firstPlayer {
    if (_players.isEmpty) return null;
    return _players.values.first.player;
  }

  /// 首个 Player 随创建时即派生好的 VideoController（供视频画面渲染）。
  /// 控制器在 Player 构造时就绪，故无绑定时序竞态。
  VideoController? get firstVideoController {
    if (_players.isEmpty) return null;
    return _players.values.first.videoController;
  }

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    if (_players.containsKey(request.id)) {
      throw PlatformException(
        code: 'error',
        message: 'Player ${request.id} already exists!',
      );
    }
    final player = SongloftMediaKitPlayer(request.id);
    _players[request.id] = player;
    await player.ready();
    return player;
  }

  @override
  Future<DisposePlayerResponse> disposePlayer(
      DisposePlayerRequest request) async {
    if (_disposingPlayers.containsKey(request.id)) {
      await _disposingPlayers[request.id];
      return DisposePlayerResponse();
    }
    final player = _players.remove(request.id);
    if (player != null) {
      final future = player.release();
      _disposingPlayers[request.id] = future;
      await future;
      _disposingPlayers.remove(request.id);
    }
    return DisposePlayerResponse();
  }

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(
      DisposeAllPlayersRequest request) async {
    for (final player in _players.values) {
      await player.release();
    }
    _players.clear();
    await Future.wait(_disposingPlayers.values);
    return DisposeAllPlayersResponse();
  }
}
