import '../../../core/network/api_exceptions.dart';
import '../../../core/storage/secure_storage.dart';
import '../domain/auth_state.dart';
import 'auth_api.dart';

/// 认证仓库
/// 整合 API 调用和本地存储
class AuthRepository {
  final AuthApi authApi;
  final SecureStorageService secureStorage;

  AuthRepository({
    required this.authApi,
    required this.secureStorage,
  });

  /// 登录
  /// 调用 API 并存储 Token
  Future<AuthTokens> login({
    required String username,
    required String password,
  }) async {
    try {
      final tokens = await authApi.login(
        username: username,
        password: password,
      );

      // 存储 Token
      await secureStorage.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        expiresIn: tokens.expiresIn,
      );

      return tokens;
    } catch (e) {
      rethrow;
    }
  }

  /// 刷新 Token
  Future<AuthTokens> refreshToken() async {
    final refreshToken = await secureStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      throw UnauthorizedException(message: '没有可用的刷新令牌');
    }

    try {
      final tokens = await authApi.refresh(refreshToken: refreshToken);

      // 更新存储的 Token
      await secureStorage.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        expiresIn: tokens.expiresIn,
      );

      return tokens;
    } catch (e) {
      // 刷新失败，清除 Token
      await secureStorage.clearTokens();
      rethrow;
    }
  }

  /// 登出：通知服务端吊销 token（尽力而为）
  ///
  /// 本地 token / wallet 的清理由上层（AuthNotifier）统一负责并优先执行，
  /// 保证离线时也能立即登出；本方法仅负责服务端吊销通知，失败可忽略。
  /// [accessToken] 由调用方在清除本地缓存前捕获并传入，用于携带吊销凭证。
  Future<void> logout({String? accessToken}) async {
    await authApi.logout(accessToken: accessToken);
  }

  /// 检查是否已认证
  Future<bool> isAuthenticated() async {
    return secureStorage.hasTokens();
  }

  /// 获取 Token 列表
  Future<TokenListResponse> getTokens({
    int limit = 20,
    int offset = 0,
  }) async {
    return authApi.getTokens(limit: limit, offset: offset);
  }

  /// 获取单个 Token 信息
  Future<TokenInfo> getToken(String tokenId) async {
    return authApi.getToken(tokenId);
  }

  /// 撤销 Token
  Future<void> revokeToken(String tokenId) async {
    return authApi.revokeToken(tokenId);
  }

  /// 检查 Access Token 是否已过期
  Future<bool> isAccessTokenExpired() async {
    return secureStorage.isAccessTokenExpired();
  }

  /// 获取当前 Access Token
  Future<String?> getAccessToken() async {
    return secureStorage.getAccessToken();
  }
}
