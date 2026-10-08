import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_theme.dart';

/// 把宿主真实的 [ColorScheme] 序列化成插件页能吃的色板，随 `songloft-theme`
/// 消息一起下推（songloft-org/songloft#341）。
///
/// **为什么必须下推**：`internal/jsplugin/assets/common.css` 里的 `--md-*` 是
/// 静态硬编码，而宿主主题由 `ColorScheme.fromSeed` 生成、还能被 ThemePack 整体
/// 换掉。不下推的话插件页永远只能用兜底色板，用户换了主题包插件却不跟着变。
///
/// **为什么挂在 `songloft-theme` 上而不是单开一条消息**：亮暗标记（`data-theme`）
/// 与色值必须**同时**生效。分两条消息就会有一帧「`data-theme=dark` 但变量还是
/// 亮色」的错色闪烁。
///
/// **key 刻意用 ColorScheme 的字段名（camelCase）**，由 `common.js` 转成
/// `--md-<kebab-case>`。这样 Dart 侧这张表能和 `ColorScheme` 逐字段对照审计，
/// 不必在两个仓库之间记一套映射。`common.js` 另外负责补 `--md-surface-variant`
/// / `--md-surface-1` / `--md-surface-2` 三个兼容别名。
///
/// 不含 `--md-success*` / `--md-warning*`：M3 没有这两个角色，它们是项目自有的
/// 语义色，只有 `common.css` 里的静态值。
Map<String, String> pluginColorSchemeMap(ColorScheme cs) {
  return <String, String>{
    'primary': _hex(cs.primary),
    'onPrimary': _hex(cs.onPrimary),
    'primaryContainer': _hex(cs.primaryContainer),
    'onPrimaryContainer': _hex(cs.onPrimaryContainer),
    'secondary': _hex(cs.secondary),
    'onSecondary': _hex(cs.onSecondary),
    'secondaryContainer': _hex(cs.secondaryContainer),
    'onSecondaryContainer': _hex(cs.onSecondaryContainer),
    'tertiary': _hex(cs.tertiary),
    'onTertiary': _hex(cs.onTertiary),
    'tertiaryContainer': _hex(cs.tertiaryContainer),
    'onTertiaryContainer': _hex(cs.onTertiaryContainer),
    'error': _hex(cs.error),
    'onError': _hex(cs.onError),
    'errorContainer': _hex(cs.errorContainer),
    'onErrorContainer': _hex(cs.onErrorContainer),
    'surface': _hex(cs.surface),
    'onSurface': _hex(cs.onSurface),
    'onSurfaceVariant': _hex(cs.onSurfaceVariant),
    'surfaceDim': _hex(cs.surfaceDim),
    'surfaceBright': _hex(cs.surfaceBright),
    'surfaceContainerLowest': _hex(cs.surfaceContainerLowest),
    'surfaceContainerLow': _hex(cs.surfaceContainerLow),
    'surfaceContainer': _hex(cs.surfaceContainer),
    'surfaceContainerHigh': _hex(cs.surfaceContainerHigh),
    'surfaceContainerHighest': _hex(cs.surfaceContainerHighest),
    'outline': _hex(cs.outline),
    'outlineVariant': _hex(cs.outlineVariant),
    'inverseSurface': _hex(cs.inverseSurface),
    'onInverseSurface': _hex(cs.onInverseSurface),
    'inversePrimary': _hex(cs.inversePrimary),
  };
}

/// 把主题包中会影响插件布局的视觉参数序列化到 `songloft-theme.appearance`。
///
/// 插件不能从 [ColorScheme] 推断 `navigationStyle`：标准与胶囊主题可以使用完全
/// 相同的颜色。由宿主显式下推，才能让插件迷你播放器与主程序保持一致。
Map<String, Object> pluginThemeAppearanceMap(ThemeData theme) {
  final ext = theme.extension<SongloftThemeExtension>();
  final navigationStyle =
      ext?.navigationStyle == 'capsule' ? 'capsule' : 'standard';
  final playerGradient = ext?.playerGradientColors;
  return <String, Object>{
    'navigationStyle': navigationStyle,
    'cardRadius': ext?.cardRadius ?? AppRadius.md,
    'controlRadius': ext?.controlRadius ?? AppRadius.md,
    'navigationRadius': ext?.navigationRadius ?? AppRadius.md,
    'reduceTransparency': ext?.reduceTransparency ?? false,
    'increaseContrast': ext?.increaseContrast ?? false,
    if (playerGradient != null)
      'playerGradient': playerGradient.map(_hex).toList(growable: false),
    if (ext != null) ...<String, String>{
      'glassFill': _rgba(ext.glassFill),
      'glassBorder': _rgba(ext.glassBorder),
    },
  };
}

/// `#RRGGBB`。刻意丢掉 alpha：CSS 变量要喂给 `<flutter-cupertino-*>` 的属性，
/// 那边的 `_parseColor` 只认 `#` 开头的字面量（不展开 `var()`，也不接受 rgba）。
/// ColorScheme 的角色色本来就都是不透明的。
String _hex(Color c) {
  final rgb = c.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// `rgba(...)` for CSS-only appearance tokens. Unlike the native color parser,
/// CSS can consume alpha directly, and the host mini player's glass tokens are
/// translucent by design.
String _rgba(Color c) {
  final argb = c.toARGB32();
  final r = (argb >> 16) & 0xFF;
  final g = (argb >> 8) & 0xFF;
  final b = argb & 0xFF;
  final a = ((argb >> 24) & 0xFF) / 255;
  return 'rgba($r, $g, $b, ${a.toStringAsFixed(3)})';
}
