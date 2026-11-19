# Flutter Frontend Scripts Guide

This directory contains build and release scripts for the Songloft Flutter frontend.

## 📋 Script List

| Script | Description |
|--------|-------------|
| `build-frontend.sh` | Multi-platform build script, supports web/linux/windows/macos/android/ios/all |
| `bump-version.sh` | Release script (semantic versioning + Git tagging) |
| `docker-build-frontend.sh` | Docker build helper |
| `download-fonts.sh` | Font download script (downloads custom fonts used by the project) |
| `compute_native_contract.sh` | Hash plugins, MethodChannels and release ProGuard rules for hot-update compatibility |
| `check-android-preferences-jni.py` | Check the preferences plugin's JNI method descriptor in a release APK using Android SDK `apkanalyzer` |

After an Android release build, run `python3 scripts/check-android-preferences-jni.py <apk>` to verify JNI method descriptors and the Kotlin coroutine, result and Unit classes/members referenced by the JNI runtime. The release workflow checks the DEX in each edition’s universal APK and verifies the Flutter native libraries for all three ABIs before producing the per-ABI patches. Dart tests and debug APKs cannot replace it. ProGuard changes require a full APK; the native contract hash prevents old APKs from receiving only a Dart patch. Run script regressions with `python3 -m unittest discover -s scripts/tests -p '*_test.py'`.

## 🔧 `bump-version.sh` — Versioning & Release

Automates the Flutter frontend version release process. **Unified release contract**: parameters and behavior are identical to `clients/player-lynx/scripts/bump-version.sh` and the parent repo's `scripts/bump-version.sh`, so the parent's `scripts/release-all.sh` can orchestrate them directly.

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

# Explicit new version (must be newer than the current one)
./scripts/bump-version.sh 2.1.0

# Dry run — preview only: no file changes, no tags, no network
./scripts/bump-version.sh minor --dry-run

# Skip the interactive confirmation / keep commit+tag local
./scripts/bump-version.sh patch --yes
./scripts/bump-version.sh patch --no-push

# Show help
./scripts/bump-version.sh --help
```

**What the script does**:

1. Reads the current version from `pubspec.yaml`
2. Computes the new version from the bump type (release/major/minor/patch) or the explicit argument; the new version must be newer
3. Preflight: on `main`, clean worktree, `v<new>` tag absent locally and remotely, local main contains `origin/main`
4. Updates `pubspec.yaml` version (preserving the `+build number`)
5. Git commit + annotated tag (`v{version}`) + `git push --atomic` of main and that tag in one shot

After the tag is pushed, `.github/workflows/build-and-release.yml` automatically handles multi-platform builds and GitHub Release creation.

Release bodies contain automatically generated, categorized changes, with only installation links in `.github/release-notes.md`. Platform installation instructions are maintained in the root [README.md](../README.md#下载安装) and [README.en.md](../README.en.md#download). After a version-tag release succeeds, a separate job updates the Chinese-only root `CHANGELOG.md` from the latest `main` and commits it back to the repository. Rolling dev builds do not write this file. Changelog updates for different versions run serially and do not trigger another build.

**Safety features**:

- Any failed preflight exits before the first write; `--dry-run` performs no writes and no network calls
- Published tags are **never overwritten**; on failure the local state is kept (no tag deletion, no reset) for manual handling per this doc
- Use `--yes` in non-interactive environments; `--no-push` lets you verify locally and later run `git push --atomic origin HEAD:refs/heads/main refs/tags/v<version>` yourself
- The last stdout line prints `v<version>` while logs go to stderr, so the output chains cleanly (the parent's `release-all.sh` relies on this)

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
