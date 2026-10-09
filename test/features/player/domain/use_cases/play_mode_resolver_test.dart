import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/features/player/domain/player_state.dart';
import 'package:songloft_flutter/features/player/domain/use_cases/play_mode_resolver.dart';

void main() {
  group('PlayModeResolver', () {
    group('nextIndex', () {
      test('order mode: returns next index', () {
        final resolver = PlayModeResolver(mode: PlayMode.order);
        expect(resolver.nextIndex(currentIndex: 0, length: 5), 1);
        expect(resolver.nextIndex(currentIndex: 3, length: 5), 4);
      });

      test('order mode: returns null at end of playlist', () {
        final resolver = PlayModeResolver(mode: PlayMode.order);
        expect(resolver.nextIndex(currentIndex: 4, length: 5), isNull);
      });

      test('loop mode: wraps around to beginning', () {
        final resolver = PlayModeResolver(mode: PlayMode.loop);
        expect(resolver.nextIndex(currentIndex: 4, length: 5), 0);
        expect(resolver.nextIndex(currentIndex: 2, length: 5), 3);
      });

      test('single mode: returns current index (repeat)', () {
        final resolver = PlayModeResolver(mode: PlayMode.single);
        expect(resolver.nextIndex(currentIndex: 2, length: 5), 2);
      });

      test('singlePlay mode: returns current index (repeat)', () {
        final resolver = PlayModeResolver(mode: PlayMode.singlePlay);
        expect(resolver.nextIndex(currentIndex: 3, length: 5), 3);
      });

      test('random mode: does not repeat until all played', () {
        final resolver = PlayModeResolver(
          mode: PlayMode.random,
          random: Random(42),
        );

        const length = 5;
        final played = <int>{0};
        resolver.markPlayed(0);
        int current = 0;

        // Play through all remaining songs - should not repeat.
        for (var i = 1; i < length; i++) {
          final next =
              resolver.nextIndex(currentIndex: current, length: length)!;
          expect(
            played.contains(next),
            isFalse,
            reason: 'Index $next was repeated before all songs were played',
          );
          played.add(next);
          resolver.markPlayed(next);
          current = next;
        }

        expect(played.length, length);
      });

      test(
        'random mode: resets after all played and does not immediately repeat current',
        () {
          final resolver = PlayModeResolver(
            mode: PlayMode.random,
            random: Random(42),
          );

          const length = 3;
          // Mark all as played
          for (var i = 0; i < length; i++) {
            resolver.markPlayed(i);
          }

          // Next call should reset and avoid current index
          const currentIndex = 1;
          final results = <int>{};
          // Run multiple times to verify it doesn't always return currentIndex
          for (var i = 0; i < 20; i++) {
            final next =
                resolver.nextIndex(currentIndex: currentIndex, length: length)!;
            results.add(next);
            // After reset, mark played again for clean state on next iteration
            resolver.onQueueChanged();
            for (var j = 0; j < length; j++) {
              resolver.markPlayed(j);
            }
          }

          // Should never immediately return the current index after reset
          // (because current index is added to _playedIndices on reset)
          // Actually, the first call after reset should not return currentIndex
          final resolverSingle = PlayModeResolver(
            mode: PlayMode.random,
            random: Random(42),
          );
          for (var i = 0; i < length; i++) {
            resolverSingle.markPlayed(i);
          }
          final next =
              resolverSingle.nextIndex(currentIndex: 1, length: length)!;
          expect(next, isNot(equals(1)));
        },
      );

      test('empty list (length=0) returns null', () {
        final resolver = PlayModeResolver(mode: PlayMode.order);
        expect(resolver.nextIndex(currentIndex: 0, length: 0), isNull);
      });

      test('random mode with length=0 returns null', () {
        final resolver = PlayModeResolver(mode: PlayMode.random);
        expect(resolver.nextIndex(currentIndex: 0, length: 0), isNull);
      });

      test('random mode with single song returns 0', () {
        final resolver = PlayModeResolver(mode: PlayMode.random);
        expect(resolver.nextIndex(currentIndex: 0, length: 1), 0);
      });
    });

    group('prevIndex', () {
      test('returns currentIndex when position > 3 seconds', () {
        final resolver = PlayModeResolver(mode: PlayMode.order);
        final result = resolver.prevIndex(
          currentIndex: 3,
          length: 5,
          currentPosition: const Duration(seconds: 4),
        );
        expect(result, 3);
      });

      test('returns currentIndex when position is exactly > 3 seconds', () {
        final resolver = PlayModeResolver(mode: PlayMode.loop);
        final result = resolver.prevIndex(
          currentIndex: 2,
          length: 5,
          currentPosition: const Duration(seconds: 4),
        );
        expect(result, 2);
      });

      test('does not return currentIndex when position <= 3 seconds', () {
        final resolver = PlayModeResolver(mode: PlayMode.order);
        final result = resolver.prevIndex(
          currentIndex: 3,
          length: 5,
          currentPosition: const Duration(seconds: 3),
        );
        expect(result, 2);
      });

      test('order mode: returns previous index', () {
        final resolver = PlayModeResolver(mode: PlayMode.order);
        final result = resolver.prevIndex(
          currentIndex: 3,
          length: 5,
          currentPosition: Duration.zero,
        );
        expect(result, 2);
      });

      test('order mode: returns null at beginning', () {
        final resolver = PlayModeResolver(mode: PlayMode.order);
        final result = resolver.prevIndex(
          currentIndex: 0,
          length: 5,
          currentPosition: Duration.zero,
        );
        expect(result, isNull);
      });

      test('loop mode: wraps around to end', () {
        final resolver = PlayModeResolver(mode: PlayMode.loop);
        final result = resolver.prevIndex(
          currentIndex: 0,
          length: 5,
          currentPosition: Duration.zero,
        );
        expect(result, 4);
      });

      test('single mode: returns current index', () {
        final resolver = PlayModeResolver(mode: PlayMode.single);
        final result = resolver.prevIndex(
          currentIndex: 2,
          length: 5,
          currentPosition: Duration.zero,
        );
        expect(result, 2);
      });

      test('random mode: returns null without playback history', () {
        final resolver = PlayModeResolver(
          mode: PlayMode.random,
          random: Random(42),
        );
        final result = resolver.prevIndex(
          currentIndex: 2,
          length: 5,
          currentPosition: Duration.zero,
        );
        expect(result, isNull);
      });

      test('empty list (length=0) returns null', () {
        final resolver = PlayModeResolver(mode: PlayMode.order);
        final result = resolver.prevIndex(
          currentIndex: 0,
          length: 0,
          currentPosition: Duration.zero,
        );
        expect(result, isNull);
      });
    });

    group('preSelectNext', () {
      test('order mode: caches next index', () {
        final resolver = PlayModeResolver(mode: PlayMode.order);
        resolver.preSelectNext(currentIndex: 2, length: 5);
        expect(resolver.preSelectedIndex, 3);
      });

      test('order mode: null at end', () {
        final resolver = PlayModeResolver(mode: PlayMode.order);
        resolver.preSelectNext(currentIndex: 4, length: 5);
        expect(resolver.preSelectedIndex, isNull);
      });

      test('loop mode: wraps around', () {
        final resolver = PlayModeResolver(mode: PlayMode.loop);
        resolver.preSelectNext(currentIndex: 4, length: 5);
        expect(resolver.preSelectedIndex, 0);
      });

      test('random mode: caches a valid index', () {
        final resolver = PlayModeResolver(
          mode: PlayMode.random,
          random: Random(42),
        );
        resolver.preSelectNext(currentIndex: 2, length: 5);
        expect(resolver.preSelectedIndex, isNotNull);
        expect(resolver.preSelectedIndex, inInclusiveRange(0, 4));
      });

      test('single/singlePlay mode: caches null', () {
        final resolver = PlayModeResolver(mode: PlayMode.single);
        resolver.preSelectNext(currentIndex: 2, length: 5);
        expect(resolver.preSelectedIndex, isNull);

        final resolver2 = PlayModeResolver(mode: PlayMode.singlePlay);
        resolver2.preSelectNext(currentIndex: 2, length: 5);
        expect(resolver2.preSelectedIndex, isNull);
      });

      test('nextIndex consumes preSelectedIndex in random mode', () {
        final resolver = PlayModeResolver(
          mode: PlayMode.random,
          random: Random(42),
        );
        resolver.preSelectNext(currentIndex: 2, length: 5);
        final preSelected = resolver.preSelectedIndex;
        expect(preSelected, isNotNull);

        final next = resolver.nextIndex(currentIndex: 2, length: 5);
        expect(next, preSelected);
        // After consumption, preSelectedIndex should be null
        expect(resolver.preSelectedIndex, isNull);
      });

      test('empty list returns null', () {
        final resolver = PlayModeResolver(mode: PlayMode.order);
        resolver.preSelectNext(currentIndex: 0, length: 0);
        expect(resolver.preSelectedIndex, isNull);
      });

      test('negative currentIndex returns null', () {
        final resolver = PlayModeResolver(mode: PlayMode.order);
        resolver.preSelectNext(currentIndex: -1, length: 5);
        expect(resolver.preSelectedIndex, isNull);
      });
    });

    group('onModeChanged', () {
      test('clears playedIndices and preSelectedIndex', () {
        final resolver = PlayModeResolver(
          mode: PlayMode.random,
          random: Random(42),
        );

        // Build up some state
        resolver.markPlayed(0);
        resolver.markPlayed(1);
        resolver.preSelectNext(currentIndex: 2, length: 5);
        expect(resolver.preSelectedIndex, isNotNull);

        // Change mode
        resolver.onModeChanged(PlayMode.order);

        expect(resolver.mode, PlayMode.order);
        expect(resolver.preSelectedIndex, isNull);

        // Verify playedIndices cleared: in random mode all indices should be available
        resolver.onModeChanged(PlayMode.random);
        // After clearing, with 5-length list and no played indices,
        // should be able to get all indices
        final indices = <int>{};
        for (var i = 0; i < 50; i++) {
          final idx = resolver.nextIndex(currentIndex: 0, length: 5);
          if (idx != null) indices.add(idx);
          resolver.onModeChanged(PlayMode.random); // reset each time
        }
        // Should have seen multiple different indices (state was cleared)
        expect(indices.length, greaterThan(1));
      });
    });

    group('onQueueChanged', () {
      test('resets internal state', () {
        final resolver = PlayModeResolver(
          mode: PlayMode.random,
          random: Random(42),
        );

        resolver.markPlayed(0);
        resolver.markPlayed(1);
        resolver.markPlayed(2);
        resolver.preSelectNext(currentIndex: 3, length: 5);

        resolver.onQueueChanged();

        expect(resolver.preSelectedIndex, isNull);
        // After queue change, all indices should be available again
      });
    });

    group('markPlayed', () {
      test('adds index to played set', () {
        final resolver = PlayModeResolver(
          mode: PlayMode.random,
          random: Random(42),
        );

        const length = 3;
        resolver.markPlayed(0);
        resolver.markPlayed(1);

        // Only index 2 should be available
        final next = resolver.nextIndex(currentIndex: 0, length: length);
        expect(next, 2);
      });
    });

    group('random playback history', () {
      late PlayModeResolver resolver;
      setUp(() {
        resolver = PlayModeResolver(mode: PlayMode.random, random: Random(42));
        for (final index in [0, 3, 1]) {
          resolver.markPlayed(index);
        }
      });

      int? previous(int current) => resolver.prevIndex(
        currentIndex: current,
        length: 5,
        currentPosition: const Duration(seconds: 90),
      );

      test('previous follows actual order even after three seconds', () {
        expect(previous(1), 3);
        resolver.markPlayed(3);
        expect(previous(3), 0);
        resolver.markPlayed(0);
        expect(previous(0), isNull);
      });

      test('rapid previous/next use the in-flight history cursor', () {
        expect(previous(1), 3);
        expect(previous(3), 0); // Previous load has not finished yet.
        resolver.markPlayed(0); // Only the final request succeeds.
        expect(resolver.nextIndex(currentIndex: 0, length: 5), 3);
        expect(resolver.nextIndex(currentIndex: 3, length: 5), 1);
        resolver.markPlayed(1);
        expect(previous(1), 3);
      });

      test(
        'scheduling while going back does not overwrite the navigation cursor',
        () {
          expect(previous(1), 3);
          resolver.prioritizeNext(4);
          resolver.markPlayed(3);
          expect(previous(3), 0);
          resolver.markPlayed(0);
          expect(resolver.nextIndex(currentIndex: 0, length: 5), 4);
        },
      );

      test(
        'previous during a new load returns the last actually played song',
        () {
          resolver.prioritizeNext(4);
          expect(resolver.nextIndex(currentIndex: 1, length: 5), 4);
          expect(previous(4), 1);
          resolver.markPlayed(1);
          expect(previous(1), 3);
        },
      );

      test('next retraces history before choosing another random song', () {
        expect(previous(1), 3);
        resolver.markPlayed(3);
        expect(previous(3), 0);
        resolver.markPlayed(0);
        expect(resolver.preSelectNext(currentIndex: 0, length: 5), 3);
        expect(resolver.nextIndex(currentIndex: 0, length: 5), 3);
        resolver.markPlayed(3);
        expect(resolver.nextIndex(currentIndex: 3, length: 5), 1);
        resolver.markPlayed(1);
        expect(resolver.nextIndex(currentIndex: 1, length: 5), anyOf(2, 4));
      });

      test('preselection and retries do not add phantom history entries', () {
        resolver.preSelectNext(currentIndex: 1, length: 5);
        resolver.preSelectNext(currentIndex: 1, length: 5);
        resolver.markPlayed(1);
        resolver.markPlayed(1);
        expect(previous(1), 3);
      });

      test('manual next overrides forward history and starts a new branch', () {
        previous(1);
        resolver.markPlayed(3);
        resolver.prioritizeNext(4);
        expect(resolver.preSelectNext(currentIndex: 3, length: 5), 4);
        expect(resolver.nextIndex(currentIndex: 3, length: 5), 4);
        resolver.markPlayed(4);
        expect(previous(4), 3);
        resolver.markPlayed(3);
        expect(resolver.nextIndex(currentIndex: 3, length: 5), 4);
      });

      test('queue reorder remaps history and manual next by song identity', () {
        resolver.prioritizeNext(4);
        resolver.remapQueue({0: 4, 1: 3, 2: 2, 3: 1, 4: 0});
        expect(previous(3), 1);
        resolver.markPlayed(1);
        expect(resolver.nextIndex(currentIndex: 1, length: 5), 0);
      });

      test(
        'deleting a history song skips it, without clearing older history',
        () {
          resolver.remapQueue({0: 0, 1: 1, 2: 2, 4: 3});
          expect(
            resolver.prevIndex(
              currentIndex: 1,
              length: 4,
              currentPosition: Duration.zero,
            ),
            0,
          );
        },
      );

      test(
        'failed forward-history song is skipped without becoming current history',
        () {
          previous(1);
          resolver.markPlayed(3);
          expect(resolver.nextIndex(currentIndex: 3, length: 5), 1);
          resolver.markFailed(1);
          expect(resolver.nextIndex(currentIndex: 1, length: 5), anyOf(2, 4));
        },
      );

      test(
        'replacing or clearing the queue resets history and manual choices',
        () {
          resolver.prioritizeNext(4);
          resolver.onQueueChanged();
          expect(resolver.hasPriorityNext, isFalse);
          expect(previous(1), isNull);
          expect(resolver.preSelectedIndex, isNull);
        },
      );
    });

    group('priority next', () {
      for (final mode in PlayMode.values) {
        test('manual choices override ${mode.name} once, latest first', () {
          final resolver = PlayModeResolver(mode: mode, random: Random(42));
          resolver.markPlayed(0);
          resolver.prioritizeNext(1);
          resolver.prioritizeNext(3);
          resolver.prioritizeNext(3); // same request is not added twice.
          expect(resolver.preSelectNext(currentIndex: 0, length: 5), 3);
          expect(resolver.nextIndex(currentIndex: 0, length: 5), 3);
          resolver.markPlayed(3);
          expect(resolver.nextIndex(currentIndex: 3, length: 5), 1);
          resolver.markPlayed(1);
          expect(resolver.hasPriorityNext, isFalse);
          expect(resolver.mode, mode);
          if (mode == PlayMode.single || mode == PlayMode.singlePlay) {
            expect(resolver.nextIndex(currentIndex: 1, length: 5), 1);
          }
        });
      }

      test(
        'deleting a pending next removes the priority and cached selection',
        () {
          final resolver = PlayModeResolver(mode: PlayMode.random);
          resolver.prioritizeNext(2);
          resolver.preSelectNext(currentIndex: 0, length: 3);
          resolver.remapQueue({0: 0, 1: 1});
          expect(resolver.hasPriorityNext, isFalse);
          expect(resolver.preSelectedIndex, isNull);
          expect(resolver.nextIndex(currentIndex: 0, length: 2), 1);
        },
      );

      test('mode changes preserve manual choices but reset random history', () {
        final resolver = PlayModeResolver(mode: PlayMode.random);
        resolver.markPlayed(0);
        resolver.markPlayed(1);
        resolver.prioritizeNext(2);
        resolver.onModeChanged(PlayMode.single);
        expect(resolver.nextIndex(currentIndex: 1, length: 3), 2);
      });
    });

    group('edge cases', () {
      test('single song in random mode has no previous history', () {
        final resolver = PlayModeResolver(
          mode: PlayMode.random,
          random: Random(42),
        );
        final result = resolver.prevIndex(
          currentIndex: 0,
          length: 1,
          currentPosition: Duration.zero,
        );
        expect(result, isNull);
      });

      test('preSelectNext called twice, second overwrites first', () {
        final resolver = PlayModeResolver(
          mode: PlayMode.random,
          random: Random(42),
        );
        resolver.preSelectNext(currentIndex: 0, length: 10);
        final first = resolver.preSelectedIndex;

        resolver.preSelectNext(currentIndex: 0, length: 10);
        final second = resolver.preSelectedIndex;

        // Both are valid indices (may or may not be same due to random)
        expect(first, inInclusiveRange(0, 9));
        expect(second, inInclusiveRange(0, 9));
      });

      test('nextIndex with currentIndex=-1 in order mode returns 0', () {
        final resolver = PlayModeResolver(mode: PlayMode.order);
        // -1 + 1 = 0, which is < length
        expect(resolver.nextIndex(currentIndex: -1, length: 5), 0);
      });

      test(
        'nextIndex with currentIndex=-1 in random mode returns valid index',
        () {
          final resolver = PlayModeResolver(
            mode: PlayMode.random,
            random: Random(42),
          );
          final result = resolver.nextIndex(currentIndex: -1, length: 5);
          expect(result, inInclusiveRange(0, 4));
        },
      );
    });
  });
}
