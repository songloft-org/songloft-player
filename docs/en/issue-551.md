# Manual ordering under other view sorts (songloft-org/songloft#551)

## 2026-11-02 follow-up: edge dragging across screens

Comment `6576318751` reports that manual dragging stays within the viewport. The old sorting view nested a non-scrollable, shrink-wrapped `ReorderableListView` inside the page's `CustomScrollView`; its auto-scroller owned the inner viewport. Use `SliverReorderableList` in the page instead, retaining a Material drag proxy, Done/Cancel and full-order persistence. No pinning feature is added.

Flutter baseline: `feb97bb0c46f5d9e4de3ff5049ebdd07c3a9f605` plus this uncommitted worktree; parent `e204855590bdf4c38483ff87ee19769ba91df1fc`. Linux amd64; the install directory says 3.41.5, but the actual tools report Flutter 3.44.8 / Dart 3.12.2.

- Four real-page gesture cases with 80 songs, widths 500/1440 and both directions pass: holding at an edge scrolls over 200px and persists the changed order without losing members. An isolated old page fails all four with zero movement; `/tmp/songloft-551-scroll-negative-clean.log`. Earlier missing-asset/dependency and resource-contention failures are not negative evidence.
- `flutter analyze`, all 20 focused tests, all 813 tests and the embedded release Web build pass. WASM dry run passes; the CupertinoIcons font notice remains.
- Docker Chrome at 1440×1000: a scanned playlist of 140 synthetic songs moves its first song to position 25 in one edge drag. Done persists that position through the real API, retaining all 140 members; no page exceptions. Evidence: `/tmp/songloft-551-scroll/flutter-ui.json`, `flutter-drag.png`, `flutter-saved.png`.
- `dart format lib/ test/` and diff checks pass. Logs: `/tmp/songloft-551-scroll-{focused,analyze,all,build}.log`.

Lynx also lacked a scroll boundary; its companion record is `docs/project/issue-551-scroll.md` in that repository. No commit, push, parent pointer update, release or comment in this batch. Not run: Windows and other native devices; browser/Widget checks do not replace the reporter's Windows acceptance. Backend source is unchanged and backend tests were not rerun.

Date: 2026-11-02. Issue: [songloft-org/songloft#551](https://github.com/songloft-org/songloft/issues/551).

## Cause and behavior

The reported screenshot shows an automatically created Mp3 playlist with ascending file time selected. Flutter only offered manual ordering when `currentSort == 'position'`; that condition does not inspect scan scope or the `auto_created` label. Copying a directory or scanning a specific folder is therefore not the condition hiding the entry; switching the view sort reproduces it.

Remove the field restriction. Outside search results, all seven view fields in either direction now offer manual ordering, starting with the displayed order. Done uses the existing API to submit all member IDs and save custom ascending view order. Cancel changes neither persistent positions nor the view preference. Search results continue to exclude permanent sorting.

Lynx already exposes its entry independently of the current field and saves `position asc` before displaying drag controls. Code inspection, existing page regressions and actual Web interaction found no corresponding defect, so Lynx source needs no change. The clients have different existing policies for the initial drag order; each was validated against its own flow.

## Validation identity

- Flutter: songloft-org/songloft-player, baseline `5be710cd57227fd60d16396b198be10f700ae91e` plus this uncommitted change.
- Lynx: songloft-org/songloft-player-lynx, `8ed3c6484d6107a5f5fd0dc417b6d984578524fd`, no source changes; read-only verification found the same SHA on remote main.
- Backend: songloft-org/songloft, unchanged `ee5d16ab38552ea0416f86a1cf9679e57a3f7a40`; the temporary service was built with `CGO_ENABLED=0 go build -tags dev,lite`.
- Environment: Linux amd64, Flutter 3.44.8, Dart 3.12.2, Node 22.17.1, pnpm 11.15.1, Docker HeadlessChrome 121.0.6167.85. Source/worktree identity is saved in `/tmp/songloft-551-verification.json`.
- An isolated database and four synthetic MP3 files under `/home/hanxi/.cache/songloft-551-music/Mp3` were used. A real `/scan` request targeted this folder and produced an `auto_created` playlist with all four tracks imported and no failures.

## Commands and results

| Check | Result |
| --- | --- |
| Before the fix: `flutter test test/features/playlist/presentation/playlist_manual_sort_test.dart` | 14 fail and 2 pass; other fields lack the manual entry, as expected |
| `flutter analyze` | No issues |
| `flutter test` | All 809 pass, including 16 new actual-page regressions |
| `flutter test --no-pub test/features/playlist/presentation/playlist_manual_sort_test.dart` | All 16 final focused regressions pass; see `focused-final.log` |
| `flutter build web --release --dart-define=DEPLOY_MODE=embedded --no-web-resources-cdn` | Success; WASM dry run succeeds and the CupertinoIcons font notice remains. Browser acceptance uses the JavaScript build |
| Lynx: `pnpm exec vitest run src/features/playlist/__tests__/playlist-detail.test.tsx` | 29 pass, including existing entry coverage from another view sort |
| Lynx: `pnpm run build:web-embedded` | Success; this build was used in the browser |
| `dart format lib/ test/`, format recheck and `git diff --check` | Pass |

Actual browser interaction and backend evidence:

- Flutter, Chinese at 1440×1000: open the scanned Mp3 playlist from Home, open the sort menu under ascending file time, enter manual ordering, drag the first row three places down and select Done. The backend returns the intended full order `[1,2,4,3]` and saves `position asc`. Reload and reopen from Home: UI titles match the backend order, with zero page errors.
- Lynx, English at 1200×900: under ascending file time, the same scanned playlist offers Reorder in its more menu. Selecting it saves `position asc`. Dragging the first row three places down produces the actual `songs/move` request and intended full backend order `[2,1,3,4]`. Reload preserves the displayed order, with zero page errors.

Evidence is in `/tmp/songloft-551/`: `before.log`, `analyze.log`, `tests.log`, `focused-final.log`, `build.log`, `lynx-tests.log`, `lynx-build.log`, `fixture.json`, `flutter-ui-verified.json`, `lynx-ui.json`, `flutter-*.png`, `lynx-*.png` and browser drivers. JSON records requests but excludes authentication request bodies. An initial focused run hung because the test directly awaited search inside fake async; the harness now pumps before awaiting. Two Flutter driver reload assertions failed because they did not reopen the playlist or wait for semantic nodes. Diagnostics remain in `flutter-ui-attempt{1,2}.json`; the final driver passes, without product changes for these harness failures.

Not run: native Windows packages, other native platforms and the reporter's private library. Web checks do not establish Windows acceptance. The full backend suite, full Lynx suite and native builds were not run because their source was unchanged. This is the pre-commit validation record; commits, the parent gitlink, pushes, CI and development packages are tracked by their GitHub revisions and this delivery. No stable release was performed.

Commit: `fix(playlist): 保留其他视图排序下的手动排序入口`, referencing `Ref songloft-org/songloft#551`. The issue remains open for the reporter's acceptance.
