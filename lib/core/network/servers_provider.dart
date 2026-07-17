import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../storage/secure_storage.dart';
import 'base_url_provider.dart';
import 'server_entry.dart';

enum ProbeStatus { unknown, probing, ok, fail }

/// 探测结果摘要，供 StartupGate 写入、首屏 SnackBar 读取。
enum ProbeOutcome { idle, success, fallbackUsed, noServers }

/// 服务器列表的持久化状态。所有 CRUD 走这个 Notifier，保证去重 + 顺序持久化。
class ServersNotifier extends AsyncNotifier<List<ServerEntry>> {
  @override
  Future<List<ServerEntry>> build() async {
    final prefs = await ref.watch(appPreferencesProvider.future);
    return prefs.getApiServers();
  }

  Future<void> _save(List<ServerEntry> next) async {
    final prefs = await ref.read(appPreferencesProvider.future);
    await prefs.setApiServers(next);
    state = AsyncData(prefs.getApiServers());
  }

  Future<void> add(ServerEntry entry) async {
    final current = state.value ?? const <ServerEntry>[];
    if (current.any((e) => e.url == entry.url)) return;
    await _save([...current, entry]);
  }

  Future<void> editEntry(ServerEntry entry) async {
    final current = state.value ?? const <ServerEntry>[];
    final next = current.map((e) => e.id == entry.id ? entry : e).toList();
    await _save(next);
  }

  Future<void> remove(String id) async {
    final current = state.value ?? const <ServerEntry>[];
    final next = current.where((e) => e.id != id).toList();
    await _save(next);
  }

  /// onReorderItem：newIndex 已是移除后的最终目标索引，无需再自行调整。
  Future<void> reorder(int oldIndex, int newIndex) async {
    final current = [...(state.value ?? const <ServerEntry>[])];
    final item = current.removeAt(oldIndex);
    current.insert(newIndex, item);
    await _save(current);
  }

  Future<void> replace(List<ServerEntry> next) async {
    await _save(next);
  }

  /// 更新指定服务器的保存凭证（登录成功后调用）
  Future<void> updateCredentials(String url, {String? username, String? password}) async {
    final current = state.value ?? const <ServerEntry>[];
    final next = current.map((e) {
      if (e.url != url) return e;
      return e.copyWith(
        usernameOverride: () => username,
        passwordOverride: () => password,
      );
    }).toList();
    await _save(next);
  }
}

final serversProvider =
    AsyncNotifierProvider<ServersNotifier, List<ServerEntry>>(
  ServersNotifier.new,
);

/// 探测状态：ServerEntry id → ProbeStatus
class ProbeStatusNotifier extends Notifier<Map<String, ProbeStatus>> {
  @override
  Map<String, ProbeStatus> build() => const <String, ProbeStatus>{};

  void setStatus(String id, ProbeStatus status) {
    state = {...state, id: status};
  }

  void clear() => state = const {};
}

final probeStatusProvider =
    NotifierProvider<ProbeStatusNotifier, Map<String, ProbeStatus>>(
  ProbeStatusNotifier.new,
);

/// 启动探测结果。StartupGate 写入；首屏读取后置回 idle 避免重复弹。
class ProbeOutcomeNotifier extends Notifier<ProbeOutcome> {
  @override
  ProbeOutcome build() => ProbeOutcome.idle;

  void set(ProbeOutcome v) => state = v;
}

final probeOutcomeProvider =
    NotifierProvider<ProbeOutcomeNotifier, ProbeOutcome>(
  ProbeOutcomeNotifier.new,
);

/// 切换到指定服务器（统一入口）：
/// 存档当前 session → 切换 baseUrl → 恢复目标 session → 判断登录态
Future<void> applyServerSelection(WidgetRef ref, ServerEntry entry) async {
  final currentUrl = ref.read(baseUrlProvider);
  if (currentUrl == entry.url) return;

  final storage = SecureStorageService();
  // 1. 存档当前 session
  await storage.saveWallet(SecureStorageService.walletKey(currentUrl));
  // 2. 切换 baseUrl（触发 dioProvider 重建）
  ref.read(baseUrlProvider.notifier).set(entry.url);
  // 3. 恢复目标 session
  final restored = await storage.restoreWallet(SecureStorageService.walletKey(entry.url));
  if (restored && !await storage.isAccessTokenExpired()) {
    debugPrint('[Servers] 恢复 ${entry.displayName} 的登录态');
    ref.read(authStateProvider.notifier).setAuthenticated();
  } else {
    await storage.clearTokens();
    ref.read(authStateProvider.notifier).setUnauthenticated();
  }
}
