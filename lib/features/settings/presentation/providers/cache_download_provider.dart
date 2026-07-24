import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/backend/run_mode_provider.dart';
import '../../../../core/storage/song_cache_service.dart';
import '../../../../shared/models/song.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'song_cache_provider.dart';

/// 歌单批量缓存进度（songloft-org/songloft#312）。
@immutable
class CacheDownloadState {
  final bool running;
  final int total;
  final int done;
  final int failed;
  final String? currentTitle;
  final int? playlistId;

  /// 因达到本地缓存上限而中止。
  final bool limitHit;

  const CacheDownloadState({
    this.running = false,
    this.total = 0,
    this.done = 0,
    this.failed = 0,
    this.currentTitle,
    this.playlistId,
    this.limitHit = false,
  });

  CacheDownloadState copyWith({
    bool? running,
    int? total,
    int? done,
    int? failed,
    String? currentTitle,
    int? playlistId,
    bool? limitHit,
  }) {
    return CacheDownloadState(
      running: running ?? this.running,
      total: total ?? this.total,
      done: done ?? this.done,
      failed: failed ?? this.failed,
      currentTitle: currentTitle ?? this.currentTitle,
      playlistId: playlistId ?? this.playlistId,
      limitHit: limitHit ?? this.limitHit,
    );
  }
}

final cacheDownloadProvider =
    NotifierProvider<CacheDownloadNotifier, CacheDownloadState>(
      CacheDownloadNotifier.new,
    );

/// 串行下载队列：逐首缓存，避免并发占满磁盘/网络；可取消。
///
/// 串行而非并发的取舍：单曲缓存的瓶颈通常是网络，并发收益有限，而串行下取消/
/// 进度/错误处理都简单可靠，且不会同时打满多路上游转码 worker。
class CacheDownloadNotifier extends Notifier<CacheDownloadState> {
  CancelToken? _cancelToken;
  bool _cancelled = false;

  @override
  CacheDownloadState build() => const CacheDownloadState();

  bool get isRunning => state.running;

  void cancel() {
    _cancelled = true;
    _cancelToken?.cancel('user-cancelled');
  }

  /// 缓存整个歌单：过滤不可缓存项（直播 / 本地模式下的 local），逐首下载。
  Future<void> cachePlaylist(List<Song> songs, int playlistId) async {
    if (state.running) return;

    final runMode = ref.read(runModeProvider);
    final targets =
        songs.where((s) => canCacheLocally(s, runMode: runMode)).toList();
    if (targets.isEmpty) return;

    final prefs = await ref.read(appPreferencesProvider.future);
    final quality = prefs.getAudioQuality();
    final maxSize = prefs.getLocalCacheMaxSize();
    final cacheNotifier = ref.read(songCacheProvider.notifier);
    final tag = songCachePlaylistTag(playlistId);

    _cancelled = false;
    state = CacheDownloadState(
      running: true,
      total: targets.length,
      playlistId: playlistId,
    );

    var done = 0;
    var failed = 0;
    for (final song in targets) {
      if (_cancelled) break;
      state = state.copyWith(currentTitle: song.title);
      _cancelToken = CancelToken();
      try {
        await SongCacheService().cache(
          song,
          tag: tag,
          quality: quality,
          maxSize: maxSize,
          cancelToken: _cancelToken,
        );
        done++;
      } on SongCacheLimitExceeded {
        state = state.copyWith(
          running: false,
          limitHit: true,
          done: done,
          failed: failed,
        );
        cacheNotifier.bump();
        return;
      } catch (e) {
        if (_cancelled) break;
        failed++;
        debugPrint('[CacheDownload] cache failed for ${song.title}: $e');
      }
      state = state.copyWith(done: done, failed: failed);
    }

    // 批量结束统一刷新缓存 UI（列表 / 菜单文案）。
    cacheNotifier.bump();
    state = state.copyWith(running: false, done: done, failed: failed);
  }
}
