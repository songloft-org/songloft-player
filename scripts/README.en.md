# Flutter Frontend Scripts Guide

This directory contains build and release scripts for the Songloft Flutter frontend.

## 📋 Script List

| Script | Description |
|--------|-------------|
| `build-frontend.sh` | Multi-platform build script, supports web/linux/windows/macos/android/ios/all |
| `bump-version.sh` | Release script (semantic versioning + Git tagging) |
| `docker-build-frontend.sh` | Docker build helper |
| `download-fonts.sh` | Font download script (downloads custom fonts used by the project) |

## 🔧 `bump-version.sh` — Versioning & Release

Automates the Flutter frontend version release process.

**Usage**:

```bash
# Patch version bump (bug fix, 1.0.0 -> 1.0.1, default)
./scripts/bump-version.sh patch

# Minor version bump (new feature, 1.0.0 -> 1.1.0)
./scripts/bump-version.sh minor

# Major version bump (breaking change, 1.0.0 -> 2.0.0)
./scripts/bump-version.sh major

# Formal release (strip pre-release suffix: 2.0.0-alpha.2 -> 2.0.0)
./scripts/bump-version.sh release

# Dry run — preview only, no changes made
./scripts/bump-version.sh minor --dry-run

# Show help
./scripts/bump-version.sh --help
```

**What the script does**:

1. Reads the current version from `pubspec.yaml`
2. Calculates the new version based on the bump type (release/major/minor/patch)
3. Updates `pubspec.yaml` version (preserving the build number)
4. Git commit + creates an annotated tag (`v{version}`) + push

After the tag is pushed, `.github/workflows/build-and-release.yml` automatically handles multi-platform builds and GitHub Release creation.

**Safety features**:
- Validates Git repository environment
- Prompts for confirmation on uncommitted changes
- Interactive confirmation for key steps
- Handles tag conflicts with overwrite prompt

## 🔧 `build-frontend.sh` — Multi-Platform Build

```bash
# Build a single platform
./scripts/build-frontend.sh web              # Web standalone
./scripts/build-frontend.sh web-embedded     # Web embedded mode
./scripts/build-frontend.sh linux
./scripts/build-frontend.sh windows
./scripts/build-frontend.sh macos
./scripts/build-frontend.sh android
./scripts/build-frontend.sh ios

# Build all platforms
./scripts/build-frontend.sh all
```

Build artifacts are output to the `songloft-player-build/` directory.

## 📝 Semantic Versioning

Follows the [Semantic Versioning](https://semver.org/) specification:

- **MAJOR**: Incompatible API or breaking changes
- **MINOR**: Backward-compatible new functionality
- **PATCH**: Backward-compatible bug fixes
- Version format: `X.Y.Z+W` (X=major, Y=minor, Z=patch, W=build number)
- The script only modifies `X.Y.Z`, preserving the build number
