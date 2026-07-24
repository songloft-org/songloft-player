import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../shared/models/song.dart';
import '../utils/url_helper.dart';

/// 当前歌曲的播放来源。用于播放页「歌曲信息」区分本地缓存 vs 远端流串。
///
/// 定义在 core 层（而非 player domain），避免 [SongloftAudioHandler] 反向依赖 feature。
enum PlaybackSource {
  /// 本机手动缓存的文件（`file://`）。
  localCache,

  /// 远端流串（走 `/api/v1/songs/{id}/play`，含 just_audio 临时边播边缓存）。
  remoteStream,

  /// 尚未确定（未开始播放）。
  unknown,
}

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

/// 单条缓存索引记录。
///
/// [sourceTags] 记录这首歌是被哪些来源缓存的：手动缓存打 [kSongCacheTagManual]，
/// 随歌单缓存打 `pl:<playlistId>`。一首歌可同属多个来源；只有当标签全部移除后
/// 才真正删除本地文件，避免清除某个歌单时误删另一来源仍需要的文件。
class CachedSongEntry {
  final int songId;
  final String path;
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
  });

  CachedSongEntry copyWith({Set<String>? sourceTags}) => CachedSongEntry(
    songId: songId,
    path: path,
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
  SongCacheService._();

  static const _dirName = 'song_cache';
  static const _indexFileName = 'index.json';

  /// 独立 Dio：播放 URL 已内嵌 access_token 与解析后的 baseUrl（见 [UrlHelper]），
  /// 无需 app 的 AuthInterceptor；自签证书由全局 HttpOverrides trust-all 覆盖。
  final Dio _dio = Dio();

  final Map<int, CachedSongEntry> _index = {};
  Directory? _cacheDir;
  bool _loaded = false;

  bool get isSupported => !kIsWeb;

  /// 启动时载入索引到内存。重复调用只生效一次。
  Future<void> load() async {
    if (_loaded || kIsWeb) return;
    try {
      final dir = await _ensureDir();
      final indexFile = File('${dir.path}/$_indexFileName');
      if (await indexFile.exists()) {
        final raw = await indexFile.readAsString();
        if (raw.isNotEmpty) {
          final list = jsonDecode(raw) as List<dynamic>;
          for (final e in list) {
            final entry = CachedSongEntry.fromJson(e as Map<String, dynamic>);
            _index[entry.songId] = entry;
          }
        }
      }
    } catch (e) {
      debugPrint('[SongCacheService] load index failed: $e');
    }
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

  Future<void> _persist() async {
    if (kIsWeb) return;
    try {
      final dir = await _ensureDir();
      final indexFile = File('${dir.path}/$_indexFileName');
      final data = _index.values.map((e) => e.toJson()).toList();
      await indexFile.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('[SongCacheService] persist index failed: $e');
    }
  }

  // ── 查询 ────────────────────────────────────────────────────────────────

  /// 是否已缓存（内存查，播放热路径要快；文件缺失的惰性清理见 [entry]）。
  bool isCached(int songId) => _index.containsKey(songId);

  /// 取缓存记录（同步）。播放侧应再校验文件存在，见 [resolvePlayablePath]。
  CachedSongEntry? entry(int songId) => _index[songId];

  /// 返回可播放的本地文件路径；文件已被外部删除时惰性清理索引并返回 null。
  Future<String?> resolvePlayablePath(int songId) async {
    if (kIsWeb) return null;
    final e = _index[songId];
    if (e == null) return null;
    try {
      if (await File(e.path).exists()) return e.path;
    } catch (_) {}
    // 文件不在了：清索引，让播放回落远端流串。
    _index.remove(songId);
    unawaited(_persist());
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
    await load();

    // 已缓存：并入来源标签即可。
    final existing = _index[song.id];
    if (existing != null && await File(existing.path).exists()) {
      if (!existing.sourceTags.contains(tag)) {
        _index[song.id] = existing.copyWith(
          sourceTags: {...existing.sourceTags, tag},
        );
        await _persist();
      }
      return;
    }

    // 容量预检：用歌曲已知 fileSize 粗估（远程转码后实际大小可能有出入，
    // 下载完成后按真实字节数记账）。maxSize=0 表示不限制。
    if (maxSize > 0 &&
        song.fileSize > 0 &&
        totalSize() + song.fileSize > maxSize) {
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
    final ext = _extForSong(song);
    final finalPath = '${dir.path}/${song.id}.$ext';
    final partPath = '$finalPath.part';

    try {
      await _dio.download(
        downloadUrl,
        partPath,
        onReceiveProgress: onProgress,
        cancelToken: cancelToken,
      );
      // 原子落地：源与目标同目录，rename 一定同设备。
      final partFile = File(partPath);
      final size = await partFile.length();
      await partFile.rename(finalPath);

      _index[song.id] = CachedSongEntry(
        songId: song.id,
        path: finalPath,
        format: song.format,
        bitRate: song.bitRate,
        size: size,
        cachedAt: DateTime.now(),
        title: song.title,
        artist: song.artist,
        sourceTags: {tag},
      );
      await _persist();
    } catch (e) {
      // 清理半截文件
      try {
        final part = File(partPath);
        if (await part.exists()) await part.delete();
      } catch (_) {}
      rethrow;
    }
  }

  /// 清除单曲缓存（删文件 + 删索引），无视来源标签。
  Future<void> removeSong(int songId) async {
    if (kIsWeb) return;
    await load();
    final e = _index.remove(songId);
    if (e != null) {
      await _deleteFile(e.path);
      await _persist();
    }
  }

  /// 清除某歌单的缓存：逐首摘掉 `pl:<playlistId>` 标签，标签清空的才删文件。
  Future<void> removePlaylist(int playlistId) async {
    if (kIsWeb) return;
    await load();
    final tag = songCachePlaylistTag(playlistId);
    var changed = false;
    final toDelete = <int>[];
    for (final entry in _index.values.toList()) {
      if (!entry.sourceTags.contains(tag)) continue;
      final remaining = {...entry.sourceTags}..remove(tag);
      changed = true;
      if (remaining.isEmpty) {
        toDelete.add(entry.songId);
        await _deleteFile(entry.path);
      } else {
        _index[entry.songId] = entry.copyWith(sourceTags: remaining);
      }
    }
    for (final id in toDelete) {
      _index.remove(id);
    }
    if (changed) await _persist();
  }

  /// 清空全部本地歌曲缓存。
  Future<void> clearAll() async {
    if (kIsWeb) return;
    await load();
    _index.clear();
    try {
      final dir = await _ensureDir();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        await dir.create(recursive: true);
      }
    } catch (e) {
      debugPrint('[SongCacheService] clearAll failed: $e');
    }
  }

  Future<void> _deleteFile(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (e) {
      debugPrint('[SongCacheService] delete file failed: $e');
    }
  }

  String _extForSong(Song song) {
    final f = song.format?.trim().toLowerCase();
    if (f != null && f.isNotEmpty && !f.contains('/') && f.length <= 5) {
      return f;
    }
    return 'audio';
  }
}
