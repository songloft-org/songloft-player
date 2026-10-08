import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/features/jsplugin/data/jsplugin_api.dart';
import 'package:songloft_flutter/features/jsplugin/domain/github_plugin.dart';

import '../github_discovery_fixtures.dart';

void main() {
  test('根清单允许省略或留空哈希，有值时仍校验格式', () {
    for (final hash in ['entryHash', 'zipHash']) {
      expect(
        GithubPluginManifest.fromJson(discoveryManifest()..remove(hash)),
        isA<GithubPluginManifest>(),
      );
      expect(
        GithubPluginManifest.fromJson({...discoveryManifest(), hash: ''}),
        isA<GithubPluginManifest>(),
      );
      for (final value in [null, 123, 'bad']) {
        expect(
          () => GithubPluginManifest.fromJson({
            ...discoveryManifest(),
            hash: value,
          }),
          throwsFormatException,
        );
      }
    }
  });
  test('发布清单必填项及类型与 Lynx 一致，未知权限可保留', () {
    expect(GithubPluginManifest.fromJson(discoveryManifest()).permissions, [
      'net',
      'storage',
    ]);
    for (final key in ['name', 'version', 'entryPath', 'main', 'permissions']) {
      expect(
        () => GithubPluginManifest.fromJson(discoveryManifest()..remove(key)),
        throwsFormatException,
        reason: key,
      );
    }
    for (final entry
        in {
          'name': '',
          'version': 'dev',
          'entryPath': 'Bad_Path',
          'main': '../main.js',
          'entryHash': 'a',
          'zipHash': List.filled(64, 'B').join(),
          'permissions': [12],
          'renderEngine': 'unknown',
          'description': null,
        }.entries) {
      expect(
        () => GithubPluginManifest.fromJson({
          ...discoveryManifest(),
          entry.key: entry.value,
        }),
        throwsFormatException,
        reason: entry.key,
      );
    }
    expect(
      GithubPluginManifest.fromJson({
        ...discoveryManifest(),
        'permissions': ['future:permission'],
      }).permissions,
      ['future:permission'],
    );
  });
  test('名称按 UTF-8 字节限制，安全入口与引擎保持兼容', () {
    expect(
      () => GithubPluginManifest.fromJson({
        ...discoveryManifest(),
        'name': List.filled(17, '中').join(),
      }),
      throwsFormatException,
    );
    for (final main in [
      '/main.js',
      'C:main.js',
      'a\\main.js',
      './main.js',
      'a/../main.js',
      'main.ts',
    ]) {
      expect(
        () => GithubPluginManifest.fromJson({
          ...discoveryManifest(),
          'main': main,
        }),
        throwsFormatException,
      );
    }
    expect(
      GithubPluginManifest.fromJson({
        ...discoveryManifest(),
        'main': 'dist/main.jsc',
        'renderEngine': 'lynx',
      }).renderEngine,
      'lynx',
    );
  });
  test('更新元数据与包 URL 只能来自同仓库公开 HTTPS 地址', () {
    expect(
      isRepositoryMetadataUrl(
        'https://raw.githubusercontent.com/$discoveryRepo/main/plugin.json',
        discoveryRepo,
      ),
      isTrue,
    );
    expect(
      isRepositoryMetadataUrl(
        'https://github.com/$discoveryRepo/raw/main/plugin.json',
        discoveryRepo,
      ),
      isTrue,
    );
    for (final address in [
      'https://user@raw.githubusercontent.com/$discoveryRepo/main/plugin.json',
      'https://raw.githubusercontent.com/other/repo/main/plugin.json',
      'http://raw.githubusercontent.com/$discoveryRepo/main/plugin.json',
      'https://raw.githubusercontent.com/$discoveryRepo/main/plugin.json?token=abc',
      'https://raw.githubusercontent.com/$discoveryRepo/main/../plugin.json',
      'https://raw.githubusercontent.com/$discoveryRepo/main/%2e%2e/plugin.json',
      'https://raw.githubusercontent.com/$discoveryRepo/main/a%5cb/plugin.json',
    ]) {
      expect(isRepositoryMetadataUrl(address, discoveryRepo), isFalse);
    }
    expect(releaseDownload(discoveryDownload, discoveryRepo)?.tag, 'v1.2.3');
    for (final address in [
      '$discoveryDownload?token=abc',
      '$discoveryDownload#hash',
      discoveryDownload.replaceFirst('github.com', 'user@github.com'),
      discoveryDownload.replaceFirst(discoveryRepo, 'other/repo'),
      discoveryDownload.replaceFirst('.jsplugin.zip', '.zip'),
      discoveryDownload.replaceFirst('/v1.2.3/', '/%2e%2e/'),
    ]) {
      expect(releaseDownload(address, discoveryRepo), isNull);
    }
  });
  test('dev 宿主跳过最低版本检查，正式版和未知版本继续校验', () {
    for (final minimum in ['2.10.0', '999.0.0', 'future']) {
      expect(
        pluginHostCompatibility(minimum, 'dev'),
        PluginHostCompatibility.compatible,
      );
    }
    expect(
      pluginHostCompatibility('', null),
      PluginHostCompatibility.compatible,
    );
    expect(
      pluginHostCompatibility('2.10.0', 'v2.11.0'),
      PluginHostCompatibility.compatible,
    );
    expect(
      pluginHostCompatibility('2.10.0', '2.9.0'),
      PluginHostCompatibility.incompatible,
    );
    for (final value in [
      null,
      '2.10',
      '02.10.0',
      '2.10.0-beta',
      '2.10.0+abc',
    ]) {
      expect(
        pluginHostCompatibility('2.10.0', value),
        PluginHostCompatibility.unknown,
      );
    }
  });
  test('插件仓库身份使用下载/更新 URL，不能凭作者或主页推断', () {
    JSPlugin installed({String? download, String? update}) => JSPlugin(
      id: 1,
      entryPath: 'test',
      version: '1.0.0',
      homepage: 'https://github.com/$discoveryRepo',
      author: 'sample',
      downloadUrl: download,
      updateUrl: update,
      filePath: '',
      status: 'active',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final plugin = discoveryPlugin();
    final cross = GithubPlugin(
      repository: plugin.repository,
      manifest: plugin.manifest,
      downloadUrl: discoveryDownload.replaceFirst(discoveryRepo, 'other/repo'),
      releaseUrl: 'https://github.com/other/repo/releases/tag/v1.2.3',
      publishedAt: plugin.publishedAt,
    );
    expect(cross.installedFrom(installed(download: cross.downloadUrl)), isTrue);
    expect(
      cross.installedFrom(
        installed(
          download: discoveryDownload.replaceFirst(
            discoveryRepo,
            'unrelated/repo',
          ),
        ),
      ),
      isFalse,
    );
    for (final url in [
      cross.downloadUrl.replaceFirst('github.com', 'example.com'),
      '${cross.downloadUrl}?token=abc',
      cross.downloadUrl.replaceFirst('other/repo', 'other/%2e%2e'),
    ]) {
      expect(parseReleaseDownload(url), isNull);
    }
    expect(plugin.installedFrom(installed()), isFalse);
    expect(
      plugin.installedFrom(installed(download: discoveryDownload)),
      isTrue,
    );
    expect(
      plugin.hasUpdate(
        installed(
          update:
              'https://raw.githubusercontent.com/$discoveryRepo/main/plugin.json',
        ),
      ),
      isTrue,
    );
    expect(
      JSPlugin.fromJson({
        'update_url': 1,
        'download_url': discoveryDownload,
      }).updateUrl,
      isNull,
    );
  });
}
