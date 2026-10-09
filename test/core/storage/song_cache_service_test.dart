import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songloft_flutter/core/storage/android_song_cache_storage.dart';
import 'package:songloft_flutter/core/storage/app_preferences.dart';
import 'package:songloft_flutter/core/storage/song_cache_service.dart';
import 'package:songloft_flutter/shared/models/song.dart';

// The bridge double performs real filesystem copies/deletes. URI permissions
// and removable-volume failures are injected at the platform boundary.
class DiskStorage extends AndroidSongCacheStorage {
  DiskStorage(this.folder);
  final Directory folder;
  final files = <String, File>{};
  bool unavailable = false;
  int copies = 0;
  int? failCopy;
  int deletions = 0;
  int? failDelete;
  Future<void> Function()? afterCopy;

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<void> validateDirectory(String tree) async {
    if (unavailable) throw const FileSystemException('volume unavailable');
  }

  @override
  Future<String> status(String uri, String tree) async {
    if (unavailable) return 'unavailable';
    return files.containsKey(uri) && await files[uri]!.exists()
        ? 'available'
        : 'missing';
  }

  @override
  Future<String> copyToDirectory({
    required String source,
    required String tree,
    required String name,
    required String mime,
    required String operation,
    required int expectedBytes,
  }) async {
    await validateDirectory(tree);
    copies++;
    if (copies == failCopy) throw const FileSystemException('copy failed');
    final uri = '$tree/document/$copies';
    final file = File('${folder.path}/$copies-$name');
    final original =
        source.startsWith('content://') ? files[source]! : File(source);
    if (await original.length() != expectedBytes) {
      throw const FileSystemException('short copy');
    }
    files[uri] = await original.copy(file.path);
    await afterCopy?.call();
    return uri;
  }

  @override
  Future<void> copyToPrivate(
    String uri,
    String path,
    String operation,
    int expectedBytes,
  ) async {
    if (unavailable) throw const FileSystemException('volume unavailable');
    if (await files[uri]!.length() != expectedBytes) {
      throw const FileSystemException('short copy');
    }
    await files[uri]!.copy(path);
  }

  @override
  Future<void> delete(String uri) async {
    if (unavailable) throw const FileSystemException('volume unavailable');
    if (++deletions == failDelete) {
      throw const FileSystemException('delete failed');
    }
    final file = files.remove(uri);
    if (file != null && await file.exists()) await file.delete();
  }

  @override
  Future<void> cancel(String operation) async {}
}

class DownloadAdapter implements HttpClientAdapter {
  Future<ResponseBody> Function()? respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return respond == null
        ? ResponseBody.fromBytes(
          [1, 2, 3, 4],
          200,
          headers: {
            Headers.contentTypeHeader: ['audio/mpeg'],
            Headers.contentLengthHeader: ['4'],
          },
        )
        : respond!();
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const tree =
      'content://com.android.externalstorage.documents/tree/primary%3AMusic';
  late Directory root;
  late Directory private;
  late DiskStorage storage;
  late AppPreferences preferences;
  late SongCacheService service;
  late DownloadAdapter adapter;

  SongCacheService createService() => SongCacheService.forTesting(
    directory: private,
    preferences: preferences,
    external: storage,
    dio: Dio()..httpClientAdapter = adapter,
  );

  Future<List<CachedSongEntry>> seed(
    int count, {
    Set<String> sourceTags = const {'manual', 'pl:7'},
  }) async {
    final entries = <CachedSongEntry>[];
    for (var id = 1; id <= count; id++) {
      final file = File('${private.path}/$id.mp3');
      await file.writeAsBytes([id, 2, 3, 4]);
      entries.add(
        CachedSongEntry(
          songId: id,
          path: file.path,
          format: 'mp3',
          bitRate: 320,
          size: 4,
          cachedAt: DateTime(2026),
          title: '歌曲 $id',
          artist: '歌手',
          sourceTags: sourceTags,
        ),
      );
    }
    await File(
      '${private.path}/index.json',
    ).writeAsString(jsonEncode(entries.map((e) => e.toJson()).toList()));
    await service.load();
    return entries;
  }

  Song song(int id) => Song(
    id: id,
    type: 'remote',
    title: '测试 / 歌曲',
    artist: '歌手',
    duration: 30,
    url: 'https://example.com/test.flac',
    format: 'flac',
    addedAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('song-cache-test-');
    private = await Directory('${root.path}/private').create();
    final shared = await Directory('${root.path}/shared').create();
    storage = DiskStorage(shared);
    SharedPreferences.setMockInitialValues({});
    preferences = await AppPreferences.create();
    adapter = DownloadAdapter();
    service = createService();
  });

  tearDown(() async {
    await root.delete(recursive: true);
  });

  test(
    'legacy index loads; directory changes do not move existing songs',
    () async {
      final old = await seed(1);
      await service.setDirectory(tree, 'Music');
      expect(await service.resolvePlayablePath(1), old.first.path);
      final restarted = createService();
      await restarted.load();
      expect(restarted.directory, tree);
      expect(restarted.directoryLabel, 'Music');
      expect(restarted.entry(1)!.sourceTags, {'manual', 'pl:7'});
      await restarted.setDirectory(null, null);
      expect(preferences.getSongCacheDirectory(), isNull);
    },
  );

  test('migration and restore copy real bytes; index stays private', () async {
    final old = await seed(2);
    await service.setDirectory(tree, 'Music');
    await service.migrate();
    expect(service.totalSize(), 8);
    for (final e in old) {
      expect(await File(e.path).exists(), false);
      final migrated = service.entry(e.songId)!;
      expect(migrated.storageDirectory, tree);
      expect(await storage.files[migrated.path]!.readAsBytes(), [
        e.songId,
        2,
        3,
        4,
      ]);
      expect(
        songCachePlayableUri(
          (await service.resolvePlayablePath(e.songId))!,
        ).scheme,
        'content',
      );
    }
    expect(await File('${private.path}/index.json').exists(), true);
    await service.setDirectory(null, null);
    await service.migrate();
    expect(storage.files, isEmpty);
    expect(service.entry(1)!.storageDirectory, isNull);
    expect(await File(service.entry(1)!.path).readAsBytes(), [1, 2, 3, 4]);
  });

  test(
    'failed second copy preserves its original and first committed move',
    () async {
      final old = await seed(2);
      storage.failCopy = 2;
      await service.setDirectory(tree, 'Music');
      await expectLater(service.migrate(), throwsA(isA<FileSystemException>()));
      expect(service.entry(1)!.storageDirectory, tree);
      expect(await File(old[0].path).exists(), false);
      expect(service.entry(2)!.path, old[1].path);
      expect(await File(old[1].path).readAsBytes(), [2, 2, 3, 4]);
      expect(service.isBusy, false);
    },
  );

  test(
    'index write failure rolls back copy without deleting original',
    () async {
      final old = await seed(1);
      await Directory('${private.path}/index.json.tmp').create();
      await service.setDirectory(tree, 'Music');
      await expectLater(service.migrate(), throwsA(isA<FileSystemException>()));
      expect(service.entry(1)!.path, old.first.path);
      expect(await File(old.first.path).exists(), true);
      expect(storage.files, isEmpty);
    },
  );

  test(
    'cancel before index commit cleans copy and preserves original',
    () async {
      final old = await seed(1);
      final token = CancelToken();
      storage.afterCopy = () async {
        token.cancel('cancel');
      };
      await service.setDirectory(tree, 'Music');
      await expectLater(
        service.migrate(cancelToken: token),
        throwsA(isA<DioException>()),
      );
      expect(service.entry(1)!.path, old.first.path);
      expect(await File(old.first.path).exists(), true);
      expect(storage.files, isEmpty);
    },
  );

  test(
    'unmounted volume retains index during playback and failed clear',
    () async {
      await seed(1);
      await service.setDirectory(tree, 'Music');
      await service.migrate();
      final migrated = service.entry(1)!;
      storage.unavailable = true;
      await expectLater(
        service.resolvePlayablePath(1),
        throwsA(isA<SongCacheStorageUnavailable>()),
      );
      await expectLater(
        service.clearAll(),
        throwsA(isA<FileSystemException>()),
      );
      expect(service.entry(1), same(migrated));
      storage.unavailable = false;
      expect(await service.resolvePlayablePath(1), migrated.path);
    },
  );

  test(
    'clear only indexed caches; unrelated files survive in both directories',
    () async {
      await seed(2);
      final otherPrivate = File('${private.path}/user.mp3');
      final otherShared = File('${storage.folder.path}/user.mp3');
      await otherPrivate.writeAsString('private user file');
      await otherShared.writeAsString('shared user file');
      await service.setDirectory(tree, 'Music');
      await service.migrate();
      await service.removePlaylist(7);
      expect(service.totalSize(), 8); // manual tags still own both songs
      await service.clearAll();
      expect(service.totalSize(), 0);
      expect(await otherPrivate.readAsString(), 'private user file');
      expect(await otherShared.readAsString(), 'shared user file');
      expect(storage.files, isEmpty);
    },
  );

  test(
    'new download uses response format and leaves no private duplicate',
    () async {
      await service.setDirectory(tree, 'Music');
      await service.cache(song(5), tag: 'manual', quality: '192');
      final entry = service.entry(5)!;
      expect(entry.format, 'mp3');
      expect(storage.files[entry.path]!.path, contains('歌手 - 测试 _ 歌曲 - 5.mp3'));
      expect(await storage.files[entry.path]!.readAsBytes(), [1, 2, 3, 4]);
      expect(
        (await private.list().toList()).map((f) => f.path.split('/').last),
        ['index.json'],
      );
    },
  );

  test(
    'cancelled network download never enters index or leaves staging files',
    () async {
      final token = CancelToken();
      final started = Completer<void>();
      final bytes = StreamController<Uint8List>();
      adapter.respond = () async {
        started.complete();
        return ResponseBody(
          bytes.stream,
          200,
          headers: {
            Headers.contentTypeHeader: ['audio/mpeg'],
          },
        );
      };
      final request = service.cache(song(5), tag: 'manual', cancelToken: token);
      final assertion = expectLater(request, throwsA(isA<DioException>()));
      await started.future;
      bytes.add(Uint8List.fromList([1, 2]));
      token.cancel('cancel');
      await assertion;
      await bytes.close();
      expect(service.isCached(5), false);
      expect(await private.list().toList(), isEmpty);
    },
  );

  test('size limit checks actual bytes even when size was unknown', () async {
    await expectLater(
      service.cache(song(5), tag: 'manual', maxSize: 3),
      throwsA(isA<SongCacheLimitExceeded>()),
    );
    expect(service.isCached(5), false);
    expect(await private.list().toList(), isEmpty);
  });

  test('directory change rejects active migration', () async {
    await seed(1);
    await service.setDirectory(tree, 'Music');
    final copied = Completer<void>();
    final release = Completer<void>();
    storage.afterCopy = () async {
      copied.complete();
      await release.future;
    };
    final migration = service.migrate();
    await copied.future;
    await expectLater(
      service.setDirectory(null, null),
      throwsA(isA<SongCacheBusy>()),
    );
    release.complete();
    await migration;
    expect(service.directory, tree);
  });

  test(
    'replacing a missing cache does not count its stale size twice',
    () async {
      final old = await seed(1);
      await File(old.first.path).delete();
      await service.cache(
        song(1).copyWith(fileSize: 4),
        tag: 'manual',
        maxSize: 4,
      );
      expect(service.totalSize(), 4);
      expect(await File(service.entry(1)!.path).readAsBytes(), [1, 2, 3, 4]);
    },
  );

  test(
    'already cancelled migration never copies or deletes originals',
    () async {
      final old = await seed(1);
      await service.setDirectory(tree, 'Music');
      final token = CancelToken()..cancel('page closed');
      await expectLater(
        service.migrate(cancelToken: token),
        throwsA(isA<DioException>()),
      );
      expect(storage.copies, 0);
      expect(service.entry(1)!.path, old.first.path);
      expect(await File(old.first.path).exists(), true);
    },
  );

  test('failed target validation does not change saved directory', () async {
    await service.setDirectory(tree, 'Music');
    storage.unavailable = true;
    await expectLater(
      service.setDirectory('$tree-other', 'other'),
      throwsA(isA<FileSystemException>()),
    );
    expect(service.directory, tree);
    expect(preferences.getSongCacheDirectory(), tree);
  });

  test('missing media removes only its stale record', () async {
    final old = await seed(2);
    await File(old.first.path).delete();
    expect(await service.resolvePlayablePath(1), isNull);
    expect(service.isCached(1), false);
    expect(service.isCached(2), true);
  });

  for (final playlistOnly in [false, true]) {
    test(
      'partial ${playlistOnly ? 'playlist' : 'full'} cleanup persists successful deletions',
      () async {
        await seed(3, sourceTags: playlistOnly ? {'pl:7'} : {'manual', 'pl:7'});
        await service.setDirectory(tree, 'Music');
        await service.migrate();
        storage.deletions = 0;
        storage.failDelete = 2;
        await expectLater(
          playlistOnly ? service.removePlaylist(7) : service.clearAll(),
          throwsA(isA<FileSystemException>()),
        );
        expect(service.isCached(1), false);
        expect(service.isCached(2), true);
        expect(service.isCached(3), true);
        final restarted = createService();
        await restarted.load();
        expect(restarted.isCached(1), false);
        expect(restarted.totalSize(), 8);
      },
    );
  }

  test(
    'missing cache playback does not wait for an unrelated download',
    () async {
      final old = await seed(1);
      await File(old.first.path).delete();
      final started = Completer<void>();
      final response = Completer<ResponseBody>();
      adapter.respond = () {
        started.complete();
        return response.future;
      };
      final download = service.cache(song(5), tag: 'manual');
      await started.future;
      try {
        expect(
          await service
              .resolvePlayablePath(1)
              .timeout(const Duration(seconds: 1)),
          isNull,
        );
      } finally {
        response.complete(ResponseBody.fromBytes([1, 2, 3, 4], 200));
        await download;
        await service.removeSong(999); // Wait for queued index cleanup.
      }
      expect(service.isCached(1), false);
      expect(service.isCached(5), true);
    },
  );

  test(
    'damaged index is preserved without publishing a partial cache list',
    () async {
      final old = await seed(1);
      final index = File('${private.path}/index.json');
      final damaged = jsonEncode([
        old.first.toJson(),
        {'song_id': 2, 'path': 3},
      ]);
      await index.writeAsString(damaged);
      final restarted = createService();
      await expectLater(restarted.load(), throwsA(isA<TypeError>()));
      expect(restarted.isCached(1), false);
      await expectLater(
        restarted.cache(song(5), tag: 'manual'),
        throwsA(isA<TypeError>()),
      );
      expect(await index.readAsString(), damaged);
      expect(await File(old.first.path).exists(), true);
    },
  );

  test('copy size mismatch leaves original file and index untouched', () async {
    final old = await seed(1);
    await File(old.first.path).writeAsBytes([1, 2]);
    await service.setDirectory(tree, 'Music');
    await expectLater(service.migrate(), throwsA(isA<FileSystemException>()));
    expect(service.entry(1)!.path, old.first.path);
    expect(await File(old.first.path).readAsBytes(), [1, 2]);
    expect(storage.files, isEmpty);
  });

  test(
    'native deletion and validation require positive acknowledgements',
    () async {
      const channel = MethodChannel('com.songloft/floating_lyric');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => null);
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final bridge = AndroidSongCacheStorage();
      await expectLater(
        bridge.validateDirectory(tree),
        throwsA(isA<PlatformException>()),
      );
      await expectLater(
        bridge.delete('$tree/document/1'),
        throwsA(isA<PlatformException>()),
      );
    },
  );

  test(
    'old APK reports unsupported instead of claiming directory access',
    () async {
      const channel = MethodChannel('com.songloft/floating_lyric');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            throw MissingPluginException();
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      expect(await AndroidSongCacheStorage().isSupported(), false);
    },
  );

  test(
    'URI playback preserves encoded document ID and local file escaping',
    () {
      const uri = '$tree/document/primary%3AMusic%2F%E6%AD%8C.mp3';
      expect(songCachePlayableUri(uri).toString(), uri);
      expect(
        songCachePlayableUri('/tmp/歌曲 a.mp3').toFilePath(),
        '/tmp/歌曲 a.mp3',
      );
    },
  );

  test(
    'public filename fits byte limits with Unicode and rejects separators',
    () {
      final entry = CachedSongEntry(
        songId: 8,
        path: '',
        format: 'mp3',
        bitRate: 0,
        size: 0,
        cachedAt: DateTime(2026),
        title: '🎵' * 20000,
        artist: '../歌手',
        sourceTags: {},
      );
      final name = songCacheFileName(entry);
      expect(utf8.encode(name).length, lessThan(256));
      expect(name, isNot(contains('/')));
      expect(name, endsWith(' - 8.mp3'));
    },
  );
}
