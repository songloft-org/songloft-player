import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';

/// 当前生效的**身份 URL**（入口域名，稳定）。
///
/// 是 single source of truth：dioProvider watch 它，仅身份切换（换服务器）时重建 Dio；
/// 同时 mirror 到 [AppConfig.baseUrl] 供少数非 Riverpod 上下文读取。
/// 用途：walletKey 派生、多服务器定位、持久化。运行期所有写入必须经此 Notifier。
///
/// 实际发网络请求用的真实地址见 [resolvedBaseUrlProvider]（入口域名 302 重定向解析
/// 后的结果）。切换身份 URL 时会自动把 resolved 重置为新身份，避免跨服务器串地址；
/// 之后由登录/启动/请求失败触发重新 resolve。
class BaseUrlNotifier extends Notifier<String> {
  @override
  String build() => AppConfig.baseUrl;

  void set(String url) {
    if (state == url) return;
    state = url;
    AppConfig.baseUrl = url;
    // 身份变化 → resolved 先回退到新身份（未解析态），待重新 resolve 刷新
    ref.read(resolvedBaseUrlProvider.notifier).set(url);
  }
}

final baseUrlProvider = NotifierProvider<BaseUrlNotifier, String>(
  BaseUrlNotifier.new,
);

/// 实际发起网络请求使用的**真实地址**（入口域名 302 重定向解析后的结果）。
///
/// mirror 到 [AppConfig.resolvedBaseUrl]，由 [RedirectResolveInterceptor] 在 onRequest
/// 每请求同步读取（覆盖 Dio baseUrl）、[UrlHelper] 拼接播放/封面/歌词 URL 时读取。
/// 由 [ServerRedirectResolver] 解析后经此 Notifier 写入；[BaseUrlNotifier.set] 在身份
/// 变化时会先把它重置为新身份 URL。STUN 端口变化时可随时被重新 resolve 覆盖。
class ResolvedBaseUrlNotifier extends Notifier<String> {
  @override
  String build() => AppConfig.resolvedBaseUrl;

  void set(String url) {
    if (state == url) return;
    state = url;
    AppConfig.resolvedBaseUrl = url;
  }
}

final resolvedBaseUrlProvider =
    NotifierProvider<ResolvedBaseUrlNotifier, String>(
      ResolvedBaseUrlNotifier.new,
    );
