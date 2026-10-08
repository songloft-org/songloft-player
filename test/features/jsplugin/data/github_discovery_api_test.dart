import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/features/jsplugin/data/github_discovery_api.dart';

import '../github_discovery_fixtures.dart';

class _Adapter implements HttpClientAdapter {
  final FutureOr<ResponseBody> Function(RequestOptions) handle;
  final requests = <RequestOptions>[];
  _Adapter(this.handle);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handle(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(
  dynamic value, {
  int status = 200,
  Map<String, List<String>>? headers,
}) => ResponseBody.fromString(
  jsonEncode(value),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
    ...?headers,
  },
);

ResponseBody _standard(RequestOptions request) {
  final path = request.uri.path;
  if (path == '/search/repositories') {
    return _json({
      'items': [discoveryRepository()],
      'total_count': 1,
    });
  }
  if (path.endsWith('plugin.json')) return _json(discoveryManifest());
  return _json(discoveryRelease());
}

void main() {
  Future<GithubDiscoveryPageData> run(
    _Adapter adapter, {
    String proxy = '',
    String search = '',
    CancelToken? cancel,
  }) => GithubDiscoveryApi(dio: Dio()..httpClientAdapter = adapter).discover(
    page: 1,
    search: search,
    sort: 'updated',
    proxy: proxy,
    cancelToken: cancel ?? CancelToken(),
  );

  test('公开 topic 搜索与真实发布包校验，不携带服务器认证', () async {
    final adapter = _Adapter(_standard);
    final result = await run(adapter, search: 'test topic:other');
    expect(result.plugins.single.downloadUrl, discoveryDownload);
    expect(result.checked, 1);
    expect(result.failures, isEmpty);
    expect(
      adapter.requests.first.uri.queryParameters['q'],
      contains('topic:songloft-plugin archived:false fork:false'),
    );
    expect(
      adapter.requests.first.uri.queryParameters['q'],
      isNot(contains('topic:other')),
    );
    expect(
      adapter.requests.every(
        (request) =>
            !request.headers.keys.any(
              (key) => key.toLowerCase() == 'authorization',
            ),
      ),
      isTrue,
    );
    expect(
      adapter.requests.last.uri.path,
      '/repos/$discoveryRepo/releases/tags/v1.2.3',
    );
  });
  test('fork、私有、归档和无 topic 仓库不进入验证队列', () async {
    final adapter = _Adapter(
      (request) => _json({
        'items': [
          {...discoveryRepository(), 'fork': true},
          {...discoveryRepository(), 'archived': true},
          {...discoveryRepository(), 'private': true},
          {...discoveryRepository(), 'topics': []},
        ],
        'total_count': 4,
      }),
    );
    final result = await run(adapter);
    expect(result.checked, 0);
    expect(adapter.requests, hasLength(1));
  });
  test('支持旧版最小更新清单，拒绝跨仓库、循环和版本错配', () async {
    for (final mode in ['valid', 'cross', 'cycle', 'version']) {
      final updateUrl =
          'https://raw.githubusercontent.com/${mode == 'cross' ? 'other/repo' : discoveryRepo}/main/update.json';
      final adapter = _Adapter((request) {
        if (request.uri.path.endsWith('/plugin.json')) {
          return _json(
            discoveryManifest()
              ..remove('download_url')
              ..['updateUrl'] = updateUrl,
          );
        }
        if (request.uri.path.endsWith('/update.json')) {
          return _json(
            mode == 'cycle'
                ? {'version': '1.2.3', 'updateUrl': updateUrl}
                : {
                  'version': mode == 'version' ? '1.0.0' : '1.2.3',
                  'download_url': discoveryDownload,
                },
          );
        }
        return _standard(request);
      });
      final result = await run(adapter);
      expect(result.plugins.length, mode == 'valid' ? 1 : 0, reason: mode);
      if (mode != 'valid') expect(result.failures.values.single, 1);
      if (mode == 'cross') {
        expect(
          adapter.requests.any((r) => r.uri.path.contains('other/repo')),
          isFalse,
        );
      }
    }
  });
  test('坏清单与网络失败分开计数，不把超大或非 JSON 当网络错误', () async {
    for (final mode in ['missing', 'json', 'oversize', 'network']) {
      final adapter = _Adapter((request) {
        if (!request.uri.path.endsWith('/plugin.json')) {
          return _standard(request);
        }
        return switch (mode) {
          'missing' => _json(discoveryManifest()..remove('zipHash')),
          'json' => ResponseBody.fromString('<html>oops</html>', 200),
          'oversize' => ResponseBody.fromString(
            List.filled(2 * 1024 * 1024 + 1, 'a').join(),
            200,
          ),
          _ => _json({}, status: 503),
        };
      });
      final result = await run(adapter);
      expect(result.failures, {
        mode == 'network'
                ? DiscoveryFailure.unavailable
                : DiscoveryFailure.invalidManifest:
            1,
      });
    }
  });
  test('拒绝不稳定、版本错配、空包或不存在的资产', () async {
    for (final mode in ['draft', 'prerelease', 'tag', 'size', 'asset', 'url']) {
      final adapter = _Adapter((request) {
        if (!request.uri.path.contains('/releases/tags/')) {
          return _standard(request);
        }
        final release = discoveryRelease();
        if (mode == 'draft' || mode == 'prerelease') release[mode] = true;
        if (mode == 'tag') release['tag_name'] = 'v1.0.0';
        final asset = (release['assets'] as List).single as Map;
        if (mode == 'size') asset['size'] = 0;
        if (mode == 'asset') asset['name'] = 'different.jsplugin.zip';
        if (mode == 'url') {
          asset['browser_download_url'] = 'https://example.com/package.zip';
        }
        return _json(release);
      });
      expect((await run(adapter)).plugins, isEmpty, reason: mode);
    }
  });
  test('代理失败降级直连，限流不降级并显示恢复时间', () async {
    final adapter = _Adapter(
      (request) =>
          request.uri.host == 'proxy.example'
              ? _json({}, status: 502)
              : _standard(request),
    );
    expect(
      (await run(adapter, proxy: 'https://proxy.example/')).plugins,
      hasLength(1),
    );
    expect(adapter.requests.any((r) => r.uri.host == 'api.github.com'), isTrue);
    final limited = _Adapter(
      (request) => _json(
        {'message': 'rate limit'},
        status: 403,
        headers: {
          'x-ratelimit-remaining': ['0'],
          'x-ratelimit-reset': ['1800000000'],
        },
      ),
    );
    await expectLater(
      run(limited, proxy: 'https://proxy.example/'),
      throwsA(
        isA<GithubDiscoveryException>()
            .having(
              (error) => error.reason,
              'reason',
              DiscoveryFailure.rateLimited,
            )
            .having(
              (error) => error.retryAt,
              'retryAt',
              DateTime.fromMillisecondsSinceEpoch(1800000000000),
            ),
      ),
    );
    expect(limited.requests, hasLength(1));
  });
  test('发现验证限制 3 并发，出现限流后停止新调度', () async {
    var active = 0, peak = 0;
    final adapter = _Adapter((request) async {
      if (request.uri.path == '/search/repositories') {
        return _json({
          'items': List.generate(
            8,
            (i) => discoveryRepository(id: i + 1, name: 'sample/plugin-$i'),
          ),
          'total_count': 8,
        });
      }
      active++;
      if (active > peak) peak = active;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      active--;
      return _json(
        {},
        status: 429,
        headers: {
          'retry-after': ['60'],
        },
      );
    });
    final result = await run(adapter);
    expect(peak, 3);
    expect(result.checked, 3);
    expect(result.incomplete, isTrue);
    expect(result.nextPage, isNull);
    expect(adapter.requests, hasLength(4));
  });
  test('正结果缓存一小时，主动刷新绕过，逐仓库报告进度', () async {
    final adapter = _Adapter(_standard);
    var now = DateTime(2026);
    final api = GithubDiscoveryApi(
      dio: Dio()..httpClientAdapter = adapter,
      now: () => now,
    );
    final progress = <int>[];
    Future<GithubDiscoveryPageData> discover({bool force = false}) =>
        api.discover(
          page: 1,
          search: '',
          sort: 'updated',
          proxy: '',
          cancelToken: CancelToken(),
          force: force,
          onProgress: (data) => progress.add(data.checked),
        );
    await discover();
    expect(adapter.requests, hasLength(3));
    await discover();
    expect(adapter.requests, hasLength(3));
    now = now.add(const Duration(minutes: 16));
    await discover();
    expect(adapter.requests, hasLength(4));
    await discover(force: true);
    expect(adapter.requests, hasLength(7));
    now = now.add(const Duration(hours: 2));
    await discover();
    expect(adapter.requests, hasLength(10));
    expect(progress, [1, 1, 1, 1, 1]);
  });
  test('取消请求后不继续校验或回写进度', () async {
    final cancel = CancelToken();
    final progress = <int>[];
    final adapter = _Adapter((request) {
      cancel.cancel();
      return _standard(request);
    });
    final api = GithubDiscoveryApi(dio: Dio()..httpClientAdapter = adapter);
    await expectLater(
      api.discover(
        page: 1,
        search: '',
        sort: 'updated',
        proxy: '',
        cancelToken: cancel,
        onProgress: (data) => progress.add(data.checked),
      ),
      throwsA(isA<DioException>()),
    );
    expect(adapter.requests, hasLength(1));
    expect(progress, isEmpty);
  });
  test('GitHub 搜索最多翻至 1000 条，不接受带凭据的代理', () async {
    final adapter = _Adapter(
      (request) => _json({'items': [], 'total_count': 1200}),
    );
    final api = GithubDiscoveryApi(dio: Dio()..httpClientAdapter = adapter);
    final result = await api.discover(
      page: 50,
      search: '',
      sort: 'stars',
      proxy: 'https://secret@proxy.example/',
      cancelToken: CancelToken(),
    );
    expect(result.nextPage, isNull);
    expect(adapter.requests.single.uri.host, 'api.github.com');
  });
}
