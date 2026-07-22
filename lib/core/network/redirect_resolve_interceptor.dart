import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../config/app_config.dart';
import 'dio_insecure.dart';
import 'server_redirect_resolver.dart';

/// 让每个请求实时使用当前**真实地址**（[AppConfig.resolvedBaseUrl]），并在请求因
/// **连接失败 / 超时 / 收到未跟随的 3xx** 出错时，认为入口域名对应的真实地址可能已
/// 变化（典型：STUN 穿透端口变了，songloft-org/songloft-player#22），于是对身份 URL
/// 重新 resolve；若解析出的真实地址与当前不同，则用新地址**重发一次**该请求。
///
/// 设计要点：
/// - `onRequest` 每次读 [AppConfig.resolvedBaseUrl] 覆盖 baseUrl，故 Dio 无需因 resolve
///   刷新而重建（避免 dioProvider 及其下游连锁 recompute），只在身份切换时重建。未
///   resolve 时该 getter 回退到入口域名，仍是合法的会 302 的地址。
/// - 身份 / 当前地址均从 [AppConfig] 静态读取（provider 的 mirror），读取不依赖 ref；
///   [onResolved] 把新地址写回 provider（同时 mirror 回 [AppConfig.resolvedBaseUrl]）。
/// - 对 POST 同样生效——重发由本拦截器主动发起，不依赖 dart:io 对非 GET 的 302 自动
///   跟随（后者默认不跟随，正是 #22 登录失败的根因）。
class RedirectResolveInterceptor extends Interceptor {
  /// resolve 出新真实地址后回写 provider（其 set 会同时 mirror 到 [AppConfig.resolvedBaseUrl]）。
  final void Function(String resolved) onResolved;

  final bool insecureTls;

  RedirectResolveInterceptor({
    required this.onResolved,
    this.insecureTls = false,
  });

  static const String _retriedFlag = '__redirect_resolve_retried';

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    // 实时使用当前 resolved 真实地址（可能已被上次失败的重解析刷新）；
    // 未 resolve 时回退入口域名（getter 保证非空）。
    final resolved = AppConfig.resolvedBaseUrl;
    if (resolved.isNotEmpty) {
      options.baseUrl = resolved;
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final opts = err.requestOptions;

    // 已重试过 / 不是可触发重解析的错误类型 → 透传
    if (opts.extra[_retriedFlag] == true || !_shouldReresolve(err)) {
      handler.next(err);
      return;
    }

    final identity = AppConfig.baseUrl;
    if (identity.isEmpty) {
      handler.next(err);
      return;
    }

    final resolved = await ServerRedirectResolver.resolve(
      identity,
      insecureTls: insecureTls,
    );
    // 解析结果与当前一致（含降级返回入口域名）→ 无新地址可试，透传原错误
    if (resolved == AppConfig.resolvedBaseUrl) {
      handler.next(err);
      return;
    }
    onResolved(resolved);

    try {
      opts
        ..baseUrl = resolved
        ..extra[_retriedFlag] = true;
      final retryDio = Dio(
        BaseOptions(
          connectTimeout: opts.connectTimeout,
          receiveTimeout: opts.receiveTimeout,
          sendTimeout: opts.sendTimeout,
        ),
      );
      if (insecureTls) {
        applyInsecureTls(retryDio);
      }
      final resp = await retryDio.fetch<dynamic>(opts);
      retryDio.close(force: true);
      handler.resolve(resp);
    } catch (e) {
      debugPrint('[RedirectResolveInterceptor] 重解析后重试仍失败: $e');
      handler.next(err);
    }
  }

  bool _shouldReresolve(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return true;
      case DioExceptionType.badResponse:
        final code = err.response?.statusCode ?? 0;
        return code >= 300 && code < 400;
      case DioExceptionType.unknown:
        // dart:io SocketException 等落到 unknown
        return true;
      default:
        return false;
    }
  }
}
