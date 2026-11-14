# Large-playlist resume queue fix (2026-11-14)

Object: songloft-player baseline 4708c64 plus this working tree. Implementation and commit/push authorization carry over from the current playlist-resume task.

Previously playPlaylistTarget exposed one track until all pages completed, and same-song Continue returned early. It now fetches up to 100 tracks around the target and publishes every forward/prepend batch. Every visible queue is a contiguous interval of the original order. Current index, random navigation and preview state are remapped while retaining the current Song/audio instance. Continue repairs an incomplete queue without losing its position.

Validation: analyze clean; flutter test --no-pub test/features/player passed all 298 cases; embedded Web build passed. New pure Dart loader tests cover a thousand tracks with the second page held, contiguous intervals, retained batches on failure and cancellation. Docker Chrome delayed later pages by one second: initial queue 100, Next played actual episode 129, final queue 1000. Screenshots: /tmp/songloft-resume-1000/flutter-first-window.png and flutter-full.png; result flutter-result.json; logs /tmp/songloft-resume-1000-flutter-*.

Native devices, background and casting: Not run. The previous independent Android CI for 4708c64 failed its release JNI check; Android/ProGuard is unchanged and Web acceptance does not imply native package acceptance. Final source/commit identities are recorded under /tmp/songloft-resume-1000/. The parent docs/playlist-resume.md documents the shared behavior/API.
