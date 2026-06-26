# Flutter Frontend Release Guide

This directory contains release scripts and best practices for the Songloft Flutter frontend.

## 📋 Release Script

### `release-frontend.sh`

Automates the Flutter frontend version release process.

**Location**: `songloft-player/scripts/release-frontend.sh`

**Usage**:

```bash
# Patch version bump (bug fix, 1.0.0 -> 1.0.1)
./scripts/release-frontend.sh patch

# Minor version bump (new feature, 1.0.0 -> 1.1.0)
./scripts/release-frontend.sh minor

# Major version bump (breaking change, 1.0.0 -> 2.0.0)
./scripts/release-frontend.sh major

# Show help
./scripts/release-frontend.sh --help
```

## 🔧 What the Script Does

After running `release-frontend.sh`, the script automatically:

1. **Reads the current version** — extracts the current version from `pubspec.yaml`
2. **Bumps the version** — calculates the new version based on the specified bump type (major/minor/patch)
3. **Updates pubspec.yaml** — modifies the version number, preserving the build number
4. **Checks and updates README.md** — updates version references if present
5. **Commits changes** — commits modified files to git
6. **Creates a Git tag** — creates an annotated tag in the format `v{version}`
7. **Pushes the tag** — pushes the Git tag to the remote repository

## 🛡️ Safety Features

- ✅ **Git repository check** — ensures the script is run inside a git repository
- ✅ **Uncommitted changes detection** — prompts for confirmation if uncommitted changes exist
- ✅ **Interactive confirmation** — key steps require user confirmation
- ✅ **Tag conflict handling** — prompts whether to overwrite if the tag already exists
- ✅ **Error handling** — comprehensive error handling with user-friendly messages

## 📝 Semantic Versioning

Follows the [Semantic Versioning](https://semver.org/) specification:

- **MAJOR**: Incompatible API or breaking changes
- **MINOR**: Backward-compatible new functionality
- **PATCH**: Backward-compatible bug fixes

**Examples**:
- `1.0.0` → `2.0.0` (major) — Breaking update
- `1.0.0` → `1.1.0` (minor) — New feature
- `1.0.0` → `1.0.1` (patch) — Bug fix

## 🚀 Full Release Workflow

### 1. Release a New Version

```bash
cd songloft-player

# Choose the appropriate bump type
./scripts/release-frontend.sh patch  # or minor / major
```

### 2. Build All Platforms

```bash
# After the Git tag is pushed, build all platforms
./scripts/build-frontend.sh all
```

### 3. Create a GitHub Release

Go to https://github.com/songloft-org/songloft-player/releases/new

- Tag version: select the newly created tag (e.g. `v1.0.1`)
- Release title: `v1.0.1`
- Description: describe the changelog for this release

### 4. Upload Build Artifacts

Upload the platform artifacts from the `songloft-player-build/` directory to the Release.

## 📦 Build Artifacts

| File | Description |
|------|-------------|
| `songloft-web-standalone.tar.gz` | Web standalone deployment |
| `songloft-web-embedded.tar.gz` | Web embedded (for Go backend) |
| `songloft-linux-x64/` | Linux desktop |
| `songloft-linux-amd64.deb` | Debian/Ubuntu package |
| `songloft-windows-x64.zip` | Windows portable |
| `songloft-macos.dmg` | macOS DMG |
| `songloft-arm64-v8a.apk` | Android APK (ARM64) |
| `songloft-ios-nosign.ipa` | iOS IPA (unsigned) |

## 🔄 Differences from Backend Release

| | Frontend (`release-frontend.sh`) | Backend (`release.sh`) |
|---|----------------------------------|------------------------|
| Version file | `pubspec.yaml` | `Makefile` |
| Swagger update | ❌ | ✅ |
| CHANGELOG update | ❌ | ✅ |
| Docker build | ❌ | ✅ |
| GitHub Release | Manual | Automatic |
| Build trigger | Manual | Automatic |

## ⚠️ Notes

1. **Pre-release checklist**
   - Ensure all tests pass
   - Ensure code is formatted
   - Ensure there are no uncommitted changes

2. **Version format**
   - Format: `X.Y.Z+W` (X=major, Y=minor, Z=patch, W=build number)
   - The script only modifies `X.Y.Z`, preserving the build number

3. **Git tags**
   - Tag format: `v{version}` (e.g. `v1.0.1`)
   - Uses annotated tags with release information

4. **When to release**
   - PATCH: bug fixes, release anytime
   - MINOR: accumulated new features, release periodically
   - MAJOR: major updates, release with caution

## 🆘 Troubleshooting

### Issue: Script says "Flutter not detected"

**Fix**: Ensure Flutter SDK is installed and added to PATH

```bash
flutter --version  # Check if Flutter is available
```

### Issue: Git tag push fails

**Fix**: Check remote repository permissions

```bash
git remote -v  # Check remote config
git push origin v1.0.1  # Test push manually
```

### Issue: pubspec.yaml format error

**Fix**: Ensure the version field is correctly formatted

```yaml
version: 1.0.0+1  # Correct format
```

## 📚 Related Docs

- [Build Script Guide](../docs/en/build_guide.md)
- [Flutter Versioning](https://flutter.dev/docs/development/tools/pubspec)
