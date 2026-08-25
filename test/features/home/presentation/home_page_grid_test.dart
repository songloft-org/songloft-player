import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songloft_flutter/features/home/domain/home_grid_config.dart';
import 'package:songloft_flutter/features/home/presentation/home_page.dart';
import 'package:songloft_flutter/features/home/presentation/providers/home_grid_config_provider.dart';
import 'package:songloft_flutter/features/jsplugin/data/jsplugin_api.dart';
import 'package:songloft_flutter/features/jsplugin/presentation/providers/jsplugin_provider.dart';
import 'package:songloft_flutter/features/library/presentation/providers/songs_provider.dart';
import 'package:songloft_flutter/features/player/presentation/providers/player_provider.dart';
import 'package:songloft_flutter/features/playlist/domain/playlist.dart';
import 'package:songloft_flutter/features/playlist/presentation/providers/playlist_provider.dart';
import 'package:songloft_flutter/features/settings/presentation/providers/settings_provider.dart';
import 'package:songloft_flutter/l10n/app_localizations.dart';
import 'package:songloft_flutter/shared/models/library_stats.dart';

/// 首页宽屏歌单网格的行列配置（songloft-org/songloft#332）。
///
/// 网格几何本身的边界在 test/features/home/domain/home_grid_config_test.dart 里
/// 单测；这里只验证「配置真的接到了 GridView 上」以及数据源三态 gating。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  /// 宽屏视口。首页只有 useWideLayout 时才走网格分支。
  void useWideViewport(WidgetTester tester, {double width = 1600}) {
    tester.view.physicalSize = Size(width, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpHome(
    WidgetTester tester, {
    int? normalCount,
    int? radioCount,
    PaginatedPlaylistsNotifier Function()? normalNotifier,
    HomeGridConfig config = HomeGridConfig.defaults,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playlistListProvider('normal').overrideWith(
            () =>
                normalNotifier != null
                    ? normalNotifier()
                    : normalCount == null
                    ? _FailingNotifier('normal')
                    : _FakePlaylistsNotifier('normal', normalCount),
          ),
          playlistListProvider('radio').overrideWith(
            () =>
                radioCount == null
                    ? _FailingNotifier('radio')
                    : _FakePlaylistsNotifier('radio', radioCount),
          ),
          homeGridConfigProvider.overrideWith(() => _FixedGridConfig(config)),
          jsPluginsProvider.overrideWith((ref) async => const <JSPlugin>[]),
          // 底部 StatsStrip 自己 watch 这个 provider，不短路会经 dioProvider
          // 走 secure storage 平台通道发真请求。
          libraryStatsProvider.overrideWith((ref) async => LibraryStats.empty),
          // 首页 initState 会跑一次启动更新检查，真发 HTTP 会留下 30s 的 pending
          // timer 让测试报错。把它依赖的两个 provider 短路掉。
          githubProxyProvider.overrideWith(() => _NoProxyNotifier()),
          frontendVersionCheckProvider.overrideWith(
            (ref) => throw Exception('skip update check in tests'),
          ),
          playerStateProvider.overrideWith(
            () => throw UnimplementedError('mock'),
          ),
          isPlayingProvider.overrideWith((ref) => false),
          sourcePlaylistIdProvider.overrideWith((ref) => null),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomePage(),
        ),
      ),
    );
    // 不用 pumpAndSettle：首页 initState 里的启动更新检查会发起网络请求，
    // settle 等不到静止。固定 pump 足够让两个 AsyncNotifier 完成。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  SliverGridDelegateWithFixedCrossAxisCount firstDelegate(WidgetTester tester) {
    final grid = tester.widget<GridView>(find.byType(GridView).first);
    return grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
  }

  /// GridView.builder 把 itemCount 塞进 semanticChildCount，比数 InkWell 稳。
  int? firstItemCount(WidgetTester tester) =>
      tester.widget<GridView>(find.byType(GridView).first).semanticChildCount;

  testWidgets('默认配置渲染 4 列 × 2 行 = 8 张卡（与改造前一致）', (tester) async {
    useWideViewport(tester);
    await pumpHome(tester, normalCount: 20, radioCount: 20);

    expect(firstDelegate(tester).crossAxisCount, 4);
    // 长宽比被夹回改造前的字面值 ⇒ 默认路径零视觉 diff
    expect(firstDelegate(tester).childAspectRatio, kHomeGridMaxAspectRatio);
    expect(firstItemCount(tester), 8);
  });

  testWidgets('配置 5 列 × 3 行时网格用 5 列并截断到 15 张', (tester) async {
    useWideViewport(tester);
    await pumpHome(
      tester,
      normalCount: 20,
      radioCount: 20,
      config: const HomeGridConfig(columns: 5, rows: 3),
    );

    expect(firstDelegate(tester).crossAxisCount, 5);
    expect(firstItemCount(tester), 15);
  });

  testWidgets('「全部」行数不截断，12 个歌单全部渲染', (tester) async {
    useWideViewport(tester);
    await pumpHome(
      tester,
      normalCount: 12,
      radioCount: 3,
      config: const HomeGridConfig(columns: 5, rows: HomeGridConfig.allRows),
    );

    expect(firstItemCount(tester), 12);
  });

  testWidgets('窄窗口下 6 列被 clamp，且行数语义仍是 2 行', (tester) async {
    // 760px：仍是宽屏分支（>=600）但内容宽放不下 6 列
    useWideViewport(tester, width: 760);
    await pumpHome(
      tester,
      normalCount: 20,
      radioCount: 0,
      config: const HomeGridConfig(columns: 6, rows: 2),
    );

    final crossAxisCount = firstDelegate(tester).crossAxisCount;
    expect(crossAxisCount, lessThan(6));
    // 截断按 clamp 后的列数算，否则会多渲染出第三行
    expect(firstItemCount(tester), crossAxisCount * 2);
  });

  testWidgets('「全部」行数会自动续拉后续分页，直到上游没有更多', (tester) async {
    useWideViewport(tester);
    // 首页只发 1 页（30 条），上游共 45 条
    final normal = _PagedNotifier('normal', total: 45);
    await pumpHome(
      tester,
      normalNotifier: () => normal,
      radioCount: 0,
      config: const HomeGridConfig(columns: 5, rows: HomeGridConfig.allRows),
    );
    // 给 post-frame 续拉几帧时间
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(normal.loadMoreCalls, 1);
    expect(firstItemCount(tester), 45);
  });

  testWidgets('有限行数时不触发续拉（不白发请求）', (tester) async {
    useWideViewport(tester);
    final normal = _PagedNotifier('normal', total: 45);
    await pumpHome(
      tester,
      normalNotifier: () => normal,
      radioCount: 0,
      config: const HomeGridConfig(columns: 5, rows: 2),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(normal.loadMoreCalls, 0);
    expect(firstItemCount(tester), 10);
  });

  testWidgets('续拉在 kHomeAutoLoadAllMaxItems 处停住，不无限拉', (tester) async {
    useWideViewport(tester);
    // 上游数量远超上限，且 hasMore 恒真
    final normal = _PagedNotifier('normal', total: 100000);
    await pumpHome(
      tester,
      normalNotifier: () => normal,
      radioCount: 0,
      config: const HomeGridConfig(columns: 5, rows: HomeGridConfig.allRows),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(
      normal.items.length,
      lessThanOrEqualTo(
        kHomeAutoLoadAllMaxItems + PaginatedPlaylistsNotifier.pageLimit,
      ),
    );
    expect(normal.loadMoreCalls, lessThan(20));
  });

  testWidgets('电台区有「查看全部」出口（按行数截断后用户能到曲库）', (tester) async {
    useWideViewport(tester);
    await pumpHome(tester, normalCount: 20, radioCount: 20);

    // 两个 section 各一个「查看全部」
    expect(find.text('查看全部'), findsNWidgets(2));
  });

  testWidgets('一类歌单加载失败时另一类照常渲染，不整页报错', (tester) async {
    useWideViewport(tester);
    await pumpHome(tester, normalCount: null, radioCount: 5);

    // 电台区仍在并渲染了网格
    expect(find.text('我的电台'), findsOneWidget);
    expect(find.byType(GridView), findsOneWidget);
    // 失败的歌单区显示内联重试，而不是整页错误
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('两类都失败时整页报错', (tester) async {
    useWideViewport(tester);
    await pumpHome(tester, normalCount: null, radioCount: null);

    expect(find.text('加载失败'), findsOneWidget);
    expect(find.text('我的电台'), findsNothing);
    expect(find.byType(GridView), findsNothing);
  });
}

/// 固定返回指定配置，绕开 SharedPreferences 的异步回读
class _FixedGridConfig extends HomeGridConfigNotifier {
  _FixedGridConfig(this._config);

  final HomeGridConfig _config;

  @override
  HomeGridConfig build() => _config;
}

class _FakePlaylistsNotifier extends PaginatedPlaylistsNotifier {
  _FakePlaylistsNotifier(String super.typeArg, this._count) : _type = typeArg;

  final String _type;
  final int _count;

  @override
  Future<PaginatedPlaylistsState> build() async {
    final now = DateTime.utc(2026, 1, 1);
    return PaginatedPlaylistsState(
      items: List.generate(
        _count,
        (i) => Playlist(
          id: i + 1,
          name: '$_type $i',
          type: _type,
          songCount: i,
          createdAt: now,
          updatedAt: now,
        ),
      ),
      totalCount: _count,
      hasMore: false,
      isLoadingMore: false,
    );
  }
}

/// 可分页的假上游：模拟 total 条数据，按 pageLimit 分页，记录 loadMore 调用次数。
class _PagedNotifier extends PaginatedPlaylistsNotifier {
  _PagedNotifier(String super.typeArg, {required this.total}) : _type = typeArg;

  final String _type;
  final int total;
  int loadMoreCalls = 0;
  List<Playlist> items = const [];

  List<Playlist> _page(int offset) {
    final now = DateTime.utc(2026, 1, 1);
    final end =
        (offset + PaginatedPlaylistsNotifier.pageLimit) > total
            ? total
            : offset + PaginatedPlaylistsNotifier.pageLimit;
    return List.generate(
      end - offset,
      (i) => Playlist(
        id: offset + i + 1,
        name: '$_type ${offset + i}',
        type: _type,
        songCount: 0,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  PaginatedPlaylistsState _stateFor(List<Playlist> all) {
    items = all;
    return PaginatedPlaylistsState(
      items: all,
      totalCount: total,
      hasMore: all.length < total,
      isLoadingMore: false,
    );
  }

  @override
  Future<PaginatedPlaylistsState> build() async => _stateFor(_page(0));

  @override
  Future<void> loadMore() async {
    loadMoreCalls++;
    final current = state.value;
    if (current == null || !current.hasMore) return;
    state = AsyncValue.data(
      _stateFor([...current.items, ..._page(current.items.length)]),
    );
  }
}

class _FailingNotifier extends PaginatedPlaylistsNotifier {
  _FailingNotifier(String super.typeArg);

  @override
  Future<PaginatedPlaylistsState> build() async {
    throw Exception('boom');
  }
}

/// 不发 HTTP 的 GitHub 代理：直连
class _NoProxyNotifier extends GithubProxyNotifier {
  @override
  Future<String> build() async => '';
}
