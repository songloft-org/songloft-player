import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/features/player/domain/player_state.dart';
import 'package:songloft_flutter/features/player/domain/use_cases/prefetch_strategy.dart';
import 'package:songloft_flutter/shared/models/song.dart';

Song _makeSong({
  int id = 1,
  String type = 'remote',
  String? url = '/api/v1/songs/1/stream',
  String? format,
  double duration = 240.0,
}) {
  return Song(
    id: id,
    type: type,
    title: 'Song $id',
    duration: duration,
    url: url,
    format: format,
    addedAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );
}

List<Song> _makePlaylist(int count, {String type = 'remote'}) {
  return List.generate(
    count,
    (i) =>
        _makeSong(id: i + 1, type: type, url: '/api/v1/songs/${i + 1}/stream'),
  );
}

void main() {
  group('PrefetchStrategy', () {
    late PrefetchStrategy strategy;

    setUp(() {
      strategy = PrefetchStrategy();
    });

    group('evaluateAfterPlay', () {
      test('normal case returns shouldPrefetch=true with correct song', () {
        final playlist = _makePlaylist(5);
        final decision = strategy.evaluateAfterPlay(
          playlist: playlist,
          currentIndex: 0,
          preSelectedNextIndex: 1,
          playMode: PlayMode.loop,
        );

        expect(decision.shouldPrefetch, isTrue);
        expect(decision.songToPrefetch, equals(playlist[1]));
        expect(decision.nextIndex, equals(1));
      });

      test('empty playlist returns skip', () {
        final decision = strategy.evaluateAfterPlay(
          playlist: [],
          currentIndex: 0,
          preSelectedNextIndex: null,
          playMode: PlayMode.loop,
        );

        expect(decision.shouldPrefetch, isFalse);
        expect(decision.songToPrefetch, isNull);
      });

      test('single-song playlist returns skip', () {
        final decision = strategy.evaluateAfterPlay(
          playlist: _makePlaylist(1),
          currentIndex: 0,
          preSelectedNextIndex: 0,
          playMode: PlayMode.loop,
        );

        expect(decision.shouldPrefetch, isFalse);
      });

      test('single mode returns skip', () {
        final decision = strategy.evaluateAfterPlay(
          playlist: _makePlaylist(5),
          currentIndex: 0,
          preSelectedNextIndex: 0,
          playMode: PlayMode.single,
        );

        expect(decision.shouldPrefetch, isFalse);
      });

      test('singlePlay mode returns skip', () {
        final decision = strategy.evaluateAfterPlay(
          playlist: _makePlaylist(5),
          currentIndex: 0,
          preSelectedNextIndex: 0,
          playMode: PlayMode.singlePlay,
        );

        expect(decision.shouldPrefetch, isFalse);
      });

      test('local song returns skip', () {
        final playlist = [_makeSong(id: 1), _makeSong(id: 2, type: 'local')];
        final decision = strategy.evaluateAfterPlay(
          playlist: playlist,
          currentIndex: 0,
          preSelectedNextIndex: 1,
          playMode: PlayMode.loop,
        );

        expect(decision.shouldPrefetch, isFalse);
      });

      test('song with no url returns skip', () {
        final playlist = [_makeSong(id: 1), _makeSong(id: 2, url: null)];
        final decision = strategy.evaluateAfterPlay(
          playlist: playlist,
          currentIndex: 0,
          preSelectedNextIndex: 1,
          playMode: PlayMode.loop,
        );

        expect(decision.shouldPrefetch, isFalse);
      });

      test('song with empty url returns skip', () {
        final playlist = [_makeSong(id: 1), _makeSong(id: 2, url: '')];
        final decision = strategy.evaluateAfterPlay(
          playlist: playlist,
          currentIndex: 0,
          preSelectedNextIndex: 1,
          playMode: PlayMode.loop,
        );

        expect(decision.shouldPrefetch, isFalse);
      });

      test('song with external url (not starting with /) returns skip', () {
        final playlist = [
          _makeSong(id: 1),
          _makeSong(id: 2, url: 'https://example.com/song.mp3'),
        ];
        final decision = strategy.evaluateAfterPlay(
          playlist: playlist,
          currentIndex: 0,
          preSelectedNextIndex: 1,
          playMode: PlayMode.loop,
        );

        expect(decision.shouldPrefetch, isFalse);
      });

      test('preSelectedNextIndex null returns skip', () {
        final decision = strategy.evaluateAfterPlay(
          playlist: _makePlaylist(5),
          currentIndex: 0,
          preSelectedNextIndex: null,
          playMode: PlayMode.order,
        );

        expect(decision.shouldPrefetch, isFalse);
      });

      test('preSelectedNextIndex out of bounds returns skip', () {
        final decision = strategy.evaluateAfterPlay(
          playlist: _makePlaylist(3),
          currentIndex: 0,
          preSelectedNextIndex: 10,
          playMode: PlayMode.loop,
        );

        expect(decision.shouldPrefetch, isFalse);
      });

      test('order mode with valid next index returns shouldPrefetch=true', () {
        final playlist = _makePlaylist(3);
        final decision = strategy.evaluateAfterPlay(
          playlist: playlist,
          currentIndex: 1,
          preSelectedNextIndex: 2,
          playMode: PlayMode.order,
        );

        expect(decision.shouldPrefetch, isTrue);
        expect(decision.songToPrefetch, equals(playlist[2]));
        expect(decision.nextIndex, equals(2));
      });

      test('random mode with valid next index returns shouldPrefetch=true', () {
        final playlist = _makePlaylist(5);
        final decision = strategy.evaluateAfterPlay(
          playlist: playlist,
          currentIndex: 2,
          preSelectedNextIndex: 4,
          playMode: PlayMode.random,
        );

        expect(decision.shouldPrefetch, isTrue);
        expect(decision.songToPrefetch, equals(playlist[4]));
        expect(decision.nextIndex, equals(4));
      });
    });

    group('evaluateLateStagePrefetch', () {
      test('triggers when remaining < 30s', () {
        final playlist = _makePlaylist(3);
        final decision = strategy.evaluateLateStagePrefetch(
          currentPosition: const Duration(seconds: 200),
          duration: const Duration(seconds: 220),
          playlist: playlist,
          currentIndex: 0,
          preSelectedNextIndex: 1,
          playMode: PlayMode.loop,
        );

        expect(decision.shouldPrefetch, isTrue);
        expect(decision.songToPrefetch, equals(playlist[1]));
      });

      test('only triggers once (second call returns skip)', () {
        final playlist = _makePlaylist(3);

        // First call triggers
        final first = strategy.evaluateLateStagePrefetch(
          currentPosition: const Duration(seconds: 200),
          duration: const Duration(seconds: 220),
          playlist: playlist,
          currentIndex: 0,
          preSelectedNextIndex: 1,
          playMode: PlayMode.loop,
        );
        expect(first.shouldPrefetch, isTrue);

        // Second call should skip
        final second = strategy.evaluateLateStagePrefetch(
          currentPosition: const Duration(seconds: 210),
          duration: const Duration(seconds: 220),
          playlist: playlist,
          currentIndex: 0,
          preSelectedNextIndex: 1,
          playMode: PlayMode.loop,
        );
        expect(second.shouldPrefetch, isFalse);
      });

      test('does not trigger when remaining > 30s', () {
        final playlist = _makePlaylist(3);
        final decision = strategy.evaluateLateStagePrefetch(
          currentPosition: const Duration(seconds: 100),
          duration: const Duration(seconds: 220),
          playlist: playlist,
          currentIndex: 0,
          preSelectedNextIndex: 1,
          playMode: PlayMode.loop,
        );

        expect(decision.shouldPrefetch, isFalse);
      });

      test('skips for short songs (duration < 60s)', () {
        final playlist = _makePlaylist(3);
        final decision = strategy.evaluateLateStagePrefetch(
          currentPosition: const Duration(seconds: 40),
          duration: const Duration(seconds: 50),
          playlist: playlist,
          currentIndex: 0,
          preSelectedNextIndex: 1,
          playMode: PlayMode.loop,
        );

        expect(decision.shouldPrefetch, isFalse);
      });

      test('skips when duration is zero', () {
        final playlist = _makePlaylist(3);
        final decision = strategy.evaluateLateStagePrefetch(
          currentPosition: Duration.zero,
          duration: Duration.zero,
          playlist: playlist,
          currentIndex: 0,
          preSelectedNextIndex: 1,
          playMode: PlayMode.loop,
        );

        expect(decision.shouldPrefetch, isFalse);
      });
    });

    test('manual next is prefetched in single and singlePlay modes', () {
      final playlist = _makePlaylist(3);
      for (final mode in [PlayMode.single, PlayMode.singlePlay]) {
        final decision = strategy.evaluateAfterPlay(
          playlist: playlist,
          currentIndex: 0,
          preSelectedNextIndex: 2,
          playMode: mode,
          hasPriorityNext: true,
        );
        expect(decision.songToPrefetch, playlist[2]);
        expect(decision.shouldPrefetch, isTrue);
      }
    });

    group('onSongChanged', () {
      test('resets lateStageFired so it can trigger again', () {
        final playlist = _makePlaylist(3);

        // Fire late stage
        strategy.evaluateLateStagePrefetch(
          currentPosition: const Duration(seconds: 200),
          duration: const Duration(seconds: 220),
          playlist: playlist,
          currentIndex: 0,
          preSelectedNextIndex: 1,
          playMode: PlayMode.loop,
        );
        expect(strategy.lateStageFired, isTrue);

        // Reset
        strategy.onSongChanged();
        expect(strategy.lateStageFired, isFalse);

        // Should be able to trigger again
        final decision = strategy.evaluateLateStagePrefetch(
          currentPosition: const Duration(seconds: 200),
          duration: const Duration(seconds: 220),
          playlist: playlist,
          currentIndex: 0,
          preSelectedNextIndex: 1,
          playMode: PlayMode.loop,
        );
        expect(decision.shouldPrefetch, isTrue);
      });
    });
  });
}
