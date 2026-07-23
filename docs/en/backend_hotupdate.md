# Bundle Android Backend Hot Update (swap libgojni.so)

This doc describes songloft-player's **self-hosted Android hot update for the embedded Go backend** in Bundle local mode: on cold start it replaces the whole gomobile-generated `libgojni.so`, patches are hosted on the **parent repo**'s GitHub Release, with **startup check + manual update**, merged with the frontend [flutter_patcher hot update](./flutter_patcher_hotupdate.md) into a single experience (both `.so` files download together, one restart).

> Bilingual: any change here must be mirrored in `docs/cn/backend_hotupdate.md`.

## Scope & boundaries

| Dimension | Conclusion |
|------|------|
| Platform | **Android only**. iOS backend is a static `.xcframework` linked at compile time and Apple forbids downloading/running native code → unsupported, full app update only; desktop not done this round |
| Applies to | Bundle builds only (`--dart-define=HAS_BACKEND=true`, `AppConfig.hasEmbeddedBackend`) in `local` mode with the backend running; remote mode's backend lives on a server and is not client-patched |
| Hot-patchable | Any internal Go logic (handlers/services/scanner/cache bugfixes) **as long as `mobile.go`'s export surface (`Start/Stop/IsRunning/GetPort`) is unchanged** |
| Not hot-patchable | Changing `mobile.go` export signatures (needs classes.jar/DEX too), native dep changes, gomobile/engine upgrades → ship a new APK. x86_64 has no aar artifact and is not covered |
| When it applies | On the **next cold start** after download (Go runtime inits once per process; no in-process swap); ships pending→confirmed crash rollback + blacklist |
| Channel | **dev updates dev, stable updates stable, no crossing** (tag decided by compile-time `FRONTEND_VERSION`) |
| Version compare | **dev by git commit hash; stable by version number** (semver). See `lib/core/updater/version_compare.dart` |
| Integrity | md5 (client after download + native `System.load` catch) |

## Feasibility basis (native mechanism)

- `libgojni.so` is lazily loaded by gomobile's `go.Seq` static block `System.loadLibrary("gojni")` on the **first touch of any `mobile.*` class**.
- A custom `SongloftApplication.onCreate()` (before any `mobile.*` call) `System.load("<filesDir>/backend_patch/active/libgojni.so")` **preloads the patched build**; the bionic linker dedups by ELF `DT_SONAME`, so the later `loadLibrary("gojni")` reuses the patched copy instead of the APK's bundled one.
- Precondition: the patch `.so`'s `DT_SONAME` must equal `libgojni.so` (Go c-shared satisfies this by default; the release workflow asserts via `readelf -d`).
- W^X: on targetSdk 29+, `System.load()` of a downloaded `.so` from app-private storage is allowed (the restriction targets `execve` of executables and `.so` files with text relocations).

## Client flow (unified with the frontend patch)

Entry: the home page calls `PatchUpdateDialog.maybeShow` once per session in `initState` (`lib/core/updater/`).

1. **Check in parallel**: the frontend flutter_patcher patch (libapp.so) + the backend patch (libgojni.so, `BackendPatchService.checkPatch`).
2. If either has an update and isn't ignored → **one** dialog lists the pending components + a GitHub proxy selector (reusing `GithubProxySelectionMixin`), buttons **[Ignore this version] [Later] [Download & update]**.
3. "Download & update" downloads all available patches together (frontend `flutter_patcher.applyPatch` stages libapp.so; backend `downloadAndStage` downloads the `.so` + md5 + hands it to native `stageBackendPatch`).
4. On completion → "Restart now" performs a **single** `ProcessRestarter` real process restart (libapp.so takes effect + Application preloads libgojni.so), with a "the app will restart, may interrupt playback" note. "Later" keeps everything staged for the next natural cold start.

- Ignore is remembered separately: `AppPreferences.ignoredPatchVersion` (frontend) / `ignoredBackendPatchVersion` (backend).
- The backend's "current version" is read at runtime from `GET /api/v1/version` (`version` / `git_commit`), not a compile-time constant.

## Crash rollback + blacklist (native `BackendPatchManager`)

State lives in a plain file `filesDir/backend_patch/state.json` (must be readable before the Dart engine starts, so not shared_preferences).

- `preloadIfStaged`: no active / blacklisted → don't preload (roll back to bundled); `state=confirmed` → `System.load` directly; `staged/pending` → `bootAttempts++`, over threshold (>1) means boot-crash → blacklist (gitCommit+md5) + clear active + roll back; otherwise mark pending then `System.load`. If `System.load` throws → blacklist + roll back immediately; never crash the process.
- Confirm timing: after the backend starts healthy in the new process (`startup_gate` cold-start path / `backend_lifecycle` resume), call `BackendPatchService.confirmIfHealthy()`; if `/api/v1/version`'s git_commit matches the staged one → `confirmBackendPatch()` (state→confirmed, bootAttempts=0).

## Hosting & URL convention (parent repo Release, per ABI)

Patches are uploaded to the parent repo `songloft-org/songloft` (`AppConfig.frontendUpdateRepo`) Release, same tag as the bundle client (dev / v<x.y.z>).

- Backend manifest: `backend-manifest-<abi>.json`
  - fields: `{hasUpdate, backend:{abi, version, patchLabel, gitCommit, buildTime, targetVersionCode, soUrl, md5, size}}`
  - `targetVersionCode` binds the APK versionCode (locks export surface/classes.jar to the installed APK); mismatches are not offered.
- Backend payload: `libgojni-<abi>.so` in the same Release.
- Companion frontend patch: `manifest-<abi>.json` + `patch-<abi>.zip` at the same tag (so both `.so` files download together).

## Publishing a patch (`.github/workflows/backend-patch-release.yml`, manual)

1. Cherry-pick an **internal-logic-only** fix onto the baseline (dev branch / the stable release's commit), **keeping `mobile.go`'s export surface unchanged**;
2. Dispatch with `target_version` (dev, or a stable base like `2.11.0`), `patch_version` (**stable only**, must be > baseline like `2.11.1`, for version-number comparison; ignored for dev), `patch_label` (e.g. `2.11.1-b1`);
3. Workflow: **export-surface guard** (`go doc ./mobile` vs `mobile/export_surface.txt`, fail on drift) → `make build-go-mobile-android` (`VERSION=<so version>`) → `flutter build apk --split-per-abi` (`FRONTEND_VERSION=<baseline channel>`) → per ABI: `flutter_patcher:pack` for the frontend `patch-<abi>.zip`, extract `libgojni-<abi>.so` from the APK (**assert SONAME=libgojni.so via `readelf -d`**) → write both manifests → `gh release upload <tag> ... --clobber`.

## Release discipline

- **Internal fix (export surface unchanged)** → publish a patch, effective on cold start;
- **Export surface / native dep / engine change** → cut a new tag / new APK (don't patch the old baseline); the guard blocks accidental publishes.
- For a stable patch, bump `patch_version` above the baseline, otherwise the client's version-number comparison won't detect it.

## Verification

1. **Both `.so` together, single restart**: publish frontend + backend patches at the same tag → one dialog lists both → one download → restart once → new process: libapp.so effective + libgojni.so preloaded → `/api/v1/version` git_commit/version becomes new → confirm.
2. **Crash rollback**: publish a patch that panics in Init → apply + restart → early crash → next boot bootAttempts over threshold → blacklist + roll back to bundled → no longer offered.
3. **Silent**: remote mode / standard build / iOS / x86_64 → the backend branch is skipped, frontend flow unaffected.
4. **Channel + compare**: dev only pulls the `dev` tag and compares git hash; stable only pulls `v<x.y.z>` and compares version number; no crossing.
5. **Ignore**: after ignoring, the same patchLabel stops prompting; a newer patchLabel resumes.

## Notes

- Google Play and some channels may restrict dynamic delivery of executable `.so`; this project targets self-controlled / sideload distribution.
- Orthogonal to the frontend flutter_patcher (which swaps libapp.so); they do not affect each other.
