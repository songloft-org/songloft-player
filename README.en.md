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

<p align="center">
  <a href="https://github.com/songloft-org/songloft-player">🏠 GitHub</a> •
  <a href="https://github.com/songloft-org/songloft-player/releases">📥 Download</a> •
  <a href="https://github.com/songloft-org/songloft-player/issues">💬 Issues</a>
</p>

## Screenshots

https://github.com/songloft-org/songloft/issues/6

## Download

Download the latest version from [GitHub Releases](https://github.com/songloft-org/songloft-player/releases/latest):

| Platform | Download | Notes |
|----------|----------|-------|
| 🌐 **Web (standalone)** | [songloft-web-standalone.tar.gz](https://github.com/songloft-org/songloft-player/releases/latest/download/songloft-web-standalone.tar.gz) | Self-hosted, configurable backend URL |
| 🌐 **Web (embedded)** | [songloft-web-embedded.tar.gz](https://github.com/songloft-org/songloft-player/releases/latest/download/songloft-web-embedded.tar.gz) | Embedded with Go backend on same domain |
| 🐧 **Linux** | [songloft-linux-x64.tar.gz](https://github.com/songloft-org/songloft-player/releases/latest/download/songloft-linux-x64.tar.gz) | x64 desktop |
| | [songloft-linux-x64.deb](https://github.com/songloft-org/songloft-player/releases/latest/download/songloft-linux-x64.deb) | Debian/Ubuntu x64 |
| | [songloft-linux-x64.rpm](https://github.com/songloft-org/songloft-player/releases/latest/download/songloft-linux-x64.rpm) | Fedora/RHEL/CentOS x64 |
| | [songloft-linux-x64.AppImage](https://github.com/songloft-org/songloft-player/releases/latest/download/songloft-linux-x64.AppImage) | Portable executable |
| 🪟 **Windows** | [songloft-windows-x64.zip](https://github.com/songloft-org/songloft-player/releases/latest/download/songloft-windows-x64.zip) | x64 portable |
| | [songloft-windows-x64.msix](https://github.com/songloft-org/songloft-player/releases/latest/download/songloft-windows-x64.msix) | x64 installer |
| 🍎 **macOS** | [songloft-macos.dmg](https://github.com/songloft-org/songloft-player/releases/latest/download/songloft-macos.dmg) | Universal DMG (Intel/Apple Silicon) |
| | [songloft-macos.zip](https://github.com/songloft-org/songloft-player/releases/latest/download/songloft-macos.zip) | Universal App archive |
| 🤖 **Android** | [songloft-arm64-v8a.apk](https://github.com/songloft-org/songloft-player/releases/latest/download/songloft-arm64-v8a.apk) | ARM64 (recommended) |
| | [songloft-armeabi-v7a.apk](https://github.com/songloft-org/songloft-player/releases/latest/download/songloft-armeabi-v7a.apk) | ARMv7 |
| | [songloft-x86_64.apk](https://github.com/songloft-org/songloft-player/releases/latest/download/songloft-x86_64.apk) | x86_64 emulator/device |
| 📱 **iOS** | [songloft-ios-nosign.ipa](https://github.com/songloft-org/songloft-player/releases/latest/download/songloft-ios-nosign.ipa) | Unsigned IPA, install via AltStore/Sideloadly |

> Development builds are available at the [dev branch Release](https://github.com/songloft-org/songloft-player/releases/tag/dev).

## Features

- **Cross-platform**: iOS, Android (phone/tablet/TV), macOS, Windows, Linux, Web
- **Bundle local mode**: Embedded Go backend, no server needed, supports local/remote mode switching
- **Responsive layout**: 4-level breakpoints (Mobile < 600px, Tablet 600-900px, Desktop 900-1920px, TV 1920px+)
- **Adaptive navigation**: Bottom bar on mobile, sidebar on tablet, side menu on desktop, top tab on TV
- **Music playback**: Powered by just_audio, supports local and network songs, background playback
- **Playlist management**: Create, edit, delete playlists, add/remove songs
- **Song library**: Paginated loading, search/filter, song editing
- **Theme**: Light / Dark / System
- **JWT authentication**: Dual-token mechanism with secure storage (auto-fallback)
- **TV support**: D-Pad focus navigation, large buttons and fonts

## Requirements

- Flutter >= 3.29.0
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
flutter build apk --split-per-abi                                              # Android APK
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
│   ├── player/      # Player (desktop/mobile/TV/mini)
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

The bundle version embeds the Go backend into the client, so users don't need a separate server:

- **Mobile (Android/iOS)**: Go backend compiled as native library (`.aar` / `.xcframework`) via gomobile, accessed through MethodChannel
- **Desktop (macOS/Windows/Linux)**: Go backend compiled as `songloft-server` executable, launched as a subprocess
- **Web**: Not supported for bundle mode

Usage: On first launch, tap "Use Local Mode" on the login page → select music directory → done. Switch between local/remote mode anytime in settings.

Pre-built bundle packages are available from [songloft main repo Releases](https://github.com/songloft-org/songloft/releases/latest) (`songloft-bundled-*` files).

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

**Bundle version** embeds the Go backend, no separate server deployment needed. Auto-logs in with admin/admin.

Default credentials: admin / admin

🔗 **Backend GitHub**: [https://github.com/songloft-org/songloft](https://github.com/songloft-org/songloft)

## License

This project is open-sourced under the [Apache-2.0 license](LICENSE).

> **LGPL Compliance Note**: On Windows/Linux, this client uses `just_audio_media_kit` to call libmpv (LGPL-2.1+) as the audio backend. The Windows package includes an **audio-only LGPL build** (without GPL encoders like libx264/libx265); Linux dynamically links the system libmpv. See [NOTICE](NOTICE) for the full list of third-party components, license types, and source availability.
