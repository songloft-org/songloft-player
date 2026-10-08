import 'dart:convert';

import '../data/jsplugin_api.dart';

/// Discovery validates distribution metadata, not the safety of plugin code.
class GithubPluginManifest {
  final String name, version, entryPath, main, entryHash, zipHash;
  final String description,
      minHostVersion,
      renderEngine,
      updateUrl,
      downloadUrl;
  final List<String> permissions;

  const GithubPluginManifest({
    required this.name,
    required this.version,
    required this.entryPath,
    required this.main,
    required this.entryHash,
    required this.zipHash,
    required this.permissions,
    this.description = '',
    this.minHostVersion = '',
    this.renderEngine = '',
    this.updateUrl = '',
    this.downloadUrl = '',
  });

  factory GithubPluginManifest.fromJson(Map<String, dynamic> json) {
    String text(String key, {bool optional = false}) {
      final value = json[key];
      if (optional && value == null && !json.containsKey(key)) return '';
      if (value is! String) throw const FormatException('manifest text');
      return value;
    }

    final name = text('name');
    final version = text('version');
    final entryPath = text('entryPath');
    final main = text('main');
    final entryHash = text('entryHash');
    final zipHash = text('zipHash');
    final engine = text('renderEngine', optional: true);
    final permissions = json['permissions'];
    if (utf8.encode(name).length < 2 ||
        utf8.encode(name).length > 50 ||
        !RegExp(r'^\d+\.\d+\.\d+').hasMatch(version) ||
        !RegExp(r'^[a-z][a-z0-9-]*$').hasMatch(entryPath) ||
        !RegExp(r'\.(js|jsc)$').hasMatch(main) ||
        main.startsWith('/') ||
        main.contains('\\') ||
        main.contains(':') ||
        main.split('/').any((part) => part == '..' || part == '.') ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(entryHash) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(zipHash) ||
        !['', 'webview', 'lynx'].contains(engine) ||
        permissions is! List ||
        permissions.any((value) => value is! String)) {
      throw const FormatException('invalid manifest');
    }
    // Keep the optional metadata types aligned with the Lynx validator.
    text('author', optional: true);
    text('homepage', optional: true);
    return GithubPluginManifest(
      name: name,
      version: version,
      entryPath: entryPath,
      main: main,
      entryHash: entryHash,
      zipHash: zipHash,
      permissions: List<String>.unmodifiable(permissions.cast<String>()),
      description: text('description', optional: true),
      minHostVersion: text('minHostVersion', optional: true),
      renderEngine: engine,
      updateUrl: text('updateUrl', optional: true),
      downloadUrl: text('download_url', optional: true),
    );
  }
}

class GithubRepository {
  final int id, stars;
  final String fullName, defaultBranch, updatedAt;
  const GithubRepository({
    required this.id,
    required this.fullName,
    required this.defaultBranch,
    required this.stars,
    required this.updatedAt,
  });
}

class GithubPlugin {
  final GithubRepository repository;
  final GithubPluginManifest manifest;
  final String downloadUrl, releaseUrl, publishedAt;
  const GithubPlugin({
    required this.repository,
    required this.manifest,
    required this.downloadUrl,
    required this.releaseUrl,
    required this.publishedAt,
  });

  GithubPlugin withRepository(GithubRepository repo) => GithubPlugin(
    repository: repo,
    manifest: manifest,
    downloadUrl: downloadUrl,
    releaseUrl: releaseUrl,
    publishedAt: publishedAt,
  );

  bool installedFrom(JSPlugin? installed) =>
      installed != null &&
      (isRepositoryMetadataUrl(
            installed.updateUrl ?? '',
            repository.fullName,
          ) ||
          releaseDownload(installed.downloadUrl ?? '', repository.fullName) !=
              null);

  bool hasUpdate(JSPlugin? installed) =>
      installedFrom(installed) &&
      (comparePluginVersions(manifest.version, installed?.version ?? '') ?? 0) >
          0;
}

Uri? _publicHttps(String address) {
  // Inspect the original path before Uri normalizes dot segments. Keep the
  // same repository-boundary rules as the native Lynx validator.
  final match = RegExp(
    r'^https://(github\.com|raw\.githubusercontent\.com)(/[^\s?#\\]*)$',
    caseSensitive: false,
  ).firstMatch(address);
  if (match == null) return null;
  try {
    for (final segment in match[2]!.split('/')) {
      final decoded = Uri.decodeComponent(segment);
      if (decoded == '.' || decoded == '..' || decoded.contains('\\')) {
        return null;
      }
    }
  } on FormatException {
    return null;
  }
  final uri = Uri.tryParse(address);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort ||
      uri.hasQuery ||
      uri.hasFragment) {
    return null;
  }
  return uri;
}

bool isRepositoryMetadataUrl(String address, String repository) {
  final uri = _publicHttps(address);
  if (uri == null) return false;
  final path = uri.path.toLowerCase(), repo = repository.toLowerCase();
  return uri.host == 'raw.githubusercontent.com' &&
          path.startsWith('/$repo/') ||
      uri.host == 'github.com' && path.startsWith('/$repo/raw/');
}

({String tag, String file})? releaseDownload(
  String address,
  String repository,
) {
  final uri = _publicHttps(address);
  final prefix = '/$repository/releases/download/';
  if (uri == null ||
      uri.host != 'github.com' ||
      !uri.path.toLowerCase().startsWith(prefix.toLowerCase())) {
    return null;
  }
  try {
    final parts = uri.path.substring(prefix.length).split('/');
    if (parts.length != 2) return null;
    final tag = Uri.decodeComponent(parts[0]),
        file = Uri.decodeComponent(parts[1]);
    if (tag.isEmpty ||
        !file.endsWith('.jsplugin.zip') ||
        file.contains('/') ||
        file.contains('\\')) {
      return null;
    }
    return (tag: tag, file: file);
  } on FormatException {
    return null;
  }
}

/// Version ordering requires known stable versions.
int? comparePluginVersions(String a, String b) {
  final pattern = RegExp(
    r'^(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})$',
  );
  final left = pattern.firstMatch(a.replaceFirst(RegExp(r'^v'), ''));
  final right = pattern.firstMatch(b.replaceFirst(RegExp(r'^v'), ''));
  if (left == null || right == null) return null;
  for (var i = 1; i <= 3; i++) {
    final comparison = int.parse(left[i]!).compareTo(int.parse(right[i]!));
    if (comparison != 0) return comparison;
  }
  return 0;
}

enum PluginHostCompatibility { compatible, incompatible, unknown }

PluginHostCompatibility pluginHostCompatibility(
  String minimum,
  String? current,
) {
  if (current == 'dev' || minimum.isEmpty) {
    return PluginHostCompatibility.compatible;
  }
  final comparison = comparePluginVersions(current ?? '', minimum);
  if (comparison == null) return PluginHostCompatibility.unknown;
  return comparison < 0
      ? PluginHostCompatibility.incompatible
      : PluginHostCompatibility.compatible;
}
