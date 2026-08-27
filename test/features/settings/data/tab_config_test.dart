import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/features/jsplugin/data/jsplugin_api.dart';
import 'package:songloft_flutter/features/settings/data/settings_api.dart';

JSPlugin _plugin(int id, String entryPath, {String status = 'active'}) {
  return JSPlugin(
    id: id,
    name: entryPath,
    entryPath: entryPath,
    filePath: '$entryPath.jsplugin.zip',
    status: status,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

PluginTabEntry _entry(int id, String entryPath) =>
    PluginTabEntry(pluginId: id, entryPath: entryPath, name: entryPath);

void main() {
  group('TabConfig.activeEntries', () {
    test('仅保留插件已安装且 active 的条目', () {
      final config = TabConfig(
        showLibrary: true,
        showPlaylists: true,
        pluginTabs: [
          _entry(1, 'alive'),
          _entry(2, 'ghost'), // 插件已卸载的孤儿条目
          _entry(3, 'disabled'), // 禁用插件的条目
        ],
      );
      final plugins = [
        _plugin(1, 'alive'),
        _plugin(3, 'disabled', status: 'inactive'),
      ];

      final entries = config.activeEntries(plugins);

      expect(entries.map((e) => e.entryPath), ['alive']);
    });

    test('条目与插件顺序无关，按配置顺序返回', () {
      final config = TabConfig(
        showLibrary: true,
        showPlaylists: true,
        pluginTabs: [_entry(2, 'b'), _entry(1, 'a')],
      );
      final plugins = [_plugin(1, 'a'), _plugin(2, 'b')];

      final entries = config.activeEntries(plugins);

      expect(entries.map((e) => e.entryPath), ['b', 'a']);
    });

    test('忽略 entryPath 为空的插件', () {
      final config = TabConfig(
        showLibrary: true,
        showPlaylists: true,
        pluginTabs: [_entry(1, 'a')],
      );
      final plugins = [
        _plugin(1, ''), // entryPath 为空不应匹配任何条目
        _plugin(2, 'a', status: 'inactive'),
      ];

      expect(config.activeEntries(plugins), isEmpty);
    });

    test('空插件列表返回空（不因缺失插件列表误判）', () {
      final config = TabConfig(
        showLibrary: true,
        showPlaylists: true,
        pluginTabs: [_entry(1, 'a')],
      );

      expect(config.activeEntries(const []), isEmpty);
    });
  });
}
