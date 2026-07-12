// 按平台切换：native(dart:io) 走真实实现，web 走 no-op stub。
// Web 平台由浏览器接管 TLS，Dart 层无法（也无需）干预证书校验，故为空实现。
export 'dio_insecure_stub.dart'
    if (dart.library.io) 'dio_insecure_native.dart';
