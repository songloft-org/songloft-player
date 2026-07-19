// 「忽略 SSL 证书校验」开启时，用于 HLS 播放的 trust-all 本地代理入口。
//
// - native（dart:io）：见 insecure_media_proxy_native.dart，起一个 127.0.0.1 明文
//   回环代理，用 trust-all 的 HttpClient 拉取上游自签 HTTPS，并递归改写 m3u8 里所有
//   子资源（切片 / key / 变体播放列表）URI，使其也经本机代理——解决 just_audio 自带
//   代理只能代理单一资源、无法处理 HLS 子切片的结构性限制（songloft-org/songloft#272）。
// - web：见 insecure_media_proxy_stub.dart，no-op（浏览器自行处理 TLS）。
export 'insecure_media_proxy_stub.dart'
    if (dart.library.io) 'insecure_media_proxy_native.dart';
