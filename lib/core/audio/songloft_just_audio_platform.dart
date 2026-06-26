import 'dart:collection';

import 'package:flutter/services.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:media_kit/media_kit.dart';

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
    MediaKit.ensureInitialized();
  }

  Player? getPlayer(String id) => _players[id]?.player;

  Player? get firstPlayer {
    if (_players.isEmpty) return null;
    return _players.values.first.player;
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
