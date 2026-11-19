# Bundle Android Hot Update (frontend libapp.so + backend libgojni.so)

This doc describes songloft-player's **self-hosted Android hot update** in Bundle local mode: **baseline-free** — any non-latest dev updates to the latest dev, any non-latest stable to the latest stable. Standard and Bundle packages share this repository's Release, with distinct Bundle manifest and patch prefixes. **Every release auto-publishes** the latest patches as Release assets; the client checks on startup, downloads once, and restarts once: a single real cold restart makes both the frontend `libapp.so` (flutter_patcher) and the backend `libgojni.so` (gomobile) take effect.

> Bilingual: any change here must be mirrored in `docs/cn/backend_hotupdate.md`.

## Core model: baseline-free + auto-publish + toolchain compatibility key

- **Baseline-free**: the client fetches the **latest of its channel** — dev → rolling tag `dev`; stable → GitHub `/releases/latest` (dev is a prerelease, so latest returns the newest stable). Resolved by `lib/core/updater/channel_release_resolver.dart`, reusing `FrontendVersionApi`'s approach.
- **Auto-publish**: this repository's `build-and-release.yml` Android job produces and uploads Bundle frontend `bundle-patch-<abi>-<commit>.zip`+`bundle-manifest-<abi>.json` and backend `bundle-libgojni-<abi>-<backend-sha>.so`+`bundle-backend-manifest-<abi>.json` on every release (arm64-v8a / armeabi-v7a / x86_64; gomobile bind includes android/amd64). **No manual workflow, no versionCode binding.**
- **Compatibility key instead of versionCode** (automatic, not hand-edited):
  - **Frontend libapp.so**: flutter_patcher inherently binds by **versionCode** (libapp.so ↔ engine). With `--split-per-abi` gradle rewrites each ABI APK's versionCode to "ABI offset × 1000 + pubspec base" (e.g. arm64-v8a = 2001), so CI reads the **real value** from the per-ABI APK via aapt and writes it into the manifest/patch; this project's pubspec `+N` is **constant** (CI does not bump it per build), so old and new builds of the same ABI share the same versionCode and natural binding already allows cross-version hot update — versionCode is an **automatic compatibility proxy, not a hand-picked baseline**. The client additionally compares `AppConfig.flutterBinding` (= CI `FLUTTER_VERSION`) with the manifest's `flutterBinding`: different → not hot-patchable (guards against same versionCode but a changed Flutter engine crashing) → full-APK branch. Only a deliberate pubspec `+N` bump (usually alongside engine/native changes) forces the frontend to full APK.
  - **Backend libgojni.so**: the boundary is the gomobile export surface (`mobile/export_surface.txt` + the `release.yml` guard, automatic). **versionCode dropped**; safety comes from "frozen export surface + crash rollback/blacklist", so any old build updates to the latest.
- **Comparison**: dev by **git commit hash**; stable by **version number** (semver, `lib/core/updater/version_compare.dart`). Already-applied (`flutter_patcher.currentVersion == patchLabel` / backend confirmed) is skipped.

## Native contract hash gate (runtime Dart↔native / Go export-surface check)

Hot update only swaps the native .so; **Kotlin/Java is never hot-updated** (it ships only with the full APK). The versionCode and `flutterBinding` gates cannot catch **Dart↔native MethodChannel contract drift**: if a release adds a method to some `com.songloft/*` channel (Kotlin side + Dart call) without touching the engine or versionCode, both existing gates pass → an old build hot-patches to the new `libapp.so`, but the device's old Kotlin lacks that method → runtime `MissingPluginException`. This is worst on the dev channel: a single rolling release, and git commit differs every time, so it cannot distinguish "a normal new version" from "a contract-incompatible one". The standard build has no backend bridge yet still hot-patches `libapp.so`, so its exposure is even larger (custom channels + many native plugins).

**The only signal that faithfully reflects "what the installed APK's native layer supports" must be read at runtime from the never-hot-updated Kotlin** (any Dart/Go constant gets overwritten by the patch). Hence the native contract hash gate:

- **Two hashes**, returned together by the native channel `com.songloft/contract`'s `getHash` as `{"dart","go"}`:
  - `dart` = the Dart↔native contract = {all `com.songloft/*` channel names + method-name set + the `GeneratedPluginRegistrant` plugin set + android native plugin name+version from `.flutter-plugins-dependencies` + release ProGuard rules}. Gates the **frontend libapp.so** (both standard and bundle). ProGuard changes that alter JNI descriptors also require a full APK; comment-only and blank-line changes do not affect the hash.
  - `go` = `sha256(mobile/export_surface.txt)`. Gates the **backend libgojni.so** (bundle only), closing the "old-APK Kotlin vs new libgojni runtime skew" that the CI export-surface freeze guard cannot see.
- **Value source**: CI computes it deterministically via `scripts/compute_native_contract.sh` before `flutter build apk`, writing it both into the APK asset `android/app/src/main/assets/native_contract.json` (read back by Kotlin) and into the hot-update manifest (`patch.contractHash` / `backend.contractHash`) — **same source, same value**.
- **Comparison**: `checkPatch` uses `contractHashBlocks(manifestHash, deviceHash)` — both non-empty and different → return null (full APK). **Either empty** (old host without the channel / local dev without the asset / legacy manifest without the field) → treated as unknown, **not blocked** (graceful degradation), same as the `flutterBinding` gate.
- **iOS not involved**: hot update is Android-only; `NativeContractService`'s `_isAndroid` guard means iOS never triggers it.
- **Residual risk (honest)**: the Kotlin method set is parsed heuristically (`call.method == "x"` / `when` branch `"x" ->`); dynamically-composed method names may be missed, and a plugin's "same version but changed internal native impl" is not captured. Over-inclusive by design (a false trigger only means an extra full APK = safe side), in exchange for a zero-maintenance descriptor.

## Capability boundaries (honest)

| Scenario | Frontend libapp.so | Backend libgojni.so |
|------|----------------|------------------|
| dev → latest dev | ✓ (dev shares versionCode/engine) | ✓ |
| stable → latest stable (engine unchanged) | ✓ (engine key equal, cross versionCode) | ✓ (no versionCode) |
| stable with a Flutter engine upgrade | ✗ → full APK (it's a new engine/new APK anyway) | ✓ (independent of gomobile surface) |
| `com.songloft/*` channel method set changed / native plugin added-removed | ✗ full APK (dart contract hash mismatch) | —— |
| mobile.go export surface changed | ✗ full APK (unaffected frontend still hot-patchable) | ✗ full APK (guard + go contract hash, both block) |

- Android only; backend patch is checked only on Bundle builds (`hasEmbeddedBackend`) in local mode with the backend running. iOS static xcframework + Apple policy → unsupported.

### Kotlin layer freeze strategy

`classes.dex` (Kotlin/Java code) cannot be hot-updated, but by **freezing the Kotlin method interface** the contract hash stays unchanged, so routine iterations don't block `libapp.so` hot-updates. Strategy:

1. **Parameter extension first**: new styles/behavior go through existing methods' (`show`/`updateConfig`) argument Maps by adding keys. Kotlin reads via `call.argument` with default fallbacks. Method name set unchanged → hash unchanged.
2. **`exec` escape method**: `FloatingLyricPlugin` has a pre-planted `exec` method. New native capabilities use `exec` + `cmd` parameter. **Key**: sub-command dispatch uses `if/else` (not `when`), because `compute_native_contract.sh`'s grep captures `"x" ->` patterns but not `cmd == "x"` comparisons. Dart-side `exec` returns null when the current APK doesn't support the command (graceful degradation, no crash).
3. **Pure Dart plugins preferred**: adding/removing Flutter plugins with native code changes `GeneratedPluginRegistrant` → hash changes. Use Dart-only implementations when possible.

Capability boundary changes after freeze:

| Scenario | Hot-updatable? |
|------|-----------|
| FloatingLyric new style params (font size/color/alignment) | ✓ via `updateConfig` argument Map |
| FloatingLyric new native capability (exec sub-command) | ✓ works when APK contains the sub-command, degrades otherwise |
| New Kotlin→Dart reverse callbacks | ✓ `channel.invokeMethod` not captured by hash script |
| Widget new data fields | ✓ SharedPreferences keys don't affect hash |
| Adding/removing Flutter plugins with native code | ✗ still requires full APK |

See `songloft-player/AGENTS.md` "Kotlin 层冻结规则" for enforcement details.

## Feasibility basis (native mechanism)

- `libgojni.so` is lazily loaded by gomobile's `go.Seq` static block `System.loadLibrary("gojni")` on the first touch of any `mobile.*` class.
- `SongloftApplication.onCreate()` (before any `mobile.*`) `System.load("<filesDir>/backend_patch/active/libgojni.so")` preloads the patched build; bionic dedups by soname, so the later `loadLibrary("gojni")` reuses it. **gomobile output has no DT_SONAME** (normal); bionic (minSdk 24 ≥ API 23) falls back to the **file basename** as the soname, and the client stages the file as `libgojni.so`, so dedup still holds. release.yml only checks "soname is empty or exactly libgojni.so" (fails only on a non-empty, different soname).
- W^X: on targetSdk 29+, `System.load()` of a downloaded `.so` from app-private storage is allowed (the restriction targets `execve` and text-relocation `.so`).
- Must cold-restart the process (Go runtime inits once per process); `SystemNavigator.pop()` only finishes the Activity → use `ProcessRestarter` (AlarmManager + killProcess).

## Client flow (unified entry)

`ShellLayout.initState` calls `PatchUpdateDialog.maybeShow` once per session (`lib/core/updater/`). **In the Shell, not the home page**: the Shell stays mounted for the whole session (so it can't be disposed during the delay), and both `HomePage` and `TvHomePage` live under it, which covers TV mode too.

**Three gates on the startup path** (in order; any of them blocking means a silent early return with zero network requests):
1. **Toggle**: "Settings → About & updates → Check for updates on startup" (`autoUpdateCheckProvider`, prefs `auto_update_check_enabled`, on by default).
2. **Throttle**: skip when the last check was less than `kPatchCheckThrottle` ago (6h, prefs `last_patch_check_at`). The timestamp is deliberately written **before** the check starts — `checkPatch` swallows network errors into `null`, so callers can't tell "no patch" from "check failed"; better to wait out one window after a failure than to burn a full round on every cold start on a weak network, with the manual entry as the escape hatch.
3. **Delay + timeout**: fire `kPatchCheckStartupDelay` (4s) after the first frame so the home page's playlist/radio requests land first; the check phase itself is wrapped in a 20s overall timeout.

> **The gate order is "wait for auth, then wait for the delay" — do not fall back to checking only `mounted`.** When not signed in, `/login` sits outside the ShellRoute, but the Shell still mounts briefly before auth state settles and is then disposed by the redirect. Checking only `mounted` is a race, not a causal guarantee: when auth resolution outlasts the delay (Web `secure_storage` over IndexedDB, a cold Keychain, slow devices) that short-lived mount consumes the session's only check slot, burns the throttle window, and runs the check with a token-less dio against the backend's `/settings/github-proxy`. So it uses `ref.listenManual(authStateProvider)` and only arms the delay once `AuthStatus.authenticated` arrives (the same shape as the sibling `_scheduleAutoEnterLyrics` waiting on playback restore), and the delay is a **cancellable `Timer`** rather than `Future.delayed` — only a handle can be cancelled in `dispose`, otherwise a short-lived mount pins the disposed State subtree for one extra delay period and any future widget test that pumps the Shell hits "A Timer is still pending".

**Manual entry**: "Settings → About & updates → Check for client updates" (merged with the full-package update into one tile) calls `maybeShow(manual: true)` — it skips the toggle and throttle, **bypasses the "ignore this version" list** (it only skips the filter for this call; the `ignored_*` records are not cleared), and does not write the throttle timestamp. With no patch it skips the full-package check and lets the caller fall back to `FrontendUpgradeDialog`, which already renders "checking / up to date / failed", so no extra snackbar is needed. The gate semantics are covered by `test/core/updater/patch_update_dialog_gates_test.dart`.

**Roll the throttle timestamp back when a patch was found but couldn't be shown**: when `context.mounted` is false (the user signed out or left the settings page mid-check) the discovery has to be dropped, but the timestamp must be restored to its previous value — otherwise one unlucky unmount suppresses a genuinely available patch for a whole throttle window. That branch logs its own message; do not let it fall through to the "no hot patch" line, which would mislead anyone debugging it.

**Known gaps (pre-existing, not introduced here)**: the tile hosting the manual entry sits *inside* the `AppConfig.isEmbedded` guard while the toggle sits *outside* it, so on embedded builds users can disable the automatic check but have no manual entry — which is why the toggle's subtitle deliberately does not promise "check manually when off". Also, once a version is ignored, the manual entry keeps surfacing that patch dialog first and therefore can't reach the full-package version info.

Once the gates pass:
1. Check frontend (`PatchUpdateService.checkPatch`) + backend (`BackendPatchService.checkPatch`, only when `hasEmbeddedBackend && Android && local && backend running`) latest-of-channel patches in parallel, each filtered by "ignore this version" (not filtered when `manual`).
2. If either has an update → **one** dialog lists the pending components + a GitHub proxy selector (reusing `GithubProxySelectionMixin`), buttons **[Ignore this version] [Later] [Download & update]**.
3. "Download & update" downloads all together (frontend `flutter_patcher.applyPatch` stages libapp.so; backend `downloadAndStage` downloads the `.so` + md5 + hands it to native `stageBackendPatch`).
4. On completion → "Restart now" does a **single** `EmbeddedBackendService.restartProcess()` (real cold restart), with a "the app will restart, may interrupt playback" note. "Later" keeps everything staged for the next cold start.
5. If the frontend patch is engine-incompatible (a new stable changed Flutter) → checkPatch returns null → falls into the full-APK "incompatible" branch.

## Crash rollback + blacklist (native `BackendPatchManager`)

State in a plain file `filesDir/backend_patch/state.json` (readable before the Dart engine). `preloadIfStaged`: no active / blacklisted → don't preload (roll back to bundled); `confirmed` → `System.load` directly; `staged/pending` → `bootAttempts++`, over threshold (>1) means boot-crash → blacklist (gitCommit+md5) + clear active + roll back; `System.load` throws → blacklist + roll back immediately, never crash the process. Confirm timing: after the backend is healthy in the new process (`startup_gate` cold start / `backend_lifecycle` resume), `BackendPatchService.confirmIfHealthy()` verifies `/api/v1/version` git_commit matches → `confirmBackendPatch()`.

## Manifest convention (songloft-player Release assets, per ABI)

- Standard frontend uses `manifest-<abi>.json`; Bundle uses `bundle-manifest-<abi>.json`. Both contain `{hasUpdate, patch:{version(patchLabel), semanticVersion, gitCommit, flutterBinding, contractHash, targetVersionCode, patchUrl, md5}}`.
- Bundle backend uses `bundle-backend-manifest-<abi>.json` with `{hasUpdate, backend:{abi, version, gitCommit, buildTime, soUrl, md5, contractHash, size}}` (no `targetVersionCode`).
- The Flutter client repository builds Bundle assets. CI resolves the latest root `main` commit and its version at startup. All platforms use that SHA, and the gomobile version comes from its `go.mod`.
- Assets are uploaded with this repository's release (tag = dev / v<x.y.z>); the client resolves the latest of its channel.

## Release discipline

- Every release ships patches automatically, no extra steps; the **export-surface guard** (`go doc ./mobile` vs `mobile/export_surface.txt`) in the client build workflow fails on drift (must go full APK).
- Changing the Flutter version → old frontend builds auto-fall to full APK (engine key mismatch); changing mobile.go's export surface / adding native plugins → full APK.
- **Native contract hash is fully automatic**: `scripts/compute_native_contract.sh` recomputes the asset + manifest on every build, with no hand-maintained version number or descriptor. Changing a `com.songloft/*` channel method set / adding-removing a native plugin → the dart hash changes automatically, and old builds reading a mismatch auto-fall to full APK; an export-surface change → the go hash changes automatically. **No constant needs bumping.**

## Verification

1. **dev any → latest**: an old dev build → one dialog lists frontend + backend → one download → single restart → `/api/v1/version` git_commit becomes latest + frontend change visible → confirm.
2. **stable any → latest (engine unchanged)**: an old stable build → backend updates to the latest stable by version number; frontend engine key equal → also updates.
3. **stable engine changed**: frontend engine key mismatch → frontend goes full APK; backend still hot-updates.
4. **Crash rollback**: a bad `.so` → System.load/Init crash → bootAttempts over threshold → blacklist + roll back, no longer offered.
5. **No versionCode dependency**: the backend never compares versionCode; the CI `readelf` + export-surface guard are the only backend gates.

## Notes

- Google Play and some channels may restrict dynamic delivery of `.so`; this project targets self-controlled / sideload distribution.
- **Standard (non-bundle) is baseline-free too**: the player repo's `build-and-release.yml` `build-android` job auto-produces frontend `patch-<abi>-<commit>.zip`+`manifest` on every release (no backend); the manual `patch-release.yml` has been removed. The client remains backward-compatible with legacy manifests (falls back to hasUpdate + versionCode binding when the new fields are absent).
