import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/core/theme/app_theme.dart';
import 'package:songloft_flutter/features/settings/data/theme_pack_api.dart';

void main() {
  group('ThemePackColors.fromJson glassColor', () {
    test('parses valid glassColor', () {
      final colors = ThemePackColors.fromJson({
        'seedColor': '#2196F3',
        'glassColor': '#3BAEEF',
      });
      expect(colors.glassColor, isNotNull);
      expect(colors.glassColor, const Color(0xFF3BAEEF));
    });

    test('returns null when glassColor absent', () {
      final colors = ThemePackColors.fromJson({
        'seedColor': '#2196F3',
      });
      expect(colors.glassColor, isNull);
    });

    test('parses 6-digit hex without #', () {
      final colors = ThemePackColors.fromJson({
        'seedColor': '#2196F3',
        'glassColor': '5BC0F5',
      });
      expect(colors.glassColor, const Color(0xFF5BC0F5));
    });
  });

  group('SongloftThemeExtension glass tokens', () {
    test('copyWith preserves glass fields', () {
      const ext = SongloftThemeExtension(
        glassGlow: Color(0xFF3BAEEF),
        glassGlowFaint: Color(0x193BAEEF),
      );

      final copied = ext.copyWith(glassGlow: const Color(0xFFFF0000));
      expect(copied.glassGlow, const Color(0xFFFF0000));
      expect(copied.glassGlowFaint, const Color(0x193BAEEF));
    });

    test('copyWith without args keeps all values', () {
      const ext = SongloftThemeExtension(
        glassGlow: Color(0xFF3BAEEF),
        glassFill: Color(0xB8FFFFFF),
      );

      final copied = ext.copyWith();
      expect(copied.glassGlow, ext.glassGlow);
      expect(copied.glassFill, ext.glassFill);
    });

    test('lerp interpolates glass colors', () {
      const a = SongloftThemeExtension(
        glassGlow: Color(0xFF000000),
      );
      const b = SongloftThemeExtension(
        glassGlow: Color(0xFFFFFFFF),
      );

      final mid = a.lerp(b, 0.5);
      expect((mid.glassGlow.r * 255).round(), closeTo(128, 1));
      expect((mid.glassGlow.g * 255).round(), closeTo(128, 1));
      expect((mid.glassGlow.b * 255).round(), closeTo(128, 1));
    });

    test('lerp at 0 returns first value', () {
      const a = SongloftThemeExtension(
        glassGlow: Color(0xFF3BAEEF),
      );
      const b = SongloftThemeExtension(
        glassGlow: Color(0xFFFF0000),
      );

      final result = a.lerp(b, 0.0);
      expect(result.glassGlow, const Color(0xFF3BAEEF));
    });

    test('lerp at 1 returns second value', () {
      const a = SongloftThemeExtension(
        glassGlow: Color(0xFF3BAEEF),
      );
      const b = SongloftThemeExtension(
        glassGlow: Color(0xFFFF0000),
      );

      final result = a.lerp(b, 1.0);
      expect(result.glassGlow, const Color(0xFFFF0000));
    });
  });

  group('AppTheme glass token generation', () {
    test('light theme without pack uses star-blue baseline', () {
      final theme = AppTheme.lightTheme();
      final ext = theme.extension<SongloftThemeExtension>()!;
      expect(ext.glassGlow, const Color(0xFF3BAEEF));
    });

    test('dark theme without pack uses star-blue baseline', () {
      final theme = AppTheme.darkTheme();
      final ext = theme.extension<SongloftThemeExtension>()!;
      expect(ext.glassGlow, const Color(0xFF5BC0F5));
    });

    test('theme with pack glassColor uses pack color', () {
      final pack = ThemePack.fromJson({
        'id': 1,
        'theme_id': 'test',
        'name': 'Test',
        'version': '1.0.0',
        'schema_version': 1,
        'created_at': '',
        'updated_at': '',
        'data': {
          'light': {
            'seedColor': '#2196F3',
            'glassColor': '#FF5722',
          },
          'dark': {
            'seedColor': '#4FC3F7',
            'glassColor': '#FF8A65',
          },
        },
      });

      final lightTheme = AppTheme.lightTheme(themePack: pack);
      final lightExt = lightTheme.extension<SongloftThemeExtension>()!;
      expect(lightExt.glassGlow, const Color(0xFFFF5722));

      final darkTheme = AppTheme.darkTheme(themePack: pack);
      final darkExt = darkTheme.extension<SongloftThemeExtension>()!;
      expect(darkExt.glassGlow, const Color(0xFFFF8A65));
    });

    test('navigation bar indicator uses glassGlowFaint', () {
      final theme = AppTheme.lightTheme();
      final ext = theme.extension<SongloftThemeExtension>()!;
      expect(theme.navigationBarTheme.indicatorColor, ext.glassGlowFaint);
    });

    test('navigation bar background uses glassFill', () {
      final theme = AppTheme.lightTheme();
      final ext = theme.extension<SongloftThemeExtension>()!;
      expect(theme.navigationBarTheme.backgroundColor, ext.glassFill);
    });

    test('default navigationStyle is standard', () {
      final theme = AppTheme.lightTheme();
      final ext = theme.extension<SongloftThemeExtension>()!;
      expect(ext.navigationStyle, 'standard');
    });

    test('pack with navigationStyle capsule propagates', () {
      final pack = ThemePack.fromJson({
        'id': 1,
        'theme_id': 'glass',
        'name': 'Glass',
        'version': '1.0.0',
        'schema_version': 1,
        'created_at': '',
        'updated_at': '',
        'data': {
          'light': {'seedColor': '#2196F3'},
          'dark': {'seedColor': '#4FC3F7'},
          'navigationStyle': 'capsule',
        },
      });

      final theme = AppTheme.lightTheme(themePack: pack);
      final ext = theme.extension<SongloftThemeExtension>()!;
      expect(ext.navigationStyle, 'capsule');
    });
  });
}
