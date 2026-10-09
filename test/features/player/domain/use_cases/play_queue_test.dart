import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/features/player/domain/use_cases/play_queue.dart';
import 'package:songloft_flutter/shared/models/song.dart';

Song _makeSong(int id, {String type = 'local'}) {
  return Song(
    id: id,
    type: type,
    title: 'Song $id',
    duration: 180.0,
    addedAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 1),
  );
}

void main() {
  group('PlayQueue', () {
    group('empty', () {
      test('has no songs and index -1', () {
        expect(PlayQueue.empty.songs, isEmpty);
        expect(PlayQueue.empty.currentIndex, -1);
        expect(PlayQueue.empty.currentSong, isNull);
        expect(PlayQueue.empty.isEmpty, isTrue);
        expect(PlayQueue.empty.length, 0);
      });
    });

    group('add', () {
      test('appends songs to empty queue', () {
        final queue = PlayQueue.empty.add([_makeSong(1), _makeSong(2)]);

        expect(queue.length, 2);
        expect(queue.songs[0].id, 1);
        expect(queue.songs[1].id, 2);
        expect(queue.currentIndex, -1);
      });

      test('appends songs to existing queue', () {
        final queue = PlayQueue(
          songs: [_makeSong(1)],
          currentIndex: 0,
        ).add([_makeSong(2), _makeSong(3)]);

        expect(queue.length, 3);
        expect(queue.currentIndex, 0);
      });

      test('filters duplicate songs by id and type', () {
        final queue = PlayQueue(
          songs: [_makeSong(1), _makeSong(2)],
          currentIndex: 0,
        ).add([_makeSong(2), _makeSong(3)]);

        expect(queue.length, 3);
        expect(queue.songs.map((s) => s.id).toList(), [1, 2, 3]);
      });

      test('same id but different type is not a duplicate', () {
        final queue = PlayQueue(
          songs: [_makeSong(1, type: 'local')],
          currentIndex: 0,
        ).add([_makeSong(1, type: 'remote')]);

        expect(queue.length, 2);
      });

      test('does nothing when adding empty list', () {
        final queue = PlayQueue(songs: [_makeSong(1)], currentIndex: 0);
        final result = queue.add([]);
        expect(identical(result, queue), isTrue);
      });

      test('preserves currentIndex', () {
        final queue = PlayQueue(
          songs: [_makeSong(1), _makeSong(2)],
          currentIndex: 1,
        ).add([_makeSong(3)]);

        expect(queue.currentIndex, 1);
        expect(queue.currentSong?.id, 2);
      });
    });

    group('insert', () {
      test('inserts at beginning and shifts currentIndex', () {
        final queue = PlayQueue(
          songs: [_makeSong(1), _makeSong(2)],
          currentIndex: 0,
        ).insert(0, _makeSong(3));

        expect(queue.length, 3);
        expect(queue.songs[0].id, 3);
        expect(queue.currentIndex, 1); // shifted forward
        expect(queue.currentSong?.id, 1);
      });

      test('inserts at current position shifts currentIndex', () {
        final queue = PlayQueue(
          songs: [_makeSong(1), _makeSong(2), _makeSong(3)],
          currentIndex: 1,
        ).insert(1, _makeSong(4));

        expect(queue.currentIndex, 2); // shifted forward
        expect(queue.currentSong?.id, 2);
      });

      test('inserts after current position does not shift currentIndex', () {
        final queue = PlayQueue(
          songs: [_makeSong(1), _makeSong(2)],
          currentIndex: 0,
        ).insert(1, _makeSong(3));

        expect(queue.currentIndex, 0);
        expect(queue.songs[1].id, 3);
      });

      test('clamps position to valid range', () {
        final queue = PlayQueue(
          songs: [_makeSong(1)],
          currentIndex: 0,
        ).insert(100, _makeSong(2));

        expect(queue.length, 2);
        expect(queue.songs.last.id, 2);
      });

      test('insert into empty queue with index -1 does not crash', () {
        final queue = PlayQueue.empty.insert(0, _makeSong(1));

        expect(queue.length, 1);
        expect(queue.currentIndex, -1); // stays -1 since -1 < 0
      });
    });

    group('playNext', () {
      test('new song follows current without changing the current song', () {
        final original = PlayQueue(
          songs: [_makeSong(1), _makeSong(2)],
          currentIndex: 0,
        );
        final queue = original.playNext(_makeSong(3));
        expect(queue.songs.map((s) => s.id), [1, 3, 2]);
        expect(queue.currentSong?.id, 1);
        expect(original.songs.length, 2);
      });

      test('existing earlier song moves after current without duplicates', () {
        final original = PlayQueue(
          songs: [_makeSong(1), _makeSong(2), _makeSong(3), _makeSong(4)],
          currentIndex: 2,
        );
        final queue = original.playNext(_makeSong(1));
        expect(queue.songs.map((s) => s.id), [2, 3, 1, 4]);
        expect(queue.currentIndex, 1);
        expect(queue.currentSong?.id, 3);
        expect(original.indexMappingTo(queue), {0: 2, 1: 0, 2: 1, 3: 3});
      });

      test('existing later song moves after current', () {
        final queue = PlayQueue(
          songs: [_makeSong(1), _makeSong(2), _makeSong(3)],
          currentIndex: 0,
        ).playNext(_makeSong(3));
        expect(queue.songs.map((s) => s.id), [1, 3, 2]);
      });

      test(
        'current song can be scheduled once again, repeated requests deduplicate',
        () {
          final song = _makeSong(1);
          final original = PlayQueue(
            songs: [song, _makeSong(2)],
            currentIndex: 0,
          );
          final queue = original.playNext(song).playNext(song);
          expect(queue.songs.map((s) => s.id), [1, 1, 2]);
          expect(queue.currentIndex, 0);
          expect(original.indexMappingTo(queue), {0: 0, 1: 2});
          final moved = queue.move(0, 2);
          expect(queue.indexMappingTo(moved), {0: 2, 1: 0, 2: 1});
        },
      );

      test('same id with different type is a separate song', () {
        final queue = PlayQueue(
          songs: [_makeSong(1)],
          currentIndex: 0,
        ).playNext(_makeSong(1, type: 'radio'));
        expect(queue.length, 2);
        expect(queue.songs[1].type, 'radio');
      });

      test('empty and unstarted queues insert at the beginning', () {
        expect(PlayQueue.empty.playNext(_makeSong(1)).songs.single.id, 1);
        final queue = PlayQueue(
          songs: [_makeSong(1), _makeSong(2)],
          currentIndex: -1,
        ).playNext(_makeSong(2));
        expect(queue.songs.map((s) => s.id), [2, 1]);
        expect(queue.currentIndex, -1);
      });

      test('deleted songs have no mapping; new songs do not steal history', () {
        final old = PlayQueue(
          songs: [_makeSong(1), _makeSong(2)],
          currentIndex: 1,
        );
        final updated = old.removeAt(0).queue.insert(0, _makeSong(3));
        expect(old.indexMappingTo(updated), {1: 1});
      });
    });

    group('removeAt', () {
      test('removes song after current does not change currentIndex', () {
        final result = PlayQueue(
          songs: [_makeSong(1), _makeSong(2), _makeSong(3)],
          currentIndex: 0,
        ).removeAt(2);

        expect(result.queue.length, 2);
        expect(result.queue.currentIndex, 0);
        expect(result.shouldStop, isFalse);
        expect(result.currentSong?.id, 1);
      });

      test('removes song before current decrements currentIndex', () {
        final result = PlayQueue(
          songs: [_makeSong(1), _makeSong(2), _makeSong(3)],
          currentIndex: 2,
        ).removeAt(0);

        expect(result.queue.length, 2);
        expect(result.queue.currentIndex, 1);
        expect(result.shouldStop, isFalse);
        expect(result.currentSong?.id, 3);
      });

      test('removes current song advances to next', () {
        final result = PlayQueue(
          songs: [_makeSong(1), _makeSong(2), _makeSong(3)],
          currentIndex: 1,
        ).removeAt(1);

        expect(result.queue.length, 2);
        expect(result.queue.currentIndex, 1);
        expect(result.shouldStop, isFalse);
        expect(result.currentSong?.id, 3);
      });

      test('removes current song at end wraps to last', () {
        final result = PlayQueue(
          songs: [_makeSong(1), _makeSong(2), _makeSong(3)],
          currentIndex: 2,
        ).removeAt(2);

        expect(result.queue.length, 2);
        expect(result.queue.currentIndex, 1);
        expect(result.shouldStop, isFalse);
        expect(result.currentSong?.id, 2);
      });

      test('removes last song sets shouldStop true', () {
        final result = PlayQueue(
          songs: [_makeSong(1)],
          currentIndex: 0,
        ).removeAt(0);

        expect(result.queue.length, 0);
        expect(result.queue.currentIndex, -1);
        expect(result.shouldStop, isTrue);
        expect(result.currentSong, isNull);
      });

      test('invalid index does nothing', () {
        final queue = PlayQueue(songs: [_makeSong(1)], currentIndex: 0);
        final result = queue.removeAt(-1);
        expect(identical(result.queue, queue), isTrue);

        final result2 = queue.removeAt(5);
        expect(identical(result2.queue, queue), isTrue);
      });
    });

    group('move', () {
      test('moves current song forward', () {
        final queue = PlayQueue(
          songs: [_makeSong(1), _makeSong(2), _makeSong(3)],
          currentIndex: 0,
        ).move(0, 2);

        expect(queue.songs.map((s) => s.id).toList(), [2, 3, 1]);
        expect(queue.currentIndex, 2);
        expect(queue.currentSong?.id, 1);
      });

      test('moves current song backward', () {
        final queue = PlayQueue(
          songs: [_makeSong(1), _makeSong(2), _makeSong(3)],
          currentIndex: 2,
        ).move(2, 0);

        expect(queue.songs.map((s) => s.id).toList(), [3, 1, 2]);
        expect(queue.currentIndex, 0);
        expect(queue.currentSong?.id, 3);
      });

      test('moves song from before current to after current', () {
        final queue = PlayQueue(
          songs: [_makeSong(1), _makeSong(2), _makeSong(3)],
          currentIndex: 1,
        ).move(0, 2);

        expect(queue.songs.map((s) => s.id).toList(), [2, 3, 1]);
        expect(queue.currentIndex, 0); // decremented
        expect(queue.currentSong?.id, 2);
      });

      test('moves song from after current to before current', () {
        final queue = PlayQueue(
          songs: [_makeSong(1), _makeSong(2), _makeSong(3)],
          currentIndex: 1,
        ).move(2, 0);

        expect(queue.songs.map((s) => s.id).toList(), [3, 1, 2]);
        expect(queue.currentIndex, 2); // incremented
        expect(queue.currentSong?.id, 2);
      });

      test('same index does nothing', () {
        final queue = PlayQueue(
          songs: [_makeSong(1), _makeSong(2)],
          currentIndex: 0,
        );
        final result = queue.move(0, 0);
        expect(identical(result, queue), isTrue);
      });

      test('invalid oldIndex does nothing', () {
        final queue = PlayQueue(
          songs: [_makeSong(1), _makeSong(2)],
          currentIndex: 0,
        );
        expect(identical(queue.move(-1, 0), queue), isTrue);
        expect(identical(queue.move(5, 0), queue), isTrue);
      });

      test('invalid newIndex does nothing', () {
        final queue = PlayQueue(
          songs: [_makeSong(1), _makeSong(2)],
          currentIndex: 0,
        );
        expect(identical(queue.move(0, -1), queue), isTrue);
        expect(identical(queue.move(0, 5), queue), isTrue);
      });
    });

    group('contains', () {
      test('finds song by id and type', () {
        final queue = PlayQueue(
          songs: [_makeSong(1), _makeSong(2, type: 'remote')],
          currentIndex: 0,
        );

        expect(queue.contains(_makeSong(1)), isTrue);
        expect(queue.contains(_makeSong(2, type: 'remote')), isTrue);
        expect(queue.contains(_makeSong(2, type: 'local')), isFalse);
        expect(queue.contains(_makeSong(3)), isFalse);
      });

      test('empty queue contains nothing', () {
        expect(PlayQueue.empty.contains(_makeSong(1)), isFalse);
      });
    });

    group('indexOf', () {
      test('finds song position by id and type', () {
        final queue = PlayQueue(
          songs: [_makeSong(1), _makeSong(2), _makeSong(3, type: 'remote')],
          currentIndex: 0,
        );

        expect(queue.indexOf(_makeSong(1)), 0);
        expect(queue.indexOf(_makeSong(2)), 1);
        expect(queue.indexOf(_makeSong(3, type: 'remote')), 2);
        expect(queue.indexOf(_makeSong(3, type: 'local')), -1);
        expect(queue.indexOf(_makeSong(99)), -1);
      });
    });

    group('jumpTo', () {
      test('changes currentIndex', () {
        final queue = PlayQueue(
          songs: [_makeSong(1), _makeSong(2), _makeSong(3)],
          currentIndex: 0,
        ).jumpTo(2);

        expect(queue.currentIndex, 2);
        expect(queue.currentSong?.id, 3);
      });

      test('invalid index does nothing', () {
        final queue = PlayQueue(
          songs: [_makeSong(1), _makeSong(2)],
          currentIndex: 0,
        );
        expect(identical(queue.jumpTo(-1), queue), isTrue);
        expect(identical(queue.jumpTo(5), queue), isTrue);
      });
    });

    group('empty queue safety', () {
      test('add to empty queue', () {
        final queue = PlayQueue.empty.add([_makeSong(1)]);
        expect(queue.length, 1);
        expect(queue.currentIndex, -1);
      });

      test('removeAt from empty queue', () {
        final result = PlayQueue.empty.removeAt(0);
        expect(result.shouldStop, isFalse);
        expect(identical(result.queue, PlayQueue.empty), isTrue);
      });

      test('move in empty queue', () {
        final result = PlayQueue.empty.move(0, 1);
        expect(identical(result, PlayQueue.empty), isTrue);
      });

      test('jumpTo in empty queue', () {
        final result = PlayQueue.empty.jumpTo(0);
        expect(identical(result, PlayQueue.empty), isTrue);
      });

      test('contains on empty queue', () {
        expect(PlayQueue.empty.contains(_makeSong(1)), isFalse);
      });

      test('indexOf on empty queue', () {
        expect(PlayQueue.empty.indexOf(_makeSong(1)), -1);
      });
    });

    group('additional edge cases', () {
      test('insert does not deduplicate (by design, for undo scenarios)', () {
        final queue = PlayQueue(
          songs: [_makeSong(1), _makeSong(2)],
          currentIndex: 0,
        );
        // Insert same song - should succeed (insert is for undo/restore)
        final result = queue.insert(1, _makeSong(1));
        expect(result.songs.length, 3);
        expect(result.songs[1].id, 1);
      });

      test('removeAt with currentIndex=-1 keeps index at -1', () {
        final queue = PlayQueue(
          songs: [_makeSong(1), _makeSong(2), _makeSong(3)],
          currentIndex: -1,
        );
        final result = queue.removeAt(1);
        expect(result.queue.currentIndex, -1);
        expect(result.queue.songs.length, 2);
        expect(result.shouldStop, isFalse);
      });

      test('move with only 2 elements swaps correctly', () {
        final queue = PlayQueue(
          songs: [_makeSong(1), _makeSong(2)],
          currentIndex: 0,
        );
        final result = queue.move(0, 1);
        expect(result.songs[0].id, 2);
        expect(result.songs[1].id, 1);
        expect(result.currentIndex, 1); // follows the moved song
      });
    });
  });
}
