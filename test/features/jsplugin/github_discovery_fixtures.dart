import 'package:songloft_flutter/features/jsplugin/domain/github_plugin.dart';

const discoveryRepo = 'sample/songloft-plugin-test';
const discoveryDownload =
    'https://github.com/$discoveryRepo/releases/download/v1.2.3/test.jsplugin.zip';

Map<String, dynamic> discoveryManifest() => {
  'name': '测试插件',
  'version': '1.2.3',
  'entryPath': 'test',
  'main': 'main.js',
  'permissions': ['net', 'storage'],
  'entryHash': List.filled(64, 'a').join(),
  'zipHash': List.filled(64, 'b').join(),
  'description': '社区插件描述',
  'download_url': discoveryDownload,
};

Map<String, dynamic> discoveryRepository({
  int id = 1,
  String name = discoveryRepo,
}) => {
  'id': id,
  'full_name': name,
  'default_branch': 'main',
  'stars': 5,
  'updated_at': '2026-10-08T00:00:00Z',
  'topics': ['songloft-plugin'],
  'archived': false,
  'fork': false,
  'private': false,
};

Map<String, dynamic> discoveryRelease() => {
  'draft': false,
  'prerelease': false,
  'tag_name': 'v1.2.3',
  'published_at': '2026-10-08T00:00:00Z',
  'assets': [
    {
      'name': 'test.jsplugin.zip',
      'browser_download_url': discoveryDownload,
      'size': 1024,
      'state': 'uploaded',
    },
  ],
};

GithubPlugin discoveryPlugin({String minimum = '', int id = 1}) => GithubPlugin(
  repository: GithubRepository(
    id: id,
    fullName: discoveryRepo,
    defaultBranch: 'main',
    stars: 5,
    updatedAt: '2026-10-08T00:00:00Z',
  ),
  manifest: GithubPluginManifest.fromJson({
    ...discoveryManifest(),
    'minHostVersion': minimum,
  }),
  downloadUrl: discoveryDownload,
  releaseUrl: 'https://github.com/$discoveryRepo/releases/tag/v1.2.3',
  publishedAt: '2026-10-08T00:00:00Z',
);
