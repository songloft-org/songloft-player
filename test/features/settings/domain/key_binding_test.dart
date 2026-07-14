import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/features/settings/domain/key_binding.dart';
import 'package:songloft_flutter/features/settings/domain/player_shortcut_action.dart';

void main() {
  group('KeyBinding', () {
    test('toJson/fromJson 往返', () {
      const b = KeyBinding(keyId: 42, ctrl: true, shift: true);
      final round = KeyBinding.fromJson(b.toJson());
      expect(round, b);
    });

    test('toJson 省略 false 修饰键', () {
      const b = KeyBinding(keyId: 42, ctrl: true);
      expect(b.toJson(), {'keyId': 42, 'ctrl': true});
    });

    test('fromJson 对非法输入返回 null', () {
      expect(KeyBinding.fromJson(null), isNull);
      expect(KeyBinding.fromJson('x'), isNull);
      expect(KeyBinding.fromJson({'ctrl': true}), isNull); // 缺 keyId
    });

    test('== / hashCode 覆盖全部字段', () {
      const a = KeyBinding(keyId: 1, alt: true);
      const b = KeyBinding(keyId: 1, alt: true);
      const c = KeyBinding(keyId: 1, meta: true);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
    });

    test('isModifierKey 识别修饰键', () {
      expect(KeyBinding.isModifierKey(LogicalKeyboardKey.controlLeft), isTrue);
      expect(KeyBinding.isModifierKey(LogicalKeyboardKey.shift), isTrue);
      expect(KeyBinding.isModifierKey(LogicalKeyboardKey.space), isFalse);
    });
  });

  group('defaultBindings', () {
    test('macOS 主修饰键用 meta，其余用 ctrl', () {
      final mac = defaultBindings(TargetPlatform.macOS);
      final win = defaultBindings(TargetPlatform.windows);
      expect(mac[PlayerShortcutAction.playNext]!.meta, isTrue);
      expect(mac[PlayerShortcutAction.playNext]!.ctrl, isFalse);
      expect(win[PlayerShortcutAction.playNext]!.ctrl, isTrue);
      expect(win[PlayerShortcutAction.playNext]!.meta, isFalse);
    });

    test('playPause 为裸 Space（无修饰键）', () {
      final b = defaultBindings(TargetPlatform.linux)[
          PlayerShortcutAction.playPause]!;
      expect(b.keyId, LogicalKeyboardKey.space.keyId);
      expect(b.ctrl || b.alt || b.shift || b.meta, isFalse);
    });

    test('覆盖所有动作', () {
      final b = defaultBindings(TargetPlatform.windows);
      for (final action in PlayerShortcutAction.values) {
        expect(b.containsKey(action), isTrue, reason: '$action 缺默认键');
      }
    });

    test('默认表内无重复键位（无自冲突）', () {
      final b = defaultBindings(TargetPlatform.macOS);
      final seen = <KeyBinding>{};
      for (final binding in b.values) {
        expect(seen.add(binding), isTrue, reason: '默认键位重复: $binding');
      }
    });
  });

  group('formatKeyBinding', () {
    test('方向键与修饰键顺序', () {
      const b = KeyBinding(keyId: 0, ctrl: true); // keyId 占位
      expect(formatKeyBinding(b).startsWith('Ctrl + '), isTrue);
    });

    test('箭头映射为符号', () {
      final b = KeyBinding(keyId: LogicalKeyboardKey.arrowRight.keyId);
      expect(formatKeyBinding(b), '→');
    });
  });
}
