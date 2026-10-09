import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/features/jsplugin/data/jsplugin_api.dart';
import 'package:songloft_flutter/features/jsplugin/presentation/providers/jsplugin_provider.dart';
import 'package:songloft_flutter/features/jsplugin/presentation/widgets/jsplugin_manager.dart';
import 'package:songloft_flutter/features/jsplugin/presentation/widgets/plugin_navigation_settings.dart';
import 'package:songloft_flutter/features/settings/data/settings_api.dart';
import 'package:songloft_flutter/features/settings/presentation/providers/settings_provider.dart';
import 'package:songloft_flutter/l10n/app_localizations.dart';
import 'package:songloft_flutter/shared/layouts/active_destinations.dart';

JSPlugin _plugin(int id, {String status = 'active', String? path}) => JSPlugin(
  id: id,
  name: 'Plugin $id',
  entryPath: path ?? 'plugin$id',
  filePath: 'plugin$id.js',
  status: status,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

PluginTabEntry _entry(int id) =>
    PluginTabEntry(pluginId: id, entryPath: 'plugin$id', name: 'Plugin $id');

class _SettingsApi extends SettingsApi {
  _SettingsApi(this.saved) : super(dio: Dio());

  TabConfig saved;
  final writes = <TabConfig>[];
  Completer<TabConfig>? loading;
  Completer<TabConfig>? saving;
  bool failLoad = false;

  @override
  Future<TabConfig> getTabConfig() async {
    if (failLoad) throw StateError('load failed');
    return loading == null ? saved : await loading!.future;
  }

  @override
  Future<TabConfig> updateTabConfig(TabConfig config) async {
    writes.add(config);
    saved = saving == null ? config : await saving!.future;
    return saved;
  }
}

class _PluginsApi extends JSPluginApi {
  _PluginsApi(this.plugins) : super(dio: Dio());
  final List<JSPlugin> plugins;

  Future<JSPlugin> _setStatus(int id, String status) async {
    final index = plugins.indexWhere((p) => p.id == id);
    return plugins[index] = _plugin(id, status: status);
  }

  @override
  Future<JSPlugin> enablePlugin(int id) => _setStatus(id, 'active');

  @override
  Future<JSPlugin> disablePlugin(int id) => _setStatus(id, 'inactive');
}

void main() {
  Future<ProviderContainer> pump(
    WidgetTester tester,
    _SettingsApi api,
    List<JSPlugin> plugins, {
    double width = 390,
    bool manager = false,
    bool settle = true,
    Future<List<JSPlugin>> Function()? loadPlugins,
  }) async {
    await tester.binding.setSurfaceSize(Size(width, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer(
      overrides: [
        settingsApiProvider.overrideWithValue(api),
        jsPluginsProvider.overrideWith(
          (ref) async =>
              loadPlugins == null ? List.of(plugins) : await loadPlugins(),
        ),
        jsPluginApiProvider.overrideWithValue(_PluginsApi(plugins)),
        pluginKeepAliveProvider.overrideWith((ref) async => []),
        pluginAutoUpdateProvider.overrideWith((ref) async => false),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child:
                  manager
                      ? const JSPluginManager()
                      : Column(
                        children: [
                          for (final plugin in plugins)
                            PluginNavigationToggle(plugin: plugin),
                          const PluginNavigationOrder(),
                        ],
                      ),
            ),
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
    return container;
  }

  SwitchListTile toggle(WidgetTester tester, int id) =>
      tester.widget(find.byKey(ValueKey('plugin-navigation-$id')));

  testWidgets('显示开关只修改当前插件，保留停用插件及曲库偏好', (tester) async {
    final api = _SettingsApi(
      TabConfig(
        showLibrary: false,
        showPlaylists: false,
        pluginTabs: [_entry(2)],
      ),
    );
    final plugins = [_plugin(1), _plugin(2, status: 'inactive')];
    final container = await pump(tester, api, plugins);
    expect(toggle(tester, 1).value, isFalse);
    await tester.tap(find.byKey(const ValueKey('plugin-navigation-1')));
    await tester.pumpAndSettle();
    expect(api.saved.showLibrary, isFalse);
    expect(api.saved.showPlaylists, isFalse);
    expect(api.saved.pluginTabs.map((e) => e.entryPath), [
      'plugin2',
      'plugin1',
    ]);
    expect(toggle(tester, 1).value, isTrue);
    expect(
      container
          .read(tabConfigProvider)
          .requireValue
          .activeEntries(plugins)
          .map((e) => e.entryPath),
      ['plugin1'],
    );
    await tester.tap(find.byKey(const ValueKey('plugin-navigation-1')));
    await tester.pumpAndSettle();
    expect(api.saved.pluginTabs.map((e) => e.entryPath), ['plugin2']);
  });

  testWidgets('排序保留停用插件的槽位，重新启用后恢复', (tester) async {
    final api = _SettingsApi(
      TabConfig(
        showLibrary: true,
        showPlaylists: true,
        pluginTabs: [_entry(1), _entry(2), _entry(3)],
      ),
    );
    final plugins = [_plugin(1), _plugin(2, status: 'inactive'), _plugin(3)];
    await pump(tester, api, plugins);
    tester
        .widget<ReorderableListView>(find.byType(ReorderableListView))
        .onReorderItem!(0, 1);
    await tester.pumpAndSettle();
    expect(api.saved.pluginTabs.map((e) => e.entryPath), [
      'plugin3',
      'plugin2',
      'plugin1',
    ]);
    plugins[1] = _plugin(2);
    expect(api.saved.activeEntries(plugins).map((e) => e.entryPath), [
      'plugin3',
      'plugin2',
      'plugin1',
    ]);
  });

  testWidgets('保存期间保留已保存导航并锁定控制项，失败后可重试', (tester) async {
    final api = _SettingsApi(TabConfig.defaultConfig())
      ..saving = Completer<TabConfig>();
    final container = await pump(tester, api, [_plugin(1), _plugin(2)]);
    await tester.tap(find.byKey(const ValueKey('plugin-navigation-1')));
    await tester.pump();
    expect(toggle(tester, 1).value, isFalse);
    expect(toggle(tester, 1).onChanged, isNull);
    expect(toggle(tester, 2).onChanged, isNull);
    expect(container.read(tabConfigProvider).requireValue.pluginTabs, isEmpty);
    expect(container.read(tabConfigSavingProvider), isTrue);
    api.saving!.completeError(StateError('save failed'));
    await tester.pumpAndSettle();
    expect(find.textContaining('保存失败'), findsOneWidget);
    expect(toggle(tester, 1).value, isFalse);
    expect(toggle(tester, 2).onChanged, isNotNull);
    expect(container.read(tabConfigSavingProvider), isFalse);
    api.saving = null;
    await tester.tap(find.byKey(const ValueKey('plugin-navigation-1')));
    await tester.pumpAndSettle();
    expect(toggle(tester, 1).value, isTrue);
    expect(api.writes, hasLength(2));
  });

  testWidgets('加载期间及失败时不能用默认配置覆盖服务端偏好', (tester) async {
    final api = _SettingsApi(TabConfig.defaultConfig())
      ..loading = Completer<TabConfig>();
    await pump(tester, api, [_plugin(1)], settle: false);
    expect(toggle(tester, 1).onChanged, isNull);
    api.loading!.completeError(StateError('load failed'));
    await tester.pumpAndSettle();
    expect(toggle(tester, 1).onChanged, isNull);
    expect(api.writes, isEmpty);
    expect(find.text('重试'), findsOneWidget);
    api.loading = null;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(toggle(tester, 1).onChanged, isNotNull);
  });

  testWidgets('刷新失败时旧配置只用于展示，重试成功后才允许修改', (tester) async {
    final api = _SettingsApi(
      TabConfig.defaultConfig().copyWith(pluginTabs: [_entry(1)]),
    );
    final container = await pump(tester, api, [_plugin(1)]);
    api.failLoad = true;
    container.invalidate(tabConfigProvider);
    await tester.pumpAndSettle();
    expect(container.read(tabConfigProvider).hasError, isTrue);
    expect(toggle(tester, 1).value, isTrue);
    expect(toggle(tester, 1).onChanged, isNull);
    expect(find.byType(ReorderableListView), findsNothing);
    expect(api.writes, isEmpty);
    api.failLoad = false;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(toggle(tester, 1).onChanged, isNotNull);
  });

  testWidgets('插件列表刷新失败时禁止用旧列表修改显示和排序', (tester) async {
    final api = _SettingsApi(
      TabConfig.defaultConfig().copyWith(pluginTabs: [_entry(1)]),
    );
    final plugins = [_plugin(1)];
    var failLoad = false;
    final container = await pump(
      tester,
      api,
      plugins,
      loadPlugins: () async {
        if (failLoad) throw StateError('plugins unavailable');
        return plugins;
      },
    );
    failLoad = true;
    container.invalidate(jsPluginsProvider);
    await tester.pumpAndSettle();
    expect(container.read(jsPluginsProvider).hasError, isTrue);
    expect(toggle(tester, 1).onChanged, isNull);
    final handle = tester.widget<ReorderableDragStartListener>(
      find.byType(ReorderableDragStartListener),
    );
    expect(handle.enabled, isFalse);
    expect(api.writes, isEmpty);
    failLoad = false;
    container.invalidate(jsPluginsProvider);
    await tester.pumpAndSettle();
    expect(toggle(tester, 1).onChanged, isNotNull);
  });

  test('新服务器配置读取失败时不能保存上一台服务器的数据', () async {
    final first = _SettingsApi(
      TabConfig.defaultConfig().copyWith(pluginTabs: [_entry(1)]),
    );
    final second = _SettingsApi(TabConfig.defaultConfig())..failLoad = true;
    final container = ProviderContainer(
      overrides: [settingsApiProvider.overrideWithValue(first)],
    );
    addTearDown(container.dispose);
    final oldConfig = await container.read(tabConfigProvider.future);
    container.updateOverrides([settingsApiProvider.overrideWithValue(second)]);
    await expectLater(
      container.read(tabConfigProvider.future),
      throwsStateError,
    );
    expect(container.read(tabConfigProvider).hasError, isTrue);
    await expectLater(
      container.read(tabConfigProvider.notifier).updateConfig(oldConfig),
      throwsStateError,
    );
    expect(second.writes, isEmpty);
  });

  testWidgets('上限只统计实际显示的条目，仍可取消显示', (tester) async {
    final api = _SettingsApi(
      TabConfig(
        showLibrary: true,
        showPlaylists: true,
        pluginTabs: [for (var i = 1; i <= 10; i++) _entry(i)],
      ),
    );
    final plugins = [
      for (var i = 1; i <= 9; i++) _plugin(i),
      _plugin(10, status: 'inactive'),
      _plugin(11),
    ];
    await pump(tester, api, plugins);
    expect(toggle(tester, 1).onChanged, isNotNull);
    expect(toggle(tester, 11).onChanged, isNull);
    expect(toggle(tester, 10).value, isTrue);
    expect(toggle(tester, 10).onChanged, isNull);
    await tester.tap(find.byKey(const ValueKey('plugin-navigation-1')));
    await tester.pumpAndSettle();
    expect(toggle(tester, 11).onChanged, isNotNull);
    expect(api.saved.pluginTabs.any((e) => e.entryPath == 'plugin10'), isTrue);
  });

  test('切换服务器时旧保存请求不会覆盖新配置或解除新请求的锁定', () async {
    final first = _SettingsApi(TabConfig.defaultConfig())
      ..saving = Completer<TabConfig>();
    final second = _SettingsApi(
      TabConfig(
        showLibrary: false,
        showPlaylists: false,
        pluginTabs: [_entry(2)],
      ),
    )..saving = Completer<TabConfig>();
    final container = ProviderContainer(
      overrides: [settingsApiProvider.overrideWithValue(first)],
    );
    addTearDown(container.dispose);
    await container.read(tabConfigProvider.future);
    final firstWrite = container
        .read(tabConfigProvider.notifier)
        .updateConfig(
          TabConfig.defaultConfig().copyWith(pluginTabs: [_entry(1)]),
        );
    expect(container.read(tabConfigSavingProvider), isTrue);
    container.updateOverrides([settingsApiProvider.overrideWithValue(second)]);
    final restored = await container.read(tabConfigProvider.future);
    expect(restored.pluginTabs.single.entryPath, 'plugin2');
    expect(container.read(tabConfigSavingProvider), isFalse);
    final secondWrite = container
        .read(tabConfigProvider.notifier)
        .updateConfig(restored.copyWith(showLibrary: true));
    first.saving!.complete(first.writes.single);
    await firstWrite;
    expect(container.read(tabConfigProvider).requireValue.showLibrary, isFalse);
    expect(container.read(tabConfigSavingProvider), isTrue);
    second.saving!.complete(second.writes.single);
    await secondWrite;
    expect(container.read(tabConfigProvider).requireValue.showLibrary, isTrue);
    expect(container.read(tabConfigSavingProvider), isFalse);
  });

  for (final width in [320.0, 1200.0]) {
    testWidgets('插件管理集中两个开关且启停恢复导航 ($width)', (tester) async {
      final api = _SettingsApi(
        TabConfig(
          showLibrary: true,
          showPlaylists: true,
          pluginTabs: [_entry(1)],
        ),
      );
      final plugins = [_plugin(1)];
      final container = await pump(
        tester,
        api,
        plugins,
        width: width,
        manager: true,
      );
      expect(find.text('启用插件'), findsOneWidget);
      expect(find.text('显示在导航栏'), findsOneWidget);
      expect(find.text('导航栏插件排序'), findsOneWidget);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(JSPluginManager)),
      );
      List<String> routes() =>
          ActiveDestinations.compute(
            container.read(tabConfigProvider).requireValue,
            container.read(jsPluginsProvider).requireValue,
            l10n,
          ).indexToRoute;
      expect(routes(), contains('/plugin-tab/plugin1'));
      await tester.tap(find.byKey(const ValueKey('plugin-enabled-1')));
      await tester.pumpAndSettle();
      expect(toggle(tester, 1).value, isTrue);
      expect(routes(), isNot(contains('/plugin-tab/plugin1')));
      await tester.tap(find.byKey(const ValueKey('plugin-enabled-1')));
      await tester.pumpAndSettle();
      expect(routes(), contains('/plugin-tab/plugin1'));
      expect(api.writes, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('无入口路径的插件只有运行开关', (tester) async {
    await pump(tester, _SettingsApi(TabConfig.defaultConfig()), [
      _plugin(1, path: ''),
    ], manager: true);
    expect(find.text('启用插件'), findsOneWidget);
    expect(find.text('显示在导航栏'), findsNothing);
  });
}
