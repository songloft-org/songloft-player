import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/config/app_config.dart';
import 'package:songloft_flutter/core/audio/audio_service.dart';
import 'package:songloft_flutter/core/storage/lyric_cache_service.dart';
import 'package:songloft_flutter/core/storage/playback_state_storage.dart';
import 'package:songloft_flutter/features/player/domain/player_state.dart';
import 'package:songloft_flutter/features/player/presentation/providers/lyric_provider.dart';
import 'package:songloft_flutter/features/player/presentation/providers/player_provider.dart';
import 'package:songloft_flutter/features/settings/presentation/providers/settings_provider.dart';
import 'package:songloft_flutter/main.dart';
import 'package:songloft_flutter/shared/models/song.dart';

class _RealHttp extends HttpOverrides {}

class _Audio implements SongloftAudioHandler {
  @override
  void updateNowPlayingLyric(String lyricLine, {bool inTitle = true}) {}
  @override
  void restoreNowPlaying() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Player extends PlayerNotifier {
  _Player(this.song);
  final Song? song;
  @override
  PlayerState build() => PlayerState(currentSong: song);
  void selectSong(Song? song) => state = PlayerState(currentSong: song);
}

class _Notification extends NotificationLyricInTitleNotifier {
  @override
  bool build() => true;
}

Song _song(int id, {String type = 'local', String? lyricUrl}) => Song(
  id: id,
  type: type,
  title: 'Saved song $id',
  duration: 10,
  lyricUrl: lyricUrl,
  addedAt: DateTime.utc(2026, 11, 3),
  updatedAt: DateTime.utc(2026, 11, 3),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late HttpServer server;
  final requests = <Uri>[];
  var status = 200;
  late String oldBaseUrl;
  late String oldResolvedBaseUrl;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('songloft-555-lyrics-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => directory.path,
        );
  });
  tearDownAll(() async {
    await LyricCacheService().clear();
    await directory.delete(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
  });
  setUp(() async {
    await LyricCacheService().clear();
    requests.clear();
    status = 200;
    oldBaseUrl = AppConfig.baseUrl;
    oldResolvedBaseUrl = AppConfig.resolvedBaseUrl;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    AppConfig.baseUrl = 'http://127.0.0.1:${server.port}';
    AppConfig.resolvedBaseUrl = AppConfig.baseUrl;
    server.listen((request) async {
      requests.add(request.uri);
      request.response.statusCode = status;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'lyric': '[00:00.00]saved ${request.uri.pathSegments[3]}',
          'tlyric': '[00:00.00]translation',
        }),
      );
      await request.response.close();
    });
  });
  tearDown(() async {
    await server.close(force: true);
    AppConfig.baseUrl = oldBaseUrl;
    AppConfig.resolvedBaseUrl = oldResolvedBaseUrl;
  });

  ProviderContainer createContainer(Song? song) {
    final container = ProviderContainer(
      overrides: [
        playerStateProvider.overrideWith(() => _Player(song)),
        audioHandlerProvider.overrideWithValue(_Audio()),
        notificationLyricInTitleProvider.overrideWith(_Notification.new),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<LyricState> loaded(ProviderContainer container) async {
    final initial = container.read(lyricStateProvider);
    if (!initial.isLoading) return initial;
    final complete = Completer<LyricState>();
    final subscription = container.listen(lyricStateProvider, (_, next) {
      if (!next.isLoading && !complete.isCompleted) complete.complete(next);
    });
    try {
      return await complete.future.timeout(const Duration(seconds: 5));
    } finally {
      subscription.close();
    }
  }

  void httpTest(String name, Future<void> Function() body) {
    test(
      name,
      () => HttpOverrides.runZoned(
        body,
        createHttpClient: (context) => _RealHttp().createHttpClient(context),
      ),
    );
  }

  httpTest(
    'restored Web queue without lyric URL reads saved server lyrics',
    () async {
      final encoded = PlaybackQueueCodec.encodeWeb(
        PlaybackQueueSnapshot(songs: [_song(555)], currentIndex: 0),
      );
      final restored = PlaybackQueueCodec.decode(encoded).songs.single;
      final state = await loaded(createContainer(restored));
      expect(state.rawLyricText, '[00:00.00]saved 555');
      expect(requests.single.path, '/api/v1/songs/555/lyric');
      expect(requests.single.queryParameters, isNot(contains('refresh')));
      expect(restored.lyricUrl, isNull);
    },
  );

  httpTest(
    'manual re-fetch cache survives a new provider with the old snapshot',
    () async {
      final song = _song(556);
      final original = createContainer(song);
      await loaded(original);
      await original.read(lyricStateProvider.notifier).refetch();
      expect(requests.last.queryParameters, contains('refresh'));
      final requestCount = requests.length;
      final restored = await loaded(createContainer(song));
      expect(restored.rawLyricText, '[00:00.00]saved 556');
      expect(requests, hasLength(requestCount));
    },
  );

  httpTest(
    'same-timestamp songs without URLs load separately on switching',
    () async {
      final container = createContainer(_song(557));
      expect((await loaded(container)).rawLyricText, '[00:00.00]saved 557');
      (container.read(playerStateProvider.notifier) as _Player).selectSong(
        _song(558),
      );
      expect((await loaded(container)).rawLyricText, '[00:00.00]saved 558');
      expect(requests.map((uri) => uri.path), [
        '/api/v1/songs/557/lyric',
        '/api/v1/songs/558/lyric',
      ]);
    },
  );

  httpTest('404 means no lyrics while 502 remains a loading failure', () async {
    status = 404;
    final missing = await loaded(createContainer(_song(559)));
    expect(missing.hasLyrics, isFalse);
    expect(missing.loadFailed, isFalse);
    expect(requests, hasLength(1));
    status = 502;
    expect((await loaded(createContainer(_song(560)))).loadFailed, isTrue);
  });

  httpTest(
    'radio, remote, invalid IDs and no song do not gain an endpoint',
    () async {
      for (final song in [
        null,
        _song(0),
        _song(561, type: 'radio'),
        _song(562, type: 'remote'),
      ]) {
        final state = await loaded(createContainer(song));
        expect(state.hasLyrics, isFalse);
        expect(state.isLoading, isFalse);
      }
      expect(requests, isEmpty);
    },
  );
}
