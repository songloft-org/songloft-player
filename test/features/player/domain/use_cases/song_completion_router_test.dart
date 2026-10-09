import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/features/player/domain/player_state.dart';
import 'package:songloft_flutter/features/player/domain/use_cases/song_completion_router.dart';

void main() {
  late SongCompletionRouter router;

  setUp(() {
    router = SongCompletionRouter();
  });

  group('PlayMode.single', () {
    test('returns replayCurrent', () {
      expect(
        router.resolve(
          mode: PlayMode.single,
          currentIndex: 0,
          playlistLength: 5,
        ),
        CompletionAction.replayCurrent,
      );
    });
  });

  group('PlayMode.singlePlay', () {
    test('returns pause', () {
      expect(
        router.resolve(
          mode: PlayMode.singlePlay,
          currentIndex: 2,
          playlistLength: 10,
        ),
        CompletionAction.pause,
      );
    });
  });

  group('PlayMode.order', () {
    test('returns stopEndOfList at last song', () {
      expect(
        router.resolve(
          mode: PlayMode.order,
          currentIndex: 4,
          playlistLength: 5,
        ),
        CompletionAction.stopEndOfList,
      );
    });

    test('returns playNext when not at last song', () {
      expect(
        router.resolve(
          mode: PlayMode.order,
          currentIndex: 2,
          playlistLength: 5,
        ),
        CompletionAction.playNext,
      );
    });

    test('returns playNext at index 0 of multi-song playlist', () {
      expect(
        router.resolve(
          mode: PlayMode.order,
          currentIndex: 0,
          playlistLength: 3,
        ),
        CompletionAction.playNext,
      );
    });

    test('returns stopEndOfList for single-song playlist', () {
      expect(
        router.resolve(
          mode: PlayMode.order,
          currentIndex: 0,
          playlistLength: 1,
        ),
        CompletionAction.stopEndOfList,
      );
    });
  });

  group('PlayMode.loop', () {
    test('always returns playNext', () {
      expect(
        router.resolve(mode: PlayMode.loop, currentIndex: 4, playlistLength: 5),
        CompletionAction.playNext,
      );
    });

    test('returns playNext even at last index', () {
      expect(
        router.resolve(
          mode: PlayMode.loop,
          currentIndex: 9,
          playlistLength: 10,
        ),
        CompletionAction.playNext,
      );
    });
  });

  group('PlayMode.random', () {
    test('always returns playNext', () {
      expect(
        router.resolve(
          mode: PlayMode.random,
          currentIndex: 0,
          playlistLength: 5,
        ),
        CompletionAction.playNext,
      );
    });

    test('returns playNext regardless of position', () {
      expect(
        router.resolve(
          mode: PlayMode.random,
          currentIndex: 4,
          playlistLength: 5,
        ),
        CompletionAction.playNext,
      );
    });
  });

  test('manual next overrides natural completion in every playback mode', () {
    for (final mode in PlayMode.values) {
      expect(
        router.resolve(
          mode: mode,
          currentIndex: 2,
          playlistLength: 3,
          hasPriorityNext: true,
        ),
        CompletionAction.playNext,
      );
    }
  });

  group('edge cases', () {
    test('currentIndex = -1 in order mode returns playNext', () {
      // -1 >= playlistLength - 1 is false for length >= 1
      expect(
        router.resolve(
          mode: PlayMode.order,
          currentIndex: -1,
          playlistLength: 5,
        ),
        CompletionAction.playNext,
      );
    });

    test('currentIndex out of bounds in order mode returns stopEndOfList', () {
      expect(
        router.resolve(
          mode: PlayMode.order,
          currentIndex: 10,
          playlistLength: 5,
        ),
        CompletionAction.stopEndOfList,
      );
    });

    test('single mode ignores index and length', () {
      expect(
        router.resolve(
          mode: PlayMode.single,
          currentIndex: 99,
          playlistLength: 1,
        ),
        CompletionAction.replayCurrent,
      );
    });
  });
}
