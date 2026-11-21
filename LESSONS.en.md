# Flutter Client Development Lessons

## Scope and Sources

Record Flutter, providers, audio, Bundle mode, and native hosts in songloft-org/songloft-player. See the [local AI workflow](docs/en/ai-development.md) and parent host constraints. Existing AGENTS/business references remain authoritative; link evidence rather than duplicating incident histories.

## Recording and Promotion

Include rule, scope, full owner/repo#number, failure/fix commit SHAs, actual validation, and Done right examples (pending if unavailable). Seen counts independent events on distinct dates, not repeated reviews. Three dates make promotion candidates; mark the authoritative destination. Existing hard rules/serious failures apply immediately. Synchronize the [Chinese version](LESSONS.md), never invent counts/resolution/device acceptance, and redact sensitive information.

## Entries

### CI-005: Verify the Android artifacts passed between jobs

- In [Flutter dev CI](https://github.com/songloft-org/songloft-player-flutter/actions/runs/44741264627), the Android job verified the universal APK and built patches for three ABIs. The Bundle migration had removed the Standard artifact upload. Publishing succeeded and left `dev` without the APK, patches, and version manifests.
- Upload `apk-output/` to the publishing job. When the Android job succeeds, check the APK, version metadata, and all three ABI patches and manifests before replacing the existing Release.
- Seen 1× (2026-11-21).

### CI-004: Keep shared packaging helpers outside the app build directory

- The Flutter Windows standard package built successfully, as did the Bundle app and Go backend. After the packager recreated `build/`, the Bundle ZIP step could no longer find the compiled WebView hit-test helper. Build it in `RUNNER_TEMP` and copy from there into both the standard and Bundle ZIPs. [Windows CI](https://github.com/songloft-org/songloft-player/actions/runs/44481909546/job/135416370687)
- The same macOS Bundle job built the app and backend before `lipo -verify_arch` rejected its arguments. Read the architecture list with `lipo -archs` and check for arm64 and x86_64. A universal fixture passed on a physical Mac and a single-architecture fixture was rejected. PowerShell on a physical Windows machine preserved the staged helper after recreating `build/`. Full packaging CI awaits revalidation. [macOS CI](https://github.com/songloft-org/songloft-player/actions/runs/44481909546/job/135416370907)
- Seen 1× (2026-11-19).

### CI-003: Read the committed manifest when verifying release interfaces

- Windows Bundle checked out the public backend successfully. Its interface check then failed because the manifest in the working tree had CRLF line endings. All four signatures in the diff were identical. [Windows CI](https://github.com/songloft-org/songloft-player/actions/runs/44479533779/job/135408165785)
- Use `git show HEAD:mobile/export_surface.txt` to read the manifest from the build commit. The actual composite script failed with the old comparison and passed with the fix on the same backend checkout `1861c33` with `core.autocrlf=true`.
- Seen 1× (2026-11-19).

### LYRIC-006 Distinguish inline timestamps from standard LRC line repeats

- Validation covers word-timed lyrics and the playback provider at baseline `f05d80448a99c128e520a258555e339caf639bf4`. [songloft-org/songloft-player#54](https://github.com/songloft-org/songloft-player/issues/54)
- The old playback entry point produced two identical lines from `[00:01.000]今[00:01.250]天`, reproducing the screenshot symptom. The old word parser also dropped text before the first angle tag, and a line-timed `lxlyric` could override word timing in the main lyric. All three new regressions failed on the old implementation. The reporter did not supply the original lyric.
- Treat single brackets separated by lyric text as word timing and keep consecutive leading tags for repeated lines such as choruses. Check mixed formats, explicit final word ends, translations, and cache reloads through the playback entry point.
- Seen 1× (2026-11-18).

### MENU-001: Verify each song-row adapter exposes shared queue capabilities

- Scope: playlist and favorites menus, songloft-org/songloft#572; baseline `e8ccdcc4a765356c0bd6dc0c64fc04c0d94aa521`.
- Evidence: library rows already used `playSongNext`, but the separate playlist/favorites adapter lacked its callback and menu entry. All 12 page regressions fail for the missing entry against isolated old source.
- Rule and Done right: trace page → row adapter → menu → existing queue command. Assert that only the selected song is scheduled, without fetching/replacing the source playlist; combine page checks with existing queue-rule tests. Results and native boundaries: [#572 record](docs/en/issue-572.md).
- Seen 1× (2026-11-17). Local implementation and validation complete; task records track authorized delivery commits and CI. No stable version created.

### LICENSE-001: Check the bundled login agreement copies when verifying license declarations

- Scope: Flutter login assets `assets/legal/TERMS{,.en}.md`; baseline `0427678e9f6aa0977dada8653325a2e0844e7e4e`.
- Evidence: `LICENSE`, README, `pubspec.yaml`, and the parent agreements declare Apache-2.0, but the two language assets loaded by the login page still declared GPL-3.0 four times across Service Description and Intellectual Property. Checking root declarations alone misses the copies users actually see.
- Rule and Done right: trace the loaded asset paths and pubspec registration when updating license declarations; synchronize both declarations and update dates in Chinese and English. Preserve third-party LGPL/GPL declarations according to their actual licenses. This change only corrects text.
- Validation: Linux, Python static checks of loaded paths, registration, the four Apache-2.0 declarations, and corresponding parent agreement lines; `git diff --check`. Record and worktree diff SHA-256: `/tmp/songloft-flutter-terms-20261117.json`. Not run: App build, tests, and actual dialog interaction; only Markdown assets changed.
- Seen 1× (2026-11-17). Local text correction, not committed or released.

### CI-002: Inspect release assets and specify the AppImage architecture

- Scope: Linux AppImage packaging and stable Releases; released source `65dc1d978705a0f83ae6f8bbc226c489f48c946e`.
- Evidence: the [v2.13.10 Linux job](https://github.com/songloft-org/songloft-player/actions/runs/43669474220/job/132676079255) exited 1 during AppImage packaging, reporting multiple detected architectures and requesting `ARCH=x86_64`. `continue-on-error` left the job green. The Release had only 20 assets, missing `songloft-linux-x64.AppImage` compared with the previous stable release.
- Rule: explicitly set the AppImage tool architecture for the x64 job. AppImage failure must block stable tag publication; require an existing nonempty file before collection. Verify actual release filenames and version/commit metadata rather than relying on green jobs. Supplement missing assets from the original published bundle, verify GitHub's SHA-256, and preserve existing version tags.
- Validation: actionlint v1.7.12 passed; original log `/tmp/songloft-release-20261115-flutter-linux.log`. Only packaging configuration changed; repackaging and CI acceptance follow this delivery. Not run: desktop playback and installation experience.
- Done right: the [Linux job](https://github.com/songloft-org/songloft-player/actions/runs/43671029622/job/132680883591) for repair `968148149781f3869cde11bfa8329393cdf18f67` successfully packaged and uploaded all 4 Linux files; log `/tmp/songloft-release-20261115-appimage-ci-fixed.log`. Stable asset repair used Ubuntu 24.04 and the original release bundle (GitHub SHA-256 `5801480917b0765ef2128c1294ce5b5476576c635393c921a00aa7cc860af72f`). After extraction, all 35 original files had identical hashes and all 18 ELF files were x86_64. The supplementary AppImage is 33,412,288 bytes; GitHub's returned digest matches local SHA-256 `71fb1c786ebced7750ffe1fd9aab4b87896d4fbefb0f174e5e65b32fe048cb51`. The Release now has all 21 assets; evidence `/tmp/songloft-release-20261115/appimage-repair/verification.json`.
- Seen 1× (2026-11-15). Configuration repair, remote Linux packaging, and same-version asset repair accepted; the original release tag was preserved.

### CI-001: Validate JNI releases against this build's generated signatures

- Scope: APK validation for standalone Android and the parent repository's Bundle builds; baseline `b1a1a6f6b0efebb6aeae6910afc70fd8f619d2a7`.
- Evidence: all three ABI APKs compiled in the [failed CI run](https://github.com/songloft-org/songloft-player/actions/runs/43571666848), but the first JNI check failed. The run resolved `shared_preferences_android 2.5.5`, whose generated `getAll` argument changed from `java.util.List` to `byte[]`; the checker still required the 2.5.1 descriptor.
- Rule and Done right: locate the resolved dependency through `.dart_tool/package_config.json`, read the generated binding's actual descriptor, and compare it exactly with release DEX. Fail when parsing is unsuccessful; do not accept either historical signature or remove coroutine runtime checks. The old checker failed 4 new cases, including incorrectly accepting a new Dart binding paired with an old APK. The fix passes 8 JNI regressions and 1 native contract regression. Parsing was also checked against the actual 2.5.1 and 2.5.5 bindings, using fixture DEX output.
- Validation: Linux amd64 / Python 3.12.11, `python3 -m unittest discover -s scripts/tests -p '*_test.py'`; logs `/tmp/songloft-flutter-jni-{before,after}.log`. Not run: full local Android compilation and device startup. Actual release checks for all three ABIs are tracked separately in CI for the repair SHA; fixtures are not real APK acceptance.
- Remote acceptance: the [Android job](https://github.com/songloft-org/songloft-player/actions/runs/43668053572/job/132671758046) for repair `2bc0b44b8120f01bb2b4c50b0c8b55b9a1f79d95` resolved 2.5.5 and passed all 9 script tests, ARM64/ARMv7/x86_64 release APK builds and individual JNI checks, and hot-update patch generation. Log: `/tmp/songloft-flutter-jni-android-ci.log`. Native runtime code was unchanged; device startup remains Not run.
- Seen 1× (2026-11-15). Script repair, local regressions, and remote three-ABI acceptance complete; full-platform CI and stable publication follow this delivery.

### RESUME-002: Publish large queues before all pages finish

- Scope: playlist resume and paginated queues; baseline 4708c64 plus this working tree.
- Evidence: the previous implementation retained one temporary track until a full replacement. With a thousand tracks and delayed browser pages, the repair showed 100 tracks first, played the next episode before completion, and finally showed 1000. See the [record](docs/en/playlist-resume-queue.md).
- Rule and Done right: load neighbours first, publish contiguous windows and remap indices/navigation by song identity. Reusing the current audio must not bypass incomplete queue repair. Hold later requests and assert intermediate queue state, rather than only the final length.
- Seen 1× (2026-11-14). Local tests and Web passed; native devices Not run, delivery follows this batch's record.

### FAVORITE-001: Session reset must reject old favorite initialization

- Scope: favorite initialization and server change subscriptions, songloft-org/songloft#563.
- Rule: stopping subscriptions only blocks future events. In-flight domain initialization also needs a session generation; after reset it must not restore old IDs or clear the new initialization state.
- Evidence and Done right: loading the old FavoriteService in isolation fails the new-session id=2 assertion because a late response restores 1. Generation checks pass. All 831 Flutter tests and analysis passed; `/tmp/songloft-563-extra/flutter-{negative-init,tests,analyze-delivery}.log`.
- Seen 1× (2026-11-11). Status: new subscription mechanism validation, pre-commit validation; delivery status is tracked in the batch record; [record](docs/en/issue-563.md).

### LAYOUT-006: Bound index lines when narrowing the column

- Scope: playlist song rows, songloft-org/songloft#562.
- Rule: narrowing index space must keep three-digit numbers and initial hints on separate single lines. Check longer indices, hit areas and large text alongside title width.
- Evidence and correct implementation: changing 32px to 24px triggered an existing row test with 4px bottom overflow. Bounding index text to one line fixes both regressions. See [record](docs/en/issue-562.md).
- Seen 1× (2026-11-11). Found and fixed locally; uncommitted and unreleased.

### LYRIC-005: Old queues without a lyric URL must still read saved lyrics

- Scope: lyric provider, playback restoration and cache, songloft-org/songloft#555; baseline `32339c748af046a30a28744e2af10e533400d95a`.
- Rule: temporarily supplying an endpoint during manual re-fetch does not update persisted queues. Normal restoration must share endpoint resolution and distinguish song changes by the effective endpoint. Web memory cache is not persistence across page loads.
- Evidence and Done right: old code fails four new cases and passes one guard; fixed code passes all five and all 818 tests. A real temporary backend and Chrome verify two full page loads reading saved lyrics with no forced scraping. Objects, logs and device boundaries: [record](docs/en/issue-555.md).
- Seen 1× (2026-11-03). Status: local companion fix, no commit/push/release; reporter environment untested.

### SORT-002: edge dragging must use the actual page viewport

- Scope: playlist manual ordering, songloft-org/songloft#551 comment `6576318751`; baseline `feb97bb0c46f5d9e4de3ff5049ebdd07c3a9f605`.
- Rule: use a Sliver sharing the page Scrollable instead of a disabled shrink-wrapped inner viewport. Its drag proxy still needs Material. Short-list reordering does not prove cross-screen dragging works.
- Evidence / Done right: four real gesture cases with 80 songs, narrow/wide layouts and both directions fail with zero movement on the old page, then scroll over 200px and persist the order after the fix. All 20 focused tests, 813 full tests, analysis and Web build pass. A real browser moves song 1 to position 25 in a 140-song playlist and verifies the API. See [#551](docs/en/issue-551.md).
- Seen 1× (2026-11-02). Status: local fix; native Windows acceptance not run. No commit, push or release.

### SORT-001: manual ordering must remain accessible under other view sort fields

- Scope: Flutter playlist details, songloft-org/songloft#551; baseline `5be710cd57227fd60d16396b198be10f700ae91e`.
- Evidence: the reported screenshot selects ascending file time. The old menu only shows manual ordering when `currentSort == 'position'`, independently of `auto_created` labels or scanning mode. New actual-page regressions fail 14 cases and pass 2 on the old implementation; 12 failures directly assert the missing entry under other sort fields.
- Rule and fix: a view preference should not hide permanent ordering. Flutter starts dragging from the displayed order, submits all member IDs, then switches to custom ascending order. Cancel writes nothing; search results still exclude permanent sorting.
- Done right: cover ascending/descending views for seven fields, saving a drag, cancellation and search restrictions. All 809 tests and static analysis pass. See the [#551 record](docs/en/issue-551.md) for both browser checks, source identity and platform boundaries. Lynx already exposes its entry independently of the field; 29 related tests and actual drag persistence pass.
- Seen 1× (2026-11-02). Status: implementation and local checks pass; commits, pushes and CI follow this delivery. The native Windows package has not been accepted.

### AUDIO-005: duplicate interruption listeners alone do not prove failed recovery

- Scope: Flutter audio_session / just_audio interruptions, user cancellation and live recovery, songloft-org/songloft-player#52; baseline `538c228677350fa7c87f74bb5fe12e6e71b7ef56`.
- Evidence: on 2026-10-26, the initial investigation attributed the reported failure directly to duplicate Handler/just_audio listeners. Line-by-line review found just_audio maintains separate resume intent, and the old Handler passes normal single-interruption recovery with injected events. This does not establish the device root cause. The old Handler does have gaps around repeated begin, unknown end, manual pause, asynchronous pause completion, live recovery and late subscriptions: 14 of 17 isolated old-logic regressions fail and 3 pass.
- Rule: inspect dependency subscription order, the synchronous part of pause, resume state and the OS shouldResume mapping before explaining symptoms. Give interruptions one owner and clear recovery intent on explicit cancellation/headphone unplug. Injected session boundary tests establish that layer's behavior, not reproduction on a released package or the reporter's device.
- Done right: the candidate gives the Handler interruption ownership, waits for pause, routes recovery through the live entry point, and prevents recovery after cancellation. Linux x86_64 / Flutter 3.44.8 / Dart 3.12.2 passes all 791 tests and static analysis. See the [#52 record](docs/en/issue-52.md) for code identity, isolation and evidence. Not run: iOS compilation, iPhone video interruptions/background track changes, and other native focus paths. Background track changes still need version/device logs.
- Seen 1× (2026-10-26). Status: lesson; the user authorized commit, push and an issue reply. Device testing awaits a new package; the reported symptoms are not declared resolved.

### LYRIC-004: applying the static 7:1 floor to the song-change animation neutralizes the accent

- Scope: Flutter mobile/desktop full player `PlayerBackdrop`, songloft-org/songloft#537; baseline `8fa1d6e` (v2.13.6).
- Evidence: on 2026-10-24 the reported screenshot shows the active line and icons at `#415F91` (light primary), inactive lines near 50% onSurface and a dark top overlay, matching the pre-#523 implementation. Current `_readable` also holds the black/white cover tints that only appear during a song change to 7:1; the active line of every built-in palette therefore collapses to near-neutral gray (light blue/teal/forest/rose/amber/violet `#1F2631`/`#122C2C`/`#1F281A`/`#37232A`/`#352515`/`#2D2536`; dark `#E8E8ED`/`#E4E9E9`/`#E7E9E1`/`#F2E5E7`/`#F1E6DD`/`#ECE6ED`), losing the accent hue. A new hue regression fails on the old implementation in both modes (light saturation delta 0.15595 > 0.02; dark hue delta 20.47° > 1.5°).
- Rule and fix: require 7:1 for the static background, but only 4.5:1 for the previous background that may still be visible during the animation. Adjust the foreground through HSL lightness alone instead of mixing toward neutral onSurface. With the default blue theme the light accent changes from `#1F2631` to `#2D4266`; dark mode keeps `#AAC7FF`.
- Done right: contrast/transition regressions and the full related suite pass; the new hue test fails on the old implementation and passes on the new one. See the [#537 record](docs/en/issue-537.md) for full validation and Not run items. The screenshot is an old client, so it cannot establish that current versions still have the dark-gray background.
- Seen 1× (2026-10-24). Status: lesson; commits and publication follow Git/CI.

### ANDROID-001: JNI parameter types are native contracts; debug startup cannot replace release acceptance

- Scope: Android standard/Bundle R8 shrinking, SharedPreferences startup and hot-update compatibility hashes; baseline `203e79b5fd7ac02b8edb93af291bb6981e62974f`, official package source `d89934eea468c22f635d28e5bfd0b5fe81c98147`.
- Failure evidence: on 2026-10-20, 2.13.4 was reported stuck at “Starting” even after reinstall. The official x86_64 APK (SHA-256 `01812553e6cfc32e80b095f956c2f291dfc5f54500195b9a9a05e258a46769bf`) reproduced a `SharedPreferencesApiRegistrar.getAll` `NoSuchMethodError` during preferences initialization on an isolated API 34 emulator. Its DEX parameter is `LE3/d;`, while JNI looks up `Lkotlin/coroutines/Continuation;`. On 2026-10-21, the user-specified official ARM64 APK (SHA-256 `54e9bd33a8aaa305b1a210160e539f2faf4c4782d17a09aa6e63a0f5af8b576c`) also failed the JNI check; both DEX files are byte-identical to the official x86_64 package. Redmi K40 is a user report, not completed hardware acceptance. Release CI shows `shared_preferences_android 2.4.28` resolved for 2.13.3 and `2.5.1` for 2.13.4; the latter invokes Kotlin suspend methods via JNI. Server-free widget tests, debug packages and network timeout regressions did not detect the release shrinking issue. Network hardening was saved separately as evidence and is not the incident fix.
- Rule and fix: load release ProGuard rules, use `-keep,includedescriptorclasses` to preserve the preferences bridge and parameter types, and audit `package:jni`'s `lib/src/kotlin.dart` to keep its name-based coroutine, Result/Failure and Unit class/member lookups. The first descriptor-only candidate passed the initial static check but still failed native startup because `CoroutineSingletons` was missing. Preserve `candidate-descriptors-only.apk`, `native-partial.log` and `partial-startup.png` as a counterexample; the expanded APK check rejects it. Standard/Bundle CI checks the `getAll` descriptor and these runtime symbols in each ARM64, ARMv7 and x86_64 release APK. Include ProGuard rules in the native contract hash so rule changes require a full APK instead of a Dart-only patch; comments and blank lines do not change the hash.
- Validation record: `release-sharedprefs-dex.txt`, `jni-before.log`, `release-ci.log`, `release-2.13.3-android.log` and `native-contract-{before,test}.log` under `/tmp/songloft-startup-20261020/`. The new APK check rejects the old official package as expected; the old hash script fails the new compatibility regression and the new script passes. See `validation-native.json` for fixed-package builds, DEX checks and native startup acceptance; the initial engine-download build failure must not be recorded as passing.
- Done right (2026-10-21): Linux amd64 / Flutter 3.44.8 / Dart 3.12.2 / shared_preferences_android 2.5.1 / jni 1.1.0; the fully shrunk release APK builds and passes bridge/coroutine runtime symbol checks. All 6 startup/contract Dart tests and 1 script regression pass, with no analyzer issues. Fresh installation and a second cold start on API 34/x86_64 both reach login with no native lookup errors; see `final-{startup,restart}.png` and `native-final.log`. Preserve the initial download failure and two host-OOM build failures. The final build uses a mirror, one worker, a bounded heap and serial GC without changing release defaults. The follow-up ARM64 split release build, complete JNI checks, matching native-contract asset and ARM64-only native libraries all pass; artifact `songloft-startup-fixed-arm64-v8a.apk`, SHA-256 `1be79259583a4f0ee6d0962c682d868a99f936ef56009d25d5f724728d835504`; see `release-build-arm64.log` and `jni-fixed-arm64.log`. Its local debug certificate is for validation only. Not run: reporter ARM hardware, officially signed release packages, Bundle local backend and remote CI.
- Seen 1× (2026-10-20). Status: confirmed release native failure, fixed locally. See the validation record for device coverage, final commits and builds; stable publication is tracked separately.

### AUDIO-004: A live disconnect is not song completion; reconnection needs playback intent and cancellation boundaries

- Scope: Flutter live radio, playback retry and audio_service media sessions, songloft-org/songloft#531; baseline `d89934eea468c22f635d28e5bfd0b5fe81c98147`.
- Evidence: with the old Provider isolated, live completion advances according to play mode/queued-next requests and exhausted network retries switch to station B. The old backoff produces a zero delay for a very large retry count. The first API 34 native run confirmed continued requests for A after disconnection, while failed loads put MediaSession into idle and deactivate it. Host memory pressure interrupted that run, so it is incomplete device acceptance.
- Rule and fix: route `isLive` completion/errors to the same station, retry outside finite song budgets and clamp the exponent before calculation. Disconnects do not consume finish events, queued-next requests or sleep song counts. Pause/stop/skip/dispose invalidate the old generation; pause invalidates pending source loads. Publish buffering with playback intent during reconnection to preserve notification controls, clearing it on cancellation.
- Done right: 291 audio, player-domain and real-Provider tests pass, covering same-station recovery after three simulated offline minutes, cancellation, media play and sleep timers. The final full suite passes 767 tests; the API 34 emulator passes same-station recovery after a 110-second outage and media pause/resume/stop checks. Full code objects are in the [#531 record](docs/en/issue-531.md) and `/tmp/songloft-531-20261020/`. An emulator with synthetic sources does not replace the reporter's hardware and long background use.
- Seen 1× (2026-10-20). Status: lesson; local validation preceded commit; Git/CI provides the final commit and release status.

### AUDIO-003: a libmpv error log is not a fatal error; check whether playback actually stopped before declaring the track finished

- Scope: native platforms (Win/Linux/macOS/Android/iOS) on media_kit/libmpv, songloft-org/songloft#529, baseline `1dcc52612f6242a0598b3c06c946200a5d2f1ec5`.
- Evidence: 2026-10-20, the reported sample MP3 contains exactly **32,768 zero bytes** at file offset 728728 (no Xing header, so this lands at 25.73s of audio). The backend is clean: scan duration 282.996083333s is correct and `/api/v1/songs/1/play` returns `Content-Length: 6903290`, byte-identical to the file; an independent `curl -r` range re-fetch from the origin returns the same bytes, so the corruption is in the source file. Decoders do recover: ffmpeg logs one `[mp3float] Header missing` and still decodes 281.52s (the 1.4s shortfall versus 283.0s is exactly 32768 ÷ 24000 B/s), and Chrome's `<audio>` plays to 283s before firing `ended`. But libmpv reports this **recoverable** decode error at `level=error` from its `ad` module; the vendored media_kit `real.dart` `prefix == 'ad'` branch turns it into `player.stream.error`, and the playback-error branch in `songloft_mediakit_player.dart` (added for songloft-org/songloft#357 FLAC tail errors / dropped network streams) unconditionally set `completed` → the layer above treated the track as finished and auto-advanced → the whole song was skipped at 00:25.
- Rule: **the error event alone cannot distinguish recoverable from fatal**; never use it by itself to declare a track finished. Look at whether the position still advances afterwards: record the position, wait an observation window, and only call it fatal if the position barely moved. Do not decide while paused (there is nothing to compare, and auto-advancing a paused player is wrong anyway); a storm of repeated errors must not restart the window, or it never expires; seek/track change/load/release must invalidate the baseline.
- Done right: added `lib/core/audio/playback_error_watchdog.dart` (3s window / 500ms progress threshold); playback errors now `arm()` it while the load-failure branch is unchanged (#357's unrecoverable cases still end the track, just 3s later). 7 new unit tests cover "still advancing → not fatal", "stalled → fatal", "below threshold → fatal", "paused → no auto-advance", "cancel", "repeated errors decide once", and "can re-arm after a verdict"; an isolated destruction check removing the progress comparison made the #529 regression test fail as expected. `flutter analyze` (core/audio + test/core/audio) is clean, the full 749-test suite passes, and `dart format` reports no diff.
- Other clients: Flutter Web (`songloft_web_audio_player.dart`) maps error → `idle` and never advances; the real Flutter Web build driven in headless Chrome played straight from 25.1s to 33.1s with no error and no `ended`. Lynx Web (`audio.on('error')` in `player-store.ts`) retries the same song in place via `scheduleRetry`, and its `stateChanged: 'error'` branch is empty. Neither is affected, so the reporter's "web client" claim is unexplained pending confirmation of which client they used.
- Not run: acceptance on the reporter's Windows/Android native builds and private library; no Windows/Android device here, and ffmpeg plus Chrome do not substitute for a native libmpv regression on real hardware.
- Seen 1x (2026-10-20). Status: lesson; Git provides the fix commit.

### AUDIO-002: just_audio headers always enable its loopback proxy, whose HLS child keys do not match

- Scope: desktop (Win/Linux/macOS) HLS radio playback with the libmpv backend and just_audio 0.10.6, songloft-org/songloft-player, baseline `a9e5dda70b61e313ee9902b9bfc26691c16230c6`.
- Evidence: `UriAudioSource._onLoad` starts `_ProxyHttpServer` whenever `headers` (or a player-level userAgent) is non-null. For relative m3u8 children it registers the handler key from the **entry URL's** query (`uri.replace(path: ...)` keeps the query), while libmpv resolves segments against the proxy entry URL and requests the segment's own query (`u=...`). Keys differ → `_handlerMap[uriPath]!` throws on null → every segment fails with `Failed to open segment` → 18s timeout and retry. The user log's `_ProxyHttpServer.start.<anonymous closure>` null check is exactly this.
- Rule: **do not pass origin-facing request headers via `AudioSource.uri(headers:)`** unless the source has no child resources (non-HLS). Do not globally set `useProxyForRequestHeaders: false` either: the `insecureTls` path relies on that proxy to route upstream HTTPS through Dart's trust-all HttpClient (#272).
- Done right: desktop live now wraps UA/Referer/`Icy-MetaData` in `LiveStreamHeaders` attached to just_audio's `tag`; `SongloftMediaKitPlayer` turns it into `Media(httpHeaders:)` (media_kit → mpv `http-header-fields`) straight to libmpv, leaving `headers` null so the proxy never starts. 10 new unit tests cover "desktop live has no headers and keeps them on the tag", "tag reaches Media.httpHeaders", and unchanged non-desktop behavior. `flutter analyze` shows only the 2 pre-existing warnings; the new tests pass.
- Not run: real Windows client playback against the reporter's LAN radio, and no upstream just_audio issue filed yet (`uri.replace` dropping query plus an unchecked `_handlerMap[...]!`).
- Seen 1× (2026-10-19). Status: lesson; Git provides the fix commit.

### LYRIC-003: Verify cover color separation independently of text contrast

- Scope: Flutter cover extraction and mobile/desktop player backgrounds, songloft-org/songloft#523 feedback on 2026-10-17.
- Evidence: baseline `18b50cbca02a7470279ddcd04907f71365140a57` passed text contrast tests while light backgrounds retained only 12%→4% artwork; the lower end reverted to the theme without mutedColor. Real HTTP/PNG regressions also confirmed discarded warm/monochrome colors and server identity missing from relative cache keys. Both extraction tests and both separation tests failed on the old implementation.
- Done right: verify both gradient ends, real image decoding and text contrast separately. Stronger washes must include the previous cover during song animations when computing foregrounds. Existing contrast/transition tests caught the first stronger wash; all 12 related tests pass after extending bounds. Full checks and device limits are in the [record](docs/en/issue-523.md#2026-10-17--cover-colors-remain-too-subtle). Local defects do not establish the reporter's device cause.
- Seen 1× (2026-10-17). Status: lesson; currently an uncommitted worktree.

### LYRIC-002: Check effective accessibility settings before diagnosing cover tinting

- Scope: Flutter full-screen player; songloft-org/songloft#523 feedback on 2026-10-16.
- Evidence: the actual color function at baseline `bb03a5c49eb6701d90a73b924ed12ec388c6560c` deliberately returns a solid background with increased contrast; the old switch description omitted the cover-background effect. Visible artwork without a gradient does not establish extraction failure; the app toggle alone does not account for system high contrast.
- Done right: preserve the accessibility policy and clarify the switch in three languages. Actual-function comparisons and validation boundaries are in the [#523 follow-up record](docs/en/issue-523.md). The reporter's device settings remain unconfirmed; no proven device cause is claimed.
- Seen 1× (2026-10-16). Status: lesson; copy was uncommitted during validation, with final validation objects in the task record.

### QUEUE-001: Give large queues an item extent and avoid scanning the queue for every appended song

- Scope: mobile queue sheets, desktop drawers, and batch appends, songloft-org/songloft#525.
- Evidence: on 2026-10-15, baseline `00cbe94841acca3eaf561a339f61072914c9de31` omitted item extents on both `ReorderableListView.builder` instances. Regressions against isolated old sources hit the 200-row build guard when opening the middle of a 30,000-song queue. Appending 100 songs to 30,000 caused 6,000,000 song ID reads in the old `PlayQueue.add`.
- Rule and fix: share the same extent between layout and automatic positioning, allowing space for scaled title/artist text. Deduplicate with an `(id, type)` set while preserving existing duplicates, batch deduplication, and order.
- Done right: opening and distant track changes each read fewer than 100 queue entries; the append regression reads at most 30,100 IDs. All 728 Flutter tests, analysis, and the embedded Web build pass. See the [#525 record](docs/en/issue-525.md) for bilingual/scaled text, drag/remove checks, and browser evidence.
- Not run: the reporter's native Windows/Android packages and private library. Browser checks do not replace device acceptance; the candidate is not described as released.
- Seen 1× (2026-10-15). Status: lesson; tested object is the baseline plus this fix. The task record identifies the worktree at test time; Git provides the commit SHA.

### AUDIO-001: Check SDK conversion by Android version for notification Stop

- Scope: Flutter audio_service notifications and Android system media panels, songloft-org/songloft#520.
- Rule: Inspect the locked version's `createCustomAction`, notification-action list and platform conversion; a Dart customAction field does not prove rendering on every Android version.
- Evidence: On 2026-10-14, baseline `3860205b0d8cf8449d8cf31746c254ef597c55e3` used an explicit custom Stop, excluded from audio_service 0.18.19's ordinary notification list. This batch initially added standard STOP as well; API 34 showed two Stop actions. The library already converts standard STOP to a custom STOP on Android 13+, making dual registration redundant.
- Done right: Keep standard STOP alone, supplying the older notification action and one newer panel action. Removing it in an isolated copy fails four regressions, which pass with the fix. Final API 34/x86_64 playback reports one Stop; Account exit during playback removes PID, services and notification. Evidence: `/tmp/songloft-520-flutter-{single-stop,final-playing,playing-exit}.json`; working-tree object: [#520 record](docs/en/issue-520.md).
- Stop lifecycle: actual API 34 checks found late ready/completed events could republish active playback, and an Activity binding prevented upstream stopSelf() from destroying the service, retaining its foreground notification/wake lock. Dart's stop state rejects stale loads/completion callbacks; local audio_service 0.18.19 ends foreground mode and releases the wake lock in stop(). After stopping: zero notifications, inactive session, startRequested=false; selecting a song restores playback. This remains one incident.
- Icons (2026-10-15, same Issue): check density configurations when overriding library icons. The new APK uses same-name `drawable-anydpi` vectors, retaining `audio_service_*` names that old packages can resolve. `aapt2 dump resources` and actual API 34 notifications verify packaging and the X stop glyph separately; see the [follow-up record](docs/en/issue-520.md). Contract checks cover default standard controls and both app/library resources instead of skipping the entire `audio_service_*` prefix.
- Not run: HarmonyOS 4.2 hardware notification layout; API 34 does not replace that acceptance.
- Seen 1× (2026-10-14). Status: lesson; the fix commit is determined by Git, and emulator results do not imply hardware acceptance.

### WIN-001: Auxiliary window coordinate tests do not verify WebView2 desktop input

- Scope: Windows plugin WebView2, cross-monitor movement, and mouse input in abandoned screen regions.
- Rule: Check the fix commit, release version, and actual input separately. Simulated Win32 coordinate tests and Windows compilation cannot prove desktop context menus work in the old region. Cover fullscreen plugins, movement between monitors in both directions, different DPI settings, minimization, and tray restoration; record real window and input evidence.
- Failure: The position synchronization patch [f1ef7f2](https://github.com/songloft-org/songloft-player/commit/f1ef7f2d8aabf4ba9e9da12cac029f52e211e189) for songloft-org/songloft#499 landed on 2026-10-06 with simulated window and compilation checks, explicitly without a dual-monitor smoke test. On 2026-10-14, the reporter [said client 2.13.1 still blocked right-clicks](https://github.com/songloft-org/songloft/issues/499#issuecomment-6160069251). Both the standard v2.13.1 tag and the parent release's client gitlink resolve to f684da386c75bb8825713b1b14fdd2a3c24d7adb, which includes the patch; a missing release inclusion does not explain this report.
- Investigation: At baseline 1cb9b4947cdc1c641507e9486b0a0024fc274e97, all seven existing simulated scenarios passed on Linux/GCC 12.2. The tests contain no WebView2 controller or real mouse hit testing. Neither the baseline runner nor the locked flutter_inappwebview_windows 0.6.0 calls `NotifyParentWindowPositionChanged`. This is a confirmed integration gap, but not a proven cause of recurrence.
- Candidate fix: This candidate patch vendors the Windows platform package into `third_party/flutter_inappwebview_windows` and notifies the controller after default processing of the auxiliary HWND's `WM_WINDOWPOSCHANGED`. Exit and window destruction both detach the observer, with protection against reentrancy and HWND reuse. Windows packaging CI adds real HWND/comctl32 checks; ZIP packages include a read-only `webview_hit_test.exe` to identify the actual hit window if the bug persists. See the [patch notes](third_party/flutter_inappwebview_windows/README.en.md) and [platform acceptance steps](docs/en/platform-notes.md#windows-plugin-and-desktop-context-menu-acceptance).
- Done right: Linux/GCC 12.2 `cmake` and `ctest` passed (seven existing coordinate scenarios plus eight observer scenarios, in `/tmp/songloft-499-native-20261014-02`). Removing the notification or explicit detachment in isolated copies compiled successfully and made the target test fail; logs are `/tmp/songloft-499-no-notify-final-20261014/validation.log` and `/tmp/songloft-499-no-detach-final-20261014/validation.log`. These are mutation checks, not Windows reproduction using the old package. On Flutter 3.41.5, 13 plugin-related tests, `flutter analyze`, formatting, and diff checks passed. Not run: complete Windows compilation, real HWND checks, diagnostic tool execution, and dual-monitor/WebView2 input acceptance. The host runs Linux and the user has no Windows environment; CI builds and reporter testing remain pending.
- Seen 1× (2026-10-14). Status: lesson; #499 still lacks device acceptance.

### LYRIC-001: Calculate Lyric Foreground Contrast Against the Actual Background

- Scope: Flutter mobile and desktop full-screen lyrics, songloft-org/songloft#523.
- Evidence: On 2026-10-15, baseline `b80e03b47eefb1aaedf07d611b1d9d3c3d48257b` combined dark cover colors and a black top overlay while lyrics directly used theme primary, further reducing translation/romaji opacity. An isolated copy using baseline `lyrics_view.dart` against the new soft background measured 5.17:1 for the light-mode active line and 5.82:1 for the dark-mode translation, below this change's 7:1 target. Both rendering regressions failed as expected; log `/tmp/songloft-523/before-lyrics.log`.
- Rule: Design background tints and foreground together. Composite translucent text against its actual background before measuring contrast. Material contrast guarantees on its default surface do not automatically apply to cover overlays. Check consistent missing/failed-cover fallbacks and ensure increased contrast covers dynamic layers.
- Done right: Shared `PlayerBackdrop` blends tints into the current surface and strengthens the accent against that background. Active lines, translations, romaji, and karaoke share full contrast. Light/dark gradient samples across six built-in palettes and extreme covers passed, alongside all 716 tests, static analysis, and embedded builds. Actual browser song switching and missing/failed-cover comparisons are in the [#523 record](docs/en/issue-523.md). Not run: native outdoor device acceptance.
- Seen 1× (2026-10-15). Status: experience; uncommitted worktree identity is in the task record. Check Git/CI separately for release inclusion.

### BUNDLE-FFMPEG-001: Bundle builds reuse one resolved FFmpeg Release

- Scope: Flutter Bundle Android, desktop, and iOS builds.
- Rule: resolve `ffmpeg-resolution.json` first, then verify the asset digest for each platform and ABI. Android installs tools through the APK native library directory, desktop launchers pass packaged tool paths, and iOS links the static library at build time. Jobs must not read a rolling `latest` file.
- Seen 1× (2026-11-20). [Backend Bundle CI](https://github.com/songloft-org/songloft/actions/runs/44754365874) reused one resolution record to produce Flutter test packages for five platforms. Device installation and playback are checked separately.
