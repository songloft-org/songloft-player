import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/backend/run_mode_provider.dart';
import '../../../../core/storage/song_cache_service.dart';
import '../../../../shared/models/song.dart';

/// 某首歌能否在本机缓存（songloft-org/songloft#312）：
/// - Web 无持久文件存储，一律不可
/// - 直播/电台流无法缓存
/// - Bundle 本地模式下 `local` 歌曲后端就在设备上，缓存属重复占用
bool canCacheLocally(Song song, {required RunMode runMode}) {
  if (kIsWeb) return false;
  if (song.isLive) return false;
  if (runMode == RunMode.local && song.type == 'local') return false;
  return true;
}

/// 本机歌曲缓存状态。`state` 是修订号，每次增删缓存后自增以触发 UI 重建；
/// 具体查询/操作转发到单例 [SongCacheService]。
final songCacheProvider = NotifierProvider<SongCacheNotifier, int>(
  SongCacheNotifier.new,
);

class SongCacheNotifier extends Notifier<int> {
  final SongCacheService _service = SongCacheService();

  @override
  int build() {
    // 首帧异步载入索引，完成后 bump 修订号刷新已挂载的 UI。
    if (!kIsWeb) {
      _service.load().then((_) => state = state + 1);
    }
    return 0;
  }

  // ── 查询（同步，读内存索引）───────────────────────────────────────────────
  bool isCached(int songId) => _service.isCached(songId);
  CachedSongEntry? entry(int songId) => _service.entry(songId);
  int totalSize() => _service.totalSize();
  List<CachedSongEntry> get manualEntries => _service.manualEntries;
  Map<int, List<CachedSongEntry>> playlistGroups() => _service.playlistGroups();

  // ── 操作 ──────────────────────────────────────────────────────────────────

  /// 缓存单曲（打 [kSongCacheTagManual] 标签）。
  Future<void> cacheSong(
    Song song, {
    required String quality,
    required int maxSize,
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    await _service.cache(
      song,
      tag: kSongCacheTagManual,
      quality: quality,
      maxSize: maxSize,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    state = state + 1;
  }

  Future<void> removeSong(int songId) async {
    await _service.removeSong(songId);
    state = state + 1;
  }

  Future<void> removePlaylist(int playlistId) async {
    await _service.removePlaylist(playlistId);
    state = state + 1;
  }

  Future<void> clearAll() async {
    await _service.clearAll();
    state = state + 1;
  }

  /// 供批量队列在多首完成后统一刷新一次 UI。
  void bump() => state = state + 1;
}
