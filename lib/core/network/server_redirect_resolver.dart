import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../config/app_config.dart';
import 'dio_insecure.dart';

/// 解析"入口域名 → 真实服务地址"的重定向。
///
/// 场景（songloft-org/songloft-player#22）：用户用 lucky + Cloudflare 之类做双栈
/// 自动重定向，入口域名（如 `http://song.123.xyz`）会按访问端网络环境 302 跳到真实
/// 地址（IPv6 直连固定端口，或 IPv4 STUN 穿透的**随机端口**）。直接把入口域名当
/// baseUrl 会因登录 POST 的 302 不被 dart:io 自动跟随而失败。
///
/// 本类对入口域名发一次**跟随重定向**的健康探测，从 [Response.realUri] 反推出真实
/// 地址，供网络请求实际使用。由于 STUN 端口随时可能变化，调用方应在需要时（登录、
/// 启动、请求失败）随时重新 resolve，而非一次固定。
///
/// **平台差异**：Web（浏览器 adapter）无法在 Dart 层获取跨域重定向后的 realUri，
/// 故 Web 上直接返回入口域名（浏览器自行透明跟随 302）。
class ServerRedirectResolver {
  ServerRedirectResolver._();

  static const String _healthPath = '/api/v1/health';
  static const Duration _timeout = Duration(seconds: 5);

  /// 解析 [identityUrl]（入口域名）对应的真实服务基地址。
  ///
  /// 成功返回真实 base（scheme://host[:port][basePath]，去尾斜杠）；
  /// Web 平台、探测失败或超时时**降级返回原 [identityUrl]**（保守，不破坏现状）。
  static Future<String> resolve(
    String identityUrl, {
    bool insecureTls = false,
  }) async {
    if (kIsWeb || identityUrl.isEmpty) return identityUrl;

    final dio = Dio(
      BaseOptions(
        baseUrl: identityUrl,
        connectTimeout: _timeout,
        receiveTimeout: _timeout,
        sendTimeout: _timeout,
        followRedirects: true,
        maxRedirects: 5,
        headers: const {'Accept': 'application/json'},
      ),
    );
    if (insecureTls) {
      applyInsecureTls(dio);
    }
    try {
      final res = await dio.get<dynamic>(_healthPath);
      final base = deriveBase(res.realUri);
      return base.isEmpty ? identityUrl : base;
    } catch (e) {
      debugPrint('[ServerRedirectResolver] $identityUrl resolve 失败，降级用原地址: $e');
      return identityUrl;
    } finally {
      dio.close(force: true);
    }
  }

  /// 从最终 URL（可能经过若干次 302）推导服务基地址：
  /// 剥离末尾的 `/api/v1/health`（重定向通常保留路径，兼容子路径部署），
  /// 剥离不掉则退回 `scheme://host[:port]` origin。
  @visibleForTesting
  static String deriveBase(Uri realUri) {
    if (realUri.host.isEmpty) return '';
    var path = realUri.path;
    if (path.endsWith(_healthPath)) {
      path = path.substring(0, path.length - _healthPath.length);
    } else {
      path = '';
    }
    final portPart = realUri.hasPort ? ':${realUri.port}' : '';
    final base = '${realUri.scheme}://${realUri.host}$portPart$path';
    return base.replaceAll(RegExp(r'/+$'), '');
  }

  /// 便捷方法：使用全局 [AppConfig.insecureTls] 作为 TLS 策略解析。
  static Future<String> resolveWithGlobalTls(String identityUrl) {
    return resolve(identityUrl, insecureTls: AppConfig.insecureTls);
  }
}
