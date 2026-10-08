import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../providers/appearance_preferences_provider.dart';

class AppearanceAccessibilitySettings extends ConsumerWidget {
  const AppearanceAccessibilitySettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(appearancePreferencesProvider).value;
    final notifier = ref.read(appearancePreferencesProvider.notifier);
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        SwitchListTile(
          title: Text(l10n.appearanceReduceTransparency),
          subtitle: Text(l10n.appearanceReduceTransparencyDescription),
          value: value?.reduceTransparency ?? false,
          onChanged: value == null ? null : notifier.setReduceTransparency,
        ),
        SwitchListTile(
          title: Text(l10n.appearanceIncreaseContrast),
          subtitle: Text(l10n.appearanceIncreaseContrastDescription),
          value: value?.increaseContrast ?? false,
          onChanged: value == null ? null : notifier.setIncreaseContrast,
        ),
      ],
    );
  }
}
