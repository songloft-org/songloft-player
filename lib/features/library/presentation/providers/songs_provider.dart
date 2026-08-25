import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../shared/models/library_stats.dart';
import '../../../../shared/models/song.dart';
import '../../data/songs_api.dart';
import '../../data/songs_repository.dart';

/// SongsApi Provider
final songsApiProvider = Provider<SongsApi>((ref) {
  final dio = ref.watch(dioProvider);
  return SongsApi(dio);
});

/// SongsRepository Provider
final songsRepositoryProvider = Provider<SongsRepository>((ref) {
  final songsApi = ref.watch(songsApiProvider);
  return SongsRepository(songsApi);
});

/// 歌曲列表状态
class SongsListState {
  final List<Song> songs;
  final int total;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final String keyword;
  final String? type;
  final int currentPage;
  final bool hasMore;
  final bool isSelectionMode;
  final Set<int> selectedSongIds;
  final bool isSelectingAll;
  final String sort;
  final String order;

  /// 排除属于这些 label 歌单的歌曲：null → 后端默认排除隐藏歌单；'none' → 显示全部
  final String? excludePlaylistLabels;

  const SongsListState({
    this.songs = const [],
    this.total = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.keyword = '',
    this.type,
    this.currentPage = 0,
    this.hasMore = true,
    this.isSelectionMode = false,
    this.selectedSongIds = const {},
    this.isSelectingAll = false,
    this.sort = 'added_at',
    this.order = 'desc',
    this.excludePlaylistLabels,
  });

  /// 库页面是否处于「显示隐藏歌曲」状态
  bool get showHidden => excludePlaylistLabels == 'none';

  SongsListState copyWith({
    List<Song>? songs,
    int? total,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    String? keyword,
    String? type,
    int? currentPage,
    bool? hasMore,
    bool? isSelectionMode,
    Set<int>? selectedSongIds,
    bool? isSelectingAll,
    String? sort,
    String? order,
    String? excludePlaylistLabels,
    bool clearError = false,
    bool clearType = false,
    bool clearExcludePlaylistLabels = false,
  }) {
    return SongsListState(
      songs: songs ?? this.songs,
      total: total ?? this.total,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      keyword: keyword ?? this.keyword,
      type: clearType ? null : (type ?? this.type),
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      selectedSongIds: selectedSongIds ?? this.selectedSongIds,
      isSelectingAll: isSelectingAll ?? this.isSelectingAll,
      sort: sort ?? this.sort,
      order: order ?? this.order,
      excludePlaylistLabels:
          clearExcludePlaylistLabels
              ? null
              : (excludePlaylistLabels ?? this.excludePlaylistLabels),
    );
  }
}

/// 歌曲列表状态管理器
class SongsListNotifier extends Notifier<SongsListState> {
  late SongsRepository _repository;
  final int _pageSize = AppConstants.defaultPageSize;

  @override
  SongsListState build() {
    _repository = ref.watch(songsRepositoryProvider);
    return const SongsListState();
  }

  /// 加载歌曲列表
  Future<void> loadSongs({
    int page = 0,
    String? keyword,
    String? type,
    bool clearType = false,
  }) async {
    // 如果要清除 type，传 clearType; 否则传 type
    state = state.copyWith(
      isLoading: true,
      keyword: keyword ?? state.keyword,
      type: clearType ? null : type,
      clearType: clearType,
      currentPage: page,
      clearError: true,
    );

    final effectiveType = clearType ? null : (type ?? state.type);

    try {
      final response = await _repository.getSongs(
        type: effectiveType,
        keyword: keyword ?? state.keyword,
        excludePlaylistLabels: state.excludePlaylistLabels,
        limit: _pageSize,
        offset: page * _pageSize,
        sort: state.sort,
        order: state.order,
      );

      state = state.copyWith(
        songs: response.songs,
        total: response.total,
        isLoading: false,
        hasMore: response.songs.length >= _pageSize,
        currentPage: page,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 加载更多
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final nextPage = state.currentPage + 1;
      final response = await _repository.getSongs(
        type: state.type,
        keyword: state.keyword,
        excludePlaylistLabels: state.excludePlaylistLabels,
        limit: _pageSize,
        offset: nextPage * _pageSize,
        sort: state.sort,
        order: state.order,
      );

      state = state.copyWith(
        songs: [...state.songs, ...response.songs],
        total: response.total,
        isLoadingMore: false,
        hasMore: response.songs.length >= _pageSize,
        currentPage: nextPage,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  /// 刷新
  Future<void> refresh() async {
    await loadSongs(page: 0, keyword: state.keyword, type: state.type);
  }

  /// 搜索
  Future<void> search(String keyword) async {
    await loadSongs(page: 0, keyword: keyword, type: state.type);
  }

  /// 设置排序字段与方向后重新加载
  Future<void> setSort(String sort, String order) async {
    if (state.sort == sort && state.order == order) return;
    state = state.copyWith(sort: sort, order: order);
    await loadSongs(page: 0, keyword: state.keyword, type: state.type);
  }

  /// 切换是否显示隐藏歌单里的歌曲。
  /// show=true → 传 'none' 显示全部；show=false → 恢复默认（后端排除隐藏歌单）
  Future<void> setShowHidden(bool show) async {
    if (state.showHidden == show) return;
    state = state.copyWith(
      excludePlaylistLabels: show ? 'none' : null,
      clearExcludePlaylistLabels: !show,
    );
    await loadSongs(page: 0, keyword: state.keyword, type: state.type);
  }

  /// 设置类型筛选
  Future<void> setTypeFilter(String? type) async {
    if (type == null) {
      // 点击"全部"时，清除 type 筛选
      await loadSongs(page: 0, keyword: state.keyword, clearType: true);
    } else {
      await loadSongs(page: 0, keyword: state.keyword, type: type);
    }
  }

  /// 切换多选模式
  void toggleSelectMode() {
    if (state.isSelectionMode) {
      state = state.copyWith(isSelectionMode: false, selectedSongIds: {});
    } else {
      state = state.copyWith(isSelectionMode: true);
    }
  }

  /// 切换歌曲选中状态
  void toggleSongSelection(int songId) {
    final newSelection = Set<int>.from(state.selectedSongIds);
    if (newSelection.contains(songId)) {
      newSelection.remove(songId);
    } else {
      newSelection.add(songId);
    }
    state = state.copyWith(selectedSongIds: newSelection);
  }

  /// 清除选择
  void clearSelection() {
    state = state.copyWith(selectedSongIds: {});
  }

  /// 全选/取消全选：覆盖当前筛选条件下的全部歌曲（不仅是已加载的页）
  /// - 已全选 → 清空
  /// - 否则 → 调 /songs/ids 一次性拿到所有匹配 id
  Future<void> toggleSelectAll() async {
    if (state.isSelectingAll) return;

    if (state.selectedSongIds.isNotEmpty &&
        state.total > 0 &&
        state.selectedSongIds.length >= state.total) {
      state = state.copyWith(selectedSongIds: {});
      return;
    }

    state = state.copyWith(isSelectingAll: true, clearError: true);
    try {
      final ids = await _repository.getSongIds(
        type: state.type,
        keyword: state.keyword.isNotEmpty ? state.keyword : null,
        excludePlaylistLabels: state.excludePlaylistLabels,
        sort: state.sort,
        order: state.order,
      );
      state = state.copyWith(
        selectedSongIds: ids.toSet(),
        isSelectingAll: false,
      );
    } catch (e) {
      state = state.copyWith(isSelectingAll: false, error: e.toString());
    }
  }

  /// 删除歌曲
  Future<void> deleteSong(int songId, {bool deleteFiles = false}) async {
    try {
      await _repository.deleteSong(songId, deleteFiles: deleteFiles);
      state = state.copyWith(
        songs: state.songs.where((s) => s.id != songId).toList(),
        total: state.total - 1,
        selectedSongIds: state.selectedSongIds.difference({songId}),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// 批量删除歌曲
  Future<int> batchDeleteSongs({bool deleteFiles = false}) async {
    if (state.selectedSongIds.isEmpty) return 0;

    final selectedIds = state.selectedSongIds.toList();

    try {
      final deleted = await _repository.batchDeleteSongs(
        selectedIds,
        deleteFiles: deleteFiles,
      );

      // 如果服务端返回的数量与选中数量不一致，状态可能已脏，直接全量刷新列表
      if (deleted != selectedIds.length) {
        await refresh();
        state = state.copyWith(isSelectionMode: false, selectedSongIds: {});
        return deleted;
      }

      // 正常路径：全部删除成功，按选中集合更新本地状态
      state = state.copyWith(
        songs:
            state.songs
                .where((s) => !state.selectedSongIds.contains(s.id))
                .toList(),
        total: state.total - deleted,
        isSelectionMode: false,
        selectedSongIds: {},
      );

      return deleted;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return 0;
    }
  }

  /// 清理歌曲
  Future<int> cleanSongs() async {
    try {
      final cleaned = await _repository.cleanSongs();
      await refresh();
      return cleaned;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return 0;
    }
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// 歌曲列表 NotifierProvider
final songsListProvider = NotifierProvider<SongsListNotifier, SongsListState>(
  SongsListNotifier.new,
);

/// 单首歌曲 Provider
final songDetailProvider = FutureProvider.family<Song, int>((
  ref,
  songId,
) async {
  final repository = ref.watch(songsRepositoryProvider);
  return repository.getSong(songId);
});

/// 曲库汇总统计 Provider（首页底部统计面板）
///
/// 刻意**不加** autoDispose：同屏的 `playlistListProvider` 是常驻缓存的，autoDispose
/// 会让切 tab 回首页时统计数重新取数而歌单网格不动，出现「数字变了、封面没变」的
/// 不一致。代价是曲库变更后统计数偏旧，由下拉刷新（HomePage.retryAll 里的
/// ref.invalidate）解决，与歌单区同一节奏。
final libraryStatsProvider = FutureProvider<LibraryStats>((ref) async {
  final api = ref.watch(songsApiProvider);
  return api.getLibraryStats();
});
