import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/core/theme/app_theme.dart';
import 'package:songloft_flutter/core/theme/widgets/glass_surface.dart';
import 'package:songloft_flutter/features/home/presentation/render/plugin_color_scheme.dart';
import 'package:songloft_flutter/features/settings/data/theme_pack_api.dart';

double contrast(Color a, Color b) {
  final values = [a.computeLuminance(), b.computeLuminance()]..sort();
  return (values[1] + .05) / (values[0] + .05);
}

void main() {
  test(
    'opaque accessibility takes effect without a translucent transition frame',
    () {
      final normal = AppTheme.lightTheme().extension<SongloftThemeExtension>()!;
      for (final target in [
        AppTheme.lightTheme(reduceTransparency: true),
        AppTheme.lightTheme(increaseContrast: true),
      ]) {
        final material = normal.lerp(
          target.extension<SongloftThemeExtension>()!,
          .01,
        );
        expect(material.opaqueGlass, isTrue);
        expect(material.glassFill.a, 1);
        expect(material.glassHighlight.a, 0);
      }
    },
  );
  for (final dark in [false, true]) {
    ThemeData theme({
      bool reduce = false,
      bool increase = false,
      ThemePack? pack,
    }) =>
        dark
            ? AppTheme.darkTheme(
              reduceTransparency: reduce,
              increaseContrast: increase,
              themePack: pack,
            )
            : AppTheme.lightTheme(
              reduceTransparency: reduce,
              increaseContrast: increase,
              themePack: pack,
            );

    testWidgets('glass and plugin policy update and restore (dark=$dark)', (
      tester,
    ) async {
      for (final flags in [
        (false, false),
        (true, false),
        (false, true),
        (false, false),
      ]) {
        final data = theme(reduce: flags.$1, increase: flags.$2);
        final ext = data.extension<SongloftThemeExtension>()!;
        await tester.pumpWidget(
          MaterialApp(
            theme: data,
            themeAnimationDuration: Duration.zero,
            home: const GlassSurface(child: Text('Glass content')),
          ),
        );
        final opaque = flags.$1 || flags.$2;
        expect(
          find.byType(BackdropFilter),
          opaque ? findsNothing : findsOneWidget,
        );
        expect(ext.glassFill.a == 1, opaque);
        expect(ext.glassFillStrong.a == 1, opaque);
        if (opaque) expect(ext.glassHighlight.a, 0);
        final message = pluginThemeAppearanceMap(data);
        expect(message['reduceTransparency'], flags.$1);
        expect(message['increaseContrast'], flags.$2);
        if (opaque) {
          expect((message['glassFill'] as String).endsWith(', 1.000)'), isTrue);
        }
      }
    });

    test(
      'contrast protects text/icons from theme-pack surface overrides (dark=$dark)',
      () {
        final pack = ThemePack.fromJson({
          'id': 1,
          'theme_id': 'contrast-test',
          'name': 'Test',
          'version': '1',
          'schema_version': 1,
          'created_at': '',
          'updated_at': '',
          'data': {
            'light': {
              'seedColor': '#F0AAAA',
              'surfaceColor': '#000000',
              'backgroundColor': '#000000',
              'glassColor': '#CCCCCC',
            },
            'dark': {
              'seedColor': '#552255',
              'surfaceColor': '#FFFFFF',
              'backgroundColor': '#FFFFFF',
              'glassColor': '#333333',
            },
            'navigationStyle': 'capsule',
          },
        });
        final data = theme(increase: true, pack: pack);
        final cs = data.colorScheme;
        final ext = data.extension<SongloftThemeExtension>()!;
        for (final surface in [
          cs.surface,
          cs.surfaceContainer,
          cs.surfaceContainerHigh,
          ext.glassFill,
        ]) {
          expect(contrast(cs.onSurface, surface), greaterThanOrEqualTo(4.5));
          expect(
            contrast(cs.onSurfaceVariant, surface),
            greaterThanOrEqualTo(4.5),
          );
          expect(contrast(cs.primary, surface), greaterThanOrEqualTo(3));
          expect(contrast(cs.outline, surface), greaterThanOrEqualTo(3));
        }
        expect(
          contrast(ext.glassGlow, ext.glassGlowFaint),
          greaterThanOrEqualTo(3),
        );
        expect(ext.navigationStyle, 'capsule');
        expect(ext.copyWith().increaseContrast, isTrue);
      },
    );
  }
}
