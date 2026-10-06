/// Songloft initialization safeguards for media_kit 1.2.6 (#49).
/// Upstream media_kit is distributed under the MIT license; see LICENSE.
import 'dart:ffi';

import 'package:media_kit/ffi/ffi.dart';
import 'package:media_kit/generated/libmpv/bindings.dart' as generated;

/// Creates and initializes a handle before any callbacks are registered.
/// The caller owns the returned handle; failed handles are destroyed here.
Pointer<generated.mpv_handle> createMpvContext(
  generated.MPV mpv,
  Map<String, String> options,
) {
  final ctx = mpv.mpv_create();
  if (ctx == nullptr) {
    throw StateError(
      'mpv_create() returned NULL. Ensure LC_NUMERIC is C on Linux; '
      'also check system resource limits and libmpv diagnostics on stderr.',
    );
  }

  try {
    for (final entry in options.entries) {
      final name = entry.key.toNativeUtf8();
      final value = entry.value.toNativeUtf8();
      try {
        mpv.mpv_set_option_string(ctx, name.cast(), value.cast());
      } finally {
        calloc.free(name);
        calloc.free(value);
      }
    }
    final result = mpv.mpv_initialize(ctx);
    if (result < 0) {
      final error = mpv.mpv_error_string(result);
      final message = error == nullptr
          ? 'unknown error'
          : error.cast<Utf8>().toDartString();
      throw StateError('mpv_initialize() failed: $message ($result).');
    }
    return ctx;
  } catch (_) {
    mpv.mpv_destroy(ctx);
    rethrow;
  }
}
