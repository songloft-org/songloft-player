// web 端自定义 just_audio 平台的注册入口（条件导出，镜像 equalizer_service_factory 的写法）。
// 默认（web）用 _web.dart（接入 hls.js 的 SongloftWebJustAudioPlugin）；
// dart.library.io（原生）用 _stub.dart（空实现），避免把 package:web / dart:js_interop 拉进原生构建。
export 'web_audio_platform_web.dart'
    if (dart.library.io) 'web_audio_platform_stub.dart';
