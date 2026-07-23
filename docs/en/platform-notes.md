# Platform-Specific Notes

Special handling and known issues for each platform in cross-platform development.

---

## Android

### Build Preparation

```bash
sdkmanager --licenses   # Accept licenses before the first build
```

Requires Android SDK, NDK, and JDK 17+.

### Runtime Notes

- **Android 13+ (API 33)**: The `POST_NOTIFICATIONS` runtime permission must be requested, otherwise playback control notifications will not appear
- **HyperOS 3 (Xiaomi)**: Set `androidStopForegroundOnPause: false`; without this, the foreground service is reclaimed on pause, interrupting background playback
- **Split-ABI APK builds**: `flutter build apk --split-per-abi` generates separate APKs for arm64-v8a, armeabi-v7a, and x86_64

### Troubleshooting

```bash
# Corrupted Gradle cache
flutter clean && rm -rf android/.gradle
flutter pub get
```

---

## iOS

### Building and Distribution

- Build an unsigned IPA with `flutter build ios --no-codesign`
- Sideload via AltStore / Sideloadly (no developer account required)
- Can only be built on macOS

### CocoaPods Issues

```bash
cd ios
pod deintegrate
pod install
cd ..
flutter clean && flutter pub get
```

---

## macOS

### Window Management

Uses `window_manager` + `tray_manager` to provide:
- Window size and position memory
- System tray icon + menu
- Single-instance enforcement

### Code Signing and Storage

When the app is unsigned, Keychain is unavailable (FlutterSecureStorage depends on it). Token storage has been switched to SharedPreferences uniformly, which is unaffected by signing status.

---

## Windows

### Audio Backend

Windows uses libmpv as the audio backend via `just_audio_media_kit`:
- Bundled as an **LGPL build** (without GPL encoders such as libx264/libx265)
- Depends on `media_kit_libs_windows_video` (includes video output, replacing the old audio variant, for in-app video songloft-org/songloft#76)

### Build Requirements

- Visual Studio 2022 (with C++ Desktop Development workload)
- Windows 10 SDK

### MSIX Packaging

```bash
flutter pub run msix:create
```

### Token Storage

SharedPreferences reads on Windows can occasionally be unstable. `AuthInterceptor` prefers the in-memory `cachedAccessToken` and only reads from storage when the cache is empty.

---

## Linux

### System Dependencies

```bash
# Ubuntu/Debian
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev
```

### Audio Backend

Linux also uses libmpv via `just_audio_media_kit`, but with **dynamic linking to the system libmpv** (not statically bundled). Users must have mpv/libmpv installed on their system.

### Distribution Formats

The build script supports tar.gz, deb, rpm, and AppImage formats.

---

## Web

### Build Flags

- **`--no-web-resources-cdn` is required** — without it, Flutter loads fonts/canvaskit from Google CDN, which is slow or unreachable in China
- Standalone mode: `flutter build web --no-web-resources-cdn`
- Embedded mode: `flutter build web --no-web-resources-cdn --dart-define=DEPLOY_MODE=embedded`
- **CanvasKit variant**: `web/index.html` uses `canvasKitVariant: "auto"`, letting the engine pick per browser — Chromium loads the smaller `chromium` variant, Firefox/Safari load `full`. Both render via **WebGL**; this is unrelated to CPU/GPU render mode (`canvasKitForceCpuOnly` is a separate thing, long removed). So the embedded self-hosted build **must keep** the `canvaskit/chromium` subdirectory (`scripts/build-frontend.sh` only prunes skwasm/wimp/`.symbols`, not chromium), otherwise Chrome 404s and white-screens offline

### Deployment Mode Differences

| | standalone | embedded |
|---|-----------|----------|
| API URL | User manually configures on the login page | Automatically uses `Uri.base` (same domain) |
| API URL UI | Visible | Hidden (tree-shaken away at compile time) |
| Sub-path deployment | Requires manual configuration | Auto-detected via `Uri.base.path` |

### Conditional Imports

Web does not support `dart:io`. Code involving native features (WebView, file system) uses the stub file pattern:

```
plugin_webview_page.dart       → export entry
plugin_webview_page_stub.dart  → Web platform (placeholder UI)
plugin_webview_page_native.dart → Native platforms (real implementation)
```

Stub file pairs in the project:
- `plugin_webview_page` — JS plugin WebView
- `plugin_tab_page` — Plugin tab page
- `web_cache_clearer` — Web cache clearing

### Storage Fallback

- `PlaybackStateStorage`: Web falls back to SharedPreferences (localStorage); native platforms use files
- `LyricCacheService`: Web falls back to in-memory cache; native platforms use the file system

### Cover / network images must decode downsampled (CanvasKit large-texture pitfall)

> **Hard rule: on web, every network cover image must go through `CoverImage` or `NetworkCoverImage`. Never use a bare `CachedNetworkImage` / `Image.network` directly.**

- **Symptom**: list/grid covers intermittently turn **solid black** after switching tabs, changing filters, or navigating back and forth; continuing to interact then turns them into the **default placeholder icon**. The persistent player artwork never breaks.
- **Root cause**: CanvasKit's default web render method `ImageRenderMethodForWeb.HtmlImage` uploads covers as **full-resolution** GPU textures (~1.5 MB each in practice), and `memCacheWidth` **has no effect** on that path. Many large cover textures accumulate and exhaust the mobile browser's GPU memory budget → CanvasKit's WebGL context is dropped → already-uploaded textures die (**black**), and fresh decodes hit `MakeLazyImageFromTextureSourceWithInfo` returning null, throwing `ImageCodecException: Failed to create image from Image.decode` (**placeholder icon**). Persistent widgets (player artwork) keep their listener attached forever, so they are pinned in the `imageCache` live set and never evicted — which is exactly why "the player never loses it but the list does".
- **Fix**: force `imageRenderMethodForWeb: ImageRenderMethodForWeb.HttpGet` + `memCacheWidth` (display size × DPR) so covers decode downsampled, shrinking textures from ~1.5 MB to tens/hundreds of KB and drastically lowering GPU memory pressure; HttpGet bytes can also be re-decoded after a context restore, making them more resilient to context loss than `<img>` lazy textures. Encapsulated in:
  - `shared/widgets/cover_image.dart` (`CoverImage`, fixed-size square covers)
  - `shared/widgets/network_cover_image.dart` (`NetworkCoverImage`, fill / custom-layout covers)
- **Easiest mistake**: when adding a new cover render site you **must** use one of the two widgets above; writing a plain `CachedNetworkImage(imageUrl: ...)` for convenience reintroduces the black covers on web. Historically the album/artist/playlist cards used bare `CachedNetworkImage` and skipped the wrapper, so those lists went black on their own (the song list stayed fine because it used `CoverImage`), which cost a long debugging detour.
- **Diagnosis criteria**: `ImageCodecException: Failed to create image from Image.decode` = GPU texture creation failure (context loss / VRAM exhaustion), **not** a network/byte problem; **solid black** = the decoded `ui.Image`'s texture died (uncatchable by `errorWidget` because the failure is in the GPU paint layer); **placeholder icon** = `errorWidget` fired (decode/load genuinely failed).
- **Follow-ups for huge playlists (songloft-org/songloft#309)**: with thousands of songs the texture pressure is worse and two follow-up problems stack up; the current mitigation stack is:
  1. **Crash**: on context loss `CkSurface` accesses an uninitialized late field and crashes (flutter/flutter#184683) → the web build switched to **beta 3.47**, which includes the official fix #185116 (see `.github/workflows/build-and-release.yml`).
  2. **Blank covers on scroll-back**: after the crash is fixed, covers that are **offscreen but still resident in `imageCache`** have their GPU textures die together with the old context; scrolling back synchronously hits the cache and gets a **dead texture** painted blank, and it never re-decodes. Because `imageCache` stores the **decoded `ui.Image` (a GPU texture handle), not encoded bytes**, a "cache hit" becomes the trap. → `core/utils/webgl_context_recovery.dart`'s `installWebGLContextRecovery` (wired for web in `main.dart`) clears `imageCache` on `webglcontextlost`/`restored`, forcing a re-decode on scroll-back (the bytes are still in `cached_network_image`'s local cache, so no network refetch).
  3. **Texture pressure**: `core/utils/web_image_tuning.dart` tightens large-list `cacheExtent` (250→100) on web and decodes small covers (queue/drawer 36–48px) to display size, reducing the count and size of simultaneously resident textures.
- **Dead ends** (all verified ineffective or worse): enlarging `imageCache` (LRU eviction was never triggered), `imageCache.evict` / key-swap rebuild (treats a symptom and worsens re-decode storms), `canvasKitForceCpuOnly` (global software rendering, extremely laggy and doesn't fix it), `canvasKitMaximumSurfaces=1` (Chrome uses a single OffscreenCanvas, no effect).
