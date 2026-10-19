import 'package:flutter/foundation.dart';

/// 桌面直播流请求头的「旁路」载体。
///
/// 为什么不直接用 `ja.AudioSource.uri(headers: ...)` 交给 just_audio：
/// just_audio 只要 headers 非空就会**无条件**启用本机回环 HTTP 代理
/// （`_useProxyForRequestHeaders`，just_audio.dart 的 `UriAudioSource._onLoad`），
/// 而该代理的 m3u8 子资源注册逻辑用**入口 URL** 拼 key：
///
/// ```dart
/// final nestedUri = uri.replace(path: '$basePath${rawNestedUri.path}');
/// ```
///
/// `Uri.replace(path:)` 只换 path，**query 仍是入口那条的**
/// （`.../play.m3u8?access_token=TOK&hls=direct`），于是注册 key 是
/// `/songs/58/hls/segment?access_token=TOK&hls=direct`；
/// 而 libmpv 以代理入口 URL 为 base 解析相对切片，实际请求
/// `/songs/58/hls/segment?u=BASE64&access_token=TOK`。两者 query 不同
/// → `_handlerMap[uriPath]!` 抛 `Null check operator used on a null value`
/// → 所有切片都打不开 → 18s 加载超时后重试切台。
///
/// 桌面直播走 `hls=direct`、由 libmpv 直连源站，本就不需要这层代理。故这里把
/// UA/Referer 等防盗链头挂在 just_audio 的 `tag` 上（tag 不参与代理判定），
/// 由 [SongloftMediaKitPlayer] 转成 `Media(httpHeaders:)`（media_kit 据此设置
/// mpv 的 `http-header-fields`）直接交给原生播放器。
///
/// 不要改用 `AudioPlayer(useProxyForRequestHeaders: false)`：那会同时关掉
/// `insecureTls` 路径赖以把上游 HTTPS 交给 Dart trust-all HttpClient 的代理
/// （songloft-org/songloft#272）。
@immutable
class LiveStreamHeaders {
  const LiveStreamHeaders(this.values);

  /// 需要随播放请求发给源站的头（UA / Referer / Icy-MetaData 等）。
  final Map<String, String> values;

  @override
  bool operator ==(Object other) =>
      other is LiveStreamHeaders && mapEquals(other.values, values);

  @override
  int get hashCode => Object.hashAllUnordered(
    values.entries.map((e) => Object.hash(e.key, e.value)),
  );

  @override
  String toString() => 'LiveStreamHeaders($values)';
}
