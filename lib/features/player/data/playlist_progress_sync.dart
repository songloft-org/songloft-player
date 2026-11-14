import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../config/app_config.dart';
import '../domain/player_state.dart';

/// Serializes writes and binds each queued snapshot to its original playlist.
class PlaylistProgressSync {
  PlaylistProgressSync(this.dio, {this.onConflict});
  final void Function()? onConflict;
  final Dio dio;
  int? id;
  int version = 0;
  bool blocked = true;
  bool ready = false;
  bool restoring = false;
  bool _completed = false;
  int _beginGeneration = 0;
  Future<void> _writes = Future.value();
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);
  String path(int id) =>
      '${AppConfig.apiPrefix}/playlists/$id/playback-progress';
  Future<Map<String, dynamic>?> read(int id) async {
    try {
      return Map<String, dynamic>.from((await dio.get(path(id))).data as Map);
    } on DioException {
      return null;
    }
  }

  Future<Map<String, dynamic>?> begin(int playlistId) async {
    final generation = ++_beginGeneration;
    await _writes;
    var value = await read(playlistId);
    final prefs = await SharedPreferences.getInstance();
    final key = 'playlist_pending:${dio.options.baseUrl}:$playlistId';
    final pending = prefs.getString(key);
    if (value != null && pending != null) {
      try {
        final body = jsonDecode(pending) as Map<String, dynamic>;
        if (body['version'] == value['version']) {
          value = Map<String, dynamic>.from(
            (await dio.put(path(playlistId), data: body)).data as Map,
          );
        }
        await prefs.remove(key);
      } on DioException {
        /* Keep the pending snapshot for a later connection. */
      } on FormatException {
        await prefs.remove(key);
      }
    }
    if (generation != _beginGeneration) return null;
    _completed = value?['completed'] == true;
    id = playlistId;
    version = value?['version'] as int? ?? 0;
    blocked = value == null;
    ready = false;
    return value;
  }

  void observe(PlayerState? previous, PlayerState next) {
    if (previous != null &&
        (previous.currentSong?.id != next.currentSong?.id ||
            previous.playbackContext?.playlistId !=
                next.playbackContext?.playlistId)) {
      save(previous);
    }
    if (previous?.currentSong?.id != next.currentSong?.id) ready = false;
    final now = DateTime.now();
    if ((next.isPlaying && now.difference(_last).inSeconds >= 5) ||
        (previous?.isPlaying == true && !next.isPlaying) ||
        previous?.playMode != next.playMode ||
        (next.currentTime - (previous?.currentTime ?? Duration.zero))
                .inMilliseconds
                .abs() >
            1500) {
      _last = now;
      save(next);
    }
  }

  void save(PlayerState state, {bool? completed, bool modeOnly = false}) {
    if (blocked ||
        restoring ||
        (!ready && !modeOnly) ||
        id != state.playbackContext?.playlistId) {
      return;
    }
    final capturedId = id!;
    if (completed != null) _completed = completed;
    final body = <String, dynamic>{
      'play_mode': state.playMode.toStorageString(),
      if (!modeOnly && state.currentSong != null) ...{
        'song_id': state.currentSong!.id,
        'position_ms': state.currentTime.inMilliseconds,
        'completed': _completed,
      },
    };
    _writes = _writes
        .then((_) async {
          if (blocked || id != capturedId) return;
          final prefs = await SharedPreferences.getInstance();
          final key = 'playlist_pending:${dio.options.baseUrl}:$capturedId';
          final request = {...body, 'version': version};
          await prefs.setString(key, jsonEncode(request));
          try {
            final result = await dio.put(path(capturedId), data: request);
            version = (result.data as Map)['version'] as int;
            await prefs.remove(key);
          } on DioException catch (e) {
            if (e.response?.statusCode == 409) {
              blocked = true;
              await prefs.remove(key);
              onConflict?.call();
            }
          }
        })
        .catchError((Object e, StackTrace st) {});
  }
}
