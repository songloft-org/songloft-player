# Manual ordering in built-in favorites (songloft-org/songloft#550)

Date: 2026-11-02. Baseline `ae85c9570943c5f06ac77397dd384ef5907e2811`; Flutter implementation unchanged, with verification documentation added. Linux amd64 / Flutter 3.44.8 / Dart 3.12.2 / Docker Chrome 121; backend baseline `71635ae30ec76a6a0a8bf4efa94304fe2276a057` plus the uncommitted backend fix.

The [reported UI](https://github.com/songloft-org/songloft/issues/550) is Flutter. `_enterSortMode` loads every member, `_exitSortMode` submits the full `song_ids` after dragging, and successful `resetFilter` persists custom ascending order. The server incorrectly prohibited built-in member ordering. Flutter needs no request change or separate local ordering scheme.

Passed:

- `flutter analyze`: no issues; `flutter test test/features/playlist`: 27 tests.
- `flutter build web --release --dart-define=DEPLOY_MODE=embedded --no-web-resources-cdn`: successful JavaScript build despite a WASM dry-run warning. WASM mode was not validated.
- In a real 1440×1000 browser, open Favorites and Radio favorites, enter manual sorting, drag the first item to the end and press Done. The persisted four-item order matches the drag in both playlists. Real PUT requests, backend reads, screenshots and the reopened UI after reload agree. No page errors.

Evidence: `/tmp/songloft-550-flutter-{analyze,tests,build}.log`; `/tmp/songloft-550-ui/flutter.js`, `flutter-final.json`, `flutter-{drag,saved}-{1,2}.png`. Source fingerprints: `/tmp/songloft-550-verification.json`. The driver waits for menu animations and reads accessibility `aria-label`; screenshots alone do not establish persistence.

Not run: native Windows and other native platforms. Web verification does not validate the reporter's Windows package. No commit, push, release or Issue reply. Deployment requires upgrading the backend; reinstalling the same Flutter version cannot remove the old server's 403 restriction.
