import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart';

import '../../shared/models/song.dart';
import '../utils/url_helper.dart';
import 'android_song_cache_storage.dart';
import 'app_preferences.dart';

export '../../features/player/domain/playback_source.dart' show PlaybackSource;

/// 手动缓存来源标签：单曲缓存。
const String kSongCacheTagManual = 'manual';

/// 歌单来源标签前缀：`pl:<playlistId>`。
String songCachePlaylistTag(int playlistId) => 'pl:$playlistId';

/// 缓存量超过本地上限时抛出，UI 捕获后提示用户。
class SongCacheLimitExceeded implements Exception {
  final int currentSize;
  final int maxSize;
  const SongCacheLimitExceeded(this.currentSize, this.maxSize);
  @override
  String toString() => 'SongCacheLimitExceeded($currentSize/$maxSize)';
}

class SongCacheBusy implements Exception {}

class SongCacheStorageUnavailable implements Exception {}

String songCacheFileName(CachedSongEntry entry) {
  String clean(String text) =>
      text.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_').trim();
  final title = clean(entry.title);
  final artist = clean(entry.artist ?? '');
  var stem = [
    if (artist.isNotEmpty) artist,
    if (title.isNotEmpty) title,
  ].join(' - ');
  // Keep UTF-8 filenames below common filesystem limits, without splitting a
  // Unicode code point. The ID disambiguates equal titles.
  final prefix = StringBuffer();
  var bytes = 0;
  for (final rune in stem.runes) {
    final length = utf8.encode(String.fromCharCode(rune)).length;
    if (bytes + length > 180) break;
    prefix.writeCharCode(rune);
    bytes += length;
  }
  stem = prefix.toString();
  final format = entry.format?.toLowerCase();
  final ext =
      format != null && RegExp(r'^[a-z0-9]{1,5}$').hasMatch(format)
          ? format
          : 'audio';
  return '${stem.isEmpty ? 'Song' : stem} - ${entry.songId}.$ext';
}

Uri songCachePlayableUri(String location) =>
    location.startsWith('content://')
        ? Uri.parse(location)
        : Uri.file(location);

/// 单条缓存索引记录。
///
/// [sourceTags] 记录这首歌是被哪些来源缓存的：手动缓存打 [kSongCacheTagManual]，
/// 随歌单缓存打 `pl:<playlistId>`。一首歌可同属多个来源；只有当标签全部移除后
/// 才真正删除本地文件，避免清除某个歌单时误删另一来源仍需要的文件。
class CachedSongEntry {
  final int songId;
  final String path;

  /// Null for legacy/default files; SAF entries retain their granting tree.
  final String? storageDirectory;
  final String? format;
  final int bitRate;
  final int size;
  final DateTime cachedAt;

  /// 展示用元信息（设置页列表无需再拉取歌曲即可显示）。
  final String title;
  final String? artist;

  final Set<String> sourceTags;

  const CachedSongEntry({
    required this.songId,
    required this.path,
    required this.format,
    required this.bitRate,
    required this.size,
    required this.cachedAt,
    required this.title,
    required this.artist,
    required this.sourceTags,
    this.storageDirectory,
  });

  CachedSongEntry copyWith({
    Set<String>? sourceTags,
    String? path,
    String? storageDirectory,
    bool privateStorage = false,
  }) => CachedSongEntry(
    songId: songId,
    path: path ?? this.path,
    storageDirectory:
        privateStorage ? null : storageDirectory ?? this.storageDirectory,
    format: format,
    bitRate: bitRate,
    size: size,
    cachedAt: cachedAt,
    title: title,
    artist: artist,
    sourceTags: sourceTags ?? this.sourceTags,
  );

  Map<String, dynamic> toJson() => {
    'song_id': songId,
    'path': path,
    if (storageDirectory != null) 'storage_directory': storageDirectory,
    'format': format,
    'bit_rate': bitRate,
    'size': size,
    'cached_at': cachedAt.toIso8601String(),
    'title': title,
    'artist': artist,
    'source_tags': sourceTags.toList(),
  };

  factory CachedSongEntry.fromJson(Map<String, dynamic> json) {
    return CachedSongEntry(
      songId: json['song_id'] as int,
      path: json['path'] as String,
      storageDirectory: json['storage_directory'] as String?,
      format: json['format'] as String?,
      bitRate: json['bit_rate'] as int? ?? 0,
      size: json['size'] as int? ?? 0,
      cachedAt:
          DateTime.tryParse(json['cached_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      title: json['title'] as String? ?? '',
      artist: json['artist'] as String?,
      sourceTags:
          (json['source_tags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toSet() ??
          <String>{},
    );
  }
}

/// 客户端本地歌曲缓存服务（songloft-org/songloft#312）。
///
/// 把远程歌曲全量下载到设备本地目录 `{appDocDir}/song_cache/`，播放时优先用本地
/// 文件、离线可播；由用户手动缓存/清除，**不参与自动淘汰**（超上限时拒绝新缓存）。
///
/// 与 just_audio 写临时目录的边播边缓存（`LockCachingAudioSource`）不同：本服务的
/// 文件用户可寻址、有持久索引、可按单曲/歌单增删。
///
/// Web 平台无持久文件存储，全部方法降级为空操作（[isSupported] 返回 false）。
///
/// 索引格式参考 [LyricCacheService] / [PlaybackStateStorage]：内存 Map + JSON 落盘。
class SongCacheService {
  static final SongCacheService _instance = SongCacheService._();
  factory SongCacheService() => _instance;
  SongCacheService._()
    : _dio = Dio(),
      _external = AndroidSongCacheStorage(),
      _preferences = AppPreferences.create();

  @visibleForTesting
  SongCacheService.forTesting({
    required Directory directory,
    required AppPreferences preferences,
    required AndroidSongCacheStorage external,
    Dio? dio,
  }) : _cacheDir = directory,
       _preferences = Future.value(preferences),
       _external = external,
       _dio = dio ?? Dio();

  static const _dirName = 'song_cache';
  static const _indexFileName = 'index.json';

  /// 独立 Dio：播放 URL 已内嵌 access_token 与解析后的 baseUrl（见 [UrlHelper]），
  /// 无需 app 的 AuthInterceptor；自签证书由全局 HttpOverrides trust-all 覆盖。
  final Dio _dio;
  final AndroidSongCacheStorage _external;
  final Future<AppPreferences> _preferences;
  final Lock _lock = Lock();

  final Map<int, CachedSongEntry> _index = {};
  Directory? _cacheDir;
  bool _loaded = false;
  Future<void>? _loading;
  String? _directory;
  String? _directoryLabel;
  int _mutations = 0;

  String? get directory => _directory;
  String? get directoryLabel => _directoryLabel;
  bool get isBusy => _mutations > 0;

  Future<T> _mutate<T>(Future<T> Function() action) async {
    _mutations++;
    try {
      return await _lock.synchronized(() async {
        await load();
        return action();
      });
    } finally {
      _mutations--;
    }
  }

  bool get isSupported => !kIsWeb;

  /// 启动时载入索引到内存。重复调用只生效一次。
  Future<void> load() {
    if (_loaded || kIsWeb) return Future.value();
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  Future<void> _load() async {
    final prefs = await _preferences;
    _directory = prefs.getSongCacheDirectory();
    _directoryLabel = prefs.getSongCacheDirectoryLabel();
    final dir = await _ensureDir();
    final indexFile = File('${dir.path}/$_indexFileName');
    final loaded = <int, CachedSongEntry>{};
    if (await indexFile.exists()) {
      final raw = await indexFile.readAsString();
      if (raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        for (final e in list) {
          final entry = CachedSongEntry.fromJson(e as Map<String, dynamic>);
          loaded[entry.songId] = entry;
        }
      }
    }
    _index
      ..clear()
      ..addAll(loaded);
    _loaded = true;
  }

  Future<Directory> _ensureDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final appDocDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDocDir.path}/$_dirName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cacheDir = dir;
    return dir;
  }

  Future<void> _saveIndex(Map<int, CachedSongEntry> next) async {
    if (kIsWeb) return;
    final dir = await _ensureDir();
    final indexFile = File('${dir.path}/$_indexFileName');
    final temporary = File('${indexFile.path}.tmp');
    final data = next.values.map((e) => e.toJson()).toList();
    await temporary.writeAsString(jsonEncode(data), flush: true);
    await temporary.rename(indexFile.path);
    _index
      ..clear()
      ..addAll(next);
  }

  Future<bool> supportsDirectorySelection() => _external.isSupported();

  Future<Map<String, String>?> pickDirectory() => _external.pickDirectory();

  Future<void> setDirectory(String? uri, String? label) async {
    if (isBusy) throw SongCacheBusy();
    await _mutate(() async {
      if (uri != null) await _external.validateDirectory(uri);
      await (await _preferences).setSongCacheDirectory(uri, label);
      _directory = uri;
      _directoryLabel = label;
    });
  }

  Future<void> validateDirectory() async {
    await load();
    if (_directory != null) await _external.validateDirectory(_directory!);
  }

  Future<String> _status(CachedSongEntry entry) async {
    if (entry.path.startsWith('content://')) {
      if (entry.storageDirectory == null) return 'unavailable';
      return _external.status(entry.path, entry.storageDirectory!);
    }
    return await File(entry.path).exists() ? 'available' : 'missing';
  }

  // ── 查询 ────────────────────────────────────────────────────────────────

  /// 是否已缓存（内存查，播放热路径要快；文件缺失的惰性清理见 [entry]）。
  bool isCached(int songId) => _index.containsKey(songId);

  /// 取缓存记录（同步）。播放侧应再校验文件存在，见 [resolvePlayablePath]。
  CachedSongEntry? entry(int songId) => _index[songId];

  /// 返回可播放的本地文件路径；文件已被外部删除时惰性清理索引并返回 null。
  Future<String?> resolvePlayablePath(int songId) async {
    if (kIsWeb) return null;
    await load();
    final e = _index[songId];
    if (e == null) return null;
    final status = await _status(e);
    if (status == 'available') return e.path;
    if (status == 'unavailable') throw SongCacheStorageUnavailable();
    final wasBusy = isBusy;
    final cleanup = _mutate(() async {
      // A concurrent migration may have replaced the entry while stat awaited.
      if (identical(_index[songId], e)) {
        await _saveIndex({..._index}..remove(songId));
      }
    });
    if (wasBusy) {
      // A missing cache must not hold playback behind a whole-song download.
      unawaited(
        cleanup.catchError((Object error) {
          debugPrint('[SongCache] stale index cleanup failed: $error');
        }),
      );
    } else {
      await cleanup;
    }
    return null;
  }

  /// 全部缓存占用字节（内存汇总，快）。
  int totalSize() => _index.values.fold<int>(0, (sum, e) => sum + e.size);

  /// 手动缓存的单曲（含 [kSongCacheTagManual] 标签）。
  List<CachedSongEntry> get manualEntries =>
      _index.values
          .where((e) => e.sourceTags.contains(kSongCacheTagManual))
          .toList();

  /// 按歌单分组：playlistId → 该歌单已缓存的记录。
  Map<int, List<CachedSongEntry>> playlistGroups() {
    final result = <int, List<CachedSongEntry>>{};
    for (final e in _index.values) {
      for (final tag in e.sourceTags) {
        if (tag.startsWith('pl:')) {
          final id = int.tryParse(tag.substring(3));
          if (id != null) {
            (result[id] ??= []).add(e);
          }
        }
      }
    }
    return result;
  }

  // ── 写入 ────────────────────────────────────────────────────────────────

  /// 缓存一首歌到本地。
  ///
  /// [tag] 来源标签（[kSongCacheTagManual] 或 [songCachePlaylistTag]）。
  /// [quality] 下载音质（透传给 [UrlHelper.buildSongUrl]）。
  /// [maxSize] 本地缓存上限字节（0 = 不限制）；预估超限时抛 [SongCacheLimitExceeded]。
  ///
  /// 已缓存则仅并入标签、不重复下载。下载走 `.part` 临时文件 + rename 原子落地。
  Future<void> cache(
    Song song, {
    required String tag,
    String quality = 'original',
    int maxSize = 0,
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (kIsWeb) return;
    await _mutate(
      () => _cache(
        song,
        tag: tag,
        quality: quality,
        maxSize: maxSize,
        onProgress: onProgress,
        cancelToken: cancelToken,
      ),
    );
  }

  Future<void> _cache(
    Song song, {
    required String tag,
    required String quality,
    required int maxSize,
    void Function(int, int)? onProgress,
    CancelToken? cancelToken,
  }) async {
    _throwCancelled(cancelToken);

    // 已缓存：并入来源标签即可。
    final existing = _index[song.id];
    final existingStatus =
        existing == null ? 'missing' : await _status(existing);
    if (existingStatus == 'unavailable') throw SongCacheStorageUnavailable();
    if (existing != null && existingStatus == 'available') {
      if (!existing.sourceTags.contains(tag)) {
        final updated = existing.copyWith(
          sourceTags: {...existing.sourceTags, tag},
        );
        await _saveIndex({..._index, song.id: updated});
      }
      return;
    }

    // 容量预检：用歌曲已知 fileSize 粗估（远程转码后实际大小可能有出入，
    // 下载完成后按真实字节数记账）。maxSize=0 表示不限制。
    if (maxSize > 0 &&
        song.fileSize > 0 &&
        totalSize() - (existing?.size ?? 0) + song.fileSize > maxSize) {
      throw SongCacheLimitExceeded(totalSize(), maxSize);
    }

    if (song.url == null || song.url!.isEmpty) {
      throw StateError('song has no playable url');
    }

    final downloadUrl = UrlHelper.buildSongUrl(
      song.url!,
      songFormat: song.format,
      quality: quality,
    );

    final dir = await _ensureDir();
    final operation = _operationId();
    final partPath = '${dir.path}/$operation.part';
    String? committedPath;
    var copying = false;
    if (cancelToken != null) {
      unawaited(
        cancelToken.whenCancel
            .then((_) async {
              if (copying) await _external.cancel(operation);
            })
            .catchError((Object e) {
              debugPrint('[SongCacheService] cancel copy: $e');
            }),
      );
    }

    try {
      final response = await _dio.download(
        downloadUrl,
        partPath,
        onReceiveProgress: onProgress,
        cancelToken: cancelToken,
      );
      final partFile = File(partPath);
      final size = await partFile.length();
      _throwCancelled(cancelToken);
      if (maxSize > 0 && totalSize() - (existing?.size ?? 0) + size > maxSize) {
        throw SongCacheLimitExceeded(totalSize(), maxSize);
      }
      final ext = _responseExtension(
        response.headers.value('content-type'),
        song,
      );
      final entry = CachedSongEntry(
        songId: song.id,
        path: partPath,
        storageDirectory: _directory,
        format: ext,
        bitRate: song.bitRate,
        size: size,
        cachedAt: DateTime.now(),
        title: song.title,
        artist: song.artist,
        sourceTags: {tag},
      );
      if (_directory != null) {
        copying = true;
        committedPath = await _external.copyToDirectory(
          source: partPath,
          tree: _directory!,
          name: songCacheFileName(entry),
          mime: _mime(ext),
          operation: operation,
          expectedBytes: size,
        );
        copying = false;
      } else {
        committedPath = '${dir.path}/$operation.$ext';
        await partFile.rename(committedPath);
      }
      _throwCancelled(cancelToken);
      await _saveIndex({
        ..._index,
        song.id: entry.copyWith(path: committedPath),
      });
      committedPath = null; // Index now owns this file.
    } catch (e) {
      if (committedPath != null) await _deleteFile(committedPath);
      rethrow;
    } finally {
      copying = false;
      try {
        final part = File(partPath);
        if (await part.exists()) await part.delete();
      } catch (_) {}
    }
  }

  /// 清除单曲缓存（删文件 + 删索引），无视来源标签。
  Future<void> removeSong(int songId) async {
    if (kIsWeb) return;
    await _mutate(() async {
      final e = _index[songId];
      if (e != null) {
        await _deleteFile(e.path);
        await _saveIndex({..._index}..remove(songId));
      }
    });
  }

  /// 清除某歌单的缓存：逐首摘掉 `pl:<playlistId>` 标签，标签清空的才删文件。
  Future<void> removePlaylist(int playlistId) async {
    if (kIsWeb) return;
    await _mutate(() async {
      final tag = songCachePlaylistTag(playlistId);
      final next = {..._index};
      var changed = false;
      try {
        for (final entry in _index.values.toList()) {
          if (!entry.sourceTags.contains(tag)) continue;
          final remaining = {...entry.sourceTags}..remove(tag);
          if (remaining.isEmpty) {
            await _deleteFile(entry.path);
            next.remove(entry.songId);
          } else {
            next[entry.songId] = entry.copyWith(sourceTags: remaining);
          }
          changed = true;
        }
      } finally {
        // Persist successful removals even when a later volume becomes unavailable.
        if (changed) await _saveIndex(next);
      }
    });
  }

  /// 清空全部本地歌曲缓存。
  Future<void> clearAll() async {
    if (kIsWeb) return;
    await _mutate(() async {
      // Never recursively delete a user-selected directory (or unindexed files).
      final next = {..._index};
      var changed = false;
      try {
        for (final entry in _index.values.toList()) {
          await _deleteFile(entry.path);
          next.remove(entry.songId);
          changed = true;
        }
      } finally {
        // One write for the batch avoids quadratic serialization for large caches.
        if (changed) await _saveIndex(next);
      }
    });
  }

  Future<void> _deleteFile(String path) async {
    if (path.startsWith('content://')) {
      await _external.delete(path);
    } else {
      final f = File(path);
      if (await f.exists()) await f.delete();
    }
  }

  /// Each song commits independently: on failure/cancellation completed songs
  /// stay migrated, while the failing and remaining songs keep their originals.
  Future<void> migrate({
    CancelToken? cancelToken,
    void Function(int done, int total)? onProgress,
  }) async {
    if (isBusy) throw SongCacheBusy();
    await _mutate(() async {
      _throwCancelled(cancelToken);
      await validateDirectory();
      final entries =
          _index.values.where((e) => e.storageDirectory != _directory).toList();
      var done = 0;
      onProgress?.call(done, entries.length);
      for (final entry in entries) {
        _throwCancelled(cancelToken);
        final operation = _operationId();
        String? destination;
        var copying = true;
        if (cancelToken != null) {
          unawaited(
            cancelToken.whenCancel
                .then((_) async {
                  if (copying) await _external.cancel(operation);
                })
                .catchError((Object e) {
                  debugPrint('[SongCacheService] cancel migration: $e');
                }),
          );
        }
        try {
          if (await _status(entry) != 'available') {
            throw SongCacheStorageUnavailable();
          }
          _throwCancelled(cancelToken);
          if (_directory != null) {
            destination = await _external.copyToDirectory(
              source: entry.path,
              tree: _directory!,
              name: songCacheFileName(entry),
              mime: _mime(entry.format),
              operation: operation,
              expectedBytes: entry.size,
            );
          } else {
            final dir = await _ensureDir();
            final part = '${dir.path}/$operation.part';
            try {
              await _external.copyToPrivate(
                entry.path,
                part,
                operation,
                entry.size,
              );
              destination = '${dir.path}/$operation.${entry.format ?? 'audio'}';
              await File(part).rename(destination);
            } finally {
              if (await File(part).exists()) await File(part).delete();
            }
          }
          copying = false;
          _throwCancelled(cancelToken);
          final replacement = entry.copyWith(
            path: destination,
            storageDirectory: _directory,
            privateStorage: _directory == null,
          );
          await _saveIndex({..._index, entry.songId: replacement});
          destination = null; // Only now may the old file be removed.
          await _deleteFile(entry.path);
          done++;
          onProgress?.call(done, entries.length);
        } catch (_) {
          if (destination != null) await _deleteFile(destination);
          rethrow;
        } finally {
          copying = false;
        }
      }
    });
  }

  void _throwCancelled(CancelToken? token) {
    if (token?.isCancelled == true) throw token!.cancelError!;
  }

  String _operationId() =>
      'cache-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';

  String _responseExtension(String? contentType, Song song) {
    final mime = contentType?.split(';').first.trim().toLowerCase();
    return switch (mime) {
      'audio/mpeg' => 'mp3',
      'audio/mp4' => 'm4a',
      'audio/x-m4a' => 'm4a',
      'audio/aac' || 'audio/aacp' => 'aac',
      'audio/flac' || 'audio/x-flac' => 'flac',
      'audio/ogg' || 'application/ogg' => 'ogg',
      'audio/wav' || 'audio/x-wav' => 'wav',
      'video/mp4' => 'mp4',
      'audio/webm' || 'video/webm' => 'webm',
      _ => _extForSong(song),
    };
  }

  String _mime(String? ext) => switch (ext) {
    'mp3' => 'audio/mpeg',
    'm4a' => 'audio/mp4',
    'aac' => 'audio/aac',
    'flac' => 'audio/flac',
    'ogg' || 'opus' => 'audio/ogg',
    'wav' => 'audio/wav',
    'mp4' => 'video/mp4',
    'webm' => 'video/webm',
    _ => 'application/octet-stream',
  };

  String _extForSong(Song song) {
    final f = song.format?.trim().toLowerCase();
    if (f != null && RegExp(r'^[a-z0-9]{1,5}$').hasMatch(f)) {
      return f;
    }
    return 'audio';
  }
}
