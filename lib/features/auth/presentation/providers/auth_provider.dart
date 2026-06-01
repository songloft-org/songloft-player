import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exceptions.dart';
import '../../../../core/network/base_url_provider.dart';
import '../../../../core/network/server_entry.dart';
import '../../../../core/network/servers_provider.dart';
import '../../../../core/storage/app_preferences.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../data/auth_api.dart';
import '../../data/auth_repository.dart';
import '../../domain/auth_state.dart';

/// AppPreferences Provider（异步初始化）
final appPreferencesProvider = FutureProvider<AppPreferences>((ref) async {
  return AppPreferences.create();
});

/// AuthApi Provider
final authApiProvider = Provider<AuthApi>((ref) {
  final dio = ref.watch(dioProvider);
  return AuthApi(dio: dio);
});

/// AuthRepository Provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final authApi = ref.watch(authApiProvider);
  final secureStorage = ref.watch(secureStorageProvider);
  return AuthRepository(authApi: authApi, secureStorage: secureStorage);
});

/// 认证状态 Notifier
class AuthNotifier extends Notifier<AuthState> {
  late SecureStorageService _secureStorage;
  bool _disposed = false;

  @override
  AuthState build() {
    _secureStorage = ref.watch(secureStorageProvider);
    _disposed = false;

    ref.onDispose(() {
      _disposed = true;
    });

    // 延迟到微任务中执行，避免在首次帧渲染的 addPostFrameCallback 阶段
    // 与 widget 树构建产生竞态（auth 状态变化触发 GoRouter redirect 导致 provider flush 冲突）
    Future.microtask(() => checkAuth());
    return AuthState.initial;
  }

  /// 检查认证状态
  /// 注意：不设置中间 loading 状态，直接从 unknown 跳到最终状态，
  /// 避免触发多余的 GoRouter redirect 重新评估导致 widget 树重建竞态。
  Future<void> checkAuth() async {
    try {
      final hasTokens = await _secureStorage.hasTokens();
      if (_disposed) return;
      if (hasTokens) {
        state = state.authenticated();
      } else {
        state = state.unauthenticated();
      }
    } catch (e) {
      if (_disposed) return;
      state = state.unauthenticated(e.toString());
    }
  }

  /// 登录
  Future<void> login({
    required String username,
    required String password,
    String? apiBaseUrl,
  }) async {
    state = state.loading();

    try {
      // 如果提供了自定义 API 地址，规范化并写入 baseUrl + 同步到服务器列表
      if (apiBaseUrl != null && apiBaseUrl.isNotEmpty) {
        final normalized = ServerEntry.normalizeUrl(apiBaseUrl);
        ref.read(baseUrlProvider.notifier).set(normalized);
        await _syncServerList(normalized);
      }

      // 创建临时 Dio 进行登录（不带认证拦截器）
      // connectTimeout 单独缩短到 10s：登录是用户首次反馈点，30s 会让用户以为 APP 卡死；
      // 业务 API 维持全局 30s，弱网下封面/音频流仍需更长容忍度
      final dio = Dio(
        BaseOptions(
          baseUrl: AppConfig.baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: AppConfig.receiveTimeout,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      final authApi = AuthApi(dio: dio);
      final tokens = await authApi.login(
        username: username,
        password: password,
      );

      // 保存 Token
      await _secureStorage.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        expiresIn: tokens.expiresIn,
      );

      // 登录成功后保存账号密码
      final prefs = await ref.read(appPreferencesProvider.future);
      await prefs.setLastUsername(username);
      await prefs.setLastPassword(password);

      state = state.authenticated();
    } on FormatException catch (e) {
      state = state.unauthenticated(e.message);
    } on ApiException catch (e) {
      state = state.unauthenticated(e.message);
    } catch (e) {
      state = state.unauthenticated('登录失败：$e');
    }
  }

  /// 把登录用的 url 同步到服务器列表：
  /// - 列表为空：promote 为首项
  /// - 列表恰好 1 项且 url 不同：更新该项 url（登录页编辑场景）
  /// - 否则若 url 已存在：不动；不存在则不主动加（管理走设置页）
  Future<void> _syncServerList(String url) async {
    final notifier = ref.read(serversProvider.notifier);
    final list = await ref.read(serversProvider.future);
    if (list.isEmpty) {
      await notifier.add(
        ServerEntry(id: ServerEntry.generateId(), name: '', url: url),
      );
      return;
    }
    if (list.length == 1 && list.first.url != url) {
      await notifier.editEntry(list.first.copyWith(url: url));
      return;
    }
  }

  /// 登出
  Future<void> logout() async {
    state = state.loading();

    try {
      final repository = ref.read(authRepositoryProvider);
      await repository.logout();
    } catch (e) {
      // 忽略登出错误，仍然清除本地状态
    }

    await _secureStorage.clearTokens();
    state = state.unauthenticated();
  }

  /// Token 过期处理
  void onTokenExpired() {
    state = state.unauthenticated('登录已过期，请重新登录');
  }
}

/// 认证状态 Provider
final authStateProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

/// 是否已认证 Provider
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.status == AuthStatus.authenticated;
});

/// 认证状态是否已确定（非 unknown）
final isAuthResolvedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.status != AuthStatus.unknown;
});

/// 认证状态枚举 Provider
final authStatusProvider = Provider<AuthStatus>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.status;
});
