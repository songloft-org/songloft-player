# Flutter Client Development Lessons

## Scope and Sources

Record Flutter, providers, audio, Bundle mode, and native hosts in songloft-org/songloft-player. See the [local AI workflow](docs/en/ai-development.md) and parent host constraints. Existing AGENTS/business references remain authoritative; link evidence rather than duplicating incident histories.

## Recording and Promotion

Include rule, scope, full owner/repo#number, failure/fix commit SHAs, actual validation, and Done right examples (pending if unavailable). Seen counts independent events on distinct dates, not repeated reviews. Three dates make promotion candidates; mark the authoritative destination. Existing hard rules/serious failures apply immediately. Synchronize the [Chinese version](LESSONS.md), never invent counts/resolution/device acceptance, and redact sensitive information.

## Entries

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
