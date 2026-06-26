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

1. Load persisted server list
2. Single server: use directly; multiple servers: probe reachability in parallel (max 2.5s)
3. Write the highest-priority successful result to `baseUrlProvider`; fall back to the first item if all fail
4. Set `probeOutcomeProvider` for the home screen SnackBar
5. In embedded mode, skip probing and use `Uri.base` directly

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

| Platform | Backend | Notes |
|----------|---------|-------|
| Web | HTML5 Audio | Native browser |
| Android | ExoPlayer | just_audio default |
| iOS | AVPlayer | just_audio default |
| macOS | AVPlayer | just_audio default |
| Windows / Linux | libmpv (media_kit) | `just_audio_media_kit`, LGPL-2.1+ |
