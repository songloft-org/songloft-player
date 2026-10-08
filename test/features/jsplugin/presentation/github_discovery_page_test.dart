import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:songloft_flutter/core/router/app_router.dart';
import 'package:songloft_flutter/features/jsplugin/data/github_discovery_api.dart';
import 'package:songloft_flutter/features/jsplugin/data/jsplugin_api.dart';
import 'package:songloft_flutter/features/jsplugin/domain/github_plugin.dart';
import 'package:songloft_flutter/features/jsplugin/presentation/pages/github_discovery_page.dart';
import 'package:songloft_flutter/features/jsplugin/presentation/providers/github_discovery_provider.dart';
import 'package:songloft_flutter/features/jsplugin/presentation/providers/jsplugin_provider.dart';
import 'package:songloft_flutter/features/jsplugin/presentation/widgets/github_plugin_detail.dart';
import 'package:songloft_flutter/features/jsplugin/presentation/widgets/plugin_registry.dart';
import 'package:songloft_flutter/features/settings/data/settings_api.dart';
import 'package:songloft_flutter/features/settings/presentation/providers/settings_provider.dart';
import 'package:songloft_flutter/l10n/app_localizations.dart';

import '../github_discovery_fixtures.dart';

class _NoProxy extends GithubProxyNotifier {
  @override
  Future<String> build() async => '';
}

class _Discovery extends GithubDiscoveryApi {
  final GithubPlugin plugin;
  _Discovery(this.plugin);
  final requests =
      <
        ({int page, String search, String sort, bool force, CancelToken cancel})
      >[];
  Future<GithubDiscoveryPageData> Function(int)? fetch;
  @override
  Future<GithubDiscoveryPageData> discover({
    required int page,
    required String search,
    required String sort,
    required String proxy,
    required CancelToken cancelToken,
    bool force = false,
    void Function(GithubDiscoveryPageData)? onProgress,
  }) async {
    requests.add((
      page: page,
      search: search,
      sort: sort,
      force: force,
      cancel: cancelToken,
    ));
    if (fetch != null) return fetch!(page);
    return GithubDiscoveryPageData(plugins: [plugin], checked: 1, failures: {});
  }
}

class _Plugins extends JSPluginApi {
  _Plugins({List<JSPlugin>? installed})
    : plugins = installed ?? [],
      super(dio: Dio());
  List<JSPlugin> plugins;
  final installs =
      <({String url, bool overwrite, String? token, String? source})>[];
  Completer<JSPluginUploadResponse>? pending;
  @override
  Future<List<JSPlugin>> getPlugins() async => plugins;
  @override
  Future<JSPluginUploadResponse> installFromRegistry({
    required String downloadUrl,
    String? githubProxy,
    String? token,
    String? sourceUrl,
    bool overwrite = false,
  }) async {
    installs.add((
      url: downloadUrl,
      overwrite: overwrite,
      token: token,
      source: sourceUrl,
    ));
    if (pending != null) await pending!.future;
    plugins = [_installed(download: discoveryDownload, version: '1.2.3')];
    return JSPluginUploadResponse(
      total: 1,
      success: 1,
      failed: 0,
      results: [],
      message: '安装成功',
    );
  }

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
  }) async => RegistryRefreshResponse(
    plugins: [
      RegistryPluginEntry(
        name: '测试插件',
        entryPath: 'test',
        version: '1.2.3',
        downloadUrl: discoveryDownload,
      ),
    ],
    total: 1,
    page: 1,
    pageSize: 20,
  );
}

class _Settings extends SettingsApi {
  final bool empty;
  _Settings(this.empty) : super(dio: Dio());
  @override
  Future<List<PluginRegistryConfig>> getPluginRegistries() async =>
      empty
          ? []
          : [
            PluginRegistryConfig(
              url: 'https://example.com/registry.json',
              name: '测试源',
            ),
          ];
}

JSPlugin _installed({String? download, String version = '1.0.0'}) => JSPlugin(
  id: 1,
  name: '原插件',
  entryPath: 'test',
  version: version,
  author: 'sample',
  homepage: 'https://github.com/$discoveryRepo',
  downloadUrl: download,
  filePath: '',
  status: 'active',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  _Discovery discovery,
  _Plugins plugins, {
  String version = '2.10.0',
  bool store = false,
  bool emptySources = false,
  Size size = const Size(390, 844),
  Locale locale = const Locale('zh'),
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation:
        store ? AppRoutes.pluginRegistry : AppRoutes.githubPluginDiscovery,
    routes: [
      GoRoute(
        path: AppRoutes.pluginRegistry,
        builder: (_, _) => const PluginRegistryPage(),
      ),
      GoRoute(
        path: AppRoutes.githubPluginDiscovery,
        builder: (_, _) => const GithubDiscoveryPage(),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        githubDiscoveryApiProvider.overrideWithValue(discovery),
        jsPluginApiProvider.overrideWithValue(plugins),
        githubProxyProvider.overrideWith(_NoProxy.new),
        settingsApiProvider.overrideWithValue(_Settings(emptySources)),
        serverVersionProvider.overrideWith(
          (ref) async => (version: version, gitCommit: null, buildTime: null),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder:
            (ctx, child) => MediaQuery(
              data: MediaQuery.of(
                ctx,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
      ),
    ),
  );
  await _frames(tester);
  return ProviderScope.containerOf(
    tester.element(
      find.byType(GithubDiscoveryPage).evaluate().isEmpty
          ? find.byType(PluginRegistryPage)
          : find.byType(GithubDiscoveryPage),
    ),
  );
}

Future<void> _detail(WidgetTester tester) async {
  await tester.tap(find.text('查看详情'));
  await _frames(tester);
  expect(find.byType(GithubPluginDetail), findsOneWidget);
}

Future<void> _install(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('github-plugin-install'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await _frames(tester);
}

void main() {
  testWidgets('服务器刷新确认卸载后清除发现安装标记，允许重新安装', (tester) async {
    final plugin = discoveryPlugin();
    final api = _Plugins();
    final container = await _pump(tester, _Discovery(plugin), api);
    await tester.tap(find.byType(Card).first);
    await _frames(tester);
    await tester.tap(find.byKey(const ValueKey('github-plugin-install')));
    await _frames(tester);
    await tester.tap(find.byKey(const ValueKey('github-install-confirm')));
    await _frames(tester);
    expect(container.read(githubDiscoveryInstallsProvider), contains('test'));
    api.plugins = [];
    container.invalidate(jsPluginsProvider);
    await _frames(tester);
    expect(container.read(githubDiscoveryInstallsProvider), isEmpty);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('github-plugin-install')),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('无插件源仍能进入 GitHub 发现，返回恢复原源选择', (tester) async {
    final discovery = _Discovery(discoveryPlugin());
    await _pump(tester, discovery, _Plugins(), store: true, emptySources: true);
    expect(find.text('还没有添加订阅源'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await _frames(tester);
    await tester.tap(find.text('GitHub 发现').last);
    await _frames(tester);
    expect(find.byType(GithubDiscoveryPage), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await _frames(tester);
    expect(find.byType(PluginRegistryPage), findsOneWidget);
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>),
          )
          .initialValue,
      isNull,
    );
  });
  testWidgets('未经审核确认前不安装，确认后一次正确请求并显示已安装', (tester) async {
    final plugins = _Plugins();
    await _pump(tester, _Discovery(discoveryPlugin()), plugins);
    await _detail(tester);
    await _install(tester);
    expect(plugins.installs, isEmpty);
    expect(find.textContaining('未经 Songloft 审核'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('github-install-confirm')));
    await _frames(tester);
    expect(plugins.installs.single, (
      url: discoveryDownload,
      overwrite: false,
      token: null,
      source: null,
    ));
    expect(find.text('已安装'), findsWidgets);
  });
  testWidgets('相同作者主页不能证明仓库一致，替换需明确确认', (tester) async {
    final plugins = _Plugins(installed: [_installed()]);
    await _pump(tester, _Discovery(discoveryPlugin()), plugins);
    await _detail(tester);
    await _install(tester);
    expect(find.textContaining('原插件 v1.0.0'), findsWidgets);
    expect(plugins.installs, isEmpty);
    await tester.tap(find.byKey(const ValueKey('github-install-confirm')));
    await _frames(tester);
    expect(plugins.installs.single.overwrite, isTrue);
  });
  testWidgets('同仓库已安装相同版本禁用安装，不同版本提供更新', (tester) async {
    final plugins = _Plugins(
      installed: [_installed(download: discoveryDownload, version: '1.2.3')],
    );
    await _pump(tester, _Discovery(discoveryPlugin()), plugins);
    await _detail(tester);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('github-plugin-install')),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('已安装'), findsWidgets);
  });
  testWidgets('dev 服务端跳过最低版本检查，仍需确认后才安装', (tester) async {
    final plugins = _Plugins();
    await _pump(
      tester,
      _Discovery(discoveryPlugin(minimum: '999.0.0')),
      plugins,
      version: 'dev',
    );
    await _detail(tester);
    await _install(tester);
    expect(plugins.installs, isEmpty);
    await tester.tap(find.byKey(const ValueKey('github-install-confirm')));
    await _frames(tester);
    expect(plugins.installs, hasLength(1));
  });
  for (final version in ['2.9.0', 'unknown']) {
    testWidgets('最低服务端版本不足或未知时禁用安装：$version', (tester) async {
      await _pump(
        tester,
        _Discovery(discoveryPlugin(minimum: '2.10.0')),
        _Plugins(),
        version: version,
      );
      await _detail(tester);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('github-plugin-install')),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('安装成功关闭详情后原商店状态就地更新，搜索保持', (tester) async {
    final container = await _pump(
      tester,
      _Discovery(discoveryPlugin()),
      _Plugins(),
      store: true,
    );
    await tester.enterText(find.byType(TextField), '测试');
    await _frames(tester);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await _frames(tester);
    await tester.tap(find.text('GitHub 发现').last);
    await _frames(tester);
    await _detail(tester);
    await _install(tester);
    await tester.tap(find.byKey(const ValueKey('github-install-confirm')));
    await _frames(tester);
    await tester.tap(find.byIcon(Icons.close));
    await _frames(tester);
    await tester.tap(find.byType(BackButton));
    await _frames(tester);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '测试',
    );
    expect(
      container.read(githubDiscoveryInstallsProvider)['test']?.downloadUrl,
      discoveryDownload,
    );
    expect(find.byType(ActionChip), findsOneWidget);
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>),
          )
          .initialValue,
      '__all_sources__',
    );
  });
  testWidgets('下一页失败保留列表，重试同一页', (tester) async {
    var attempts = 0;
    final discovery = _Discovery(discoveryPlugin())
      ..fetch = (page) async {
        if (page == 2 && attempts++ == 0) throw StateError('network');
        return GithubDiscoveryPageData(
          plugins: [discoveryPlugin(id: page)],
          checked: 1,
          failures: {},
          nextPage: page == 1 ? 2 : null,
        );
      };
    await _pump(tester, discovery, _Plugins());
    await tester.ensureVisible(find.text('继续发现'));
    await tester.tap(find.text('继续发现'));
    await _frames(tester);
    expect(find.text('查看详情'), findsOneWidget);
    await tester.ensureVisible(find.text('重试'));
    await tester.tap(find.text('重试'));
    await _frames(tester);
    expect(discovery.requests.map((r) => r.page), [1, 2, 2]);
    expect(find.text('查看详情'), findsNWidgets(2));
  });
  testWidgets('搜索防抖立即取消旧请求，销毁页面取消当前请求', (tester) async {
    final completers = <Completer<GithubDiscoveryPageData>>[];
    final discovery = _Discovery(discoveryPlugin())
      ..fetch = (_) {
        final value = Completer<GithubDiscoveryPageData>();
        completers.add(value);
        return value.future;
      };
    await _pump(tester, discovery, _Plugins());
    await tester.enterText(find.byType(TextField), 'new');
    expect(discovery.requests.first.cancel.isCancelled, isTrue);
    completers.first.complete(
      GithubDiscoveryPageData(
        plugins: [discoveryPlugin()],
        checked: 1,
        failures: {},
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await _frames(tester);
    expect(discovery.requests.last.search, 'new');
    expect(find.text('查看详情'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await _frames(tester);
    expect(discovery.requests.last.cancel.isCancelled, isTrue);
    completers.last.complete(
      const GithubDiscoveryPageData(plugins: [], checked: 0, failures: {}),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  for (final locale in [
    const Locale('zh'),
    const Locale('en'),
    const Locale('es'),
  ]) {
    for (final width in [390.0, 1100.0]) {
      testWidgets('详情适配大字号 ${locale.languageCode} $width', (tester) async {
        await _pump(
          tester,
          _Discovery(discoveryPlugin()),
          _Plugins(),
          locale: locale,
          size: Size(width, 900),
          scale: 1.8,
        );
        await tester.ensureVisible(find.byKey(const ValueKey(1)));
        await tester.tap(find.byKey(const ValueKey(1)));
        await _frames(tester);
        expect(find.byType(width < 600 ? BottomSheet : Dialog), findsOneWidget);
        await tester.ensureVisible(
          find.byKey(const ValueKey('github-plugin-install')),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
