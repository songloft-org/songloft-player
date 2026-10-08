import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songloft_flutter/core/storage/app_preferences.dart';
import 'package:songloft_flutter/features/auth/presentation/providers/auth_provider.dart';
import 'package:songloft_flutter/features/settings/presentation/providers/appearance_preferences_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults off and restores both preferences in a new session', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final initial = await container.read(appearancePreferencesProvider.future);
    expect(initial.reduceTransparency, isFalse);
    expect(initial.increaseContrast, isFalse);
    final notifier = container.read(appearancePreferencesProvider.notifier);
    await notifier.setReduceTransparency(true);
    await notifier.setIncreaseContrast(true);
    final restored = ProviderContainer();
    addTearDown(restored.dispose);
    final value = await restored.read(appearancePreferencesProvider.future);
    expect(value.reduceTransparency, isTrue);
    expect(value.increaseContrast, isTrue);
  });

  test(
    'pending initialization and rapid toggles preserve the final values of both fields',
    () async {
      final pending = Completer<AppPreferences>();
      final container = ProviderContainer(
        overrides: [
          appPreferencesProvider.overrideWith((ref) => pending.future),
        ],
      );
      addTearDown(container.dispose);
      container.read(appearancePreferencesProvider);
      final notifier = container.read(appearancePreferencesProvider.notifier);
      final writes = [
        notifier.setReduceTransparency(true),
        notifier.setIncreaseContrast(true),
        notifier.setReduceTransparency(false),
      ];
      pending.complete(await AppPreferences.create());
      await Future.wait(writes);
      final value = container.read(appearancePreferencesProvider).requireValue;
      final saved = await AppPreferences.create();
      expect(value.reduceTransparency, isFalse);
      expect(value.increaseContrast, isTrue);
      expect(saved.getReduceTransparency(), isFalse);
      expect(saved.getIncreaseContrast(), isTrue);
    },
  );

  test(
    'storage failure keeps defaults and allows session-local choices',
    () async {
      final container = ProviderContainer(
        overrides: [
          appPreferencesProvider.overrideWith(
            (ref) => throw StateError('unavailable'),
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(
        (await container.read(
          appearancePreferencesProvider.future,
        )).reduceTransparency,
        isFalse,
      );
      await container
          .read(appearancePreferencesProvider.notifier)
          .setIncreaseContrast(true);
      expect(
        container
            .read(appearancePreferencesProvider)
            .requireValue
            .increaseContrast,
        isTrue,
      );
    },
  );

  test(
    'disposing while preferences load does not publish late state',
    () async {
      final pending = Completer<AppPreferences>();
      final container = ProviderContainer(
        overrides: [
          appPreferencesProvider.overrideWith((ref) => pending.future),
        ],
      );
      container.read(appearancePreferencesProvider);
      container.dispose();
      pending.complete(await AppPreferences.create());
      await Future<void>.delayed(Duration.zero);
    },
  );
}
