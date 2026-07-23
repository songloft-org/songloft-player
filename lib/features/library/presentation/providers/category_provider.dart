import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/models/song.dart';
import '../../../playlist/presentation/providers/playlist_provider.dart'
    show PaginatedSongsState;
import '../../data/songs_api.dart';
import 'songs_provider.dart';

/// 分类浏览支持的 7 个维度字段（顺序即 UI 展示顺序）。
const List<String> categoryFields = [
  'genre',
  'artist',
  'album',
  'year',
  'decade',
  'language',
  'style',
];

/// 维度字段的展示名称。
String categoryFieldLabel(AppLocalizations l10n, String field) {
  switch (field) {
    case 'genre':
      return l10n.categoryFieldGenre;
    case 'artist':
      return l10n.categoryFieldArtist;
    case 'album':
      return l10n.categoryFieldAlbum;
    case 'year':
      return l10n.categoryFieldYear;
    case 'decade':
      return l10n.categoryFieldDecade;
    case 'language':
      return l10n.categoryFieldLanguage;
    case 'style':
      return l10n.categoryFieldStyle;
    default:
      return field;
  }
}

/// 某取值的展示文案（year/decade 做数字友好化，其余原样返回）。
String categoryValueLabel(AppLocalizations l10n, String field, String value) {
  if (value.isEmpty) return l10n.categoryValueUnknown;
  switch (field) {
    case 'decade':
      return l10n.categoryValueDecade(value);
    case 'year':
      return l10n.categoryValueYear(value);
    default:
      return value;
  }
}

/// 某维度 facet 网格的分页状态。
class FacetListState {
  final List<SongFacet> items;
  final int total;
  final bool hasMore;
  final bool isLoadingMore;

  /// 当前生效的服务端搜索关键词。
  final String keyword;
  final Object? loadMoreError;

  const FacetListState({
    required this.items,
    required this.total,
    required this.hasMore,
    this.isLoadingMore = false,
    this.keyword = '',
    this.loadMoreError,
  });

  FacetListState copyWith({
    List<SongFacet>? items,
    int? total,
    bool? hasMore,
    bool? isLoadingMore,
    String? keyword,
    Object? loadMoreError,
    bool clearError = false,
  }) => FacetListState(
    items: items ?? this.items,
    total: total ?? this.total,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    keyword: keyword ?? this.keyword,
    loadMoreError: clearError ? null : (loadMoreError ?? this.loadMoreError),
  );
}

/// 某维度 facet 卡片网格的分页 Notifier。
///
/// - family 参数为维度字段（genre/artist/album/language/style/year/decade）。
/// - 首屏加载 pageLimit 条；触底 [loadMore] 加载下一页；[search] 触发服务端关键词搜索重载。
/// - 后端返回 total（去重取值总数），通过 `items.length < total` 判断是否还有更多。
/// - 复用现有 [CategorySongsNotifier] 的 family 写法（extends AsyncNotifier + 构造注入 key）。
class FacetListNotifier extends AsyncNotifier<FacetListState> {
  FacetListNotifier(this._field);

  final String _field;

  /// 每页大小（网格视图，取偏大值减少翻页）。
  static const int pageLimit = 60;

  String _keyword = '';

  Future<SongFacetResponse> _fetch({required int offset}) {
    final api = ref.read(songsApiProvider);
    return api.getFacets(
      _field,
      keyword: _keyword,
      limit: pageLimit,
      offset: offset,
    );
  }

  FacetListState _fromResponse(SongFacetResponse resp) => FacetListState(
    items: resp.facets,
    total: resp.total,
    hasMore: resp.facets.length < resp.total,
    isLoadingMore: false,
    keyword: _keyword,
  );

  @override
  Future<FacetListState> build() async {
    final resp = await _fetch(offset: 0);
    return _fromResponse(resp);
  }

  /// 服务端关键词搜索（空串清除）。keyword 未变化时不重复请求。
  Future<void> search(String keyword) async {
    final normalized = keyword.trim();
    if (normalized == _keyword) return;
    _keyword = normalized;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async => _fromResponse(await _fetch(offset: 0)));
  }

  /// 触底加载下一页。
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null) return;
    if (!current.hasMore || current.isLoadingMore) return;

    state = AsyncValue.data(
      current.copyWith(isLoadingMore: true, clearError: true),
    );
    try {
      final resp = await _fetch(offset: current.items.length);
      final merged = [...current.items, ...resp.facets];
      state = AsyncValue.data(
        current.copyWith(
          items: merged,
          total: resp.total,
          hasMore: merged.length < resp.total,
          isLoadingMore: false,
          clearError: true,
        ),
      );
    } catch (e) {
      state = AsyncValue.data(
        current.copyWith(isLoadingMore: false, loadMoreError: e),
      );
    }
  }
}

/// 某维度 facet 网格分页 Provider（family 参数为维度字段）。
final facetListProvider =
    AsyncNotifierProvider.family<FacetListNotifier, FacetListState, String>(
      FacetListNotifier.new,
    );

/// getSongs 的分类过滤参数集合（各维度互斥，仅其一非空）。
typedef CategoryFilter = ({
  String? genre,
  String? artist,
  String? album,
  String? language,
  String? style,
  int? year,
  int? decade,
});

/// 将分类维度 [key]（field + value）映射为 getSongs 的过滤参数。
///
/// 分类页拉取分页、以及点击单曲后后台补齐整个分类队列，都要用同一套映射，
/// 故抽出此纯函数作为唯一来源，避免映射逻辑散落多处漂移。
CategoryFilter categorySongsFilter(({String field, String value}) key) {
  final field = key.field;
  final value = key.value;
  return (
    genre: field == 'genre' ? value : null,
    artist: field == 'artist' ? value : null,
    album: field == 'album' ? value : null,
    language: field == 'language' ? value : null,
    style: field == 'style' ? value : null,
    year: field == 'year' ? int.tryParse(value) : null,
    decade: field == 'decade' ? int.tryParse(value) : null,
  );
}

/// 某分类下歌曲的分页 Notifier。
///
/// - family 参数为 (field, value)：field 决定给 getSongs 传哪个过滤参数，
///   value 为该维度的取值（year/decade 是数字字符串，需转 int）。
/// - 初次进入加载首页（pageLimit 条）。
/// - 列表滚动到底部时 [loadMore] 加载下一页。
/// - 后端响应包含 total 字段，通过 `items.length < total` 判断是否还有更多。
/// - 复用歌单模块的 [PaginatedSongsState] 分页状态类，避免重造。
class CategorySongsNotifier extends AsyncNotifier<PaginatedSongsState> {
  CategorySongsNotifier(this._key);

  /// family 参数：分类维度字段与取值
  final ({String field, String value}) _key;

  /// 每页大小
  static const int pageLimit = 100;

  /// 按 field 分发到对应的 getSongs 过滤参数并发起请求。
  Future<SongListResponse> _fetch(SongsApi api, {required int offset}) {
    final f = categorySongsFilter(_key);
    return api.getSongs(
      genre: f.genre,
      artist: f.artist,
      album: f.album,
      language: f.language,
      style: f.style,
      year: f.year,
      decade: f.decade,
      limit: pageLimit,
      offset: offset,
    );
  }

  @override
  Future<PaginatedSongsState> build() async {
    final api = ref.watch(songsApiProvider);
    final response = await _fetch(api, offset: 0);
    return PaginatedSongsState(
      items: response.songs,
      total: response.total,
      hasMore: response.songs.length < response.total,
      isLoadingMore: false,
    );
  }

  /// 加载该分类下的全部歌曲（用于「播放全部」「全选」，需要整个分类在内存中）。
  /// 已全部加载则直接返回。
  Future<void> loadAll() async {
    // provider 可能尚未完成首屏 build——如从分类列表页「播放全部」直接触发时，
    // 该 provider 从未被 watch 过，state.value 为 null。此处 await future 触发并
    // 等待首屏加载，否则会直接返回空列表被误判为「没有歌曲」（详情页因先 watch
    // 过首屏才恰好正常）。
    var current = state.value ?? await future;
    final api = ref.read(songsApiProvider);
    while (current.hasMore) {
      final response = await _fetch(api, offset: current.items.length);
      if (response.songs.isEmpty) {
        state = AsyncValue.data(current.copyWith(hasMore: false));
        return;
      }
      final merged = [...current.items, ...response.songs];
      current = current.copyWith(
        items: merged,
        total: response.total,
        hasMore: merged.length < response.total,
      );
      state = AsyncValue.data(current);
    }
  }

  /// 触底加载下一页
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null) return;
    if (!current.hasMore || current.isLoadingMore) return;

    state = AsyncValue.data(
      current.copyWith(isLoadingMore: true, clearError: true),
    );

    try {
      final api = ref.read(songsApiProvider);
      final response = await _fetch(api, offset: current.items.length);
      if (response.songs.isEmpty) {
        state = AsyncValue.data(
          current.copyWith(
            hasMore: false,
            isLoadingMore: false,
            clearError: true,
          ),
        );
        return;
      }
      final merged = [...current.items, ...response.songs];
      state = AsyncValue.data(
        current.copyWith(
          items: merged,
          total: response.total,
          hasMore: merged.length < response.total,
          isLoadingMore: false,
          clearError: true,
        ),
      );
    } catch (e) {
      state = AsyncValue.data(
        current.copyWith(isLoadingMore: false, loadMoreError: e),
      );
    }
  }
}

/// 分类下歌曲分页 Provider（family 参数为 (field, value)）
final categorySongsProvider = AsyncNotifierProvider.family<
  CategorySongsNotifier,
  PaginatedSongsState,
  ({String field, String value})
>(CategorySongsNotifier.new);
