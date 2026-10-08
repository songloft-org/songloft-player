import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/network/github_proxy_fallback.dart';
import '../domain/github_plugin.dart';

enum DiscoveryFailure {
  invalidManifest,
  unpublished,
  invalidRelease,
  unavailable,
  rateLimited,
}

class GithubDiscoveryException implements Exception {
  final DiscoveryFailure reason;
  final DateTime? retryAt;
  const GithubDiscoveryException(this.reason, {this.retryAt});
}

class GithubDiscoveryPageData {
  final List<GithubPlugin> plugins;
  final int checked;
  final Map<DiscoveryFailure, int> failures;
  final int? nextPage;
  final DateTime? retryAt;
  final bool incomplete;
  const GithubDiscoveryPageData({
    required this.plugins,
    required this.checked,
    required this.failures,
    this.nextPage,
    this.retryAt,
    this.incomplete = false,
  });
}

/// Independent public client: never use the authenticated server Dio here.
class GithubDiscoveryApi {
  final Dio _dio;
  final DateTime Function() _now;
  final _cache = <String, ({DateTime until, GithubPlugin plugin})>{};
  final _pages = <String, ({DateTime until, GithubDiscoveryPageData data})>{};
  GithubDiscoveryApi({Dio? dio, DateTime Function()? now})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
              headers: {'Accept': 'application/json'},
            ),
          ),
      _now = now ?? DateTime.now;

  void close() => _dio.close(force: true);

  void _ensureActive(CancelToken token) {
    if (token.isCancelled) throw token.cancelError!;
  }

  void _checkStatus(Response<String> response) {
    final status = response.statusCode ?? 0;
    final remaining = response.headers.value('x-ratelimit-remaining');
    final retry = response.headers.value('retry-after');
    if (status == 429 ||
        status == 403 &&
            (remaining == '0' ||
                retry != null ||
                (response.data ?? '').toLowerCase().contains('rate limit'))) {
      final seconds = int.tryParse(retry ?? '');
      final reset = int.tryParse(
        response.headers.value('x-ratelimit-reset') ?? '',
      );
      throw GithubDiscoveryException(
        DiscoveryFailure.rateLimited,
        retryAt:
            seconds != null && seconds > 0
                ? _now().add(Duration(seconds: seconds))
                : reset != null && reset > 0
                ? DateTime.fromMillisecondsSinceEpoch(reset * 1000)
                : null,
      );
    }
    if (status == 404) {
      throw const GithubDiscoveryException(DiscoveryFailure.unpublished);
    }
    if (status < 200 || status >= 300) {
      throw const GithubDiscoveryException(DiscoveryFailure.unavailable);
    }
  }

  Future<dynamic> _get(
    String address,
    String proxy,
    CancelToken cancel, {
    DiscoveryFailure invalidData = DiscoveryFailure.unavailable,
  }) async {
    _ensureActive(cancel);
    final prefix = Uri.tryParse(proxy);
    final validProxy =
        prefix != null &&
        prefix.scheme == 'https' &&
        prefix.host.isNotEmpty &&
        prefix.userInfo.isEmpty &&
        !prefix.hasQuery &&
        !prefix.hasFragment;
    final proxied = applyGithubProxy(address, validProxy ? proxy : '');
    Future<dynamic> send(String url) async {
      _ensureActive(cancel);
      final response = await _dio.get<String>(
        url,
        cancelToken: cancel,
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (_) => true,
        ),
      );
      _ensureActive(cancel);
      _checkStatus(response);
      final body = response.data ?? '';
      if (utf8.encode(body).length > 2 * 1024 * 1024) {
        throw GithubDiscoveryException(invalidData);
      }
      try {
        return jsonDecode(body);
      } on FormatException {
        throw GithubDiscoveryException(invalidData);
      }
    }

    try {
      return await send(proxied);
    } catch (error) {
      if (cancel.isCancelled ||
          proxied == address ||
          error is GithubDiscoveryException &&
              error.reason == DiscoveryFailure.rateLimited) {
        rethrow;
      }
      return send(address);
    }
  }

  Map<String, dynamic> _object(
    dynamic value, [
    DiscoveryFailure reason = DiscoveryFailure.unavailable,
  ]) {
    if (value is! Map<String, dynamic>) throw GithubDiscoveryException(reason);
    return value;
  }

  Future<GithubDiscoveryPageData> discover({
    required int page,
    required String search,
    required String sort,
    required String proxy,
    required CancelToken cancelToken,
    bool force = false,
    void Function(GithubDiscoveryPageData)? onProgress,
  }) async {
    _ensureActive(cancelToken);
    final pageKey = '$page|$search|$sort|$proxy';
    final cachedPage = _pages[pageKey];
    if (!force && cachedPage != null && cachedPage.until.isAfter(_now())) {
      onProgress?.call(cachedPage.data);
      return cachedPage.data;
    }
    final keyword = search.trim().replaceAll(
      RegExp(r'[^\w\u0080-\uffff./ -]'),
      '',
    );
    final limitedKeyword =
        keyword.length > 100 ? keyword.substring(0, 100) : keyword;
    final query =
        'topic:songloft-plugin archived:false fork:false'
        '${limitedKeyword.isEmpty ? '' : ' $limitedKeyword in:name,description,readme'}';
    final result = _object(
      await _get(
        Uri.https('api.github.com', '/search/repositories', {
          'q': query,
          'sort': sort == 'stars' ? 'stars' : 'updated',
          'order': 'desc',
          'per_page': '20',
          'page': '$page',
        }).toString(),
        proxy,
        cancelToken,
      ),
    );
    if (result['items'] is! List || result['total_count'] is! int) {
      throw const GithubDiscoveryException(DiscoveryFailure.unavailable);
    }
    final repos = <GithubRepository>[];
    for (final value in result['items'] as List) {
      final repo = _object(value);
      if (repo['id'] is! int ||
          repo['full_name'] is! String ||
          !RegExp(
            r'^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$',
          ).hasMatch(repo['full_name']) ||
          repo['default_branch'] is! String ||
          (repo['default_branch'] as String).isEmpty ||
          repo['archived'] != false ||
          repo['fork'] != false ||
          repo['private'] != false ||
          repo['topics'] is! List ||
          !(repo['topics'] as List).contains('songloft-plugin')) {
        continue;
      }
      repos.add(
        GithubRepository(
          id: repo['id'],
          fullName: repo['full_name'],
          defaultBranch: repo['default_branch'],
          stars: repo['stargazers_count'] is int ? repo['stargazers_count'] : 0,
          updatedAt: repo['updated_at'] is String ? repo['updated_at'] : '',
        ),
      );
    }
    final plugins = List<GithubPlugin?>.filled(repos.length, null);
    final failures = <DiscoveryFailure, int>{};
    var cursor = 0, checked = 0;
    var limited = false;
    DateTime? retryAt;
    GithubDiscoveryPageData snapshot() => GithubDiscoveryPageData(
      plugins: List.unmodifiable(plugins.whereType<GithubPlugin>()),
      checked: checked,
      failures: Map.unmodifiable(failures),
      retryAt: retryAt,
      nextPage:
          !limited && page * 20 < (result['total_count'] as int).clamp(0, 1000)
              ? page + 1
              : null,
      incomplete: limited || result['incomplete_results'] == true,
    );
    await Future.wait(
      List.generate(repos.length.clamp(0, 3), (_) async {
        while (cursor < repos.length && !limited && !cancelToken.isCancelled) {
          final index = cursor++;
          try {
            plugins[index] = await _verify(
              repos[index],
              proxy,
              cancelToken,
              force,
            );
          } catch (error) {
            _ensureActive(cancelToken);
            final reason =
                error is GithubDiscoveryException
                    ? error.reason
                    : DiscoveryFailure.unavailable;
            failures[reason] = (failures[reason] ?? 0) + 1;
            if (reason == DiscoveryFailure.rateLimited) {
              limited = true;
              retryAt = (error as GithubDiscoveryException).retryAt;
            }
          }
          checked++;
          if (!cancelToken.isCancelled) onProgress?.call(snapshot());
        }
      }),
    );
    _ensureActive(cancelToken);
    final resultPage = snapshot();
    if (!resultPage.incomplete &&
        !failures.containsKey(DiscoveryFailure.unavailable) &&
        !failures.containsKey(DiscoveryFailure.rateLimited)) {
      _pages[pageKey] = (
        until: _now().add(const Duration(minutes: 15)),
        data: resultPage,
      );
      if (_pages.length > 500) _pages.remove(_pages.keys.first);
    }
    return resultPage;
  }

  Future<GithubPlugin> _verify(
    GithubRepository repo,
    String proxy,
    CancelToken cancel,
    bool force,
  ) async {
    final key = '${repo.fullName}|${repo.defaultBranch}|$proxy';
    final cached = _cache[key];
    if (!force && cached != null && cached.until.isAfter(_now())) {
      return cached.plugin.withRepository(repo);
    }
    var address =
        'https://raw.githubusercontent.com/${repo.fullName}/${Uri.encodeComponent(repo.defaultBranch)}/plugin.json';
    final raw = await _get(
      address,
      proxy,
      cancel,
      invalidData: DiscoveryFailure.invalidManifest,
    );
    late final GithubPluginManifest manifest;
    try {
      manifest = GithubPluginManifest.fromJson(
        _object(raw, DiscoveryFailure.invalidManifest),
      );
    } catch (_) {
      throw const GithubDiscoveryException(DiscoveryFailure.invalidManifest);
    }
    var downloadUrl = manifest.downloadUrl, updateUrl = manifest.updateUrl;
    final visited = {address};
    for (var depth = 0; downloadUrl.isEmpty && depth < 2; depth++) {
      address = updateUrl;
      if (address.isEmpty) {
        throw const GithubDiscoveryException(DiscoveryFailure.unpublished);
      }
      if (!visited.add(address) ||
          !isRepositoryMetadataUrl(address, repo.fullName)) {
        throw const GithubDiscoveryException(DiscoveryFailure.invalidManifest);
      }
      final update = _object(
        await _get(
          address,
          proxy,
          cancel,
          invalidData: DiscoveryFailure.invalidManifest,
        ),
        DiscoveryFailure.invalidManifest,
      );
      if (update['version'] != manifest.version ||
          update['entryPath'] != null &&
              update['entryPath'] != manifest.entryPath) {
        throw const GithubDiscoveryException(DiscoveryFailure.invalidRelease);
      }
      if (update['download_url'] is String &&
          (update['download_url'] as String).isNotEmpty) {
        downloadUrl = update['download_url'];
      } else if (update['updateUrl'] is String) {
        updateUrl = update['updateUrl'];
      } else {
        throw const GithubDiscoveryException(DiscoveryFailure.unpublished);
      }
    }
    final download = releaseDownload(downloadUrl, repo.fullName);
    if (downloadUrl.isEmpty) {
      throw const GithubDiscoveryException(DiscoveryFailure.invalidManifest);
    }
    if (download == null) {
      throw const GithubDiscoveryException(DiscoveryFailure.invalidRelease);
    }
    final release = _object(
      await _get(
        'https://api.github.com/repos/${repo.fullName}/releases/tags/${Uri.encodeComponent(download.tag)}',
        proxy,
        cancel,
      ),
    );
    if (release['draft'] != false ||
        release['prerelease'] != false ||
        release['tag_name'] != download.tag ||
        release['assets'] is! List ||
        release['published_at'] is! String ||
        DateTime.tryParse(release['published_at']) == null) {
      throw const GithubDiscoveryException(DiscoveryFailure.invalidRelease);
    }
    final exists = (release['assets'] as List).any(
      (value) =>
          value is Map &&
          value['name'] == download.file &&
          value['browser_download_url'] == downloadUrl &&
          value['size'] is num &&
          value['size'] > 0 &&
          value['state'] == 'uploaded',
    );
    if (!exists) {
      throw const GithubDiscoveryException(DiscoveryFailure.unpublished);
    }
    final plugin = GithubPlugin(
      repository: repo,
      manifest: manifest,
      downloadUrl: downloadUrl,
      releaseUrl:
          'https://github.com/${repo.fullName}/releases/tag/${Uri.encodeComponent(download.tag)}',
      publishedAt: release['published_at'],
    );
    _cache[key] = (until: _now().add(const Duration(hours: 1)), plugin: plugin);
    if (_cache.length > 500) _cache.remove(_cache.keys.first);
    return plugin;
  }
}
