import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../backend/run_mode_provider.dart';
import '../storage/secure_storage.dart';
import 'auth_interceptor.dart';
import 'base_url_provider.dart';

/// 创建并配置 Dio 实例
Dio createDio({
  required SecureStorageService secureStorage,
  Future<void> Function()? onTokenExpired,
  String? Function()? currentWalletKey,
  String? customBaseUrl,
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
Dio createPublicDio({String? customBaseUrl}) {
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
  return createPublicDio(customBaseUrl: customBaseUrl);
});

/// 认证 Dio Provider
final dioProvider = Provider<Dio>((ref) {
  final baseUrl = ref.watch(baseUrlProvider);
  final secureStorage = ref.watch(secureStorageProvider);
  return createDio(
    customBaseUrl: baseUrl,
    secureStorage: secureStorage,
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
});

/// API 客户端 Provider
final apiClientProvider = Provider<ApiClient>((ref) {
  final dio = ref.watch(dioProvider);
  return ApiClient(dio);
});
