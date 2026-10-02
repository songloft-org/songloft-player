import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:songloft_flutter/config/app_config.dart';
import 'package:songloft_flutter/features/jsplugin/data/jsplugin_api.dart';
import 'package:songloft_flutter/features/jsplugin/presentation/providers/jsplugin_provider.dart';
import 'package:songloft_flutter/features/jsplugin/presentation/widgets/jsplugin_manager.dart';
import 'package:songloft_flutter/l10n/app_localizations.dart';

JSPlugin plugin({String status = 'active', String? entryPath = 'downloader'}) {
  return JSPlugin(
    id: 7,
    name: '歌曲下载 & Test',
    description: '插件描述',
    entryPath: entryPath,
    filePath: 'downloader.js',
    status: status,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

class TestPluginApi extends JSPluginApi {
  TestPluginApi() : super(dio: Dio());

  int? disabledId;

  @override
  Future<JSPlugin> disablePlugin(int id) async {
    disabledId = id;
    return plugin(status: 'inactive');
  }
}

void main() {
  Future<GoRouter> pumpManager(
    WidgetTester tester,
    JSPlugin subject, {
    TestPluginApi? api,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(
      initialLocation: '/settings/plugins',
      routes: [
        GoRoute(
          path: '/settings/plugins',
          builder:
              (_, _) => const Scaffold(
                body: SingleChildScrollView(child: JSPluginManager()),
              ),
        ),
        GoRoute(
          path: '/plugin',
          builder: (_, _) => const Scaffold(body: Text('Plugin page')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jsPluginsProvider.overrideWith((ref) async => [subject]),
          pluginKeepAliveProvider.overrideWith((ref) async => []),
          pluginAutoUpdateProvider.overrideWith((ref) async => false),
          if (api != null) jsPluginApiProvider.overrideWithValue(api),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('列表打开使用解析后的服务器地址、子路径和编码后的名称', (tester) async {
    final previousUrl = AppConfig.resolvedBaseUrl;
    final previousPath = AppConfig.basePath;
    AppConfig.resolvedBaseUrl = 'https://resolved.example';
    AppConfig.basePath = '/music';
    addTearDown(() {
      AppConfig.resolvedBaseUrl = previousUrl;
      AppConfig.basePath = previousPath;
    });
    final router = await pumpManager(tester, plugin());
    await tester.tap(find.text('歌曲下载 & Test'));
    await tester.pumpAndSettle();
    expect(find.text('Plugin page'), findsOneWidget);
    final location = router.state.uri;
    expect(location.path, '/plugin');
    expect(
      location.queryParameters['url'],
      'https://resolved.example/music/api/v1/jsplugin/downloader',
    );
    expect(location.queryParameters['name'], '歌曲下载 & Test');
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('歌曲下载 & Test'), findsOneWidget);
  });

  for (final subject in [
    plugin(status: 'inactive'),
    plugin(status: 'error'),
    plugin(entryPath: null),
    plugin(entryPath: ''),
  ]) {
    testWidgets('状态 ${subject.status}、入口 ${subject.entryPath} 不可打开', (
      tester,
    ) async {
      final router = await pumpManager(tester, subject);
      await tester.tap(find.text('歌曲下载 & Test'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/settings/plugins');
    });
  }

  testWidgets('点击开关和更多菜单不会打开插件', (tester) async {
    final api = TestPluginApi();
    final router = await pumpManager(tester, plugin(), api: api);
    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();
    expect(api.disabledId, 7);
    expect(router.state.uri.path, '/settings/plugins');
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('检查更新'), findsOneWidget);
    expect(router.state.uri.path, '/settings/plugins');
  });
}
