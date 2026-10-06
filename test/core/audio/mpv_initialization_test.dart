import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit/generated/libmpv/bindings.dart' as generated;
import 'package:media_kit/src/player/native/core/initializer_isolate.dart';
import 'package:media_kit/src/player/native/core/initializer_native_callable.dart';
import 'package:media_kit/src/player/native/core/native_library.dart';

// 项目约定测试也使用相对路径引用客户端源码。
// ignore: avoid_relative_lib_imports
import '../../../lib/core/audio/songloft_just_audio_platform.dart';

// Keep the isolate computation outside main's scope so that its closure cannot
// capture the parent's unsendable DynamicLibrary/MPV values.
Future<void> _registerBrokenCallbackInIsolate(String path) =>
    Isolate.run(() async {
      final library = DynamicLibrary.open(path);
      Pointer<T> lookup<T extends NativeType>(String name) {
        if (name == 'mpv_set_wakeup_callback') {
          throw StateError('injected callback registration failure');
        }
        return library.lookup<T>(name);
      }

      final bindings = generated.MPV.fromLookup(lookup);
      await InitializerNativeCallable(bindings).create((_) async {});
    });

void main() {
  if (!Platform.isLinux) return;

  late Directory temporary;
  late String libraryPath;
  late generated.MPV mpv;
  late void Function(int) reset;
  late int Function(int) count;
  late void Function() triggerEvent;

  setUpAll(() async {
    temporary = await Directory.systemTemp.createTemp('songloft-mpv-test-');
    libraryPath = '${temporary.path}/libfake_mpv.so';
    final result = await Process.run('gcc', [
      '-shared',
      '-fPIC',
      '-Wall',
      '-Wextra',
      '-Werror',
      'test/native/linux/fake_mpv.c',
      '-o',
      libraryPath,
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    final library = DynamicLibrary.open(libraryPath);
    mpv = generated.MPV(library);
    reset = library.lookupFunction<Void Function(Int), void Function(int)>(
      'fake_mpv_reset',
    );
    count = library.lookupFunction<Int Function(Int), int Function(int)>(
      'fake_mpv_count',
    );
    triggerEvent = library.lookupFunction<Void Function(), void Function()>(
      'fake_mpv_trigger_event',
    );
    NativeLibrary.ensureInitialized(libmpv: libraryPath);
  });

  tearDownAll(() async => temporary.delete(recursive: true));

  for (final useIsolate in [false, true]) {
    final name = useIsolate ? 'isolate' : 'native callable';

    Future<Pointer<generated.mpv_handle>> create() => (useIsolate
            ? InitializerIsolate().create((_) async {}, options: {'vid': 'no'})
            : InitializerNativeCallable(
              mpv,
            ).create((_) async {}, options: {'vid': 'no'}))
        .timeout(const Duration(seconds: 5));

    test('$name: NULL fails without accessing the handle', () async {
      reset(1);
      await expectLater(
        create(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('mpv_create() returned NULL'),
          ),
        ),
      );
      expect(
        [count(0), count(1), count(2), count(3), count(4)],
        [1, 0, 0, 0, 0],
      );
    });

    test('$name: initialization failure destroys the handle once', () async {
      reset(2);
      await expectLater(
        create(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('injected initialization failure'),
          ),
        ),
      );
      expect(
        [count(0), count(1), count(2), count(3), count(4)],
        [1, 1, 1, 1, 0],
      );
    });

    test('$name: success returns a usable handle', () async {
      reset(0);
      final handle = await create();
      expect(handle, isNot(nullptr));
      expect([count(0), count(1), count(2), count(3)], [1, 1, 1, 0]);
      if (useIsolate) {
        InitializerIsolate().dispose(mpv, handle);
        // Allow the worker to acknowledge disposal before resetting the fixture.
        await Future<void>.delayed(const Duration(milliseconds: 200));
      } else {
        expect(count(4), 1);
        InitializerNativeCallable(mpv).dispose(handle);
      }
      mpv.mpv_destroy(handle);
      expect(count(3), 1);
    });
  }

  for (final mode in [1, 2]) {
    test(
      'Player initialization failure is awaitable and disposable ($mode)',
      () async {
        reset(mode);
        final player = Player();
        await expectLater(
          player.platform!.waitForPlayerInitialization.timeout(
            const Duration(seconds: 5),
          ),
          throwsStateError,
        );
        await player.dispose().timeout(const Duration(seconds: 5));
        expect(count(3), mode == 1 ? 0 : 1);
      },
    );

    test(
      'client reports initialization failure and permits retry ($mode)',
      () async {
        final platform = SongloftJustAudioPlatform.instance;
        for (var attempt = 0; attempt < 2; attempt++) {
          reset(mode);
          await expectLater(
            platform
                .init(InitRequest(id: 'failed-player'))
                .timeout(const Duration(seconds: 5)),
            throwsA(
              isA<PlatformException>().having(
                (e) => e.code,
                'code',
                'audio_initialization_failed',
              ),
            ),
          );
          expect(platform.firstPlayer, isNull);
          expect(platform.firstVideoController, isNull);
          expect(count(3), mode == 1 ? 0 : 1);
        }
      },
    );
  }

  test(
    'event callback failures do not escape as unhandled Future errors',
    () async {
      reset(0);
      var callbacks = 0;
      final handle = await InitializerNativeCallable(mpv).create((_) async {
        callbacks++;
        throw StateError('injected event callback failure');
      });
      triggerEvent();
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (callbacks == 0 && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(callbacks, 1);
      InitializerNativeCallable(mpv).dispose(handle);
      mpv.mpv_destroy(handle);
    },
  );

  test(
    'callback registration failure destroys the initialized handle',
    () async {
      reset(0);
      await expectLater(
        _registerBrokenCallbackInIsolate(
          libraryPath,
        ).timeout(const Duration(seconds: 5)),
        throwsA(isA<StateError>()),
      );
      expect([count(0), count(2), count(3), count(4)], [1, 1, 1, 0]);
    },
  );

  test(
    'failure after context creation releases callbacks and native resources',
    () async {
      reset(0);
      // The fixture deliberately omits property setup symbols. Creation succeeds
      // and publishes its handle, then the rest of NativePlayer setup fails.
      final player = Player(
        configuration: const PlayerConfiguration(async: false),
      );
      await expectLater(
        player.platform!.waitForPlayerInitialization.timeout(
          const Duration(seconds: 5),
        ),
        throwsArgumentError,
      );
      await player.dispose().timeout(const Duration(seconds: 5));
      expect(count(4), 2); // Registration, then callback removal.
      final deadline = DateTime.now().add(const Duration(seconds: 7));
      while (count(3) == 0 && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(count(3), 1);
    },
  );
}
