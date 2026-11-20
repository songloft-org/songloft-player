# AGENTS.md

This file provides **entry-point information** for AI coding assistants working on the Songloft Flutter frontend. Code is the source of truth; this file contains navigation and conventions.

See [AGENTS.md](AGENTS.md) for Chinese; keep content and structure synchronized.

> **Detailed documentation**:
> - AI development: [Workflow and retrospectives](docs/en/ai-development.md) · [Lessons](LESSONS.en.md)
> - Development: [docs/en/development.md](docs/en/development.md)
> - Architecture: [docs/en/architecture.md](docs/en/architecture.md)
> - Domain architecture: [docs/en/domain_layer.md](docs/en/domain_layer.md)
> - Platforms: [docs/en/platform-notes.md](docs/en/platform-notes.md)
> - Builds: [docs/en/build_guide.md](docs/en/build_guide.md)
> - Releases: [scripts/README.md](scripts/README.md)
> - Architecture overview: parent `docs/en/architecture_frontend.md`
> - Colors: parent `docs/en/color_system.md`

---

## Project Overview

Songloft is a cross-platform music player built with Flutter 3.41+ / Dart 3.7+, supporting iOS, Android, macOS, Windows, Linux, and Web.

The independent [songloft-org/songloft-player](https://github.com/songloft-org/songloft-player) repository is a [Songloft](https://github.com/songloft-org/songloft) submodule. Default backend API: `http://localhost:58091` (admin/admin).

---

## Directory Overview

```text
lib/
├── main.dart              # Entry point; defines audioHandlerProvider
├── config/                # app_config (deployment/baseUrl), constants (pagination/modes/song types)
├── core/                  # Infrastructure
│   ├── audio/             # SongloftAudioHandler, system_volume_provider
│   ├── env/               # tv_detector
│   ├── network/           # api_client, auth_interceptor (dual JWT), base_url_provider, servers_provider
│   ├── platform/          # live_activity_service (iOS)
│   ├── router/            # app_router (GoRouter and auth guards)
│   ├── storage/           # secure_storage, app_preferences, playback_state, lyric_cache
│   ├── theme/             # app_theme (Material 3), responsive, tv_theme, app_dimensions
│   ├── tracely/           # Optional tracely_client
│   └── utils/             # formatters, platform_utils, url_helper, window_tray_manager, color_extraction
├── features/              # data/domain/presentation per feature
│   ├── auth/              # Login/logout/tokens
│   ├── home/              # Home and plugin tabs/WebView
│   ├── jsplugin/          # Install/update/registry
│   ├── library/           # Pagination/search/edit/favorites; FavoriteService in domain/use_cases
│   ├── player/            # PlayQueue, PlayModeResolver, RetryPolicy, QueueLoader in domain/use_cases
│   ├── playlist/          # PlaylistSort with pinyin comparator in domain/use_cases
│   ├── settings/          # Scan/cache/upgrades/tabs/duplicates/servers/HLS and HTTP proxies
│   └── startup/           # Startup loading gate
└── shared/
    ├── layouts/           # adaptive_scaffold, shell_layout, active_destinations
    ├── models/            # Song, Playlist, Pagination, ApiResponse
    ├── utils/             # responsive_snackbar
    └── widgets/           # cover_image, confirm_dialog, song_picker, tv_focusable
```

---

## Common Commands

```bash
flutter pub get
flutter run -d chrome --no-web-resources-cdn              # Standalone Web
flutter run -d chrome --dart-define=DEPLOY_MODE=embedded   # Embedded Web
flutter run -d macos
flutter run -d linux
flutter analyze
flutter test

./scripts/build-frontend.sh <platform|all>
./scripts/release-frontend.sh <patch|minor|major>
```

---

## Formatting (Required)

Format after every code change and ensure no formatting differences before committing:

```bash
dart format lib/ test/
```

---

## Coding Conventions

- **State**: handwritten flutter_riverpod providers, **no** code generation/build_runner. Use `Provider`, `NotifierProvider`, and `FutureProvider` (including `AsyncNotifierProvider`).
- **Routing**: declarative go_router; `AppRoutes` constants and `redirect` auth guards.
- **HTTP**: Dio in `core/network/api_client.dart`; `AuthInterceptor` refreshes dual JWT tokens.
- **Theme**: Material 3, seed `indigo-500`; no hardcoded colors, use `Theme.of(context).colorScheme`.
- **Responsive**: Mobile < 600px, Tablet 600–900px, Desktop 900–1920px, TV >= 1920px.
- **Conditional imports**: stub/native pairs for Web-incompatible functionality, such as `plugin_webview_page.dart` / `_native.dart` / `_stub.dart`.
- **Imports**: relative paths (`../../`).
- **Lints**: `prefer_const_constructors`, `prefer_single_quotes`, `avoid_print`, `prefer_const_declarations` in `analysis_options.yaml`.
- **Features**: `features/<name>/data/` (API/Repository), `domain/` (state/business logic), `presentation/` (pages/providers/widgets).

---

## Core Providers

| Provider | File | Responsibility |
|---|---|---|
| `authStateProvider` | `features/auth/.../auth_provider.dart` | Login/logout/tokens |
| `appPreferencesProvider` | Same as above | Local preferences |
| `playerStateProvider` | `features/player/.../player_provider.dart` | Track, queue, mode, progress |
| `audioHandlerProvider` | `main.dart` | SongloftAudioHandler singleton |
| `lyricStateProvider` | `features/player/.../lyric_provider.dart` | Parsing/current line |
| `songsListProvider` | `features/library/.../songs_provider.dart` | Paginated library |
| `songDetailProvider` | Same as above | Song details |
| `libraryStatsProvider` | Same as above | Home statistics, `GET /songs/stats` |
| `favoriteProvider` | `features/library/.../favorite_provider.dart` | Favorites |
| `playlistListProvider` | `features/playlist/.../playlist_provider.dart` | Playlist list |
| `playlistNotifierProvider` | Same as above | Playlist CRUD |
| `dioProvider` | `core/network/api_client.dart` | Dio client |
| `baseUrlProvider` | `core/network/base_url_provider.dart` | Dynamic baseUrl |
| `serversProvider` | `core/network/servers_provider.dart` | Server management |
| `routerProvider` | `core/router/app_router.dart` | GoRouter |
| `themeModeProvider` | `features/settings/.../settings_provider.dart` | Light/dark/system |
| `tabConfigProvider` | Same as above | Bottom/side navigation |
| `activeDestinationsProvider` | `shared/layouts/active_destinations.dart` | Enabled destinations |

---

## API Classes

Each feature's `data/` owns backend HTTP calls:

| API | File | Backend area |
|---|---|---|
| `AuthApi` | `features/auth/data/auth_api.dart` | Authentication |
| `SongsApi` | `features/library/data/songs_api.dart` | Songs |
| `PlaylistApi` | `features/playlist/data/playlist_api.dart` | Playlists |
| `ScanApi` | `features/settings/data/scan_api.dart` | Scanning |
| `ConfigApi` | `features/settings/data/config_api.dart` | Admin KV configuration |
| `SettingsApi` | `features/settings/data/settings_api.dart` | Business settings |
| `CacheApi` | `features/settings/data/cache_api.dart` | Cache |
| `UpgradeApi` | `features/settings/data/upgrade_api.dart` | Upgrades |
| `JSPluginApi` | `features/jsplugin/data/jsplugin_api.dart` | JS plugins |
| `DirectoryApi` | `features/settings/data/directory_api.dart` | Directory browsing |
| `FrontendVersionApi` | `features/settings/data/frontend_version_api.dart` | Frontend updates |

---

## Routes

Paths are defined by `AppRoutes` in `core/router/app_router.dart`:

| Path | Page |
|---|---|
| `/login` | Login |
| `/` | Home |
| `/library` | Library |
| `/playlists` | Playlists |
| `/playlists/:id` | Playlist details |
| `/settings` | Settings |
| `/settings/servers` | Servers |
| `/settings/tab-config` | Navigation tabs |
| `/settings/duplicate-check` | Duplicates |
| `/settings/plugin-registry` | Plugin registry |
| `/plugin` | Plugin home |
| `/plugin-tab/:entryPath` | Plugin tab |

---

## Deployment Modes

| Mode | Build flag | Behavior |
|---|---|---|
| standalone | Default, no `--dart-define` | Separate frontend/backend; API address UI |
| embedded | `--dart-define=DEPLOY_MODE=embedded` | Same-origin backend embedding; API address UI hidden |

`AppConfig.isEmbedded` is compile-time and supports tree shaking; embedded Web derives a deployment subpath from `Uri.base.path`.

### Bundle Local Mode (HAS_BACKEND) and Update Repository

`--dart-define=HAS_BACKEND=true` enables `AppConfig.hasEmbeddedBackend` and a local Go backend. This is **orthogonal** to embedded `DEPLOY_MODE`: Bundle does not set embedded, so `isEmbedded=false` and the client-update settings tile remains visible.

**Standard packages are published in the Flutter client Release, while Bundle packages use the backend Release. Update checks select the repository by edition.**

| Edition | Release repository | Artifact | Builder |
|---|---|---|---|
| Standard | `songloft-org/songloft-player` | `songloft-*.apk`, etc. | Local `build-and-release.yml` |
| Bundle | `songloft-org/songloft` | `songloft-bundled-*` | This repository's `build-and-release.yml`, building the Go backend from the latest root `main` SHA selected once per workflow run |

- `FrontendVersionApi` uses compile-time `AppConfig.frontendUpdateRepo` (`hasEmbeddedBackend ? frontendBundleRepo : frontendRepo`), as does `frontendUpdateReleasesUrl`.
- Bundle update checks use the backend repository's Release. Installation links must still distinguish `songloft-bundled-*` so Bundle users do not replace their app with the standard edition.
- `frontendRepo` / `frontendReleasesUrl` retain their standard-edition meaning only for the Web-only download section in `client_download_page.dart`.

### Hot Updates (libapp.so and Bundle Android libgojni.so)

The authoritative unified Bundle model is [docs/en/backend_hotupdate.md](docs/en/backend_hotupdate.md).

- **No manually selected baseline, automatic publication**: check the latest release in the current channel (`dev` tag or stable `/releases/latest`, `channel_release_resolver.dart`). This repository's Android job builds standard and Bundle editions and publishes `bundle-patch-<abi>-<commit>.zip`, `bundle-flutter-version.json`, `bundle-libgojni-<abi>-<backend-sha>.so`, and `bundle-flutter-backend-manifest-<abi>.json` for Bundle; no manual workflow.
- **One combined experience**: `PatchUpdateDialog.maybeShow` in `lib/core/updater/` checks both patches concurrently per session, lists/downloads them together, and restarts once via a real `EmbeddedBackendService.restartProcess` cold start. This applies libapp.so and lets `SongloftApplication` preload libgojni.so.
- **Startup gates and manual entry**: use session-persistent `ShellLayout`, not HomePage, so TV is included. First wait for authenticated via `ref.listenManual(authStateProvider)`, then schedule a cancellable 4-second `kPatchCheckStartupDelay` Timer. Checking mounted alone can let slow authentication consume the once-per-session opportunity and throttle window before login with an unauthenticated Dio. Dispose cancels the Timer rather than using Future.delayed. Respect `autoUpdateCheckProvider` (preference `auto_update_check_enabled`, default on) and the 6-hour `kPatchCheckThrottle` (`last_patch_check_at`). Bound the whole check to 45 seconds because proxy fallback can double request latency. Require `elapsed >= 0` so clock rollback cannot indefinitely suppress checks. If a patch is found after context disposal, roll back the throttle timestamp and log separately from “no patch”. The manual Settings → About & updates → Check client updates calls `maybeShow(manual: true)`, bypasses delay/throttling and the ignored-version list without clearing it, and does not write the throttle timestamp. Without a patch, fall back to `FrontendUpgradeDialog`'s existing three-state UI without an extra snackbar. Tests: `test/core/updater/patch_update_dialog_gates_test.dart`.
- **Frontend patch compatibility** depends on the actual APK versionCode, the Flutter engine key (`AppConfig.flutterBinding` = CI `FLUTTER_VERSION`), and the native contract. All three ABI patches for an edition come from the same universal APK. The Android build validates the Go export surface in the pinned root SHA’s `mobile/export_surface.txt`.
- **Native contract hashes** prevent patched Dart calling methods missing in the installed APK. `com.songloft/contract` `getHash` returns `{dart,go}` computed by `scripts/compute_native_contract.sh`, embedded in APK assets and manifest `contractHash`. `contractHashBlocks` sends mismatches to full-package updates; either empty hash degrades without blocking. No manual constant bump; standard/Bundle Android use this, iOS does not.
- **Channel comparisons**: dev compares commit hashes, stable compares versions via `version_compare.dart`; native `BackendPatchManager` handles pending→confirmed rollback and blacklisting.
- For standard Android releases, `build-and-release.yml` generates a frontend patch and manifest for each ABI. The universal APK has a minimum Android `versionCode` of 4002 so it can replace older split APKs. The client still supports legacy manifest formats.

### Kotlin Freeze Rules (Android Hot-Update Safety)

Keep the Dart contract hash generated by `compute_native_contract.sh` unchanged during ordinary iteration, avoiding blocked libapp.so updates and forced full APK downloads. This matters especially when the standard edition has no Go backend to extend.

**Hard rules:**

1. **Do not add MethodChannel method names** in Kotlin `when(call.method)`. The hash extracts `call.method == "x"` and `"x" ->`; additions change it.
2. **Extend existing parameter Maps**, such as `show` / `updateConfig`. Read with `call.argument<T>("newKey")`, default when absent. This preserves method names and the hash.
3. **Extend the existing `exec` escape method** in `FloatingLyricPlugin` using `cmd` for new capabilities that parameters cannot express. Dispatch with **if/else, never when**, whose `"x" ->` is captured by the hash. A null Dart response means the current APK does not support the command and should degrade gracefully.
4. **Prefer pure-Dart Flutter plugins**: adding/removing native plugins changes `GeneratedPluginRegistrant` and the hash.
5. **Required Kotlin changes count as full-package release events**. Mark the commit explicitly: `feat(android)!: add new native channel (breaks hot-update contract hash)`.

**Does not change the hash:**

- Kotlin→Dart `channel.invokeMethod` callbacks are not captured and may be extended.
- Adding `updateConfig` / `show` parameter Map keys.
- SharedPreferences keys used by widget data.
- New `exec` subcommands implemented with if/else.

---

## Git Conventions

- Investigate, implement, validate, and self-review continuously without stage approvals; ask only for essential missing information, product decisions, or scope expansion. Commits, pushes, formal releases, and Issue writes need distinct authorization; never repeat existing requests. Commit to main, children before parent pointers.
- Read relevant LESSONS before work and record evidence-backed experience afterward in Chinese/English. Three independent events on distinct dates make promotion candidates; repeated reviews do not increase counts. Existing hard rules apply immediately.
- Unresolved Issue triage includes parent and all submodules with recursive discovery, deduplication, and full pagination. Assess bodies/all comments/current code/validation; report gaps. Open does not prove unfixed.
- Bind validation to repository, SHA or uncommitted fingerprint, environment, and observed results; list relevant `Not run`. Changes require affected checks again. Web/simulations do not replace device acceptance of native audio, backgrounding, Bundle, or hot updates. See the [local AI workflow](docs/en/ai-development.md).

- **No** `Co-Authored-By` trailer.
- Conventional Commits: `type(scope): description`.
- Parent Issue references **must** use `songloft-org/songloft#NNN`; bare `#NNN` resolves to this repository.

---

## Tests

```bash
flutter test
```

Test files mirror `lib/` paths under `test/`. Listed test files:

- `test/core/env/tv_detector_test.dart`
- `test/features/player/domain/lyric_parser_test.dart`
- `test/features/home/presentation/tv_home_page_test.dart`
- `test/shared/widgets/tv_focusable_test.dart`
- `test/widget_test.dart`
