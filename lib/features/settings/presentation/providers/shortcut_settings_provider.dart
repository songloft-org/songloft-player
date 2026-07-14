import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../domain/key_binding.dart';
import '../../domain/player_shortcut_action.dart';

/// 快捷键设置状态：总开关 + 每个动作的按键绑定。
///
/// 绑定表中缺失某动作即表示该动作「未设置」（已被用户解绑）。
@immutable
class ShortcutSettings {
  final bool enabled;
  final Map<PlayerShortcutAction, KeyBinding> bindings;

  const ShortcutSettings({required this.enabled, required this.bindings});

  ShortcutSettings copyWith({
    bool? enabled,
    Map<PlayerShortcutAction, KeyBinding>? bindings,
  }) {
    return ShortcutSettings(
      enabled: enabled ?? this.enabled,
      bindings: bindings ?? this.bindings,
    );
  }

  /// 查找与 [binding] 冲突的其它动作（排除 [exclude] 自身）。null 表示无冲突。
  PlayerShortcutAction? conflictOf(
    KeyBinding binding,
    PlayerShortcutAction exclude,
  ) {
    for (final entry in bindings.entries) {
      if (entry.key == exclude) continue;
      if (entry.value == binding) return entry.key;
    }
    return null;
  }
}

/// 纯本地偏好 Notifier（不同步后端）。build 同步返回平台默认，随后异步回读校正。
class ShortcutSettingsNotifier extends Notifier<ShortcutSettings> {
  @override
  ShortcutSettings build() {
    _load();
    return ShortcutSettings(
      enabled: true,
      bindings: defaultBindings(defaultTargetPlatform),
    );
  }

  Future<void> _load() async {
    try {
      final prefs = await ref.read(appPreferencesProvider.future);
      final enabled = prefs.getShortcutsEnabled();
      final raw = prefs.getShortcutBindings();
      state = ShortcutSettings(
        enabled: enabled,
        bindings: _parseBindings(raw),
      );
    } catch (e) {
      debugPrint('[Shortcuts] 加载快捷键偏好失败: $e');
    }
  }

  /// 解析持久化 JSON；未自定义（null）时返回平台默认。缺失动作**不**补默认
  /// （用户可能有意解绑），但只有 null（从未保存过）才整体回落默认。
  Map<PlayerShortcutAction, KeyBinding> _parseBindings(String? raw) {
    final defaults = defaultBindings(defaultTargetPlatform);
    if (raw == null || raw.isEmpty) return defaults;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return defaults;
      final result = <PlayerShortcutAction, KeyBinding>{};
      for (final action in PlayerShortcutAction.values) {
        if (!decoded.containsKey(action.name)) continue;
        final binding = KeyBinding.fromJson(decoded[action.name]);
        if (binding != null) result[action] = binding;
      }
      return result;
    } catch (e) {
      debugPrint('[Shortcuts] 解析绑定表失败: $e');
      return defaults;
    }
  }

  Future<void> _persist(Map<PlayerShortcutAction, KeyBinding> bindings) async {
    try {
      final prefs = await ref.read(appPreferencesProvider.future);
      final map = <String, dynamic>{
        for (final e in bindings.entries) e.key.name: e.value.toJson(),
      };
      await prefs.setShortcutBindings(jsonEncode(map));
    } catch (e) {
      debugPrint('[Shortcuts] 持久化绑定表失败: $e');
    }
  }

  Future<void> setEnabled(bool value) async {
    state = state.copyWith(enabled: value);
    try {
      final prefs = await ref.read(appPreferencesProvider.future);
      await prefs.setShortcutsEnabled(value);
    } catch (e) {
      debugPrint('[Shortcuts] 保存总开关失败: $e');
    }
  }

  /// 绑定/改绑某动作。冲突处置由 UI 决定（先 clearBinding 冲突动作再调本方法）。
  Future<void> setBinding(
    PlayerShortcutAction action,
    KeyBinding binding,
  ) async {
    final next = Map<PlayerShortcutAction, KeyBinding>.from(state.bindings)
      ..[action] = binding;
    state = state.copyWith(bindings: next);
    await _persist(next);
  }

  /// 解绑某动作（该动作后续无快捷键）。
  Future<void> clearBinding(PlayerShortcutAction action) async {
    final next = Map<PlayerShortcutAction, KeyBinding>.from(state.bindings)
      ..remove(action);
    state = state.copyWith(bindings: next);
    await _persist(next);
  }

  /// 将某动作恢复为平台默认键位。
  Future<void> resetBinding(PlayerShortcutAction action) async {
    final def = defaultBindings(defaultTargetPlatform)[action];
    if (def == null) {
      await clearBinding(action);
      return;
    }
    await setBinding(action, def);
  }

  /// 恢复全部动作为平台默认。
  Future<void> resetAll() async {
    final defaults = defaultBindings(defaultTargetPlatform);
    state = state.copyWith(bindings: defaults);
    await _persist(defaults);
  }
}

final shortcutSettingsProvider =
    NotifierProvider<ShortcutSettingsNotifier, ShortcutSettings>(
  ShortcutSettingsNotifier.new,
);

/// 纯函数：给定当前按下的主键与四个修饰键状态，在绑定表中找到匹配的动作。
///
/// 修饰键**精确匹配**（防止多余修饰键误触；裸键要求四修饰键全 false）。
/// 抽成顶层函数便于单测，不依赖 widget / HardwareKeyboard。
PlayerShortcutAction? matchShortcutAction(
  Map<PlayerShortcutAction, KeyBinding> bindings, {
  required int keyId,
  required bool ctrl,
  required bool alt,
  required bool shift,
  required bool meta,
}) {
  for (final entry in bindings.entries) {
    final b = entry.value;
    if (b.keyId == keyId &&
        b.ctrl == ctrl &&
        b.alt == alt &&
        b.shift == shift &&
        b.meta == meta) {
      return entry.key;
    }
  }
  return null;
}
