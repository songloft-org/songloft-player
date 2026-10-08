import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';

@immutable
class AppearancePreferences {
  final bool reduceTransparency;
  final bool increaseContrast;

  const AppearancePreferences({
    this.reduceTransparency = false,
    this.increaseContrast = false,
  });

  AppearancePreferences copyWith({
    bool? reduceTransparency,
    bool? increaseContrast,
  }) => AppearancePreferences(
    reduceTransparency: reduceTransparency ?? this.reduceTransparency,
    increaseContrast: increaseContrast ?? this.increaseContrast,
  );
}

/// Device-local preferences, independent of account/server synchronization.
class AppearancePreferencesNotifier
    extends AsyncNotifier<AppearancePreferences> {
  Future<void> _writes = Future<void>.value();

  @override
  Future<AppearancePreferences> build() async {
    try {
      final prefs = await ref.read(appPreferencesProvider.future);
      return AppearancePreferences(
        reduceTransparency: prefs.getReduceTransparency(),
        increaseContrast: prefs.getIncreaseContrast(),
      );
    } catch (_) {
      return const AppearancePreferences();
    }
  }

  Future<void> setReduceTransparency(bool enabled) =>
      _set(reduceTransparency: enabled);
  Future<void> setIncreaseContrast(bool enabled) =>
      _set(increaseContrast: enabled);

  Future<void> _set({bool? reduceTransparency, bool? increaseContrast}) async {
    if (state.value == null) await future;
    if (!ref.mounted) return;
    final next = state.value!.copyWith(
      reduceTransparency: reduceTransparency,
      increaseContrast: increaseContrast,
    );
    state = AsyncData(next);
    final preferences = ref.read(appPreferencesProvider.future);
    // Serialize snapshots so rapid toggles cannot write an older choice last.
    _writes = _writes.then((_) async {
      try {
        final prefs = await preferences;
        await prefs.setReduceTransparency(next.reduceTransparency);
        await prefs.setIncreaseContrast(next.increaseContrast);
      } catch (error) {
        debugPrint('[Appearance] Failed to save device preferences: $error');
      }
    });
    await _writes;
  }
}

final appearancePreferencesProvider =
    AsyncNotifierProvider<AppearancePreferencesNotifier, AppearancePreferences>(
      AppearancePreferencesNotifier.new,
    );
