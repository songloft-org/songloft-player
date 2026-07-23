# Shorebird Hot Update Integration

This document describes the full implementation plan for integrating [Shorebird](https://shorebird.dev) Dart code push (install-free hot updates) into **songloft-player**, honoring two hard constraints: **automated release publishing** and **release channel only — dev builds are never wired to Shorebird**.

> Background and the trade-off comparison live in the team discussion; this doc only covers "how to land it once we've decided to adopt Shorebird".

> **Landing status in this repo (2026-07)**: the Android main path is landed — the CI (`build-and-release.yml`) runs `shorebird release android --artifact apk` on tag pushes, and a new manual patch workflow `shorebird-patch.yml` was added; the client uses an **active update flow** (`shorebird.yaml` sets `auto_update: false`; the home page checks once per session: detect update → "download?" dialog → progress → "restart to apply" dialog, see `lib/core/updater/`) rather than silent background updates. **The `app_id` is NOT hardcoded in `shorebird.yaml`**: the repo only holds a placeholder, the real `app_id` lives in the GitHub repository variable `SHOREBIRD_APP_ID`, and CI overwrites it before release / patch (see §3.2, §4.3). iOS remains an **independent follow-up task** per §4.2 and is not wired up yet.

---

## 1. Scope & Boundaries

| Dimension | Conclusion |
|------|------|
| Platforms | **Android + iOS** (Shorebird only supports these two). Web / Windows / macOS / Linux are **not wired up**; they keep full-package updates. |
| Channel | **Release only** (`v*` tag builds) is wired to Shorebird release / patch. **Dev builds (rolling prerelease on push to main) are fully excluded**, keeping the existing `flutter build`. |
| Hot-updatable | Any Dart code under `lib/`, pure-Dart dependencies, Flutter assets (bundled with the release). |
| Not hot-updatable | Native Kotlin/Swift, `AndroidManifest.xml`/`Info.plist`, the native side of plugins with native code (media_kit / just_audio, etc.), Flutter engine/SDK upgrades — these require a new full-package release. |
| When it takes effect | Patches download silently in the background and **take effect on the next cold start**, never mid-process. |

### Why it naturally ships release-only

The existing CI (`.github/workflows/build-and-release.yml`) already keys the version on:

```bash
if [[ "$GITHUB_REF" == refs/tags/v* ]]; then
  VERSION="$PUBSPEC_VERSION"   # release
else
  VERSION="dev"                # push main / workflow_dispatch
fi
```

So **as long as the Shorebird steps are gated with `startsWith(github.ref, 'refs/tags/v')`**, the dev build path never touches Shorebird — naturally satisfying "dev not wired up".

---

## 2. Core Concepts

- **release (baseline)**: one `shorebird release android/ios` both (a) compiles the artifact (AAB/APK/IPA) and (b) registers that version's Dart snapshot fingerprint to the Shorebird cloud. Each release is uniquely identified by `versionName+versionCode` (i.e. pubspec's `2.11.0+1`).
- **patch**: `shorebird patch android/ios --release-version=2.11.0+1` generates a Dart-layer binary diff against **an existing release** and delivers it to devices running that release.
- **hard binding**: a patch only applies to devices with the same `release-version` + same engine + same flavor; old patches naturally expire after a release upgrade.
- **auto update**: the client has a built-in updater that fetches the matching patch in the background at launch and applies it on the next cold start — no UI code required.

---

## 3. One-Time Setup (once only)

### 3.1 Install the CLI and log in

```bash
curl --proto '=https' --tlsv1.2 https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh -sSf | bash
shorebird login          # local developer account (browser auth)
```

### 3.2 Initialize the project

In the `songloft-player/` root:

```bash
shorebird init
```

It will:
- Generate `shorebird.yaml` (with a unique `app_id`) and automatically add it to `pubspec.yaml`'s `assets:` (bundled into the app; the updater reads it at runtime).
- Android + iOS **share the same `app_id`** (the Shorebird console manages releases per platform).

Key fields in `shorebird.yaml`:

```yaml
app_id: <generated-uuid>
auto_update: true   # default true: auto check + download patches at launch (recommended)
```

> `shorebird.yaml` **must be committed**. `app_id` is a public identifier (not a secret) and could be committed directly; but **this repo** keeps the real `app_id` in the GitHub repository variable `SHOREBIRD_APP_ID`, and the committed `shorebird.yaml` holds only a placeholder (`00000000-...`) that CI overwrites via `sed` before `shorebird release` / `shorebird patch` (see §4.1, §5). The placeholder only satisfies pubspec's `assets:` requirement that the file exist — dev/web/desktop (non-Shorebird) builds bundle it but don't enable the updater, so the placeholder is harmless. Once `shorebird init` generates a real `app_id`, put it into the GitHub variable.

### 3.3 Confirm Flutter version compatibility

Shorebird ships a **customized Flutter** (requires Flutter ≥ 3.24). This project currently uses `FLUTTER_VERSION: '3.44.6'` (stable, see the workflow env).

> ✅ **3.44.6 is supported by Shorebird** — Shorebird's official GitHub Actions example uses exactly `FLUTTER_VERSION: 3.44.6`. In CI, `shorebird release` is passed `--flutter-version=3.44.6`, identical to the full-package build.

- Only pass `--flutter-version` on `shorebird release`; **`shorebird patch` does not** (see §5 — it auto-detects the target release's build version).
- If you later bump `FLUTTER_VERSION`: first `shorebird flutter versions list` to confirm the new version is supported; after the bump **old patches are void** and a new release is required; subsequent patches against the new release are auto-built with the new version.

### 3.4 Create a CI authorization token

From **[Shorebird Console](https://console.shorebird.dev) → Account → API Keys**, create an API Key (the key value is shown only once) and store it as the GitHub secret **`SHOREBIRD_TOKEN`**.

> `shorebird login:ci` is deprecated (old tokens work until 2026-09); new tokens go through the Console; the env var name is still `SHOREBIRD_TOKEN`.

### 3.5 Important change to the Android artifact shape ⚠️

**This repo has unified on a single universal APK**: both dev and release produce one APK containing all ABIs — no more split-per-abi into arm64-v8a / armeabi-v7a / x86_64.

- dev: `flutter build apk --release` (plain flutter, no Shorebird) produces a single universal APK.
- release: `shorebird release android --artifact apk` produces a single universal APK (and registers the Shorebird baseline).

- Trade-off: the universal APK is bigger (bundles multiple ABIs' native libs), but distribution is simpler and **patch delivery is unaffected** — the updater delivers the right patch for the device architecture.

---

## 4. Automated Release Publishing (CI changes)

Goal: **on `v*` tag push, Android/iOS auto-run `shorebird release`** (producing both a downloadable installer and the Shorebird baseline); dev builds on push-to-main stay as-is.

Only the `build-android` and `build-ios` jobs change; `build-web`/`build-linux`/`build-windows`/`build-macos` and the `release` aggregation job are **untouched**.

### 4.1 `build-android` job changes

After `Extract version` and before `Build APK`, insert Shorebird setup steps (**tag-only**), plus a step that injects the real `app_id` from the repo variable over the committed placeholder:

```yaml
      # Install Shorebird CLI on release (tag) only; dev builds skip it.
      - name: Setup Shorebird
        if: startsWith(github.ref, 'refs/tags/v')
        uses: shorebirdtech/setup-shorebird@v1
      - name: Inject Shorebird app_id
        if: startsWith(github.ref, 'refs/tags/v')
        env:
          SHOREBIRD_APP_ID: ${{ vars.SHOREBIRD_APP_ID }}
        run: |
          if [ -z "$SHOREBIRD_APP_ID" ]; then
            echo "::error::Missing repo variable SHOREBIRD_APP_ID" >&2
            exit 1
          fi
          sed -i "s|^app_id:.*|app_id: ${SHOREBIRD_APP_ID}|" shorebird.yaml
```

Branch the `Build APK` step by channel:

```yaml
      - name: Build APK
        env:
          ANDROID_KEYSTORE_PASSWORD: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
          ANDROID_KEY_ALIAS: ${{ secrets.ANDROID_KEY_ALIAS }}
          ANDROID_KEY_PASSWORD: ${{ secrets.ANDROID_KEY_PASSWORD }}
          SHOREBIRD_TOKEN: ${{ secrets.SHOREBIRD_TOKEN }}
        run: |
          COMMON_DEFINES="--dart-define=FRONTEND_VERSION=${{ steps.version.outputs.version }} \
            --dart-define=FRONTEND_BUILD_TIME=${{ steps.version.outputs.build_time }} \
            --dart-define=TRACELY_APP_ID=${{ secrets.TRACELY_APP_ID }} \
            --dart-define=TRACELY_APP_SECRET=${{ secrets.TRACELY_APP_SECRET }} \
            --dart-define=TRACELY_HOST=${{ secrets.TRACELY_HOST }}"

          if [[ "$GITHUB_REF" == refs/tags/v* ]]; then
            # Release: Shorebird release (register baseline + single universal APK)
            shorebird release android \
              --flutter-version=3.44.6 \
              --artifact apk \
              -- $COMMON_DEFINES
          else
            # dev: no Shorebird, also a single universal APK
            flutter build apk --release $COMMON_DEFINES
          fi
```

> Arguments after `--` are passed through by Shorebird to the underlying `flutter build`, so all `--dart-define`s still apply.

The `Collect APK` step always outputs a single `songloft-android.apk`; it only branches because the two build paths use different output dirs (Shorebird's `apk/release/` vs plain flutter's `flutter-apk/`):

```yaml
      - name: Collect APK
        run: |
          mkdir -p apk-output
          if [[ "$GITHUB_REF" == refs/tags/v* ]]; then
            cp build/app/outputs/apk/release/app-release.apk apk-output/songloft-android.apk
          else
            cp build/app/outputs/flutter-apk/app-release.apk apk-output/songloft-android.apk
          fi
```

> The actual Shorebird APK output path is whatever `shorebird release android --artifact apk` prints at the end; verify it once on first integration.

### 4.2 `build-ios` job changes

Same idea, tag-only:

```yaml
      - name: Setup Shorebird
        if: startsWith(github.ref, 'refs/tags/v')
        uses: shorebirdtech/setup-shorebird@v1

      - name: Build iOS
        env:
          SHOREBIRD_TOKEN: ${{ secrets.SHOREBIRD_TOKEN }}
        run: |
          COMMON_DEFINES="--dart-define=FRONTEND_VERSION=${{ steps.version.outputs.version }} ...(same as above)"
          if [[ "$GITHUB_REF" == refs/tags/v* ]]; then
            shorebird release ios --flutter-version=3.44.6 --no-codesign -- $COMMON_DEFINES
          else
            flutter build ios --release --no-codesign $COMMON_DEFINES
          fi
```

> ⚠️ **Key iOS difference (must read)**: Shorebird's docs are explicit — `shorebird release ios --no-codesign` produces an **`.xcarchive`**, which **cannot** be `shorebird preview`d or installed directly; you **must sign that xcarchive manually in Xcode / a signing pipeline** before distributing. This differs from the current CI's approach of "package an unsigned IPA directly from `build/ios/iphoneos/Runner.app`"; after integration the iOS artifact path and packaging steps must be reworked.
>
> So going through Shorebird on iOS actually requires a **signed release pipeline** (Apple developer account + certs/profiles, usually App Store/TestFlight). **Android is the primary payoff of this plan and works out of the box; iOS is recommended as a separate follow-up task — set up signing first, then integrate.**

### 4.3 GitHub Secrets / Variables to add

| Name | Type | Purpose |
|------|------|------|
| `SHOREBIRD_TOKEN` | Secret | Authorizes CI's `shorebird release`/`patch` (create via Console → Account → API Keys, see §3.4) |
| `SHOREBIRD_APP_ID` | Variable (repo variable) | The real app_id (public identifier, not a secret); CI uses it to overwrite the `shorebird.yaml` placeholder. Missing → release/patch step fails immediately |

The Android signing secrets (`ANDROID_KEYSTORE_*`) already exist and **must stay unchanged** — patches strictly depend on "the release the user installed and the baseline registered with Shorebird sharing the same signature + same build".

---

## 5. Patch Publishing Flow (the real "hot update" action)

After a full release, **pure-Dart fixes between two releases** are delivered via patches. **Patches don't follow commits automatically** (to avoid mis-sends and to conserve the 5000/month free quota); they're controlled by a **manually triggered standalone workflow**.

Added `.github/workflows/shorebird-patch.yml`:

```yaml
name: Shorebird Patch

on:
  workflow_dispatch:
    inputs:
      release_version:
        description: 'Target baseline version (pubspec form, e.g. 2.11.0+1)'
        required: true
      track:
        description: 'Delivery track: staging first, then stable'
        type: choice
        options: [staging, beta, stable]
        default: staging

jobs:
  patch-android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'
      - uses: shorebirdtech/setup-shorebird@v1
      - name: Inject Shorebird app_id
        env:
          SHOREBIRD_APP_ID: ${{ vars.SHOREBIRD_APP_ID }}
        run: |
          sed -i "s|^app_id:.*|app_id: ${SHOREBIRD_APP_ID}|" shorebird.yaml
      - name: Patch Android
        env:
          SHOREBIRD_TOKEN: ${{ secrets.SHOREBIRD_TOKEN }}
        run: |
          # Note: patch does NOT pass --flutter-version; Shorebird auto-detects
          # the release's build version.
          shorebird patch android \
            --release-version=${{ inputs.release_version }} \
            --track=${{ inputs.track }} \
            -- --dart-define=FRONTEND_VERSION=$(echo ${{ inputs.release_version }} | cut -d'+' -f1) ...(same defines as release)
```

> **`shorebird patch` does not accept `--flutter-version`**: it looks up the Flutter version that baseline was built with by `--release-version` and compiles the patch with the same version. The `--dart-define`s after `--` must match the corresponding release.

Standard patch procedure:

1. **Check out the commit** of the release tag to fix (e.g. `v2.11.0`) and cherry-pick / commit the pure-Dart fix on top.
2. (Recommended) publish to the **staging track** first: `shorebird patch android --release-version=2.11.0+1 --track=staging`, and verify with `shorebird preview --track=staging` or test devices.
3. Once verified, publish to the default **stable track** (no `--track`) by triggering the `Shorebird Patch` workflow, filling `release_version` with `2.11.0+1` (exactly matching that release's pubspec).
4. The Shorebird cloud generates the diff → devices running `2.11.0+1` fetch it on next launch → it takes effect on the following cold start.

> **The patch and baseline Dart snapshots must come from the same build config** (same Flutter version, same defines). So always patch **on top of the corresponding release tag's code**, never on the latest main.

---

## 6. Client Integration

### 6.1 Works with zero changes

With `shorebird.yaml`'s `auto_update: true`, the updater checks and downloads patches in the background at launch and applies them on the next cold start. **Hot update already works without any Dart code.**

### 6.2 (Optional) Prompt the user to restart for faster effect

To "prompt the user to restart after a patch is downloaded", add the dependency (requires `shorebird_code_push` v2):

```yaml
dependencies:
  shorebird_code_push: ^2.0.0
```

At an appropriate moment (e.g. returning to the home page), check the update status and show a light hint:

```dart
final updater = ShorebirdUpdater();

// Query whether an update is available
final status = await updater.checkForUpdate();
if (status == UpdateStatus.restartRequired) {
  // Patch is downloaded and takes effect on restart — use the existing
  // responsive_snackbar for a light hint
}

// Read the currently applied patch number (for logging/reporting; patches
// don't change the version number, see §9)
final patch = await updater.readCurrentPatch();
```

- Prefer **only a light hint**, no forced restart; with `auto_update: true` the patch applies on the next natural cold start anyway.
- This UI does **not conflict** with the existing `FrontendUpgradeDialog` (full-package update): the former handles Dart hot patches, the latter handles full-package release upgrades.
- API names follow `shorebird_code_push` v2 as actually published; verify against pub.dev docs at integration time.

> **Landed in this repo**: `ShorebirdUpdateService` (`lib/core/updater/shorebird_update_service.dart`) wraps the updater defensively (platform + `isAvailable` guards, all exceptions swallowed). The home page (`home_page.dart`) checks once per session on `initState` and shows the `patchReadyRestartHint` snackbar when `restartRequired`. `main.dart` reports the current patch number to tracely (see §8/§9.8).

### 6.3 Division of labor with existing version checks

| Channel | Handles | Entry point |
|------|------|------|
| Shorebird patch | Pure-Dart hot fixes (install-free) | Auto at launch / optional light hint |
| `FrontendVersionApi` + `FrontendUpgradeDialog` | Full-package release upgrades (incl. native/engine changes) | Settings "Check for client updates" |

The two coexist: daily small bugs go through Shorebird for second-level delivery; native/plugin/engine changes go through a full package.

---

## 7. Rollout, Rollback & Quota

- **Rollout mechanism = tracks (not a console percentage slider)**: Shorebird uses `staging` / `beta` / `stable` tracks. `shorebird patch` without `--track` goes to `stable` (all users).
  - **Recommended flow**: `--track=staging` (dev/internal devices) → then `stable`.
  - **True percentage rollout** requires client cooperation: set `auto_update: false` in `shorebird.yaml` + add `shorebird_code_push` + do your own user bucketing (e.g. random group + a cloud KV holding each version's rollout ratio) to decide `beta` vs `stable`. This is an optional advanced approach; staging→stable two-stage is enough initially.
- **Rollback**: publish a fix patch to the same track to override, or stop delivering the bad patch; devices already applying it fall back to the baseline or the new patch on next launch.
- **Free quota**: the Free tier has **5,000 patch installs/month, hard cap, no overage billing**. Consumption ≈ (patches this month) × (device installs per patch) — **frequent patching burns it faster**. Beyond that requires Pro ($20/month, 50,000). Assess active install base against the cap before publishing.

---

## 8. Landing Verification Checklist

**Preparation**
- [ ] `shorebird flutter versions list` confirms 3.44.6 is supported (align versions otherwise)
- [ ] `shorebird init` generates and commits `shorebird.yaml`
- [ ] `SHOREBIRD_TOKEN` added to GitHub secrets; `SHOREBIRD_APP_ID` added to repo variables

**Android end-to-end (main path)**
- [ ] Push a `vX.Y.Z` tag; CI's `build-android` runs `shorebird release android --artifact apk` successfully and the Release page shows the universal APK
- [ ] Install the APK on a real device (especially Xiaomi/HyperOS)
- [ ] Change one Dart UI thing on the release tag's code, publish a `--track=staging` patch, verify with `shorebird preview --track=staging`
- [ ] Publish a stable patch (trigger the `Shorebird Patch` workflow, `release_version` = `X.Y.Z+build`)
- [ ] Confirm the patch takes effect after two cold starts
- [ ] Publish a fix patch / stop delivery, confirm rollback works
- [ ] Push main (dev build), confirm Shorebird is **completely skipped** and a single universal APK (`songloft-android.apk`) is still produced

**iOS (separate follow-up task)**
- [ ] Set up the signing pipeline (Apple account + certs/profiles)
- [ ] `shorebird release ios` produces `.xcarchive` → sign manually/in pipeline → distribute (App Store/TestFlight)
- [ ] Publish a patch against that release and verify on a real device

---

## 9. Key Constraints & Pitfalls

1. **Dev not wired up**: all Shorebird steps must be gated with `if: startsWith(github.ref, 'refs/tags/v')`; inside the `Build` step branch again with `if [[ "$GITHUB_REF" == refs/tags/v* ]]`. Double protection — never let the dev path pull in Shorebird.
2. **Flutter version locked**: bumping `FLUTTER_VERSION` requires confirming Shorebird supports it, and after the bump **old patches are void** and a new release is required.
3. **Signature consistency**: patch baselines depend on the user's installed APK sharing the same signature as the CI-registered release. `ANDROID_KEYSTORE_*` secrets must not change or fall back to debug signing.
4. **Patch on top of the release tag**: don't patch on the latest main; the Dart snapshot config must match the target release.
5. **Only Dart is hot-updatable**: any native/plugin-native/engine change mixed into a patch won't take effect (and may behave inconsistently); such changes must go through a full-package release.
6. **Android distribution shape**: all channels unified on a single universal APK (`songloft-android.apk`), no more split-per-abi multi-arch packages; Release notes and download page copy were adjusted accordingly.
7. **Patches don't change the version number**: a Shorebird patch **does not** change the app's `versionName+versionCode` (`2.11.0+1` stays `2.11.0+1` after patching). So `FrontendVersionApi`'s full-package version comparison can't see patches — the two don't interfere; but use `readCurrentPatch()` for the patch number when doing analytics/reporting to distinguish "patched or not".
8. **Quota monitoring**: wire self-hosted monitoring (tracely) to report patch apply/failure and the `readCurrentPatch()` patch number, alongside watching the 5,000/month free quota in the Shorebird console.

---

> **Chinese version sync**: this repo mirrors `docs/cn/` and `docs/en/` with the same file names. This English doc mirrors `docs/cn/shorebird_hot_update.md`; keep the two in sync on any content/structure/link change.
