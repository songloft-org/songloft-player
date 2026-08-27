import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../shared/models/song.dart';
import '../../../playlist/presentation/providers/playlist_provider.dart'
    show PaginatedSongsState;
import '../../data/song_tags_api.dart';
import 'songs_provider.dart';

/// SongTagsApi Provider
final songTagsApiProvider = Provider<SongTagsApi>((ref) {
  final dio = ref.watch(dioProvider);
  return SongTagsApi(dio);
});

// ---------------------------------------------------------------------------
// 标签列表（网格浏览）
// ---------------------------------------------------------------------------

/// 标签网格分页状态
class SongTagListState {
  final List<SongTag> items;
  final int total;
  final bool hasMore;
  final bool isLoadingMore;
  final String keyword;

  const SongTagListState({
    required this.items,
    required this.total,
    required this.hasMore,
    this.isLoadingMore = false,
    this.keyword = '',
  });

  SongTagListState copyWith({
    List<SongTag>? items,
    int? total,
    bool? hasMore,
    bool? isLoadingMore,
    String? keyword,
  }) => SongTagListState(
    items: items ?? this.items,
    total: total ?? this.total,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    keyword: keyword ?? this.keyword,
  );
}

/// 标签网格分页 Notifier
class SongTagListNotifier extends AsyncNotifier<SongTagListState> {
  static const int pageLimit = 60;

  String _keyword = '';

  Future<SongTagListResponse> _fetch({required int offset}) {
    final api = ref.read(songTagsApiProvider);
    return api.list(keyword: _keyword, limit: pageLimit, offset: offset);
  }

  SongTagListState _fromResponse(SongTagListResponse resp) => SongTagListState(
    items: resp.tags,
    total: resp.total,
    hasMore: resp.tags.length < resp.total,
    keyword: _keyword,
  );

  @override
  Future<SongTagListState> build() async {
    final resp = await _fetch(offset: 0);
    return _fromResponse(resp);
  }

  Future<void> search(String keyword) async {
    final normalized = keyword.trim();
    if (normalized == _keyword) return;
    _keyword = normalized;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () async => _fromResponse(await _fetch(offset: 0)),
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));
    try {
      final resp = await _fetch(offset: current.items.length);
      final merged = [...current.items, ...resp.tags];
      state = AsyncValue.data(current.copyWith(
        items: merged,
        total: resp.total,
        hasMore: merged.length < resp.total,
        isLoadingMore: false,
      ));
    } catch (_) {
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
    }
  }

  Future<void> refresh() async {
    _keyword = '';
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () async => _fromResponse(await _fetch(offset: 0)),
    );
  }
}

final songTagListProvider =
    AsyncNotifierProvider<SongTagListNotifier, SongTagListState>(
      SongTagListNotifier.new,
    );

// ---------------------------------------------------------------------------
// 单首歌曲的标签列表
// ---------------------------------------------------------------------------

/// 获取某首歌的自定义标签
final songTagsForSongProvider =
    FutureProvider.family<List<SongTag>, int>((ref, songId) async {
      final api = ref.watch(songTagsApiProvider);
      return api.getSongTags(songId);
    });

// ---------------------------------------------------------------------------
// 标签下的歌曲列表（drill-down）
// ---------------------------------------------------------------------------

class TagSongsNotifier extends AsyncNotifier<PaginatedSongsState> {
  TagSongsNotifier(this._tagId);

  final int _tagId;
  static const int pageLimit = 100;

  Future<SongListResponse> _fetch({required int offset}) {
    final api = ref.read(songsApiProvider);
    return api.getSongs(tagId: _tagId, limit: pageLimit, offset: offset);
  }

  @override
  Future<PaginatedSongsState> build() async {
    final resp = await _fetch(offset: 0);
    return PaginatedSongsState(
      items: resp.songs,
      total: resp.total,
      hasMore: resp.songs.length < resp.total,
    );
  }

  Future<void> loadAll() async {
    var current = state.value ?? await future;
    final api = ref.read(songsApiProvider);
    while (current.hasMore) {
      final resp = await api.getSongs(
        tagId: _tagId,
        limit: pageLimit,
        offset: current.items.length,
      );
      if (resp.songs.isEmpty) {
        state = AsyncValue.data(current.copyWith(hasMore: false));
        return;
      }
      final merged = [...current.items, ...resp.songs];
      current = current.copyWith(
        items: merged,
        total: resp.total,
        hasMore: merged.length < resp.total,
      );
      state = AsyncValue.data(current);
    }
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncValue.data(current.copyWith(isLoadingMore: true, clearError: true));
    try {
      final resp = await _fetch(offset: current.items.length);
      final merged = [...current.items, ...resp.songs];
      state = AsyncValue.data(current.copyWith(
        items: merged,
        total: resp.total,
        hasMore: merged.length < resp.total,
        isLoadingMore: false,
      ));
    } catch (e) {
      state = AsyncValue.data(
        current.copyWith(isLoadingMore: false, loadMoreError: e),
      );
    }
  }
}

final tagSongsProvider = AsyncNotifierProvider.family<
  TagSongsNotifier,
  PaginatedSongsState,
  int
>(TagSongsNotifier.new);
