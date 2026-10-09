import 'package:flutter/services.dart';

/// SAF access uses the existing extensible native entry point. Old APKs return
/// notImplemented; callers offer an APK upgrade rather than pretending to save.
class AndroidSongCacheStorage {
  static const _channel = MethodChannel('com.songloft/floating_lyric');

  Future<T?> _call<T>(String command, [Map<String, Object?>? args]) =>
      _channel.invokeMethod<T>('exec', {'cmd': command, ...?args});

  Future<bool> isSupported() async {
    try {
      return await _call<bool>('cacheStorageSupported') == true;
    } on MissingPluginException {
      return false;
    }
  }

  Future<Map<String, String>?> pickDirectory() async {
    final result = await _call<Map<Object?, Object?>>('cacheStoragePick');
    if (result == null) return null;
    return result.map((key, value) => MapEntry(key as String, value as String));
  }

  Future<void> validateDirectory(String tree) async {
    await _expectTrue('cacheStorageValidate', {'tree': tree});
  }

  Future<void> _expectTrue(String command, Map<String, Object?> args) async {
    if (await _call<bool>(command, args) != true) {
      throw PlatformException(code: 'cache_storage_unavailable');
    }
  }

  /// Distinguish missing media from revoked access/unmounted volumes.
  Future<String> status(String uri, String tree) async =>
      await _call<String>('cacheStorageStatus', {'uri': uri, 'tree': tree}) ??
      'unavailable';

  Future<String> copyToDirectory({
    required String source,
    required String tree,
    required String name,
    required String mime,
    required String operation,
    required int expectedBytes,
  }) async {
    final uri = await _call<String>('cacheStorageCopy', {
      'source': source,
      'tree': tree,
      'name': name,
      'mime': mime,
      'operation': operation,
      'expected_bytes': expectedBytes,
    });
    if (uri == null) throw StateError('Native storage unavailable');
    return uri;
  }

  Future<void> copyToPrivate(
    String uri,
    String path,
    String operation,
    int expectedBytes,
  ) async {
    await _expectTrue('cacheStorageImport', {
      'uri': uri,
      'path': path,
      'operation': operation,
      'expected_bytes': expectedBytes,
    });
  }

  Future<void> delete(String uri) async {
    await _expectTrue('cacheStorageDelete', {'uri': uri});
  }

  Future<void> cancel(String operation) async {
    await _call<bool>('cacheStorageCancel', {'operation': operation});
  }
}
