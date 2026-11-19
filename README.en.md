# Songloft Player

[中文](README.md) | English

[![Build and Release](https://github.com/songloft-org/songloft-player/actions/workflows/build-and-release.yml/badge.svg)](https://github.com/songloft-org/songloft-player/actions/workflows/build-and-release.yml)
[![GitHub License](https://img.shields.io/github/license/songloft-org/songloft-player)](https://github.com/songloft-org/songloft-player)
[![GitHub Release](https://img.shields.io/github/v/release/songloft-org/songloft-player)](https://github.com/songloft-org/songloft-player/releases)
[![Stars](https://img.shields.io/github/stars/songloft-org/songloft-player)](https://github.com/songloft-org/songloft-player/stargazers)

<p align="center">
  <strong>🎵 Songloft Player — A cross-platform music player built with Flutter</strong>
</p>

Songloft Player is a cross-platform music player built with Flutter, supporting iOS, Android, macOS, Windows, Linux, and Web. Supports **Bundle local mode**: embeds the Go backend directly into the client, no server deployment required.

Settings → Playback → Keep screen on for lyrics keeps the display awake while viewing lyrics. It is off by default and saved only on this device. Returning to the cover on mobile, leaving the player, or backgrounding the app restores automatic screen sleep. Wide players apply it while lyrics are visible, including when playback is paused. Web support depends on browser capabilities and permission; unavailable or denied requests do not interrupt playback.

<p align="center">
  <a href="https://github.com/songloft-org/songloft-player">🏠 GitHub</a> •
  <a href="https://github.com/songloft-org/songloft-player/releases">📥 Download</a> •
  <a href="https://github.com/songloft-org/songloft-player/issues">💬 Issues</a>
</p>

## Screenshots

https://github.com/songloft-org/songloft/issues/6

## Download

Download the latest version from [GitHub Releases](https://github.com/songloft-org/songloft-player/releases/latest):

Release bodies contain version changes and installation links to this section. Version history is maintained in the Chinese-only [CHANGELOG.md](CHANGELOG.md), updated automatically after a versioned release succeeds. See the table below for installation instructions.

This repository publishes both the standard Flutter client and Bundle local-mode clients. The standard edition connects to a separate [Songloft server](https://github.com/songloft-org/songloft); Bundle starts the embedded Go backend locally and can switch between local and remote modes from the login or settings screen. The Bundle workflow selects the latest commit on the root repository’s `main` at startup and builds every platform in the run from that SHA.

Choose a file for your device under **Assets** on the release page. Some packaging formats may be unavailable; check the attached files.

| Platform | Download | Notes |
|----------|----------|-------|
| 🌐 **Web (standalone)** | [songloft-web-standalone.tar.gz](https://github.com/songloft-org/songloft-player/releases/latest/download/songloft-web-standalone.tar.gz) | Extract to a static server and configure the backend API address; cross-origin hosting requires the backend to allow access from the site |
| 🌐 **Web (embedded)** | [songloft-web-embedded.tar.gz](https://github.com/songloft-org/songloft-player/releases/latest/download/songloft-web-embedded.tar.gz) | For same-origin static hosting or a backend embedding build; hides the API address field. Extracting does not automatically replace a running server's frontend |
| 🐧 **Linux** | [songloft-linux-x64.tar.gz](https://github.com/songloft-org/songloft-player/releases/latest/download/songloft-linux-x64.tar.gz) | Extract and launch the app, keeping the complete directory |
| | [songloft-linux-x64.deb](https://github.com/songloft-org/songloft-player/releases/latest/download/songloft-linux-x64.deb) | Debian/Ubuntu x64; install using your package manager |
| | [songloft-linux-x64.rpm](https://github.com/songloft-org/songloft-player/releases/latest/download/songloft-linux-x64.rpm) | Fedora/RHEL/CentOS x64; install using your package manager |
| | [songloft-linux-x64.AppImage](https://github.com/songloft-org/songloft-player/releases/latest/download/songloft-linux-x64.AppImage) | Make the AppImage executable and run it |
| 🪟 **Windows** | [songloft-windows-x64.zip](https://github.com/songloft-org/songloft-player/releases/latest/download/songloft-windows-x64.zip) | x64 portable; extract and launch the app, keeping all files together |
| | [songloft-windows-x64.msix](https://github.com/songloft-org/songloft-player/releases/latest/download/songloft-windows-x64.msix) | x64 installer; install through the system installer |
| 🍎 **macOS** | [songloft-macos.dmg](https://github.com/songloft-org/songloft-player/releases/latest/download/songloft-macos.dmg) | Universal (Intel/Apple Silicon); open the DMG and drag the app into Applications |
| | [songloft-macos.zip](https://github.com/songloft-org/songloft-player/releases/latest/download/songloft-macos.zip) | Universal (Intel/Apple Silicon); extract the ZIP and move the app into Applications |
| 🤖 **Android** | [Stable release assets](https://github.com/songloft-org/songloft-player/releases/latest) · [Dev APK](https://github.com/songloft-org/songloft-player/releases/download/dev/songloft-android.apk) | The universal package `songloft-android.apk` supports ARM64, ARMv7, and x86_64. Open the APK and allow installation when prompted |
| 📱 **iOS** | [songloft-ios-nosign.ipa](https://github.com/songloft-org/songloft-player/releases/latest/download/songloft-ios-nosign.ipa) | Unsigned device build; re-sign with your developer certificate and a provisioning profile for your device before installing |

> Development builds are available at the [dev branch Release](https://github.com/songloft-org/songloft-player/releases/tag/dev).
> For a client with the embedded backend, look for the filenames listed under [Bundle local mode](#bundle-local-mode).

`patch-*.zip`, `manifest-*.json`, and `version.json` are used by the client's update checker and do not need manual installation.

## Features

- **Cross-platform**: iOS, Android (phone/tablet), macOS, Windows, Linux, Web
- **Car/IVI version**: For in-vehicle infotainment systems, use [songloft-tv](https://github.com/boluofan/songloft-tv)
- **Bundle local mode**: Embedded Go backend, no server needed, supports local/remote mode switching
- **Responsive layout**: 3-level breakpoints (Mobile < 600px, Tablet 600-900px, Desktop 900px+), ultra-wide screens (aspect ratio > 2.2:1) auto-switch to Dock navigation
- **Adaptive navigation**: Bottom bar on mobile, sidebar on tablet, side menu on desktop
- **Music playback**: Powered by just_audio, supports local and network songs, background playback
- **Playlist management**: Create, edit, delete playlists, add/remove songs
- **Song library**: Paginated loading, search/filter, song editing
- **Theme**: Light / Dark / System
- **JWT authentication**: Dual-token mechanism with secure storage (auto-fallback)

## Requirements

- Flutter >= 3.41.0
- Dart SDK >= 3.7.0

## Quick Start

```bash
# Install dependencies
flutter pub get

# Run (auto-selects connected device)
flutter run

# Run on specific platform
flutter run -d chrome --no-web-resources-cdn  # Web (standalone mode)
flutter run -d macos                          # macOS
flutter run -d "iPhone 16 Pro"                # iOS simulator
flutter run -d <device-id>                    # Android device
```

## Build

```bash
# Build for each platform
flutter build web --no-web-resources-cdn                                       # Web (standalone)
flutter build web --no-web-resources-cdn --dart-define=DEPLOY_MODE=embedded    # Web (embedded)
flutter build apk --release                                                    # Android APK
flutter build ios --no-codesign                                                # iOS
flutter build macos                                                            # macOS
flutter build linux                                                            # Linux
flutter build windows                                                          # Windows

# Using build script (supports parallel multi-platform builds)
./scripts/build-frontend.sh web           # Build single platform
./scripts/build-frontend.sh all           # Build all platforms
```

See [Build Guide](docs/en/build_guide.md) for details.

## CI/CD

This repository uses GitHub Actions for automated builds and releases:

- **Push `v*` tag** → Automatically build all platforms and create a Release
- **Manual trigger** → Build and publish to the branch-named Release (e.g. `main`)

Workflow file: [`.github/workflows/build-and-release.yml`](.github/workflows/build-and-release.yml)

## Project Structure

```
lib/
├── config/          # App config (API URL, constants)
├── core/            # Core layer
│   ├── a11y/        # Accessibility
│   ├── audio/       # Audio playback service
│   ├── backend/     # Bundle local mode (embedded backend abstraction)
│   ├── env/         # Environment info
│   ├── network/     # HTTP client, auth interceptor
│   ├── platform/    # Platform detection
│   ├── router/      # GoRouter configuration
│   ├── storage/     # Local storage, secure storage
│   ├── theme/       # Theme, responsive breakpoints
│   ├── tracely/     # Frontend monitoring
│   └── utils/       # Utility functions
├── features/        # Feature modules
│   ├── auth/        # Authentication (login/logout/token management/local mode entry)
│   ├── dlna/        # DLNA casting
│   ├── home/        # Home page
│   ├── jsplugin/    # JS plugin management
│   ├── startup/     # Startup flow (local/remote mode auto-bootstrap)
│   ├── library/     # Song library
│   ├── player/      # Player (desktop/mobile/mini)
│   ├── playlist/    # Playlist management
│   └── settings/    # Settings (theme/scan/plugins/upgrade)
├── shared/          # Shared layer
│   ├── constants/   # Constants
│   ├── layouts/     # Adaptive layouts (AdaptiveScaffold, ShellLayout)
│   ├── mixins/      # Common mixins
│   ├── models/      # Data models (Song, ApiResponse, Pagination)
│   ├── utils/       # Shared utilities
│   └── widgets/     # Common widgets
├── main.dart        # App entry point
scripts/
├── build-frontend.sh         # Multi-platform build script
├── bump-version.sh           # Release script (semantic versioning)
├── docker-build-frontend.sh  # Docker build helper
└── download-fonts.sh         # Font download script
```

## Documentation

| Document | Description |
|----------|-------------|
| [docs/en/build_guide.md](docs/en/build_guide.md) | Multi-platform build guide |
| [docs/en/development.md](docs/en/development.md) | Development guide |
| [docs/en/architecture.md](docs/en/architecture.md) | Architecture notes |
| [docs/en/platform-notes.md](docs/en/platform-notes.md) | Platform-specific notes |
| [scripts/README.en.md](scripts/README.en.md) | Build and release script guide |

## Tech Stack

| Category | Technology |
|----------|------------|
| State Management | Riverpod |
| Routing | GoRouter |
| HTTP | Dio + JWT interceptor |
| Audio | just_audio + audio_service |
| Local Storage | SharedPreferences |
| Image Cache | CachedNetworkImage |

## Deploy Modes

| Mode | Build Flag | Description |
|------|-----------|-------------|
| **standalone** | Default (no `--dart-define`) | Separated frontend/backend, shows API URL config UI for user to fill in |
| **embedded** | `--dart-define=DEPLOY_MODE=embedded` | Embedded with Go backend on same domain, auto uses current domain, hides API URL UI |
| **bundle** | `--dart-define=HAS_BACKEND=true` | Go backend embedded in client, no server needed, supports local/remote mode switching |

Default build (without `--dart-define`) is equivalent to standalone mode.

### Bundle Local Mode

The Bundle version embeds the Go backend into the client, so users don't need a separate server:

- **Mobile (Android/iOS)**: Go backend compiled as native library (`.aar` / `.xcframework`) via gomobile, accessed through MethodChannel
- **Desktop (macOS/Windows/Linux)**: Go backend compiled as `songloft-server` executable, launched as a subprocess
- **Web**: Not supported for bundle mode

Bundle packages for Android, iOS, Linux, Windows, and macOS are published alongside the standard client by this repository's `.github/workflows/build-and-release.yml`. The workflow records the selected backend SHA and version.

For a local Android build, prepare a backend checkout with `pkg/tag` initialized. The script uses that checkout’s HEAD.

```bash
SONGLOFT_BACKEND_SOURCE=/absolute/songloft bash scripts/build-bundle-backend.sh android
flutter build apk --dart-define=HAS_BACKEND=true
```

Android and desktop users choose a music directory the first time local mode is enabled; iOS uses the app's Documents directory. The app does not show a separate mode-selection dialog on first launch. Bundle assets are attached to [this repository's Releases](https://github.com/songloft-org/songloft-player/releases/latest) and start with `songloft-bundled-`:

| Platform | Bundle download |
|---|---|
| Android ARM64 / ARMv7 / x86_64 | Universal package `songloft-bundled-android.apk`. [Stable release assets](https://github.com/songloft-org/songloft-player/releases/latest) · [Dev APK](https://github.com/songloft-org/songloft-player/releases/download/dev/songloft-bundled-android.apk) |
| iOS | `songloft-bundled-ios-nosign.ipa` (unsigned; re-sign required) |
| Linux x86_64 | `songloft-bundled-linux-x64.tar.gz` |
| macOS Universal | `songloft-bundled-macos.zip` |
| Windows x86_64 | `songloft-bundled-windows-x64.zip` |

## Release

Use `bump-version.sh` for versioning (follows semantic versioning):

```bash
# Patch version bump (1.0.0 -> 1.0.1)
./scripts/bump-version.sh patch

# Minor version bump (1.0.0 -> 1.1.0)
./scripts/bump-version.sh minor

# Major version bump (1.0.0 -> 2.0.0)
./scripts/bump-version.sh major
```

The script will automatically:
- Read and bump the version in `pubspec.yaml`
- Create a Git tag (format: `v{version}`)
- Push the Git tag to remote
- Provide interactive confirmation and progress feedback

## Backend

**Standard version** requires the [Songloft backend](https://github.com/songloft-org/songloft) service. Default connection: `http://localhost:58091`, configurable on the login page.

**Bundle version** embeds the Go backend, so no separate server deployment is needed. The client signs in with credentials generated by the local backend and stored in the app data directory.

Default credentials: admin / admin

🔗 **Backend GitHub**: [https://github.com/songloft-org/songloft](https://github.com/songloft-org/songloft)

## License

The **source code** of this project is open-sourced under the [Apache-2.0 license](LICENSE).

> **LGPL Compliance Note**: On Windows/Linux, this client uses `just_audio_media_kit` to call libmpv (LGPL-2.1+) as the audio backend. The Windows package includes an **audio-only LGPL build** (without GPL encoders like libx264/libx265); Linux dynamically links the system libmpv. See [NOTICE](NOTICE) for the full list of third-party components, license types, and source availability.
