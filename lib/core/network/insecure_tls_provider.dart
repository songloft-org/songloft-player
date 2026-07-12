import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

/// 是否忽略 HTTPS 证书校验（不安全）。
///
/// single source of truth：[dioProvider] / [publicDioProvider] ref.watch 它，
/// 切换后自动重建 Dio；同时 mirror 到 [AppConfig.insecureTls] 供非 Riverpod
/// 上下文（如 [ServerProbe]）同步读取。
///
/// 初始值在 build() 中同步返回 [AppConfig.insecureTls]（启动时已由 main 从
/// 偏好加载），随后异步从偏好回读校正。
class InsecureTlsNotifier extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return AppConfig.insecureTls;
  }

  Future<void> _load() async {
    try {
      final prefs = await ref.read(appPreferencesProvider.future);
      final value = prefs.getInsecureTls();
      AppConfig.insecureTls = value;
      state = value;
    } catch (_) {
      // 偏好读取失败保持默认（安全）
    }
  }

  Future<void> setValue(bool value) async {
    AppConfig.insecureTls = value;
    state = value;
    try {
      final prefs = await ref.read(appPreferencesProvider.future);
      await prefs.setInsecureTls(value);
    } catch (_) {}
  }
}

final insecureTlsProvider = NotifierProvider<InsecureTlsNotifier, bool>(
  InsecureTlsNotifier.new,
);
