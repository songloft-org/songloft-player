import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/features/library/domain/use_cases/favorite_change_watcher.dart';
import 'package:songloft_flutter/features/library/domain/use_cases/favorite_service.dart';

void main() {
  test(
    'one hanging request, refresh before cursor advancement, no refresh on heartbeat',
    () async {
      final first = Completer<FavoriteChange>();
      final next = Completer<FavoriteChange>();
      final refreshStarted = Completer<void>();
      final finishRefresh = Completer<void>();
      final nextStarted = Completer<void>();
      final cursors = <String?>[];
      final watcher = FavoriteChangeWatcher(
        poll: (cursor) {
          cursors.add(cursor);
          if (cursors.length == 1) return first.future;
          nextStarted.complete();
          return next.future;
        },
        refresh: () {
          refreshStarted.complete();
          return finishRefresh.future;
        },
      );
      final run = watcher.run();
      expect(cursors, [null]);
      first.complete(const FavoriteChange('one', true));
      await refreshStarted.future;
      expect(cursors.length, 1);
      finishRefresh.complete();
      await nextStarted.future;
      expect(cursors, [null, 'one']);
      watcher.stop();
      next.complete(const FavoriteChange('one', false));
      await run;
    },
  );

  test('late notification after stop cannot refresh another session', () async {
    final event = Completer<FavoriteChange>();
    var refreshed = false;
    final watcher = FavoriteChangeWatcher(
      poll: (_) => event.future,
      refresh: () async {
        refreshed = true;
      },
    );
    final run = watcher.run();
    watcher.stop();
    event.complete(const FavoriteChange('old', true));
    await run;
    expect(refreshed, isFalse);
  });

  test('failed refresh reconnects without acknowledging the cursor', () async {
    final next = Completer<FavoriteChange>();
    final ready = Completer<void>();
    final cursors = <String?>[];
    final watcher = FavoriteChangeWatcher(
      retryDelay: Duration.zero,
      poll: (cursor) async {
        cursors.add(cursor);
        if (cursors.length == 1) return const FavoriteChange('one', true);
        ready.complete();
        return next.future;
      },
      refresh: () async {
        throw StateError('network');
      },
    );
    final run = watcher.run();
    await ready.future;
    expect(cursors, [null, null]);
    watcher.stop();
    next.complete(const FavoriteChange('one', false));
    await run;
  });

  test('old initialization cannot restore IDs after a session reset', () async {
    final old = Completer<Set<int>>();
    final loaded = Completer<void>();
    final service = FavoriteService();
    final first = service.initialize(
      findOrCreatePlaylist: () async => 1,
      loadSongIds: (_) {
        loaded.complete();
        return old.future;
      },
    );
    await loaded.future;
    service.reset();
    await service.initialize(
      findOrCreatePlaylist: () async => 2,
      loadSongIds: (_) async => {99},
    );
    old.complete({1, 2});
    await first;
    expect(service.playlistId, 2);
    expect(service.favoriteIds, {99});
  });
}
