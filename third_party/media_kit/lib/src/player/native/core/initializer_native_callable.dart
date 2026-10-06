/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
import 'dart:collection';
import 'dart:ffi';

import 'package:media_kit/generated/libmpv/bindings.dart' as generated;
import 'package:media_kit/src/player/native/core/mpv_initialization.dart';
import 'package:synchronized/synchronized.dart';

/// {@template initializer_native_callable}
///
/// InitializerNativeCallable
/// -------------------------
/// Initializes [Pointer<mpv_handle>] & notifies about events through the supplied callback.
///
/// {@endtemplate}
class InitializerNativeCallable {
  /// Singleton instance.
  static InitializerNativeCallable? _instance;

  /// {@macro initializer}
  InitializerNativeCallable._(this.mpv);

  /// {@macro initializer}
  factory InitializerNativeCallable(generated.MPV mpv) {
    _instance ??= InitializerNativeCallable._(mpv);
    return _instance!;
  }

  /// Generated libmpv C API bindings.
  final generated.MPV mpv;

  /// Creates [Pointer<mpv_handle>].
  Future<Pointer<generated.mpv_handle>> create(
    Future<void> Function(Pointer<generated.mpv_event>) callback, {
    Map<String, String> options = const {},
  }) async {
    final ctx = createMpvContext(mpv, options);
    WakeUpNativeCallable? nativeCallable;
    try {
      nativeCallable = WakeUpNativeCallable.listener(_callback);
      final nativeFunction = nativeCallable.nativeFunction;
      _locks[ctx.address] = Lock();
      _eventCallbacks[ctx.address] = callback;
      _wakeUpNativeCallables[ctx.address] = nativeCallable;
      mpv.mpv_set_wakeup_callback(ctx, nativeFunction.cast(), ctx.cast());
      return ctx;
    } catch (_) {
      _locks.remove(ctx.address);
      _eventCallbacks.remove(ctx.address);
      _wakeUpNativeCallables.remove(ctx.address);
      nativeCallable?.close();
      mpv.mpv_destroy(ctx);
      rethrow;
    }
  }

  /// Disposes [Pointer<mpv_handle>].
  void dispose(Pointer<generated.mpv_handle> ctx) {
    _locks.remove(ctx.address);
    _eventCallbacks.remove(ctx.address);

    // Clear the wakeup callback in libmpv before closing NativeCallable
    // to prevent libmpv from invoking a deleted callback
    mpv.mpv_set_wakeup_callback(ctx, nullptr, nullptr);

    _wakeUpNativeCallables.remove(ctx.address)?.close();
  }

  void _callback(Pointer<generated.mpv_handle> ctx) {
    _locks[ctx.address]?.synchronized(() async {
      while (true) {
        final event = mpv.mpv_wait_event(ctx, 0);
        if (event == nullptr) return;
        if (event.ref.event_id == generated.mpv_event_id.MPV_EVENT_NONE) return;
        try {
          await _eventCallbacks[ctx.address]?.call(event);
        } catch (exception, stacktrace) {
          // idle-active may already be queued when _create fails. Match the
          // isolate path: report callback errors while the caller cleans up.
          print(exception.toString());
          print(stacktrace.toString());
        }
      }
    });
  }

  final _locks = HashMap<int, Lock>();
  final _eventCallbacks = EventCallbackMap();
  final _wakeUpNativeCallables = WakeUpNativeCallableMap();
}

typedef WakeUpCallback = Void Function(Pointer<generated.mpv_handle>);
typedef WakeUpNativeCallable = NativeCallable<WakeUpCallback>;
typedef WakeUpNativeCallableMap = HashMap<int, WakeUpNativeCallable>;

typedef EventCallback = Future<void> Function(Pointer<generated.mpv_event>);
typedef EventCallbackMap = HashMap<int, EventCallback>;
