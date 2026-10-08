import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/core/theme/app_theme.dart';
import 'package:songloft_flutter/features/home/presentation/render/plugin_color_scheme.dart';

void main() {
  test('pluginThemeAppearanceMap serializes theme extension values', () {
    const extension = SongloftThemeExtension(
      navigationStyle: 'capsule',
      cardRadius: 18,
      controlRadius: 22,
      navigationRadius: 30,
      playerGradientColors: <Color>[Color(0xFF123456), Color(0xFFABCDEF)],
      glassFill: Color(0xB8FFFFFF),
      glassBorder: Color(0x73FFFFFF),
    );
    final theme = ThemeData(
      extensions: const <ThemeExtension<dynamic>>[extension],
    );

    expect(pluginThemeAppearanceMap(theme), <String, Object>{
      'navigationStyle': 'capsule',
      'cardRadius': 18.0,
      'controlRadius': 22.0,
      'navigationRadius': 30.0,
      'reduceTransparency': false,
      'increaseContrast': false,
      'playerGradient': <String>['#123456', '#ABCDEF'],
      'glassFill': 'rgba(255, 255, 255, 0.722)',
      'glassBorder': 'rgba(255, 255, 255, 0.451)',
    });
  });

  test('pluginThemeAppearanceMap normalizes unknown navigation style', () {
    const extension = SongloftThemeExtension(navigationStyle: 'unknown');
    final theme = ThemeData(
      extensions: const <ThemeExtension<dynamic>>[extension],
    );

    expect(pluginThemeAppearanceMap(theme)['navigationStyle'], 'standard');
  });
}
