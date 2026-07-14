import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../settings/domain/key_binding.dart';
import '../../../settings/domain/player_shortcut_action.dart';
import '../../../settings/presentation/providers/shortcut_settings_provider.dart';
import '../providers/player_provider.dart';

/// 桌面端全局播放快捷键监听层。
///
/// 用一个高层 [Focus] 拦截按键：位于 `WidgetsApp` 的默认 [Shortcuts] 之下，
/// 因此裸 Space 等能先于 Flutter 默认的按钮激活/焦点遍历触发。仅桌面挂载
/// （由 ShellLayout 用 `PlatformUtils.isDesktop` 守卫），移动/Web/TV 不包裹本层。
///
/// 焦点在文本输入（[EditableText]）上时豁免，不拦截打字。
class PlayerShortcutScope extends ConsumerWidget {
  final Widget child;

  const PlayerShortcutScope({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Focus(
      // 不抢占焦点，仅作为按键冒泡链上的旁路监听
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) => _handle(ref, event),
      child: child,
    );
  }

  KeyEventResult _handle(WidgetRef ref, KeyEvent event) {
    final settings = ref.read(shortcutSettingsProvider);
    if (!settings.enabled) return KeyEventResult.ignored;

    final isDown = event is KeyDownEvent;
    final isRepeat = event is KeyRepeatEvent;
    if (!isDown && !isRepeat) return KeyEventResult.ignored;

    // 纯修饰键抖动（单按 Ctrl/Shift 等）跳过
    if (KeyBinding.isModifierKey(event.logicalKey)) {
      return KeyEventResult.ignored;
    }

    // 输入框豁免：焦点在文本输入时让行
    if (_isTextInputFocused()) return KeyEventResult.ignored;

    final kb = HardwareKeyboard.instance;
    final action = matchShortcutAction(
      settings.bindings,
      keyId: event.logicalKey.keyId,
      ctrl: kb.isControlPressed,
      alt: kb.isAltPressed,
      shift: kb.isShiftPressed,
      meta: kb.isMetaPressed,
    );
    if (action == null) return KeyEventResult.ignored;

    // 长按仅对连续型动作（seek/音量）放行；其余 repeat 吞掉，防疯狂重触
    if (isRepeat && !kRepeatableShortcutActions.contains(action)) {
      return KeyEventResult.handled;
    }

    _dispatch(ref, action);
    return KeyEventResult.handled;
  }

  void _dispatch(WidgetRef ref, PlayerShortcutAction action) {
    final notifier = ref.read(playerStateProvider.notifier);
    switch (action) {
      case PlayerShortcutAction.playPause:
        notifier.togglePlay();
      case PlayerShortcutAction.playNext:
        notifier.playNext();
      case PlayerShortcutAction.playPrev:
        notifier.playPrev();
      case PlayerShortcutAction.seekForward:
        notifier.seekBy(const Duration(seconds: kSeekStepSeconds));
      case PlayerShortcutAction.seekBackward:
        notifier.seekBy(const Duration(seconds: -kSeekStepSeconds));
      case PlayerShortcutAction.volumeUp:
        final v = ref.read(playerStateProvider).volume;
        notifier.setVolume(v + kVolumeStep);
      case PlayerShortcutAction.volumeDown:
        final v = ref.read(playerStateProvider).volume;
        notifier.setVolume(v - kVolumeStep);
      case PlayerShortcutAction.toggleMute:
        notifier.toggleMute();
    }
  }

  bool _isTextInputFocused() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    if (ctx.widget is EditableText) return true;
    return ctx.findAncestorStateOfType<EditableTextState>() != null;
  }
}
