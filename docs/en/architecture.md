# Architecture Notes

> For a complete architecture overview, see the parent repository's `docs/architecture_frontend.md` (directory structure, page routing, responsive layout, theme system, and deployment modes). This document focuses on supplementary implementation details.

---

## State Management

### Choosing Provider Types

The project uses flutter_riverpod with hand-written Providers (no code generation):

| Type | When to Use | Examples |
|------|-------------|---------|
| `Provider` | Stateless singletons or computed values | `dioProvider`, `routerProvider`, `isPlayingProvider` |
| `NotifierProvider` | Synchronous stateful business logic | `playerStateProvider`, `authStateProvider`, `baseUrlProvider` |
| `AsyncNotifierProvider` | Async stateful + CRUD | `serversProvider`, `playlistListProvider`, `songsListProvider` |
| `FutureProvider` | One-shot async loading | `songDetailProvider`, `configsProvider`, `appPreferencesProvider` |
| `FutureProvider.family` | Parameterized async loading | `songDetailProvider(id)`, `playlistDetailProvider(id)` |
| `StreamProvider` | Continuous data streams | `systemVolumeProvider` |

### Provider Dependency Chain

```
appPreferencesProvider (SharedPreferences)
    ↓
secureStorageProvider → dioProvider → [feature xxxApiProvider]
    ↓                       ↓
authStateProvider      baseUrlProvider ← serversProvider
    ↓
routerProvider (redirect guard)
```

Core principle: `dioProvider` watches `baseUrlProvider` via `ref.watch`. When baseUrl changes, the Dio instance is automatically rebuilt, and all downstream API providers update accordingly.

### PlayerNotifier Lifecycle

`PlayerNotifier` is the most complex Notifier in the project (~1600 lines). Key internal mechanisms:

- **Play generation `_playGeneration`**: When the user skips tracks rapidly, old `playByIndex()` coroutines detect a generation change after each `await` and exit, preventing race conditions
- **Prefetch `_prefetchCancelToken`**: Fetches the next song's metadata while the current song is playing; a safety prefetch fires at 30s remaining (`_lateStagePrefetchFired`)
- **Shuffle deduplication `_playedIndices`**: In shuffle mode, tracks played indices and resets when all songs have been played
- **Playback state persistence**: `_saveDebounceTimer` debounces queue saves; `_positionSaveTimer` saves playback position every 10s
- **Failure retry**: Retries a single track up to 2 times; stops after 3 consecutive skips

---

## Network Layer

### Multi-Server Management

`ServersNotifier` (`core/network/servers_provider.dart`) manages server list CRUD and persistence.

Startup flow (`StartupGate`):

1. Load persisted `RunMode` (local / remote)
2. **Local mode (Bundle)**: request storage permission → start embedded backend (`EmbeddedBackendService.start()`) → health check polling (up to 10 × 300ms) → set `baseUrlProvider` to `127.0.0.1:<port>` → auto-login with `admin/admin`
3. **Remote mode**: load persisted server list → single server: use directly; multiple servers: probe reachability in parallel (max 2.5s) → write the highest-priority successful result to `baseUrlProvider`; fall back to the first item if all fail
4. Set `probeOutcomeProvider` for the home screen SnackBar
5. In embedded mode, skip probing and use `Uri.base` directly
6. `BackendLifecycle` (WidgetsBindingObserver) monitors app lifecycle — auto-restarts backend on resume, stops on detached

### Dynamic baseUrl Switching

`BaseUrlNotifier` (`core/network/base_url_provider.dart`) is the single source of truth for baseUrl. Writes are mirrored synchronously to `AppConfig.baseUrl` for non-Riverpod contexts (e.g. `UrlHelper` string concatenation).

### Token Refresh Flow

`AuthInterceptor` handles JWT dual-token:

1. Request intercept: non-public paths automatically inject `Authorization: Bearer <accessToken>` (memory cache preferred, falls back to storage)
2. Response intercept: on 401, trigger refreshToken → retry original request on success; call `onTokenExpired` callback on failure to trigger logout
3. Concurrency protection: `_isRefreshing` + `Completer` ensures multiple concurrent 401s trigger only one refresh

Public paths (`/auth/login`, `/auth/refresh`, `/version`, `/health`) skip token injection.

---

## Storage Layer

| Service | File | Backend | Purpose |
|---------|------|---------|---------|
| `SecureStorageService` | `core/storage/secure_storage.dart` | SharedPreferences + memory cache | Token storage (access/refresh/expiry) |
| `AppPreferences` | `core/storage/app_preferences.dart` | SharedPreferences | User preferences (theme, baseUrl, server list, volume, playback mode, last login credentials) |
| `PlaybackStateStorage` | `core/storage/playback_state_storage.dart` | Native: file (`playback_queue.json`); Web: SharedPreferences | Playback queue + progress persistence, restored on app restart |
| `LyricCacheService` | `core/storage/lyric_cache_service.dart` | Native: file (`lyric_cache/` directory); Web: in-memory only | Lyric cache to avoid repeated network requests |

### Token Storage Strategy

SharedPreferences is used exclusively (not FlutterSecureStorage). For self-hosted local music servers, simplified storage is acceptable. `cachedAccessToken` / `cachedRefreshToken` static variables provide synchronous reads, working around unstable storage reads on Windows.

---

## Platform Specialization

### TV Mode Detection

`TvDetector` (`core/env/tv_detector.dart`) detects whether the app is running on a TV system at startup and writes the result to `AppConfig.isTvMode` (`late final`, set only once).

In TV mode:
- Uses `TvThemeConstants` for larger buttons and font sizes
- Routes to `TvHomePage` (top Tab navigation)
- `TvFocusable` focus component supports D-Pad directional navigation

### Live Activity

`LiveActivityService` (`core/platform/live_activity_service.dart`) provides a Lock Screen Live Activity on iOS to display the currently playing song.

### Window and Tray

`WindowTrayManager` (`core/utils/window_tray_manager.dart`) manages window size and position memory, system tray icon, and menu on desktop platforms (macOS/Windows/Linux).

---

## Audio Playback

### SongloftAudioHandler

Integrates `audio_service` for system notification bar controls. Core design:

- Uses the official `pipe()` pattern to connect `playbackEventStream` directly to `playbackState`, which is more reliable than manual `listen + add`
- Notification callbacks (`onSkipToNext` / `onSkipToPrevious` / `onSongCompleted`) are injected by `PlayerNotifier`
- `notifySongActivated` hook: notifies the backend to cancel in-progress work (prefetch/transcode) for the old song before switching, resolving an issue where `LockCachingAudioSource` does not abort upstream HTTP connections

### Audio Backend per Platform

| Platform | Backend (default) | Notes |
|----------|---------|-------|
| Web | HTML5 Audio + hls.js | Custom `SongloftWebJustAudioPlugin` (just_audio_web + self-integrated hls.js for HLS radio) |
| Android | libmpv (media_kit) | `just_audio_media_kit`; pass `--dart-define=SONGLOFT_MEDIAKIT_MOBILE=false` to fall back to ExoPlayer |
| iOS | libmpv (media_kit) | Same; falls back to AVPlayer |
| macOS | libmpv (media_kit) | Pass `--dart-define=SONGLOFT_MEDIAKIT_MACOS=false` to fall back to AVPlayer |
| Windows / Linux | libmpv (media_kit) | `just_audio_media_kit`, LGPL-2.1+ |

> Backend selection is centralized in `AudioBackend.usesMediaKit` (`core/audio/audio_backend.dart`). macOS/mobile default to media_kit to unify the backend and enable in-app video (songloft-org/songloft#76); the compile-time flags act as a kill-switch to fall back to native.

### Video Rendering & the Web Backend Decision (songloft-org/songloft#76)

Video containers (mp4/mov/mkv/webm/avi/ts) are probed by the backend's ffprobe for `is_video`. In-app picture rendering takes two paths:

- **Native platforms** (Win/Linux/macOS/Android/iOS): derive a `VideoController` from the **same** media_kit `Player` used for audio (`core/audio/video_controller_provider.dart`) — picture and audio share one engine, naturally in sync, no second player. The `VideoStage` widget renders the picture for video songs, otherwise falls back to the cover.
- **Web**: a **muted native `<video>`** (`features/player/.../web_video_view_web.dart`) shows only the picture; audio still plays through `SongloftWebJustAudioPlugin`, and the two are synced by play/pause/position from `playerStateProvider`.

**Why not migrate Web to media_kit for a unified backend?** (investigated — don't relitigate)

- media_kit **does not use libmpv on Web**; its web backend is just the browser `<video>` element, and HLS is enabled by **dynamically injecting hls.js** (media_kit source `media_kit/lib/src/player/web/utils/hls.dart`). So switching to media_kit **cannot drop hls.js** — it just replaces "we integrate hls.js" with "media_kit integrates it for you"; HLS capability doesn't improve (official docs call web format support "extremely limited").
- The bridge package `just_audio_media_kit` targets **Windows/Linux** and has **no web implementation**. Using media_kit on Web would require abandoning just_audio for the media_kit `Player` API across the whole web layer (touching the entire `audio_service`/`player_provider` state machine) — a cost far exceeding the benefit of "maintaining one less hls.js hookup".
- Conclusion: **Web keeps just_audio_web + custom hls.js (radio) + muted `<video>` (picture)**. Revisit a full-layer migration only if unified Web video maintenance becomes a hard requirement.
