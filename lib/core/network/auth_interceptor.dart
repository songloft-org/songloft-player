import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../config/app_config.dart';
import '../../features/auth/domain/auth_state.dart';
import '../storage/secure_storage.dart';

/// 认证拦截器
///
/// 功能：
/// 1. 自动注入 Authorization header
/// 2. 401 错误时自动刷新 Token
/// 3. 刷新成功后重试原请求
/// 4. 并发刷新保护（多个 401 只触发一次刷新）
/// 5. Windows 平台优先使用内存缓存的 token，避免存储读取不稳定
class AuthInterceptor extends Interceptor {
  final SecureStorageService _secureStorage;
  final Dio _dio;

  /// Token 刷新回调（刷新失败时通知外部）
  final void Function()? onTokenExpired;

  // 不需要认证的路径
  static final _publicPaths = [
    '${AppConfig.apiPrefix}/auth/login',
    '${AppConfig.apiPrefix}/auth/refresh',
    '${AppConfig.apiPrefix}/version',
    '${AppConfig.apiPrefix}/health',
  ];

  // 用于防止并发刷新
  bool _isRefreshing = false;
  Completer<bool>? _refreshCompleter;

  AuthInterceptor({
    required SecureStorageService secureStorage,
    required Dio dio,
    this.onTokenExpired,
  }) : _secureStorage = secureStorage,
       _dio = dio;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // 检查是否是公开路径
    final isPublicPath = _publicPaths.any(
      (path) => options.path.contains(path),
    );

    if (!isPublicPath) {
      // 优先使用内存缓存的 token（解决 Windows 平台存储读取不稳定问题）
      String? accessToken = SecureStorageService.cachedAccessToken;

      // 缓存为空时才从安全存储读取
      if (accessToken == null || accessToken.isEmpty) {
        accessToken = await _secureStorage.getAccessToken();
        debugPrint(
          '[AuthInterceptor] onRequest: cachedAccessToken was null, read from storage: ${accessToken != null}',
        );
      }

      if (accessToken != null && accessToken.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $accessToken';
        debugPrint(
          '[AuthInterceptor] onRequest: ${options.path} - token attached',
        );
      } else {
        debugPrint(
          '[AuthInterceptor] onRequest: ${options.path} - NO token available',
        );
      }
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    debugPrint(
      '[AuthInterceptor] onError: ${err.requestOptions.path} - status: ${err.response?.statusCode}',
    );

    // 只处理 401 错误
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    // 如果是刷新 Token 请求失败，直接返回错误
    if (err.requestOptions.path.contains(
      '${AppConfig.apiPrefix}/auth/refresh',
    )) {
      debugPrint('[AuthInterceptor] onError: refresh token request failed');
      await _handleTokenExpired();
      handler.next(err);
      return;
    }

    // 尝试刷新 Token
    debugPrint('[AuthInterceptor] onError: attempting token refresh');
    final refreshed = await _refreshToken();

    if (refreshed) {
      // 刷新成功，重试原请求
      try {
        final response = await _retryRequest(err.requestOptions);
        handler.resolve(response);
      } catch (e) {
        debugPrint('[AuthInterceptor] onError: retry failed - $e');
        handler.next(err);
      }
    } else {
      // 刷新失败
      debugPrint('[AuthInterceptor] onError: token refresh failed');
      handler.next(err);
    }
  }

  /// 刷新 Token（带并发保护）
  Future<bool> _refreshToken() async {
    // 如果已经在刷新中，等待刷新结果
    if (_isRefreshing) {
      return _refreshCompleter?.future ?? Future.value(false);
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<bool>();

    try {
      final refreshToken = await _secureStorage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        await _handleTokenExpired();
        _refreshCompleter!.complete(false);
        return false;
      }

      // 创建新的 Dio 实例来发送刷新请求，避免循环
      final response = await _dio.post(
        '${AppConfig.apiPrefix}/auth/refresh',
        data: {'refresh_token': refreshToken},
        options: Options(
          // 不使用拦截器
          extra: {'skipAuth': true},
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final tokens = AuthTokens.fromJson(response.data);
        await _secureStorage.saveTokens(
          accessToken: tokens.accessToken,
          refreshToken: tokens.refreshToken,
          expiresIn: tokens.expiresIn,
        );
        _refreshCompleter!.complete(true);
        return true;
      }

      await _handleTokenExpired();
      _refreshCompleter!.complete(false);
      return false;
    } on DioException catch (e) {
      // 刷新请求失败
      if (e.response?.statusCode == 401) {
        // Refresh Token 也无效
        await _handleTokenExpired();
      }
      _refreshCompleter!.complete(false);
      return false;
    } catch (e) {
      _refreshCompleter!.complete(false);
      return false;
    } finally {
      _isRefreshing = false;
      _refreshCompleter = null;
    }
  }

  /// 重试原请求
  Future<Response<dynamic>> _retryRequest(RequestOptions options) async {
    // 优先使用内存缓存的新 Token
    String? accessToken = SecureStorageService.cachedAccessToken;
    accessToken ??= await _secureStorage.getAccessToken();
    options.headers['Authorization'] = 'Bearer $accessToken';
    debugPrint('[AuthInterceptor] _retryRequest: retrying ${options.path}');

    return _dio.fetch(options);
  }

  /// 处理 Token 过期
  Future<void> _handleTokenExpired() async {
    await _secureStorage.clearTokens();
    onTokenExpired?.call();
  }
}
