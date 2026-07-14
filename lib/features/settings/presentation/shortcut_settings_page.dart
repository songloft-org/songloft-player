import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../domain/player_shortcut_action.dart';
import 'providers/shortcut_settings_provider.dart';
import 'widgets/section_card.dart';
import 'widgets/shortcut_recorder.dart';

/// 键盘快捷键设置页（仅桌面从设置进入）。
class ShortcutSettingsPage extends ConsumerWidget {
  const ShortcutSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(shortcutSettingsProvider);
    final notifier = ref.read(shortcutSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsShortcutsPageTitle),
        actions: [
          TextButton(
            onPressed: () async {
              final ok = await ConfirmDialog.show(
                context,
                title: l10n.settingsShortcutResetAll,
                content: l10n.settingsShortcutResetAllConfirm,
              );
              if (ok) await notifier.resetAll();
            },
            child: Text(l10n.settingsShortcutResetAll),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          SectionCard(
            title: l10n.settingsShortcutsPageTitle,
            icon: Icons.keyboard_outlined,
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.power_settings_new_outlined),
                title: Text(l10n.settingsShortcutsEnableTitle),
                subtitle: Text(l10n.settingsShortcutsEnableSubtitle),
                value: settings.enabled,
                onChanged: notifier.setEnabled,
              ),
              const Divider(height: 1),
              for (final action in PlayerShortcutAction.values) ...[
                ShortcutRecorderTile(action: action),
                if (action != PlayerShortcutAction.values.last)
                  const Divider(height: 1),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
