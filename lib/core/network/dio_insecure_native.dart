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

class _InsecureHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback = (cert, host, port) => true;
    return client;
  }
}

/// 设置全局 [HttpOverrides]，使所有 Dart [HttpClient] 实例（包括 just_audio 的
/// [LockCachingAudioSource] 内部 HTTP 客户端）在 [insecure] 为 true 时接受任意证书。
void applyGlobalInsecureHttpOverrides(bool insecure) {
  HttpOverrides.global = insecure ? _InsecureHttpOverrides() : null;
}
