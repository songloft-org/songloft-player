import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dlna_dart/xmlParser.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songloft_flutter/core/audio/audio_service.dart';
import 'package:songloft_flutter/core/network/api_client.dart';
import 'package:songloft_flutter/core/storage/app_preferences.dart';
import 'package:songloft_flutter/core/storage/secure_storage.dart';
import 'package:songloft_flutter/features/auth/presentation/providers/auth_provider.dart';
import 'package:songloft_flutter/features/dlna/domain/dlna_state.dart';
import 'package:songloft_flutter/features/dlna/data/dlna_service.dart';
import 'package:songloft_flutter/features/dlna/presentation/providers/dlna_provider.dart';
import 'package:songloft_flutter/features/library/presentation/providers/favorite_provider.dart';
import 'package:songloft_flutter/features/player/domain/playback_context.dart';
import 'package:songloft_flutter/features/player/domain/playback_source.dart';
import 'package:songloft_flutter/features/player/domain/player_state.dart';
import 'package:songloft_flutter/features/player/presentation/providers/lyric_provider.dart';
import 'package:songloft_flutter/features/player/presentation/providers/player_provider.dart';
import 'package:songloft_flutter/features/settings/data/settings_api.dart';
import 'package:songloft_flutter/features/settings/presentation/providers/settings_provider.dart';
import 'package:songloft_flutter/main.dart';
import 'package:songloft_flutter/l10n/app_localizations_zh.dart';
import 'package:songloft_flutter/l10n/l10n_holder.dart';
import 'package:songloft_flutter/shared/models/song.dart';

// Queue/navigation use real player and DLNA notifiers, with fake audio transports.
class _Audio implements SongloftAudioHandler {
  final played = <int>[];
  final failedIds = <int>{};
  final seeks = <Duration>[];
  Completer<void>? playGate;
  @override
  VoidCallback? onSongCompleted;
  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  Stream<Duration?> get durationStream => const Stream.empty();
  @override
  Stream<ja.PlayerState> get playerStateStream => const Stream.empty();
  @override
  ja.ProcessingState get processingState => ja.ProcessingState.ready;
  @override
  PlaybackSource get lastPlaybackSource => PlaybackSource.unknown;
  @override
  Future<void> playSong(
    Song song, {
    String? quality,
    int? audioTrack,
    bool normalize = false,
  }) async {
    if (failedIds.contains(song.id)) throw StateError('audio source failed');
    played.add(song.id);
    await playGate?.future;
  }

  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> seek(Duration position) async => seeks.add(position);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Storage implements SecureStorageService {
  @override
  Future<String?> getAccessToken() async => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Favorites extends FavoriteNotifier {
  @override
  FavoriteState build() => const FavoriteState(initialized: true);
}

class _Lyrics extends LyricNotifier {
  @override
  LyricState build() => const LyricState();
}

class _DlnaTransport implements DlnaService {
  final completed = StreamController<void>.broadcast(sync: true);
  final titles = <String>[];
  bool fail = false;

  @override
  Stream<void> get completionStream => completed.stream;
  @override
  Stream<PositionParser> get positionStream => const Stream.empty();
  @override
  Future<void> castTo(
    String deviceId,
    String url, {
    String title = '',
    PlayType mime = AudioMime.mp3,
  }) async {
    if (fail) throw StateError('device rejected the song');
    titles.add(title);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Normalize extends VolumeNormalizeNotifier {
  @override
  Future<VolumeNormalizeSetting> build() async =>
      const VolumeNormalizeSetting(enabled: false);
}

Song _song(int id) => Song(
  id: id,
  type: 'local',
  title: 'Song $id',
  duration: 180,
  url: 'https://music.example.test/songs/$id',
  addedAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late _Audio audio;
  late _DlnaTransport dlna;
  late PlayerNotifier player;
  late Directory temporaryDirectory;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    updateGlobalL10n(AppLocalizationsZh());
    final preferences = await AppPreferences.create();
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'songloft-queue-test-',
    );
    audio = _Audio();
    dlna = _DlnaTransport();
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest:
            (options, handler) => handler.resolve(
              Response(
                requestOptions: options,
                data: <String, dynamic>{},
                statusCode: 200,
              ),
            ),
      ),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => temporaryDirectory.path,
        );
    container = ProviderContainer(
      overrides: [
        audioHandlerProvider.overrideWithValue(audio),
        secureStorageProvider.overrideWithValue(_Storage()),
        appPreferencesProvider.overrideWith((ref) async => preferences),
        dioProvider.overrideWithValue(dio),
        favoriteProvider.overrideWith(_Favorites.new),
        lyricStateProvider.overrideWith(_Lyrics.new),
        dlnaServiceProvider.overrideWithValue(dlna),
        volumeNormalizeProvider.overrideWith(_Normalize.new),
      ],
    );
    player = container.read(playerStateProvider.notifier);
    // Allow the real startup preference/queue restoration to finish.
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });

  tearDown(() async {
    container.dispose();
    await dlna.completed.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await temporaryDirectory.delete(recursive: true);
  });

  test(
    'scheduling preserves current song, queue source, and playback',
    () async {
      await player.playPlaylist([_song(1), _song(2)], sourcePlaylistId: 42);
      await player.playSongNext(_song(3));
      final state = container.read(playerStateProvider);
      expect(audio.played, [1]);
      expect(state.currentSong?.id, 1);
      expect(state.playlist.map((s) => s.id), [1, 3, 2]);
      expect(state.playbackContext, PlaybackContext.playlist(42));
      expect(state.hasPriorityNext, isTrue);
      await player.playNext();
      expect(audio.played, [1, 3]);
      expect(container.read(playerStateProvider).hasPriorityNext, isFalse);
    },
  );

  test('an empty queue starts the requested song', () async {
    await player.playSongNext(_song(7));
    expect(audio.played, [7]);
    expect(container.read(playerStateProvider).currentIndex, 0);
    expect(container.read(playerStateProvider).hasPriorityNext, isFalse);
  });

  test(
    'random previous returns first actual song and next retraces history',
    () async {
      await player.setPlayMode(PlayMode.random);
      await player.playPlaylist([_song(1), _song(2), _song(3)]);
      await player.playNext();
      final second = container.read(playerStateProvider).currentSong!.id;
      expect(second, isNot(1));
      await player.playPrev();
      expect(audio.played, [1, second, 1]);
      await player.playNext();
      expect(audio.played, [1, second, 1, second]);
    },
  );

  test('latest scheduled song plays first, then earlier requests', () async {
    await player.setPlayMode(PlayMode.random);
    await player.playPlaylist([_song(1), _song(2), _song(3)]);
    await player.playSongNext(_song(2));
    await player.playSongNext(_song(3));
    await player.playNext();
    await player.playNext();
    expect(audio.played, [1, 3, 2]);
  });

  test(
    'single-loop completion honors manual next once and keeps the mode',
    () async {
      await player.setPlayMode(PlayMode.single);
      await player.playPlaylist([_song(1), _song(2)]);
      await player.playSongNext(_song(2));
      audio.onSongCompleted!();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(audio.played, [1, 2]);
      expect(container.read(playerStateProvider).playMode, PlayMode.single);
      audio.onSongCompleted!();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(audio.played, [1, 2, 2]);
    },
  );

  test('history and next song survive queue insert/reorder/delete', () async {
    await player.setPlayMode(PlayMode.random);
    await player.playPlaylist([_song(1), _song(2), _song(3)]);
    await player.playSong(_song(2));
    await player.playSongNext(_song(3));
    player.insertToPlaylist(0, _song(4));
    player.moveInPlaylist(3, 0);
    await player.removeFromPlaylist(1); // Remove unplayed song 4.
    await player.playPrev();
    expect(container.read(playerStateProvider).currentSong?.id, 1);
    await player.playNext();
    expect(container.read(playerStateProvider).currentSong?.id, 3);
    expect(audio.played, [1, 2, 1, 3]);
  });

  test(
    'scheduling current song replays once and returns to remaining queue',
    () async {
      final song = _song(1);
      await player.playPlaylist([song, _song(2)]);
      await player.playSongNext(song);
      await player.playSongNext(song);
      expect(container.read(playerStateProvider).playlist.length, 3);
      await player.playNext();
      await player.playNext();
      expect(audio.played, [1, 1, 2]);
    },
  );
  test(
    'rapid previous clicks keep moving back while audio is loading',
    () async {
      await player.setPlayMode(PlayMode.random);
      await player.playPlaylist([_song(1), _song(2), _song(3)]);
      await player.playSong(_song(2));
      await player.playSong(_song(3));
      audio.playGate = Completer<void>();
      final first = player.playPrev();
      final second = player.playPrev();
      expect(container.read(playerStateProvider).currentSong?.id, 1);
      audio.playGate!.complete();
      await Future.wait([first, second]);
      audio.playGate = null;
      await player.playNext();
      expect(container.read(playerStateProvider).currentSong?.id, 2);
    },
  );
  test(
    'scheduling while previous audio is loading preserves older history',
    () async {
      await player.setPlayMode(PlayMode.random);
      await player.playPlaylist([_song(1), _song(2), _song(3)]);
      await player.playSong(_song(2));
      await player.playSong(_song(3));
      audio.playGate = Completer<void>();
      final back = player.playPrev();
      await player.playSongNext(_song(4));
      audio.playGate!.complete();
      await back;
      audio.playGate = null;
      await player.playPrev();
      expect(container.read(playerStateProvider).currentSong?.id, 1);
      await player.playNext();
      expect(container.read(playerStateProvider).currentSong?.id, 4);
    },
  );

  test('previous during a new song load returns the last heard song', () async {
    await player.setPlayMode(PlayMode.random);
    await player.playPlaylist([_song(1), _song(2), _song(3)]);
    await player.playSongNext(_song(2));
    audio.playGate = Completer<void>();
    final next = player.playNext();
    final back = player.playPrev();
    expect(container.read(playerStateProvider).currentSong?.id, 1);
    audio.playGate!.complete();
    await Future.wait([next, back]);
    audio.playGate = null;
    expect(container.read(playerStateProvider).currentSong?.id, 1);
  });

  test(
    'selecting within the same queue keeps history, priority and source',
    () async {
      await player.setPlayMode(PlayMode.random);
      await player.playPlaylist([
        _song(1),
        _song(2),
        _song(3),
      ], sourcePlaylistId: 42);
      await player.playSongNext(_song(4));
      final songs = List<Song>.from(
        container.read(playerStateProvider).playlist,
      );
      await player.playPlaylist(songs, startIndex: 2, keepContext: true);
      expect(container.read(playerStateProvider).currentSong?.id, 2);
      expect(container.read(playerStateProvider).hasPriorityNext, isTrue);
      await player.playPrev();
      expect(container.read(playerStateProvider).currentSong?.id, 1);
      await player.playNext();
      expect(container.read(playerStateProvider).currentSong?.id, 4);
      expect(container.read(playerStateProvider).sourcePlaylistId, 42);
    },
  );
  test(
    'DLNA failure clears pending history navigation before going back',
    () async {
      await player.setPlayMode(PlayMode.random);
      await player.playPlaylist([_song(1), _song(2), _song(3)]);
      await player.playSong(_song(2));
      await player.playSong(_song(3));
      final casting = container.read(dlnaStateProvider.notifier);
      await casting.castToDevice(
        const DlnaDeviceInfo(
          id: 'renderer',
          name: 'Test renderer',
          location: 'https://renderer.example.test',
        ),
      );
      await player.playPrev(); // Successfully cast song 2.
      expect(dlna.titles, ['Song 3', 'Song 2']);
      dlna.fail = true;
      await player.playNext(); // Forward-history song 3 fails.
      expect(container.read(dlnaStateProvider).error, isNotNull);
      dlna.fail = false;
      await player.playPrev();
      expect(container.read(playerStateProvider).currentSong?.id, 2);
      expect(dlna.titles.last, 'Song 2');
      await player.playPrev();
      expect(container.read(playerStateProvider).currentSong?.id, 1);
    },
  );

  test(
    'DLNA completion honors manual next before single loop and single play',
    () async {
      for (final mode in [PlayMode.single, PlayMode.singlePlay]) {
        // Start a fresh queue while retaining the established casting session.
        await player.setPlayMode(mode);
        await player.playPlaylist([_song(1), _song(2)]);
        final casting = container.read(dlnaStateProvider.notifier);
        if (!container.read(dlnaStateProvider).isCasting) {
          await casting.castToDevice(
            const DlnaDeviceInfo(
              id: 'renderer',
              name: 'Test renderer',
              location: 'https://renderer.example.test',
            ),
          );
        }
        await player.playSongNext(_song(2));
        dlna.completed.add(null);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(container.read(playerStateProvider).currentSong?.id, 2);
        expect(container.read(playerStateProvider).hasPriorityNext, isFalse);
        expect(container.read(playerStateProvider).playMode, mode);
        expect(dlna.titles.last, 'Song 2');
        dlna.completed.add(null);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        if (mode == PlayMode.singlePlay) {
          expect(container.read(dlnaStateProvider).isPlaying, isFalse);
        }
      }
    },
  );
  test(
    'failure skip honors manual next after the queue is reordered',
    () async {
      await player.playPlaylist([_song(1), _song(2), _song(3)]);
      await player.playSongNext(_song(3));
      player.moveInPlaylist(1, 0); // Priority song now precedes current song.
      audio.failedIds.add(1);
      await player.playSong(
        _song(1),
      ); // Exhaust retries, then skip automatically.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(audio.played, [1, 3]);
      expect(container.read(playerStateProvider).currentSong?.id, 3);
      expect(container.read(playerStateProvider).hasPriorityNext, isFalse);
    },
  );
}
