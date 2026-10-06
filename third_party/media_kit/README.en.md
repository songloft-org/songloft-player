# Local media_kit initialization patch

[中文](README.md)

Source: `media_kit 1.2.6` from pub.dev, maintained upstream at <https://github.com/media-kit/media-kit>. The MIT `LICENSE` is preserved. This directory contains the runtime `lib/`, `assets/`, package metadata, and license; screenshots and examples are omitted, with the screenshot declarations removed from the manifest.

The client references this directory through `dependency_overrides.media_kit.path` in `pubspec.yaml`. Do not edit the global pub cache. CI, standard clients, and bundled clients must all resolve this source.

## Patch scope

Issue: <https://github.com/songloft-org/songloft-player/issues/49>.

- `lib/src/player/native/core/mpv_initialization.dart`: checks the created handle for NULL, checks the result of `mpv_initialize()`, and destroys failed contexts. Diagnostics identify the failing API and the libmpv error.
- `initializer_native_callable.dart` and `initializer_isolate.dart`: share this initialization logic, release the context and callback if callback registration fails, send isolate failures and stack traces to the caller, close failed workers, and close the receive port if worker creation fails.
  Event callback errors are logged as on the isolate path, preventing events already queued during failed initialization from producing unhandled Future errors.
- `lib/src/player/native/player/real.dart`: forwards initialization failures to `waitForPlayerInitialization`, avoids unhandled Future errors, and allows failed creation to release Dart resources without accessing a NULL context. If creation succeeds but subsequent configuration fails, callbacks and native resources are also released.

The Linux `LC_NUMERIC=C` fix lives in the application's `linux/runner/`. Client error conversion and failed instance cleanup live in `lib/core/audio/`.

## Validation and upgrades

Run from the client root:

```bash
flutter pub get
flutter test test/core/audio/mpv_initialization_test.dart
flutter analyze
```

On Linux, tests build a failure injection shared library with GCC and call it through Dart FFI. They cover NULL creation, initialization failure, success, cleanup, and client retries for both initialization paths without requiring audio hardware.

With GTK/libmpv development packages, CMake, Xvfb, `xvfb-run`, and xauth installed, test the locale fix and audio decoding against real libraries (`ao=null` requires no audio hardware):

```bash
cmake -S test/native/linux -B /tmp/songloft-mpv-locale
cmake --build /tmp/songloft-mpv-locale
ctest --test-dir /tmp/songloft-mpv-locale -V
```

Tests cover C, C.UTF-8, en_US.UTF-8, and zh_CN.UTF-8. On glibc systems, install or generate these locales first so that non-C locales are actually exercised.

When upgrading upstream, compare the patched files with the original pub.dev package, preserve the license and Web assets, and rerun validation. Once upstream provides the complete safeguards, the local override can be removed; retain the Linux locale fix. A NULL check alone is insufficient without isolate error propagation and initialization Future handling.
