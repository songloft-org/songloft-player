# Bundle Android Hot Update (frontend libapp.so + backend libgojni.so)

This doc describes songloft-player's **self-hosted Android hot update** in Bundle local mode: **baseline-free** — any non-latest dev updates to the latest dev, any non-latest stable to the latest stable. **Every release auto-publishes** the latest patches as Release assets; the client checks on startup, downloads once, and restarts once: a single real cold restart makes both the frontend `libapp.so` (flutter_patcher) and the backend `libgojni.so` (gomobile) take effect.

> Bilingual: any change here must be mirrored in `docs/cn/backend_hotupdate.md`.

## Core model: baseline-free + auto-publish + toolchain compatibility key

- **Baseline-free**: the client fetches the **latest of its channel** — dev → rolling tag `dev`; stable → GitHub `/releases/latest` (dev is a prerelease, so latest returns the newest stable). Resolved by `lib/core/updater/channel_release_resolver.dart`, reusing `FrontendVersionApi`'s approach.
- **Auto-publish**: `release.yml`'s `build-bundled-android` job produces and uploads on every release: frontend `patch-<abi>.zip`+`manifest-<abi>.json` and backend `libgojni-<abi>.so`+`backend-manifest-<abi>.json` (arm64-v8a / armeabi-v7a only; x86_64 has no gomobile artifact). **No manual workflow, no versionCode binding.**
- **Compatibility key instead of versionCode** (automatic, not hand-edited):
  - **Frontend libapp.so**: flutter_patcher inherently binds by **versionCode** (libapp.so ↔ engine). This project's pubspec `+N` is **constant** (CI does not bump it per build), so all dev/stable builds share one versionCode and natural binding already allows cross-version hot update — versionCode is an **automatic compatibility proxy, not a hand-picked baseline**. The client additionally compares `AppConfig.flutterBinding` (= CI `FLUTTER_VERSION`) with the manifest's `flutterBinding`: different → not hot-patchable (guards against same versionCode but a changed Flutter engine crashing) → full-APK branch. Only a deliberate versionCode bump (usually alongside engine/native changes) forces the frontend to full APK.
  - **Backend libgojni.so**: the boundary is the gomobile export surface (`mobile/export_surface.txt` + the `release.yml` guard, automatic). **versionCode dropped**; safety comes from "frozen export surface + crash rollback/blacklist", so any old build updates to the latest.
- **Comparison**: dev by **git commit hash**; stable by **version number** (semver, `lib/core/updater/version_compare.dart`). Already-applied (`flutter_patcher.currentVersion == patchLabel` / backend confirmed) is skipped.

## Capability boundaries (honest)

| Scenario | Frontend libapp.so | Backend libgojni.so |
|------|----------------|------------------|
| dev → latest dev | ✓ (dev shares versionCode/engine) | ✓ |
| stable → latest stable (engine unchanged) | ✓ (engine key equal, cross versionCode) | ✓ (no versionCode) |
| stable with a Flutter engine upgrade | ✗ → full APK (it's a new engine/new APK anyway) | ✓ (independent of gomobile surface) |
| mobile.go export surface changed / native plugin added | ✗ full APK | ✗ full APK (blocked by the guard) |

- Android only; backend patch is checked only on Bundle builds (`hasEmbeddedBackend`) in local mode with the backend running. iOS static xcframework + Apple policy → unsupported.

## Feasibility basis (native mechanism)

- `libgojni.so` is lazily loaded by gomobile's `go.Seq` static block `System.loadLibrary("gojni")` on the first touch of any `mobile.*` class.
- `SongloftApplication.onCreate()` (before any `mobile.*`) `System.load("<filesDir>/backend_patch/active/libgojni.so")` preloads the patched build; bionic dedups by ELF `DT_SONAME`, so the later `loadLibrary("gojni")` reuses it. Precondition: `DT_SONAME == libgojni.so` (asserted in release.yml via `readelf -d`).
- W^X: on targetSdk 29+, `System.load()` of a downloaded `.so` from app-private storage is allowed (the restriction targets `execve` and text-relocation `.so`).
- Must cold-restart the process (Go runtime inits once per process); `SystemNavigator.pop()` only finishes the Activity → use `ProcessRestarter` (AlarmManager + killProcess).

## Client flow (unified entry)

The home page calls `PatchUpdateDialog.maybeShow` once per session in `initState` (`lib/core/updater/`):
1. Check frontend (`PatchUpdateService.checkPatch`) + backend (`BackendPatchService.checkPatch`, only when `hasEmbeddedBackend && Android && local && backend running`) latest-of-channel patches in parallel, each filtered by "ignore this version".
2. If either has an update → **one** dialog lists the pending components + a GitHub proxy selector (reusing `GithubProxySelectionMixin`), buttons **[Ignore this version] [Later] [Download & update]**.
3. "Download & update" downloads all together (frontend `flutter_patcher.applyPatch` stages libapp.so; backend `downloadAndStage` downloads the `.so` + md5 + hands it to native `stageBackendPatch`).
4. On completion → "Restart now" does a **single** `EmbeddedBackendService.restartProcess()` (real cold restart), with a "the app will restart, may interrupt playback" note. "Later" keeps everything staged for the next cold start.
5. If the frontend patch is engine-incompatible (a new stable changed Flutter) → checkPatch returns null → falls into the full-APK "incompatible" branch.

## Crash rollback + blacklist (native `BackendPatchManager`)

State in a plain file `filesDir/backend_patch/state.json` (readable before the Dart engine). `preloadIfStaged`: no active / blacklisted → don't preload (roll back to bundled); `confirmed` → `System.load` directly; `staged/pending` → `bootAttempts++`, over threshold (>1) means boot-crash → blacklist (gitCommit+md5) + clear active + roll back; `System.load` throws → blacklist + roll back immediately, never crash the process. Confirm timing: after the backend is healthy in the new process (`startup_gate` cold start / `backend_lifecycle` resume), `BackendPatchService.confirmIfHealthy()` verifies `/api/v1/version` git_commit matches → `confirmBackendPatch()`.

## Manifest convention (Release assets, per ABI)

- Frontend `manifest-<abi>.json`: `{hasUpdate, patch:{version(patchLabel), semanticVersion, gitCommit, flutterBinding, patchUrl, md5}}`
- Backend `backend-manifest-<abi>.json`: `{hasUpdate, backend:{abi, version, gitCommit, buildTime, soUrl, md5, size}}` (no targetVersionCode)
- Both auto-uploaded with the `release.yml` release (tag = dev / v<x.y.z>); the client resolves the latest of its channel.

## Release discipline

- Every release ships patches automatically, no extra steps; the **export-surface guard** (`go doc ./mobile` vs `mobile/export_surface.txt`) in `release.yml` fails on drift (must go full APK).
- Changing the Flutter version → old frontend builds auto-fall to full APK (engine key mismatch); changing mobile.go's export surface / adding native plugins → full APK.

## Verification

1. **dev any → latest**: an old dev build → one dialog lists frontend + backend → one download → single restart → `/api/v1/version` git_commit becomes latest + frontend change visible → confirm.
2. **stable any → latest (engine unchanged)**: an old stable build → backend updates to the latest stable by version number; frontend engine key equal → also updates.
3. **stable engine changed**: frontend engine key mismatch → frontend goes full APK; backend still hot-updates.
4. **Crash rollback**: a bad `.so` → System.load/Init crash → bootAttempts over threshold → blacklist + roll back, no longer offered.
5. **No versionCode dependency**: the backend never compares versionCode; the CI `readelf` + export-surface guard are the only backend gates.

## Notes

- Google Play and some channels may restrict dynamic delivery of `.so`; this project targets self-controlled / sideload distribution.
- **Standard (non-bundle) is baseline-free too**: the player repo's `build-and-release.yml` `build-android` job auto-produces frontend `patch-<abi>.zip`+`manifest` on every release (no backend); the manual `patch-release.yml` has been removed. The client remains backward-compatible with legacy manifests (falls back to hasUpdate + versionCode binding when the new fields are absent).
