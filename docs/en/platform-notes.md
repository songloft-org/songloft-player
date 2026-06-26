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
- Bundled as an **audio-only LGPL build** (without GPL encoders such as libx264/libx265)
- Depends on `media_kit_libs_windows_audio`

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
