import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songloft_flutter/core/storage/app_preferences.dart';
import 'package:songloft_flutter/features/auth/presentation/providers/auth_provider.dart';
import 'package:songloft_flutter/features/settings/domain/key_binding.dart';
import 'package:songloft_flutter/features/settings/domain/player_shortcut_action.dart';
import 'package:songloft_flutter/features/settings/presentation/providers/shortcut_settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  Future<void> pump() async {
    // 触发 build（进而启动 fire-and-forget 的 _load），再等 prefs future +
    // 事件循环，确保 _load 已把回读结果写回 state 后再做后续断言/变更。
    container.read(shortcutSettingsProvider);
    await container.read(appPreferencesProvider.future);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await AppPreferences.create();
    container = ProviderContainer(
      overrides: [
        appPreferencesProvider.overrideWith((ref) async => prefs),
      ],
    );
  });

  tearDown(() => container.dispose());

  test('初始返回平台默认且启用', () async {
    final s = container.read(shortcutSettingsProvider);
    expect(s.enabled, isTrue);
    expect(s.bindings.isNotEmpty, isTrue);
  });

  test('setBinding 持久化并可回读', () async {
    await pump();
    const custom = KeyBinding(keyId: 999, ctrl: true);
    await container
        .read(shortcutSettingsProvider.notifier)
        .setBinding(PlayerShortcutAction.playPause, custom);

    // 新容器（同一 prefs）应回读到自定义值
    final container2 = ProviderContainer(
      overrides: [
        appPreferencesProvider.overrideWith(
          (ref) async => AppPreferences(await SharedPreferences.getInstance()),
        ),
      ],
    );
    addTearDown(container2.dispose);
    container2.read(shortcutSettingsProvider); // 触发 build/_load
    await container2.read(appPreferencesProvider.future);
    await Future<void>.delayed(Duration.zero);
    expect(
      container2.read(shortcutSettingsProvider).bindings[
          PlayerShortcutAction.playPause],
      custom,
    );
  });

  test('clearBinding 后该动作未设置', () async {
    await pump();
    await container
        .read(shortcutSettingsProvider.notifier)
        .clearBinding(PlayerShortcutAction.toggleMute);
    expect(
      container
          .read(shortcutSettingsProvider)
          .bindings
          .containsKey(PlayerShortcutAction.toggleMute),
      isFalse,
    );
  });

  test('conflictOf 命中其它动作并排除自身', () async {
    await pump();
    final s = container.read(shortcutSettingsProvider);
    final playPause = s.bindings[PlayerShortcutAction.playPause]!;
    // 与 playPause 相同的键，从 playNext 视角看应冲突到 playPause
    expect(
      s.conflictOf(playPause, PlayerShortcutAction.playNext),
      PlayerShortcutAction.playPause,
    );
    // 从自身视角排除
    expect(s.conflictOf(playPause, PlayerShortcutAction.playPause), isNull);
  });

  test('resetAll 恢复默认', () async {
    await pump();
    await container
        .read(shortcutSettingsProvider.notifier)
        .clearBinding(PlayerShortcutAction.playPause);
    await container.read(shortcutSettingsProvider.notifier).resetAll();
    expect(
      container
          .read(shortcutSettingsProvider)
          .bindings
          .containsKey(PlayerShortcutAction.playPause),
      isTrue,
    );
  });

  test('setEnabled 持久化', () async {
    await pump();
    await container.read(shortcutSettingsProvider.notifier).setEnabled(false);
    expect(container.read(shortcutSettingsProvider).enabled, isFalse);
  });

  group('matchShortcutAction', () {
    final bindings = {
      PlayerShortcutAction.playPause:
          KeyBinding(keyId: LogicalKeyboardKey.space.keyId),
      PlayerShortcutAction.playNext: KeyBinding(
        keyId: LogicalKeyboardKey.arrowRight.keyId,
        ctrl: true,
      ),
    };

    test('精确匹配裸键', () {
      expect(
        matchShortcutAction(
          bindings,
          keyId: LogicalKeyboardKey.space.keyId,
          ctrl: false,
          alt: false,
          shift: false,
          meta: false,
        ),
        PlayerShortcutAction.playPause,
      );
    });

    test('多余修饰键不误触', () {
      expect(
        matchShortcutAction(
          bindings,
          keyId: LogicalKeyboardKey.arrowRight.keyId,
          ctrl: true,
          alt: false,
          shift: true, // 多按了 shift
          meta: false,
        ),
        isNull,
      );
    });

    test('修饰键组合命中', () {
      expect(
        matchShortcutAction(
          bindings,
          keyId: LogicalKeyboardKey.arrowRight.keyId,
          ctrl: true,
          alt: false,
          shift: false,
          meta: false,
        ),
        PlayerShortcutAction.playNext,
      );
    });
  });
}
