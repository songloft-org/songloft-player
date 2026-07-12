import 'package:dio/dio.dart';

/// Web 平台 no-op：浏览器接管 TLS，Dart 层无法覆盖证书校验。
void applyInsecureTls(Dio dio) {}
