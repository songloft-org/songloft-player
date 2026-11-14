import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/features/player/domain/use_cases/playlist_window_loader.dart';
import 'package:songloft_flutter/shared/models/song.dart';

List<Song> page(int offset, int limit) => List.generate(
  limit,
  (i) => Song.fromJson({
    'id': offset + i + 1,
    'type': 'local',
    'title': 'Episode ${offset + i + 1}',
  }),
);

void main() {
  test(
    '1000 tracks publish neighbours before later pages and keep every window contiguous',
    () async {
      final held = Completer<List<Song>>();
      final windows = <List<Song>>[];
      var requests = 0;
      var secondOffset = 0;
      var secondLimit = 0;
      final loading = loadPlaylistWindow(
        targetIndex: 127,
        total: 1000,
        isCurrent: () => true,
        fetch: (offset, limit) async {
          if (++requests == 2) {
            secondOffset = offset;
            secondLimit = limit;
            return held.future;
          }
          return page(offset, limit);
        },
        onWindow:
            (songs, {required initial, required complete}) =>
                windows.add(songs),
      );
      for (var i = 0; i < 20 && requests < 2; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(requests, 2);
      expect(windows.single, hasLength(100));
      final selected = windows.single.indexWhere((s) => s.id == 128);
      expect(windows.single[selected + 1].id, 129);
      held.complete(page(secondOffset, secondLimit));
      expect(await loading, true);
      expect(windows.last.map((s) => s.id), List.generate(1000, (i) => i + 1));
      expect(
        windows.any((songs) => songs.length > 100 && songs.length < 1000),
        true,
      );
      for (final songs in windows) {
        for (var i = 1; i < songs.length; i++) {
          expect(songs[i].id, songs[i - 1].id + 1);
        }
      }
    },
  );

  test(
    'a failed later batch retains the already published neighbourhood',
    () async {
      final windows = <List<Song>>[];
      var requests = 0;
      await expectLater(
        loadPlaylistWindow(
          targetIndex: 127,
          total: 1000,
          isCurrent: () => true,
          fetch: (offset, limit) async {
            if (++requests > 1) throw StateError('offline');
            return page(offset, limit);
          },
          onWindow:
              (songs, {required initial, required complete}) =>
                  windows.add(songs),
        ),
        throwsStateError,
      );
      expect(windows.single, hasLength(100));
      expect(windows.single[2].id, 129);
      expect(requests, 4);
    },
  );

  test('switching context rejects a late batch', () async {
    final held = Completer<List<Song>>();
    final windows = <List<Song>>[];
    var current = true;
    var requests = 0;
    var secondOffset = 0;
    var secondLimit = 0;
    final loading = loadPlaylistWindow(
      targetIndex: 127,
      total: 1000,
      isCurrent: () => current,
      fetch: (offset, limit) async {
        if (++requests == 2) {
          secondOffset = offset;
          secondLimit = limit;
          return held.future;
        }
        return page(offset, limit);
      },
      onWindow:
          (songs, {required initial, required complete}) => windows.add(songs),
    );
    for (var i = 0; i < 20 && requests < 2; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    current = false;
    held.complete(page(secondOffset, secondLimit));
    expect(await loading, false);
    expect(windows, hasLength(1));
    expect(requests, 2);
  });
}
