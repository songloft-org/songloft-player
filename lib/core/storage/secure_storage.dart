import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Token 存储服务
///
/// 统一使用 SharedPreferences 作为存储后端：
/// - 原生平台：SharedPreferences（Android EncryptedSharedPreferences 的简化替代）
/// - Web 平台：SharedPreferences（底层为 localStorage，刷新页面后数据仍在）
///
/// 对于自托管的本地音乐服务器，简化存储实现是可接受的。
class SecureStorageService {
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _tokenExpiresAtKey = 'token_expires_at';

  /// 同步缓存的 Access Token，供需要同步访问 token 的地方使用（如构建 URL）
  static String? cachedAccessToken;

  /// 同步缓存的 Refresh Token
  static String? cachedRefreshToken;

  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// 保存 Access Token
  Future<void> saveAccessToken(String token) async {
    cachedAccessToken = token;
    final prefs = await _getPrefs();
    await prefs.setString(_accessTokenKey, token);
  }

  /// 获取 Access Token
  Future<String?> getAccessToken() async {
    final prefs = await _getPrefs();
    final token = prefs.getString(_accessTokenKey);
    cachedAccessToken = token;
    return token;
  }

  /// 保存 Refresh Token
  Future<void> saveRefreshToken(String token) async {
    cachedRefreshToken = token;
    final prefs = await _getPrefs();
    await prefs.setString(_refreshTokenKey, token);
  }

  /// 获取 Refresh Token
  Future<String?> getRefreshToken() async {
    // 优先使用内存缓存
    if (cachedRefreshToken != null && cachedRefreshToken!.isNotEmpty) {
      return cachedRefreshToken;
    }
    final prefs = await _getPrefs();
    final token = prefs.getString(_refreshTokenKey);
    cachedRefreshToken = token;
    return token;
  }

  /// 一次性保存所有 Token 信息
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required int expiresIn,
  }) async {
    cachedAccessToken = accessToken;
    cachedRefreshToken = refreshToken;
    debugPrint('[SecureStorage] saveTokens: caching tokens in memory');

    final expiresAt =
        DateTime.now().add(Duration(seconds: expiresIn)).toIso8601String();

    final prefs = await _getPrefs();
    await Future.wait([
      prefs.setString(_accessTokenKey, accessToken),
      prefs.setString(_refreshTokenKey, refreshToken),
      prefs.setString(_tokenExpiresAtKey, expiresAt),
    ]);

    debugPrint('[SecureStorage] saveTokens: tokens saved');
  }

  /// 清除所有 Token
  Future<void> clearTokens() async {
    cachedAccessToken = null;
    cachedRefreshToken = null;
    debugPrint('[SecureStorage] clearTokens: cleared memory cache');
    final prefs = await _getPrefs();
    await Future.wait([
      prefs.remove(_accessTokenKey),
      prefs.remove(_refreshTokenKey),
      prefs.remove(_tokenExpiresAtKey),
    ]);
  }

  /// 检查是否有 Token
  Future<bool> hasTokens() async {
    final accessToken = await getAccessToken();
    return accessToken != null && accessToken.isNotEmpty;
  }

  /// 获取 Token 过期时间
  Future<DateTime?> getTokenExpiresAt() async {
    final prefs = await _getPrefs();
    final expiresAt = prefs.getString(_tokenExpiresAtKey);
    if (expiresAt == null) return null;
    return DateTime.tryParse(expiresAt);
  }

  /// 检查 Access Token 是否已过期
  Future<bool> isAccessTokenExpired() async {
    final expiresAt = await getTokenExpiresAt();
    if (expiresAt == null) return true;
    // 提前 30 秒认为过期，以便有时间刷新
    return DateTime.now().isAfter(
      expiresAt.subtract(const Duration(seconds: 30)),
    );
  }

  // ── Credential Wallet（按服务器隔离 token）──

  static const _walletKeys = [
    _accessTokenKey,
    _refreshTokenKey,
    _tokenExpiresAtKey,
  ];

  /// 规范化 URL 作为 wallet key（去尾斜杠、小写 scheme+host）
  static String walletKey(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final host = uri.host.toLowerCase();
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://$host$port';
  }

  /// 本地模式的固定 wallet key
  static const localWalletKey = '_local_';

  /// 将当前全局 token 存档到指定 server key
  Future<void> saveWallet(String serverKey) async {
    final prefs = await _getPrefs();
    for (final key in _walletKeys) {
      final value = prefs.getString(key);
      if (value != null) {
        await prefs.setString('$key@$serverKey', value);
      }
    }
  }

  /// 从指定 server key 恢复 token 到全局 key。
  /// 返回 true 表示找到了存档 token。
  Future<bool> restoreWallet(String serverKey) async {
    final prefs = await _getPrefs();
    final accessToken = prefs.getString('$_accessTokenKey@$serverKey');
    if (accessToken == null || accessToken.isEmpty) {
      cachedAccessToken = null;
      cachedRefreshToken = null;
      return false;
    }
    for (final key in _walletKeys) {
      final value = prefs.getString('$key@$serverKey');
      if (value != null) {
        await prefs.setString(key, value);
      } else {
        await prefs.remove(key);
      }
    }
    cachedAccessToken = prefs.getString(_accessTokenKey);
    cachedRefreshToken = prefs.getString(_refreshTokenKey);
    return true;
  }

  /// 清除指定 server 的存档 token
  Future<void> clearWallet(String serverKey) async {
    final prefs = await _getPrefs();
    for (final key in _walletKeys) {
      await prefs.remove('$key@$serverKey');
    }
  }
}
