import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/core/theme/app_theme.dart';
import 'package:songloft_flutter/core/theme/widgets/glass_capsule_bar.dart';
import 'package:songloft_flutter/features/jsplugin/data/jsplugin_api.dart';
import 'package:songloft_flutter/features/jsplugin/presentation/providers/jsplugin_provider.dart';
import 'package:songloft_flutter/features/jsplugin/presentation/widgets/plugin_registry.dart';
import 'package:songloft_flutter/features/settings/data/settings_api.dart';
import 'package:songloft_flutter/features/settings/presentation/providers/settings_provider.dart';
import 'package:songloft_flutter/l10n/app_localizations.dart';
import 'package:songloft_flutter/shared/layouts/adaptive_scaffold.dart';

typedef _Request = ({int page, String? search, String url, bool force});

class _SettingsApi extends SettingsApi {
  _SettingsApi() : super(dio: Dio());

  @override
  Future<List<PluginRegistryConfig>> getPluginRegistries() async => [
    PluginRegistryConfig(url: 'https://example.com/a', name: '源 A'),
    PluginRegistryConfig(url: 'https://example.com/b', name: '源 B'),
  ];
}

class _NoProxy extends GithubProxyNotifier {
  @override
  Future<String> build() async => '';
}

class _RegistryApi extends JSPluginApi {
  _RegistryApi(this.fetch) : super(dio: Dio());

  final Future<RegistryRefreshResponse> Function(_Request) fetch;
  final requests = <_Request>[];

  @override
  Future<RegistryRefreshResponse> refreshRegistry({
    String registryUrl = '',
    bool allSources = false,
    int page = 1,
    int pageSize = 20,
    String? search,
    String? githubProxy,
    String? token,
    bool force = false,
  }) {
    final request = (
      page: page,
      search: search,
      url: registryUrl,
      force: force,
    );
    requests.add(request);
    return fetch(request);
  }

  @override
  Future<JSPluginUploadResponse> installFromRegistry({
    required String downloadUrl,
    String? githubProxy,
    String? token,
    String? sourceUrl,
    bool overwrite = false,
  }) async => JSPluginUploadResponse(
    total: 1,
    success: 1,
    failed: 0,
    results: [],
    message: '安装成功',
  );
}

RegistryRefreshResponse _page(
  int page, {
  int count = 20,
  int total = 40,
  String prefix = '插件',
}) => RegistryRefreshResponse(
  plugins: List.generate(
    count,
    (index) => RegistryPluginEntry(
      name: '$prefix ${(page - 1) * 20 + index}',
      entryPath: '$prefix-${(page - 1) * 20 + index}',
      version: '1.0.0',
      description: '测试插件描述',
      downloadUrl: 'https://example.com/plugin.zip',
    ),
  ),
  page: page,
  pageSize: 20,
  total: total,
);

Future<void> _pumpStore(
  WidgetTester tester,
  _RegistryApi api, {
  bool capsule = true,
  Size size = const Size(390, 800),
  double safeBottom = 24,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding(bottom: safeBottom);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsApiProvider.overrideWithValue(_SettingsApi()),
        jsPluginApiProvider.overrideWithValue(api),
        githubProxyProvider.overrideWith(_NoProxy.new),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          extensions: [
            SongloftThemeExtension(
              navigationStyle: capsule ? 'capsule' : 'standard',
            ),
          ],
        ),
        home: AdaptiveScaffold(
          body: const PluginRegistryPage(),
          currentIndex: 1,
          onDestinationSelected: (_) {},
          destinations: const [
            NavDestination(
              label: '首页',
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
            ),
            NavDestination(
              label: '设置',
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
            ),
          ],
        ),
      ),
    ),
  );
  await _pumpFrames(tester);
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var frame = 0; frame < 5; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _scrollToEnd(WidgetTester tester) async {
  final list = tester.widget<ListView>(find.byType(ListView));
  list.controller!.jumpTo(list.controller!.position.maxScrollExtent);
  await _pumpFrames(tester);
}

void main() {
  testWidgets('临近底部追加下一页，加载中保留条目并防止重复请求', (tester) async {
    final next = Completer<RegistryRefreshResponse>();
    final api = _RegistryApi(
      (request) async => request.page == 1 ? _page(1) : next.future,
    );
    await _pumpStore(tester, api);
    expect(api.requests.map((r) => r.page), [1]);
    expect(find.byIcon(Icons.chevron_left), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsNothing);

    await _scrollToEnd(tester);
    await _scrollToEnd(tester);
    expect(api.requests.map((r) => r.page), [1, 2]);
    expect(find.byType(ListView), findsOneWidget);
    expect(find.byKey(const ValueKey('插件-19|')), findsOneWidget);

    next.complete(_page(2));
    await _pumpFrames(tester);
    await _scrollToEnd(tester);
    expect(find.text('插件 39'), findsOneWidget);
    expect(api.requests.map((r) => r.page), [1, 2]);
    expect(api.requests.every((r) => !r.force), isTrue);
  });

  testWidgets('追加失败保留列表，重试同一页且不强制刷新', (tester) async {
    var attempts = 0;
    final api = _RegistryApi((request) async {
      if (request.page == 2 && attempts++ == 0) {
        throw Exception('下一页加载失败');
      }
      return _page(request.page);
    });
    await _pumpStore(tester, api);
    await _scrollToEnd(tester);
    await _scrollToEnd(tester);
    expect(api.requests.map((r) => r.page), [1, 2]);
    expect(find.byKey(const ValueKey('插件-19|')), findsOneWidget);
    expect(find.text('Exception: 下一页加载失败'), findsOneWidget);
    expect(
      tester.getBottomLeft(find.text('重试')).dy,
      lessThan(tester.getTopLeft(find.byType(GlassCapsuleBar)).dy),
    );
    await tester.tap(find.text('重试'));
    await _pumpFrames(tester);
    await _scrollToEnd(tester);
    expect(api.requests.map((r) => r.page), [1, 2, 2]);
    expect(api.requests.last.force, isFalse);
    expect(find.text('插件 39'), findsOneWidget);
  });

  testWidgets('搜索防抖时即作废旧追加请求，从第一页展示新结果', (tester) async {
    final next = Completer<RegistryRefreshResponse>();
    final api = _RegistryApi((request) async {
      if (request.search != null) {
        return _page(1, count: 1, total: 1, prefix: '搜索');
      }
      return request.page == 1 ? _page(1) : next.future;
    });
    await _pumpStore(tester, api);
    await _scrollToEnd(tester);
    await tester.enterText(find.byType(TextField), '搜索');
    next.complete(_page(2));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('插件 39'), findsNothing);
    await tester.pump(const Duration(milliseconds: 500));
    await _pumpFrames(tester);
    expect(api.requests.last.page, 1);
    expect(api.requests.last.search, '搜索');
    expect(api.requests.last.force, isFalse);
    expect(find.text('搜索 0'), findsOneWidget);
    expect(find.byKey(const ValueKey('插件-0|')), findsNothing);
  });

  testWidgets('切换源后忽略旧源第一页的迟到结果', (tester) async {
    final old = Completer<RegistryRefreshResponse>();
    final api = _RegistryApi((request) async {
      return request.url.isEmpty
          ? old.future
          : _page(1, count: 1, total: 1, prefix: '新源');
    });
    await _pumpStore(tester, api);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await _pumpFrames(tester);
    await tester.tap(find.text('源 B').last);
    await _pumpFrames(tester);
    old.complete(_page(1));
    await _pumpFrames(tester);
    expect(api.requests.last.url, 'https://example.com/b');
    expect(api.requests.last.page, 1);
    expect(find.text('新源 0'), findsOneWidget);
    expect(find.text('插件 0'), findsNothing);
  });

  testWidgets('长列表搜索重置滚动位置，首屏不会沿用旧位置而连续补页', (tester) async {
    final api = _RegistryApi(
      (request) async => _page(
        request.page,
        prefix: request.search == null ? '插件' : '搜索',
        total: request.search == null ? 40 : 80,
      ),
    );
    await _pumpStore(tester, api);
    await _scrollToEnd(tester);
    await _scrollToEnd(tester);
    await tester.enterText(find.byType(TextField), '搜索');
    // 先让防抖期间的 loading 帧卸载旧 ListView。
    await _pumpFrames(tester);
    await tester.pump(const Duration(milliseconds: 500));
    await _pumpFrames(tester);
    expect(api.requests.map((r) => r.page), [1, 2, 1]);
    expect(find.text('搜索 0'), findsOneWidget);
    final list = tester.widget<ListView>(find.byType(ListView));
    expect(list.controller!.offset, 0);
  });

  testWidgets('主动刷新从第一页替换，只有主动刷新绕过缓存', (tester) async {
    final api = _RegistryApi((request) async => _page(request.page));
    await _pumpStore(tester, api);
    await _scrollToEnd(tester);
    await _scrollToEnd(tester);
    await tester.tap(find.byIcon(Icons.refresh));
    await _pumpFrames(tester);
    expect(api.requests.map((r) => r.page), [1, 2, 1]);
    expect(api.requests.last.force, isTrue);
    expect(find.text('插件 0'), findsOneWidget);
    expect(find.text('插件 39'), findsNothing);
  });

  testWidgets('首屏不足一屏自动补页，空页终止继续加载', (tester) async {
    final api = _RegistryApi(
      (request) async => _page(request.page, count: request.page == 1 ? 1 : 0),
    );
    await _pumpStore(tester, api);
    await _pumpFrames(tester);
    expect(api.requests.map((r) => r.page), [1, 2]);
    expect(find.text('插件 0'), findsOneWidget);
    await _scrollToEnd(tester);
    expect(api.requests.map((r) => r.page), [1, 2]);
  });

  testWidgets('已安装条目的同名不同作者在后续页展示冲突状态', (tester) async {
    final api = _RegistryApi((request) async {
      if (request.page == 1) return _page(1);
      return RegistryRefreshResponse(
        plugins: [
          RegistryPluginEntry(
            name: '另一个作者的插件',
            entryPath: '插件-0',
            identity: 'another-author',
            version: '1.0.0',
            downloadUrl: 'https://example.com/other.zip',
          ),
        ],
        total: 21,
        page: 2,
        pageSize: 20,
      );
    });
    await _pumpStore(tester, api);
    final first = find.byKey(const ValueKey('插件-0|'));
    await tester.tap(
      find.descendant(of: first, matching: find.byType(FilledButton)),
    );
    await _pumpFrames(tester);
    expect(
      find.descendant(of: first, matching: find.byType(ActionChip)),
      findsOneWidget,
    );
    await _scrollToEnd(tester);
    await _scrollToEnd(tester);
    final other = find.byKey(const ValueKey('插件-0|another-author'));
    expect(
      find.descendant(of: other, matching: find.textContaining('插件 0')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: other, matching: find.text('覆盖安装')),
      findsOneWidget,
    );
  });

  for (final capsule in [true, false]) {
    for (final safeBottom in [0.0, 24.0]) {
      testWidgets('最后一条安装按钮避让导航栏 capsule=$capsule 安全区=$safeBottom', (
        tester,
      ) async {
        final api = _RegistryApi((request) async => _page(1, total: 20));
        await _pumpStore(tester, api, capsule: capsule, safeBottom: safeBottom);
        await _scrollToEnd(tester);
        final row = find.byKey(const ValueKey('插件-19|'));
        final install = find.descendant(
          of: row,
          matching: find.byType(FilledButton),
        );
        final nav = find.byType(capsule ? GlassCapsuleBar : NavigationBar);
        expect(install, findsOneWidget);
        expect(
          tester.getBottomLeft(install).dy,
          lessThan(tester.getTopLeft(nav).dy),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
