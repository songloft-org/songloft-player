import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../backend/run_mode_provider.dart';
import '../storage/secure_storage.dart';
import 'auth_interceptor.dart';
import 'base_url_provider.dart';
import 'dio_insecure.dart';
import 'insecure_tls_provider.dart';
import 'redirect_resolve_interceptor.dart';

/// 创建并配置 Dio 实例
Dio createDio({
  required SecureStorageService secureStorage,
  Future<void> Function()? onTokenExpired,
  String? Function()? currentWalletKey,
  String? customBaseUrl,
  bool insecureTls = false,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: customBaseUrl ?? AppConfig.baseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  // 忽略 SSL 证书校验（用户显式开启时；web 上为 no-op）
  if (insecureTls) {
    applyInsecureTls(dio);
  }

  // 添加认证拦截器
  dio.interceptors.add(
    AuthInterceptor(
      secureStorage: secureStorage,
      dio: dio,
      onTokenExpired: onTokenExpired,
      currentWalletKey: currentWalletKey,
    ),
  );

  // 添加日志拦截器（仅在调试模式下）
  assert(() {
    dio.interceptors.add(
      LogInterceptor(
        requestHeader: true,
        requestBody: true,
        responseHeader: false,
        responseBody: true,
        error: true,
      ),
    );
    return true;
  }());

  return dio;
}

/// 创建无认证拦截器的 Dio 实例（用于登录等无需认证的请求）
Dio createPublicDio({String? customBaseUrl, bool insecureTls = false}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: customBaseUrl ?? AppConfig.baseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  // 忽略 SSL 证书校验（用户显式开启时；web 上为 no-op）
  if (insecureTls) {
    applyInsecureTls(dio);
  }

  // 添加日志拦截器（仅在调试模式下）
  assert(() {
    dio.interceptors.add(
      LogInterceptor(
        requestHeader: true,
        requestBody: true,
        responseHeader: false,
        responseBody: true,
        error: true,
      ),
    );
    return true;
  }());

  return dio;
}

/// API 客户端封装类
class ApiClient {
  final Dio dio;

  ApiClient(this.dio);

  /// 更新 baseUrl
  @Deprecated(
    '改走 baseUrlProvider.notifier.set；dioProvider 会自动重建带新 baseUrl 的 Dio',
  )
  void updateBaseUrl(String baseUrl) {
    dio.options.baseUrl = baseUrl;
  }
}

/// SecureStorageService Provider
final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

/// 公开 Dio Provider（无认证，用于登录）
final publicDioProvider = Provider.family<Dio, String?>((ref, customBaseUrl) {
  final insecureTls = ref.watch(insecureTlsProvider);
  return createPublicDio(customBaseUrl: customBaseUrl, insecureTls: insecureTls);
});

/// 认证 Dio Provider
///
/// watch 身份 URL（[baseUrlProvider]）：仅身份切换（换服务器）时重建 Dio。resolved
/// 真实地址的刷新不重建 Dio，而是由 [RedirectResolveInterceptor] 在 onRequest 每请求
/// 动态读取 [AppConfig.resolvedBaseUrl]，避免 dioProvider 及其下游连锁 recompute。
/// walletKey 用 [baseUrlProvider]（身份 URL），保证换端口不影响凭证隔离。拦截器在连接
/// 失败/3xx 时重新 resolve 并重试，适配 STUN 端口变化（songloft-org/songloft-player#22）。
final dioProvider = Provider<Dio>((ref) {
  // customBaseUrl 传身份作初值，实际每请求由拦截器 onRequest 覆盖为 resolved 真实地址
  final baseUrl = ref.watch(baseUrlProvider);
  final secureStorage = ref.watch(secureStorageProvider);
  final insecureTls = ref.watch(insecureTlsProvider);
  final dio = createDio(
    customBaseUrl: baseUrl,
    secureStorage: secureStorage,
    insecureTls: insecureTls,
    onTokenExpired: () async {
      debugPrint('[DioProvider] Token expired, notifying AuthNotifier');
      ref.read(authStateProvider.notifier).onTokenExpired();
    },
    currentWalletKey: () {
      if (ref.read(runModeProvider) == RunMode.local) {
        return SecureStorageService.localWalletKey;
      }
      return SecureStorageService.walletKey(ref.read(baseUrlProvider));
    },
  );
  dio.interceptors.add(
    RedirectResolveInterceptor(
      onResolved: (url) => ref.read(resolvedBaseUrlProvider.notifier).set(url),
      insecureTls: insecureTls,
    ),
  );
  return dio;
});

/// API 客户端 Provider
final apiClientProvider = Provider<ApiClient>((ref) {
  final dio = ref.watch(dioProvider);
  return ApiClient(dio);
});
