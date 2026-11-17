# #572: Play next from playlists and favorites

Related: [songloft-org/songloft#572](https://github.com/songloft-org/songloft/issues/572). Playlist details and built-in favorites share `PlaylistSongTile`, which previously neither accepted nor displayed the library's existing play-next action.

Normal song menus now offer Play next and call `PlayerNotifier.playSongNext` directly. Playback, position and queue context are preserved; only the selected song is scheduled, without loading or switching the whole playlist. Empty queues, duplicates and playback modes follow existing queue rules. Selection and manual sorting continue to hide song menus. Existing Chinese, English and Spanish labels are reused.

Tested object: 2026-11-17, `songloft-org/songloft-player` baseline `e8ccdcc4a765356c0bd6dc0c64fc04c0d94aa521` plus this uncommitted worktree; parent baseline `d57b42ba45c565bc48cd2d8f3f70f5b68d32859a`. Linux amd64, Flutter 3.44.8, Dart 3.12.2, a real temporary Go backend and Docker Chrome. Final diff/file hashes: `/tmp/songloft-572/verification.json`.

Results:

- `dart format lib/ test/`, final `flutter analyze --no-pub`, and `git diff --check` passed.
- `flutter test --no-pub --concurrency=2`: 849 passed; focused playlist and queue-navigation checks: 88 passed.
- New page regressions cover playlists/favorites, 500px/1280px, and all three languages. They assert only the single-song scheduling command runs, without additional playlist HTTP requests. The same 12 checks fail for the missing menu entry against an isolated `git archive` of the old implementation.
- Sorting fixtures now isolate the unrelated `playlistProgressProvider`. Previously, 20 checks failed because the resume card left a five-second polling timer pending. Production resume logic is unchanged.
- The embedded Web release build passed, with existing warnings about nine untranslated Spanish messages and Cupertino fonts.
- Actual browser interactions, audio progress, persisted queues and source context: `/tmp/songloft-572/flutter-{full,mobile}.json`; corresponding `playlistScreenshot.png` / `favoriteScreenshot.png` files show the menus. Fixtures use four generated silent WAV tracks, without private music.

Boundaries: the existing Spanish header play/add buttons overflow at 390px; header layout changes are outside this task. Three-language page checks use 500px, with an additional actual Chinese browser check at 390px. Not run: Android/iOS/desktop native packages and reporter-device acceptance. Web does not replace native validation. Backend business tests are not applicable; backend code is unchanged.

The user authorized commits, pushes, parent gitlink updates and a reply to #572. Delivery proceeds with client repositories first and the parent afterward; no stable version is created. Final commits and same-SHA CI status are recorded in `/tmp/songloft-572/delivery.json`. Commit: `feat(playlist): 歌单和收藏支持下一首播放 songloft-org/songloft#572`.
