# Restore saved lyrics after reopening Web (songloft-org/songloft#555)

Date: 2026-11-03. Flutter companion fix; Lynx has a separate verification record. The reporter's client and NAS queue snapshot were not obtained, so this reproduced path is not claimed as the only proven cause in their environment.

## Cause and behavior

A local queue snapshot may predate lyric scraping and lack `lyric_url`. Flutter's manual re-fetch supplied an endpoint temporarily without updating the queued Song. Restoration then returned empty state before checking cache. Two URL-less songs with identical update timestamps also shared the old provider's watch key, preventing reload on switching.

Normal loading, invalidation and manual re-fetch now share endpoint resolution: preserve supplied URLs; otherwise supply `/api/v1/songs/{id}/lyric` for local songs with positive IDs. Watch the resolved URL and update timestamp, retaining cache version checks. Normal loads omit `refresh` and prefer cached/database lyrics; manual re-fetch still forces refresh. A 404 means no lyrics; errors such as 502 remain failures. No song, invalid IDs and URL-less radio/remote songs gain no endpoint.

Flutter Web lyric caching remains memory-only, so a full page reload reads the database again. Native file caching is preserved. Neither cache persistence nor audio hosts changed.

## Verification objects and results

- Flutter repository songloft-org/songloft-player, baseline `32339c748af046a30a28744e2af10e533400d95a` plus this uncommitted worktree. Backend: unchanged parent `88c0b4138aea53a0caf65c3c29c1713c72586177`. Full diff/file SHA-256 values: `/tmp/songloft-555-runtime/flutter-verification.json`.
- Linux amd64 / Flutter 3.44.8 / Dart 3.12.2. The installation path says 3.41.5; versions follow actual tool output. Web: release embedded build, Docker Headless Chrome, real temporary backend/SQLite and synthetic 10-second MP3. No user library accessed.
- Five provider regressions use the real queue codec, HTTP and lyric cache while isolating audio hosts. Old code fails four due to empty lyrics or absent requests; one guard case passes (`/tmp/songloft-555-flutter-before.log`). Fixed code passes all five and all 818 tests (`/tmp/songloft-555-flutter-{focused,all}.log`). Covers old Web queues, cache recovery after manual re-fetch and provider recreation, same-timestamp song switches, 404/502 and excluded objects.
- `dart format lib/ test/` (zero final changes), `flutter analyze --no-pub` (no issues) and `flutter build web --release --no-pub --no-web-resources-cdn --dart-define=DEPLOY_MODE=embedded --output=/tmp/songloft-555-flutter-web` pass; WASM dry run succeeds. Existing CupertinoIcons font notice remains. Logs: `/tmp/songloft-555-flutter-{format,analyze,build}.log`.
- Docker Chrome at 1280×900: persist an old URL-less queue in localStorage while the database holds `lyric_source=scraped`. Two full page loads display both lines, with exactly two ordinary lyric requests and no forced scraping. The actual Play button verifies media progress and displayed lyrics. Results/screenshot: `/tmp/songloft-555-runtime/flutter-browser-summary.json`, `flutter-reload.png`.
- `git diff --check`, UTF-8 and bilingual pairing pass.

Not run: the reporter's NAS/Docker instance, native Android/iOS/Windows/macOS/Linux apps, Bundle backend and native background audio. Backend/hosts are unchanged; the full backend suite was not rerun. Browser/provider checks do not replace device acceptance.

No commit, push, parent pointer update, release or Issue write. Suggested commit: `fix(lyrics): 恢复旧播放队列中的已保存歌词`, with `Ref songloft-org/songloft#555`.
