import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/features/jsplugin/data/jsplugin_api.dart';

class _RegistryAdapter implements HttpClientAdapter {
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      '{"plugins":[],"total":0,"page":1,"page_size":20,"results":[],"has_update":false}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('插件安装和更新使用独立超时，普通查询保留默认值', () async {
    final adapter = _RegistryAdapter();
    final dio = Dio(
      BaseOptions(
        baseUrl: 'http://localhost:58091',
        receiveTimeout: const Duration(seconds: 15),
      ),
    )..httpClientAdapter = adapter;
    final api = JSPluginApi(dio: dio);

    await api.updatePlugin(35, force: true);
    expect(adapter.request?.receiveTimeout, const Duration(minutes: 4));
    expect(adapter.request?.data, containsPair('force', true));

    await api.installFromRegistry(
      downloadUrl: 'https://example.com/plugin.zip',
    );
    expect(adapter.request?.receiveTimeout, const Duration(minutes: 4));
    expect(
      adapter.request?.data,
      containsPair('download_url', 'https://example.com/plugin.zip'),
    );

    await api.uploadPluginBytes(Uint8List.fromList([1, 2, 3]), 'plugin.zip');
    expect(adapter.request?.receiveTimeout, const Duration(minutes: 4));

    await api.updateAllPlugins();
    expect(adapter.request?.receiveTimeout, const Duration(minutes: 30));

    await api.checkUpdate(35);
    expect(adapter.request?.receiveTimeout, const Duration(seconds: 45));
    await api.getPlugins();
    expect(adapter.request?.receiveTimeout, const Duration(seconds: 15));
    expect(dio.options.receiveTimeout, const Duration(seconds: 15));
  });

  test('注册表刷新使用独立的 60 秒接收超时', () async {
    final adapter = _RegistryAdapter();
    final dio = Dio(
      BaseOptions(
        baseUrl: 'http://localhost:58091',
        receiveTimeout: const Duration(seconds: 15),
      ),
    )..httpClientAdapter = adapter;
    final api = JSPluginApi(dio: dio);

    final response = await api.refreshRegistry(allSources: true);

    expect(response.plugins, isEmpty);
    expect(adapter.request?.path, '/api/v1/jsplugins/registry/refresh');
    expect(adapter.request?.receiveTimeout, const Duration(seconds: 60));
    expect(adapter.request?.data, containsPair('all_sources', true));
  });
}
