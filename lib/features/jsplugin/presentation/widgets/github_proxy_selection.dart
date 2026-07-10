import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../settings/presentation/providers/settings_provider.dart';

/// GitHub 代理选择器的持久化混入。
///
/// 插件商店、插件更新等处的 GitHub 代理选择器共用此逻辑：打开时从持久化的
/// [githubProxyProvider]（业务端点 GET/PUT /api/v1/settings/github-proxy）恢复上次
/// 选择，发起请求时写回，实现「记住上次使用的代理」。这样插件相关的 GitHub 镜像
/// 前缀与 App 自身升级共用同一份设置。
///
/// 使用方需：
/// - 实现 [proxyPresetValues]（与页面渲染的预设列表顺序一致的代理值）；
/// - 在 initState 中调用 [restoreGithubProxy]（商店页可 await 以保证首次刷新用到
///   恢复后的代理）；
/// - 在实际发起请求时调用 [persistGithubProxy]。
mixin GithubProxySelectionMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  /// 当前选中的预设索引，-1 表示自定义
  int selectedProxyIndex = 0;
  final TextEditingController customProxyController = TextEditingController();

  /// 预设代理值列表，顺序需与页面渲染的预设列表一致。
  List<String> get proxyPresetValues;

  /// 当前生效的代理前缀，空串表示直连。
  String get effectiveProxy {
    if (selectedProxyIndex == -1) {
      return customProxyController.text.trim();
    }
    if (selectedProxyIndex >= 0 &&
        selectedProxyIndex < proxyPresetValues.length) {
      return proxyPresetValues[selectedProxyIndex];
    }
    return '';
  }

  /// 从持久化配置恢复上次选择。需在 initState 中调用。
  Future<void> restoreGithubProxy() async {
    try {
      final value = await ref.read(githubProxyProvider.future);
      if (!mounted) return;
      setState(() => _applyProxyValue(value));
    } catch (_) {
      // 读取失败保持默认（直连）即可，不影响使用。
    }
  }

  void _applyProxyValue(String value) {
    final idx = proxyPresetValues.indexOf(value);
    if (idx >= 0) {
      selectedProxyIndex = idx;
      customProxyController.text = '';
    } else if (value.isNotEmpty) {
      selectedProxyIndex = -1;
      customProxyController.text = value;
    } else {
      selectedProxyIndex = 0;
      customProxyController.text = '';
    }
  }

  /// 将当前选择持久化到 [githubProxyProvider]。在实际发起请求时调用。
  void persistGithubProxy() {
    ref.read(githubProxyProvider.notifier).setValue(effectiveProxy);
  }

  @override
  void dispose() {
    customProxyController.dispose();
    super.dispose();
  }
}
