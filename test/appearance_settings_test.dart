import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songloft_flutter/core/router/app_router.dart';
import 'package:songloft_flutter/core/theme/widgets/glass_surface.dart';
import 'package:songloft_flutter/features/auth/presentation/providers/auth_provider.dart';
import 'package:songloft_flutter/features/home/presentation/render/plugin_color_scheme.dart';
import 'package:songloft_flutter/features/settings/data/theme_pack_api.dart';
import 'package:songloft_flutter/features/settings/presentation/providers/appearance_preferences_provider.dart';
import 'package:songloft_flutter/features/settings/presentation/providers/theme_pack_provider.dart';
import 'package:songloft_flutter/features/settings/presentation/widgets/appearance_accessibility_settings.dart';
import 'package:songloft_flutter/main.dart';

class _NoThemePack extends ActiveThemePackNotifier {
  @override
  Future<ThemePack?> build() async => null;
}

void main() {
  for (final width in [375.0, 1200.0]) {
    testWidgets(
      'actual app/settings preserve system OR and live plugin appearance ($width)',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'auto_update_check_enabled': false,
        });
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        Map<String, Object>? message;
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder:
                  (context, state) => Builder(
                    builder: (context) {
                      message = pluginThemeAppearanceMap(Theme.of(context));
                      return const Scaffold(
                        body: Column(
                          children: [
                            AppearanceAccessibilitySettings(),
                            GlassSurface(child: Text('Policy probe')),
                          ],
                        ),
                      );
                    },
                  ),
            ),
          ],
        );
        addTearDown(router.dispose);
        final container = ProviderContainer(
          overrides: [
            routerProvider.overrideWithValue(router),
            activeThemePackProvider.overrideWith(_NoThemePack.new),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const SongloftApp(),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(BackdropFilter), findsOneWidget);
        await tester.tap(find.byType(SwitchListTile).first);
        await tester.pumpAndSettle();
        expect(message!['reduceTransparency'], isTrue);
        expect(find.byType(BackdropFilter), findsNothing);
        expect(
          container
              .read(appPreferencesProvider)
              .requireValue
              .getReduceTransparency(),
          isTrue,
        );
        await tester.tap(find.byType(SwitchListTile).first);
        await tester.pumpAndSettle();
        expect(find.byType(BackdropFilter), findsOneWidget);
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(highContrast: true);
        await tester.pumpAndSettle();
        expect(message!['increaseContrast'], isTrue);
        expect(
          container
              .read(appearancePreferencesProvider)
              .requireValue
              .increaseContrast,
          isFalse,
        );
        expect(find.byType(BackdropFilter), findsNothing);
        await tester.tap(find.byType(SwitchListTile).last);
        await tester.pumpAndSettle();
        await tester.tap(find.byType(SwitchListTile).last);
        await tester.pumpAndSettle();
        expect(
          message!['increaseContrast'],
          isTrue,
          reason: 'manual off cannot disable system preference',
        );
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures();
        await tester.pumpAndSettle();
        expect(message!['increaseContrast'], isFalse);
        expect(find.byType(BackdropFilter), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
