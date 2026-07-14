import 'package:flutter/foundation.dart' show TargetPlatform, immutable;
import 'package:flutter/services.dart';

import 'player_shortcut_action.dart';

/// seek 快进/快退步进（秒）。与 tv_player.dart 的进度条步进保持一致。
const int kSeekStepSeconds = 5;

/// 音量增减步进（0-100 刻度）。与 tv_player.dart 音量按钮的 ±10 一致。
const double kVolumeStep = 10;

/// 一个可序列化的按键组合：主键 + 四个修饰键状态。
///
/// [keyId] 使用 [LogicalKeyboardKey.keyId]（稳定整型，跨 Flutter 版本安全，
/// 优于随键盘布局变化的 keyLabel）。修饰键用 [HardwareKeyboard] 的合并态
/// （不区分左右侧）。
@immutable
class KeyBinding {
  final int keyId;
  final bool ctrl;
  final bool alt;
  final bool shift;
  final bool meta;

  const KeyBinding({
    required this.keyId,
    this.ctrl = false,
    this.alt = false,
    this.shift = false,
    this.meta = false,
  });

  LogicalKeyboardKey get logicalKey => LogicalKeyboardKey(keyId);

  Map<String, dynamic> toJson() => {
    'keyId': keyId,
    if (ctrl) 'ctrl': true,
    if (alt) 'alt': true,
    if (shift) 'shift': true,
    if (meta) 'meta': true,
  };

  /// 宽松解析：非法/缺字段返回 null，由调用方补默认。
  static KeyBinding? fromJson(Object? json) {
    if (json is! Map) return null;
    final keyId = json['keyId'];
    if (keyId is! int) return null;
    return KeyBinding(
      keyId: keyId,
      ctrl: json['ctrl'] == true,
      alt: json['alt'] == true,
      shift: json['shift'] == true,
      meta: json['meta'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is KeyBinding &&
      other.keyId == keyId &&
      other.ctrl == ctrl &&
      other.alt == alt &&
      other.shift == shift &&
      other.meta == meta;

  @override
  int get hashCode => Object.hash(keyId, ctrl, alt, shift, meta);

  /// 是否为纯修饰键（单独的 Ctrl/Alt/Shift/Meta），录制与匹配时应跳过。
  static bool isModifierKey(LogicalKeyboardKey key) =>
      _modifierKeyIds.contains(key.keyId);

  static final _modifierKeyIds = <int>{
    LogicalKeyboardKey.control.keyId,
    LogicalKeyboardKey.controlLeft.keyId,
    LogicalKeyboardKey.controlRight.keyId,
    LogicalKeyboardKey.alt.keyId,
    LogicalKeyboardKey.altLeft.keyId,
    LogicalKeyboardKey.altRight.keyId,
    LogicalKeyboardKey.shift.keyId,
    LogicalKeyboardKey.shiftLeft.keyId,
    LogicalKeyboardKey.shiftRight.keyId,
    LogicalKeyboardKey.meta.keyId,
    LogicalKeyboardKey.metaLeft.keyId,
    LogicalKeyboardKey.metaRight.keyId,
  };
}

/// 平台默认键位表。macOS 主修饰键用 Meta(⌘)，其余平台用 Ctrl。
///
/// [platform] 传 [TargetPlatform]（由调用方用 `defaultTargetPlatform` 提供，
/// web 安全）。只有 playPause 用裸键（Space），靠输入框豁免规避打字冲突；
/// 其余全部带修饰键，避开裸方向键/裸字母与浏览器保留组合。
Map<PlayerShortcutAction, KeyBinding> defaultBindings(TargetPlatform platform) {
  final isMac = platform == TargetPlatform.macOS;
  // 主修饰键：macOS = Cmd(meta)，其余 = Ctrl
  KeyBinding primary(int keyId) =>
      isMac ? KeyBinding(keyId: keyId, meta: true) : KeyBinding(keyId: keyId, ctrl: true);
  KeyBinding withShift(int keyId) => KeyBinding(keyId: keyId, shift: true);

  return {
    PlayerShortcutAction.playPause: KeyBinding(
      keyId: LogicalKeyboardKey.space.keyId,
    ),
    PlayerShortcutAction.playPrev: primary(LogicalKeyboardKey.arrowLeft.keyId),
    PlayerShortcutAction.playNext: primary(LogicalKeyboardKey.arrowRight.keyId),
    PlayerShortcutAction.seekBackward: withShift(
      LogicalKeyboardKey.arrowLeft.keyId,
    ),
    PlayerShortcutAction.seekForward: withShift(
      LogicalKeyboardKey.arrowRight.keyId,
    ),
    PlayerShortcutAction.volumeDown: withShift(
      LogicalKeyboardKey.arrowDown.keyId,
    ),
    PlayerShortcutAction.volumeUp: withShift(LogicalKeyboardKey.arrowUp.keyId),
    // 静音统一 Ctrl+M：避开 macOS Cmd+M（系统最小化窗口）
    PlayerShortcutAction.toggleMute: KeyBinding(
      keyId: LogicalKeyboardKey.keyM.keyId,
      ctrl: true,
    ),
  };
}

/// 将绑定格式化为人类可读文本，如 `Ctrl + →`、`⇧ + Space`。
/// 修饰键顺序：Ctrl/Cmd → Alt/Option → Shift → 主键。
String formatKeyBinding(KeyBinding b, {bool useMacSymbols = false}) {
  final parts = <String>[];
  if (b.ctrl) parts.add(useMacSymbols ? '⌃' : 'Ctrl');
  if (b.meta) parts.add(useMacSymbols ? '⌘' : 'Meta');
  if (b.alt) parts.add(useMacSymbols ? '⌥' : 'Alt');
  if (b.shift) parts.add(useMacSymbols ? '⇧' : 'Shift');
  parts.add(_keyLabel(b.logicalKey));
  return parts.join(useMacSymbols ? ' ' : ' + ');
}

String _keyLabel(LogicalKeyboardKey key) {
  final special = _specialLabels[key.keyId];
  if (special != null) return special;
  final label = key.keyLabel;
  if (label.isNotEmpty) return label.toUpperCase();
  // 兜底：debug 名（如 "Media Play Pause"）
  return key.debugName ?? 'Key ${key.keyId}';
}

final _specialLabels = <int, String>{
  LogicalKeyboardKey.arrowLeft.keyId: '←',
  LogicalKeyboardKey.arrowRight.keyId: '→',
  LogicalKeyboardKey.arrowUp.keyId: '↑',
  LogicalKeyboardKey.arrowDown.keyId: '↓',
  LogicalKeyboardKey.space.keyId: 'Space',
  LogicalKeyboardKey.enter.keyId: 'Enter',
  LogicalKeyboardKey.escape.keyId: 'Esc',
  LogicalKeyboardKey.tab.keyId: 'Tab',
  LogicalKeyboardKey.backspace.keyId: 'Backspace',
  LogicalKeyboardKey.delete.keyId: 'Delete',
  LogicalKeyboardKey.home.keyId: 'Home',
  LogicalKeyboardKey.end.keyId: 'End',
  LogicalKeyboardKey.pageUp.keyId: 'PageUp',
  LogicalKeyboardKey.pageDown.keyId: 'PageDown',
};
