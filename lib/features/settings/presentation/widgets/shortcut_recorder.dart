import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/key_binding.dart';
import '../../domain/player_shortcut_action.dart';
import '../providers/shortcut_settings_provider.dart';

/// 单个动作的快捷键录制行：显示当前绑定，点击弹出录制对话框，可清除。
class ShortcutRecorderTile extends ConsumerWidget {
  final PlayerShortcutAction action;

  const ShortcutRecorderTile({super.key, required this.action});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final binding = ref.watch(
      shortcutSettingsProvider.select((s) => s.bindings[action]),
    );
    final theme = Theme.of(context);

    return ListTile(
      title: Text(shortcutActionLabel(l10n, action)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BindingChip(binding: binding, unsetLabel: l10n.settingsShortcutUnset),
          if (binding != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: l10n.settingsShortcutClear,
              onPressed: () =>
                  ref.read(shortcutSettingsProvider.notifier).clearBinding(action),
            ),
          Icon(Icons.edit_outlined, size: 18, color: theme.hintColor),
        ],
      ),
      onTap: () => _record(context, ref),
    );
  }

  Future<void> _record(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final captured = await showDialog<KeyBinding>(
      context: context,
      builder: (_) => _RecordDialog(action: action),
    );
    if (captured == null) return;

    final notifier = ref.read(shortcutSettingsProvider.notifier);
    final conflict = ref
        .read(shortcutSettingsProvider)
        .conflictOf(captured, action);

    if (conflict != null && context.mounted) {
      final override = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.settingsShortcutConflictTitle),
          content: Text(
            l10n.settingsShortcutConflict(shortcutActionLabel(l10n, conflict)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.settingsShortcutOverride),
            ),
          ],
        ),
      );
      if (override != true) return;
      await notifier.clearBinding(conflict);
    }

    await notifier.setBinding(action, captured);
  }
}

class _BindingChip extends StatelessWidget {
  final KeyBinding? binding;
  final String unsetLabel;

  const _BindingChip({required this.binding, required this.unsetLabel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = binding;
    if (b == null) {
      return Text(
        unsetLabel,
        style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        formatKeyBinding(b),
        style: theme.textTheme.labelLarge,
      ),
    );
  }
}

/// 录制对话框：捕获用户按下的一个「主键 + 修饰键」组合，pop 返回 [KeyBinding]。
/// Esc 取消（返回 null）。纯修饰键抖动被忽略，等待真正的主键。
class _RecordDialog extends StatefulWidget {
  final PlayerShortcutAction action;

  const _RecordDialog({required this.action});

  @override
  State<_RecordDialog> createState() => _RecordDialogState();
}

class _RecordDialogState extends State<_RecordDialog> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.handled;

    // Esc 取消
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    // 等待真正的主键，忽略纯修饰键
    if (KeyBinding.isModifierKey(event.logicalKey)) {
      return KeyEventResult.handled;
    }

    final kb = HardwareKeyboard.instance;
    final binding = KeyBinding(
      keyId: event.logicalKey.keyId,
      ctrl: kb.isControlPressed,
      alt: kb.isAltPressed,
      shift: kb.isShiftPressed,
      meta: kb.isMetaPressed,
    );
    Navigator.of(context).pop(binding);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(shortcutActionLabel(l10n, widget.action)),
      content: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.keyboard, size: 40, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                l10n.settingsShortcutRecordPrompt,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
      ],
    );
  }
}

/// 动作的 i18n 标签。
String shortcutActionLabel(AppLocalizations l10n, PlayerShortcutAction action) {
  switch (action) {
    case PlayerShortcutAction.playPause:
      return l10n.settingsShortcutActionPlayPause;
    case PlayerShortcutAction.playNext:
      return l10n.settingsShortcutActionPlayNext;
    case PlayerShortcutAction.playPrev:
      return l10n.settingsShortcutActionPlayPrev;
    case PlayerShortcutAction.seekForward:
      return l10n.settingsShortcutActionSeekForward;
    case PlayerShortcutAction.seekBackward:
      return l10n.settingsShortcutActionSeekBackward;
    case PlayerShortcutAction.volumeUp:
      return l10n.settingsShortcutActionVolumeUp;
    case PlayerShortcutAction.volumeDown:
      return l10n.settingsShortcutActionVolumeDown;
    case PlayerShortcutAction.toggleMute:
      return l10n.settingsShortcutActionToggleMute;
  }
}
