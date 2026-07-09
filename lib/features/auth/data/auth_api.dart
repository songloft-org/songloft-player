import 'package:dio/dio.dart';

import '../../../config/app_config.dart';
import '../../../core/network/api_exceptions.dart';
import '../domain/auth_state.dart';

/// 认证 API 服务
class AuthApi {
  final Dio dio;

  AuthApi({required this.dio});

  /// 登录
  /// POST /api/v1/auth/login
  Future<AuthTokens> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await dio.post(
        '${AppConfig.apiPrefix}/auth/login',
        data: {
          'username': username,
          'password': password,
        },
      );
      return AuthTokens.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 刷新 Token
  /// POST /api/v1/auth/refresh
  Future<AuthTokens> refresh({required String refreshToken}) async {
    try {
      final response = await dio.post(
        '${AppConfig.apiPrefix}/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      return AuthTokens.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 登出
  /// POST /api/v1/auth/logout
  ///
  /// [accessToken] 显式指定用于吊销的 access token。本地登出会先清空 token 缓存，
  /// 此时拦截器已无法附上 Authorization 头，故由调用方在清除前捕获并显式传入，
  /// 直接写进请求头以绕过拦截器时序。
  Future<void> logout({String? accessToken}) async {
    try {
      await dio.post(
        '${AppConfig.apiPrefix}/auth/logout',
        options: (accessToken != null && accessToken.isNotEmpty)
            ? Options(headers: {'Authorization': 'Bearer $accessToken'})
            : null,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 获取 Token 列表
  /// GET /api/v1/auth/tokens
  Future<TokenListResponse> getTokens({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await dio.get(
        '${AppConfig.apiPrefix}/auth/tokens',
        queryParameters: {
          'limit': limit,
          'offset': offset,
        },
      );
      return TokenListResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 获取单个 Token 信息
  /// GET /api/v1/auth/tokens/{token_id}
  Future<TokenInfo> getToken(String tokenId) async {
    try {
      final response = await dio.get('${AppConfig.apiPrefix}/auth/tokens/$tokenId');
      return TokenInfo.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 撤销 Token
  /// DELETE /api/v1/auth/tokens/{token_id}
  Future<void> revokeToken(String tokenId) async {
    try {
      await dio.delete('${AppConfig.apiPrefix}/auth/tokens/$tokenId');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
