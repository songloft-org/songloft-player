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

/// 某维度的标签分类聚合清单 Provider。
///
/// family 参数为维度字段（genre/artist/album/language/style/year/decade），
/// 返回按歌曲数降序的 (value, count) 列表，供分类总览页渲染取值卡片。
final facetsProvider = FutureProvider.family<List<SongFacet>, String>((
  ref,
  field,
) async {
  final api = ref.watch(songsApiProvider);
  return api.getFacets(field);
});

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
    final field = _key.field;
    final value = _key.value;
    return api.getSongs(
      genre: field == 'genre' ? value : null,
      artist: field == 'artist' ? value : null,
      album: field == 'album' ? value : null,
      language: field == 'language' ? value : null,
      style: field == 'style' ? value : null,
      year: field == 'year' ? int.tryParse(value) : null,
      decade: field == 'decade' ? int.tryParse(value) : null,
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
    var current = state.value;
    if (current == null) return;
    final api = ref.read(songsApiProvider);
    while (current != null && current.hasMore) {
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
