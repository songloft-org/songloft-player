# flutter_patcher Self-Hosted Android Hot Update

This doc describes songloft-player's **self-hosted Android hot update** built on [`flutter_patcher`](https://github.com/xuelinger2333/flutter_patcher): it replaces the whole `libapp.so` on cold start, patches are hosted on your own GitHub Release, with **startup check + manual update**; versions that can't be hot-patched send the user to Settings to download the APK.

> Bilingual: any change here must be mirrored in `docs/cn/flutter_patcher_hotupdate.md`.

## Scope & boundaries

| Dimension | Conclusion |
|------|------|
| Platform | **Android only**. On iOS/desktop/web the plugin and our wrapper are safe no-ops |
| Hot-patchable | Any Dart under `lib/`, pure-Dart deps, bundled-registered Flutter assets |
| Not hot-patchable | Native Kotlin/Java/C++, `AndroidManifest`, `res/`, native plugin add/change, Flutter Engine upgrades — must ship a new APK |
| When it applies | On the **next cold start** after download, never in-process; the plugin has crash rollback + bad-patch blacklist |
| Channel | **dev updates dev, stable updates stable, no crossing** (decided by compile-time `FRONTEND_VERSION`) |
| Integrity | Currently **MD5 only** (`FlutterPatcher.init(strictSignature: false)`); Ed25519 can be added later |

## Key bindings

- **versionCode binding**: a patch is bound to the host APK's `versionCode` (= pubspec `version`'s `+N`). One release tag = one versionCode; a patch must be packed with the **same versionCode** and only applies to devices running that APK.
- **ABI sharding**: APKs are split-per-abi, so a patch is produced per `arm64-v8a / armeabi-v7a / x86_64`; the client picks `manifest-<abi>.json` by `FlutterPatcher.deviceAbi`.

## Client flow (startup check + manual)

Entry: the home page calls `PatchUpdateDialog.maybeShow` once per session in `initState` (`lib/core/updater/`).

1. **Matching patch** (and not "ignored") → a **dismissible** dialog with a **GitHub proxy selector** (reusing `GithubProxySelectionMixin`) + buttons **[Ignore this version] [Later] [Download & update]**; download shows progress → on success a "restart to apply" dialog ([Restart now] = `SystemNavigator.pop()`).
2. **No patch but a newer full version on the same channel** (`FrontendVersionApi`, not ignored) → "New version required" dialog → **[Ignore] [Later] [Go to download]**; go-to-download navigates to `/settings` (which has the client-update APK download).
3. Neither → silent.

- Proxy: both the manifest fetch and the patch download go through the selected proxy (`PatchUpdateService.applyProxy`, prefix concat); the choice persists to `githubProxyProvider`, shared with the plugin store / full-package upgrade.
- Ignore: remembered separately in `AppPreferences.ignoredPatchVersion / ignoredClientVersion`.

## Hosting & URL convention

Patches are uploaded as assets to the **corresponding version's GitHub Release** (this phase: standard client only, repo `songloft-org/songloft-player`; the Bundle build is deferred — later just upload to the parent repo's Release, the client switches automatically via `AppConfig.frontendUpdateRepo`, no code change).

- manifest: `https://github.com/<repo>/releases/download/<tag>/manifest-<abi>.json`
  - stable: `<tag>` = `v<version>`; dev: `<tag>` = `dev`
  - content is `PatchCheckResult` shaped: `{"hasUpdate":true,"patch":{"version","patchUrl","md5","targetVersionCode"}}`
- patch package: `patch-<abi>.zip` in the same Release

## Publishing a patch (`.github/workflows/patch-release.yml`, manual)

1. Cherry-pick a **Dart-only** fix onto the target version's code, **keeping pubspec versionCode unchanged**;
2. Dispatch `Patch Release` with `target_version` (stable: version like `2.11.0`; dev: `dev`) and `patch_label` (e.g. `2.11.0-h1`);
3. The workflow runs `flutter build apk --release --split-per-abi` (FRONTEND_VERSION kept at the baseline channel value) → for each ABI `dart run flutter_patcher:pack --apk <abi apk> --version <label> --target-version-code <vc> --abi <abi>` → produces `patch-<abi>.zip` + `manifest-<abi>.json` (md5 over the zip) → `gh release upload <tag> ... --clobber`.

## Release discipline

- **Dart-only fix** → publish a patch (no new tag); users hot-update, effective on restart;
- **Native / plugin-native / engine change** → cut a new tag / new APK (do not patch the old baseline); users are guided to download the APK.

## Verification

1. `flutter analyze` passes; `flutter build apk --release --split-per-abi` succeeds.
2. Install an ABI's APK on a real device, note the versionCode.
3. Change one visible Dart thing, publish a patch for that versionCode via `patch-release.yml` (or locally with `dart run flutter_patcher:pack` + `flutter_patcher:mock_server`).
4. Open the app → "Update available" dialog → pick proxy → download → restart → see the change = success.
5. Incompatible path: cut a higher release tag without a patch → opening the app shows "New version required" → navigates to `/settings`.
6. After "Ignore this version" the same version stops prompting; a higher version resumes prompting.

## Notes

- **Google Play and some channels** may restrict dynamic delivery of executable `.so`; this project targets self-controlled / sideload distribution.
- flutter_patcher is beta; validate internally before staged rollout.
- Requirements (already met): AGP 8.11.1+ / Kotlin 2.2.20+ / Java 17 / minSdk 24 / compileSdk 36 / NDK 27+.
