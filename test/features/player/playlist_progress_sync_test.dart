import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songloft_flutter/features/player/data/playlist_progress_sync.dart';
import 'package:songloft_flutter/features/player/domain/player_state.dart';
import 'package:songloft_flutter/features/player/domain/playback_context.dart';
import 'package:songloft_flutter/shared/models/song.dart';

class ProgressAdapter implements HttpClientAdapter {
  int version = 0;
  bool conflict = false;
  final bodies = <Map<String, dynamic>>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    if (options.method == 'PUT') {
      bodies.add(Map<String, dynamic>.from(options.data as Map));
      if (conflict) {
        return ResponseBody.fromString(
          '{}',
          409,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
      version++;
    }
    return ResponseBody.fromString(
      jsonEncode({'version': version, 'song': null, 'play_mode': 'order'}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  test(
    'an unconfirmed loading attempt cannot overwrite the previous position',
    () async {
      final adapter = ProgressAdapter();
      final sync = PlaylistProgressSync(Dio()..httpClientAdapter = adapter);
      await sync.begin(3);
      final next = PlayerState(
        currentSong: Song.fromJson({
          'id': 128,
          'type': 'local',
          'title': '128',
        }),
        playbackContext: PlaybackContext.playlist(3),
        isPlaying: true,
      );
      sync.observe(const PlayerState(), next);
      await sync.begin(3);
      expect(adapter.bodies, isEmpty);
    },
  );
  test(
    'serial progress writes preserve milliseconds, and mode-only writes omit the position',
    () async {
      final adapter = ProgressAdapter();
      final sync = PlaylistProgressSync(Dio()..httpClientAdapter = adapter);
      await sync.begin(3);
      sync.ready = true;
      final state = PlayerState(
        currentSong: Song.fromJson({
          'id': 128,
          'type': 'local',
          'title': '128',
        }),
        playbackContext: PlaybackContext.playlist(3),
        currentTime: const Duration(milliseconds: 754000),
        playMode: PlayMode.single,
      );
      sync.save(state);
      sync.save(state, modeOnly: true);
      await sync.begin(3);
      expect(adapter.bodies[0]['position_ms'], 754000);
      expect(adapter.bodies[0]['version'], 0);
      expect(adapter.bodies[1]['version'], 1);
      expect(adapter.bodies[1].containsKey('position_ms'), false);
      expect(adapter.bodies[1]['play_mode'], 'single');
    },
  );
  test('conflict blocks automatic updates and informs the caller', () async {
    final adapter = ProgressAdapter()..conflict = true;
    var conflicts = 0;
    final sync = PlaylistProgressSync(
      Dio()..httpClientAdapter = adapter,
      onConflict: () => conflicts++,
    );
    await sync.begin(3);
    sync.ready = true;
    final state = PlayerState(
      currentSong: Song.fromJson({'id': 1, 'type': 'local', 'title': '1'}),
      playbackContext: PlaybackContext.playlist(3),
    );
    sync.save(state);
    sync.save(state);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(conflicts, 1);
    expect(sync.blocked, true);
    expect(adapter.bodies.length, 1);
  });
}
