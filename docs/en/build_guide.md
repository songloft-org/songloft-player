# Songloft Flutter Frontend Build Guide

## 📦 Overview

`build-frontend.sh` builds the Songloft Flutter frontend, supporting per-platform builds or parallel builds across all platforms.

### Supported Platforms

- ✅ **Web** - Standalone deployment
- ✅ **Web Embedded** - Embedded mode (for embedding into Go backend)
- ✅ **Linux** - Desktop app
- ✅ **Windows** - Desktop app (requires Windows)
- ✅ **macOS** - Desktop app (requires macOS)
- ✅ **Android** - APK + AAB (requires Android SDK)
- ⚠️ **iOS** - Can only be built on macOS

## 🚀 Quick Start

### Method 1: Using Makefile (Recommended)

```bash
# Build a specific platform
make build-frontend PLATFORM=web
make build-frontend PLATFORM=linux
make build-frontend PLATFORM=android

# Build to a custom output directory
make build-frontend PLATFORM=web OUTPUT_DIR=/tmp/songloft-player-build

# Build all platforms supported by the current system
make build-frontend-all

# Shortcut targets
make build-frontend-web        # Web standalone
make build-frontend-linux      # Linux desktop
make build-frontend-windows    # Windows desktop
make build-frontend-macos      # macOS desktop
make build-frontend-android    # Android APK + AAB
make build-frontend-ios        # iOS (macOS only)
```

### Method 2: Running the Script Directly

```bash
# Build a single platform
./songloft-player/scripts/build-frontend.sh web
./songloft-player/scripts/build-frontend.sh linux
./songloft-player/scripts/build-frontend.sh android

# Specify output directory
./songloft-player/scripts/build-frontend.sh web /tmp/songloft-player-build

# Build all platforms (unsupported platforms are skipped automatically)
./songloft-player/scripts/build-frontend.sh all
```

## ⚡ Parallel Build

### How It Works

The script uses background processes (`&`) and the `wait` command to achieve true parallel builds:

1. **Multiple build processes start simultaneously** — Web, Linux, Windows, macOS, Android all begin at once
2. **Isolated logging** — Each platform's output is saved to a separate log file
3. **Unified error handling** — Failures are checked after all processes complete

### Performance Gains

Compared to sequential builds, parallel builds significantly reduce total time:

```
Sequential: Web(2m) + Linux(5m) + Windows(5m) + macOS(5m) + Android(8m) = ~25 min
Parallel:   max(Web, Linux, Windows, macOS, Android) = ~8-10 min
```

**Estimated 60-70% faster** 🚀

## 📁 Output Structure

```
songloft-player-build/
├── .build_logs/          # Build log directory
│   ├── web.log
│   ├── linux.log
│   ├── windows.log
│   ├── macos.log
│   ├── android.log
│   └── ios.log (if built)
├── web-standalone/       # Web standalone deployment
├── linux/                # Linux desktop
├── windows/              # Windows desktop
├── macos/                # macOS desktop
├── android/
│   ├── apk/              # Android APK files
│   └── bundle/           # Android AAB files
├── ios/                  # iOS app (macOS only)
└── BUILD_REPORT.md       # Build report
```

## 🔍 Build Logs

Each platform's build log is saved in `.build_logs/`:

```bash
# View Web build log
cat songloft-player-build/.build_logs/web.log

# List all logs
ls -la songloft-player-build/.build_logs/
```

## ❌ Error Handling

If a platform build fails:

1. The script waits for all other platforms to complete
2. Displays a failure message with the log file location
3. Returns a non-zero exit code

```bash
# Check if any platform failed
if [ $? -ne 0 ]; then
    echo "Build failed. Check logs:"
    ls songloft-player-build/.build_logs/*.log
fi
```

## 📊 Build Report

The script automatically generates `BUILD_REPORT.md` containing:

- Build time and environment info
- Artifact size per platform
- File count statistics
- Suggested next steps

## 💡 Advanced Usage

### 1. Using in CI/CD

```yaml
# GitHub Actions example — multi-platform matrix build
jobs:
  build:
    strategy:
      matrix:
        include:
          - os: ubuntu-latest
            platform: web
          - os: ubuntu-latest
            platform: linux
          - os: macos-latest
            platform: macos
          - os: macos-latest
            platform: ios
          - os: windows-latest
            platform: windows
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.29.0'
      - name: Build
        run: ./songloft-player/scripts/build-frontend.sh ${{ matrix.platform }} ${{ runner.temp }}/songloft-player-build
      - uses: actions/upload-artifact@v4
        with:
          name: songloft-${{ matrix.platform }}
          path: ${{ runner.temp }}/songloft-player-build/
```

### 2. Docker Build (Web + Linux + Android)

```bash
# Build all Linux-container-supported platforms (Web + Linux + Android) by default
docker build -t songloft-frontend-builder songloft-player/

# Build Web only
docker build --build-arg BUILD_PLATFORM=web -t songloft-frontend-builder songloft-player/

# Build Android only
docker build --build-arg BUILD_PLATFORM=android -t songloft-frontend-builder songloft-player/

# Extract artifacts to local directory
docker create --name tmp-frontend songloft-frontend-builder
docker cp tmp-frontend:/output/ ./songloft-player-build/
docker rm tmp-frontend

# Or use the convenience script (supports platform argument)
./songloft-player/scripts/docker-build-frontend.sh              # Build all platforms
./songloft-player/scripts/docker-build-frontend.sh android      # Build Android only
```

## 🛠️ Requirements

### Common Requirements

- Flutter SDK 3.29+
- Dart SDK 3.7+
- Bash shell

### Platform-Specific Requirements

**Linux:**
```bash
# Ubuntu/Debian
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev
```

**Windows:**
- Visual Studio 2022 (with C++ Desktop Development workload)
- Windows 10 SDK

**macOS:**
- Xcode 15+
- CocoaPods (`sudo gem install cocoapods`)

**Android:**
- Android SDK
- Android NDK
- Java JDK 17+

**iOS:**
- macOS (required)
- Xcode 15+
- iOS SDK

## 🐛 Troubleshooting

### Issue 1: Build stuck on a platform

Check the corresponding log file:

```bash
tail -f songloft-player-build/.build_logs/<platform>.log
```

### Issue 2: Out of memory

Flutter builds are memory-intensive. Suggestions:

- Close other applications
- Increase swap space (Linux)
- Build in batches (remove `&` for some platforms in the script)

### Issue 3: Android build fails

```bash
# Accept licenses
sdkmanager --licenses

# Clean Gradle cache
cd songloft-player
flutter clean
rm -rf android/.gradle
```

### Issue 4: iOS build fails (macOS)

```bash
# Clean Pods
cd songloft-player/ios
pod deintegrate
pod install

# Clean build
flutter clean
flutter pub get
```

## 📈 Performance Tips

1. **Use SSD** — 30-50% faster builds
2. **Enough RAM** — 16GB+ recommended
3. **Network proxy** — Speeds up dependency downloads
4. **Build cache** — Keep `.flutter-plugins` and related files

## 📝 Sample Output

```
========================================
Songloft Flutter Multi-Platform Parallel Build
========================================

Output dir:   /Users/hanxi/toy/songloft/songloft-player-build
Frontend dir: /Users/hanxi/toy/songloft/songloft-player
CPU cores:    8 (for concurrency control)

Flutter version:
Flutter 3.29.0 • channel stable

[Prepare] Cleaning and creating output directory...
✓ Output directory ready: /Users/hanxi/toy/songloft/frontend-build

[Prepare] Installing Flutter dependencies...
✓ Dependencies installed

========================================
[Parallel Build] Starting concurrent builds...
========================================

→ Starting Web build process
→ Starting Linux build process
→ Starting Windows build process
→ Starting macOS build process
→ Starting Android build process
→ Starting iOS build process

Waiting for all build processes to complete...

[Web] Building Web standalone...
[Linux] Building Linux...
[Windows] Building Windows...
[macOS] Building macOS...
[Android] Building Android...
[iOS] Building iOS...

✓[Web] Web build complete
✓[Linux] Linux build complete
✓[Windows] Windows build complete
✓[macOS] macOS build complete
✓[Android] Android build complete
✓[iOS] iOS build complete

========================================
✓ All platforms built successfully!
========================================

Total size: 2.1GB

  Web (standalone):     45MB
  Linux:               180MB
  Windows:             220MB
  macOS:               250MB
  Android:             180MB
  iOS:                 320MB

Build report saved to: songloft-player-build/BUILD_REPORT.md
```

## 📞 Support

If you encounter any issues, refer to:

1. Platform-specific build logs
2. `BUILD_REPORT.md` build report
3. Flutter official docs: https://docs.flutter.dev
