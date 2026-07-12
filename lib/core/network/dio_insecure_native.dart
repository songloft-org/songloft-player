import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// native 平台：给 Dio 装上无条件接受任意证书的 HttpClient 适配器。
///
/// 不安全，仅在用户显式开启「忽略 SSL 证书校验」时调用，用于自签/内网证书场景。
void applyInsecureTls(Dio dio) {
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient();
      client.badCertificateCallback = (cert, host, port) => true;
      return client;
    },
  );
}
