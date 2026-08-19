import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';

import '../../shared/models/song.dart';
import 'url_helper.dart';

/// 封面颜色调色板
class CoverPalette {
  /// 主色调
  final Color dominantColor;

  /// 鲜艳色（适合强调元素）
  final Color? vibrantColor;

  /// 亮鲜艳色
  final Color? lightVibrantColor;

  /// 暗柔和色（适合背景渐变）
  final Color? darkMutedColor;

  /// 柔和色
  final Color? mutedColor;

  /// 适合在封面图片上显示的前景色（图标、文本）
  /// 根据封面遮罩色（darkMutedColor）亮度自动计算：深色 → 白色，浅色 → 黑色
  final Color onImageColor;

  const CoverPalette({
    required this.dominantColor,
    this.vibrantColor,
    this.lightVibrantColor,
    this.darkMutedColor,
    this.mutedColor,
    required this.onImageColor,
  });
}

/// LRU 缓存（最多 20 条）
class _LruCache<K, V> {
  final int maxSize;
  final LinkedHashMap<K, V> _map = LinkedHashMap<K, V>();

  _LruCache({this.maxSize = 20});

  V? get(K key) {
    final value = _map.remove(key);
    if (value != null) {
      _map[key] = value; // 移到末尾（最近使用）
    }
    return value;
  }

  void put(K key, V value) {
    _map.remove(key);
    _map[key] = value;
    while (_map.length > maxSize) {
      _map.remove(_map.keys.first);
    }
  }

  bool containsKey(K key) => _map.containsKey(key);
}

/// 全局颜色缓存
final _colorCache = _LruCache<String, CoverPalette>(maxSize: 20);

/// 从封面 URL 提取颜色的 Provider
///
/// 使用方式：
/// ```dart
/// final palette = ref.watch(coverColorsProvider(coverUrl));
/// palette.when(
///   data: (colors) => ... ,
///   loading: () => ... ,
///   error: (e, s) => ... ,
/// );
/// ```
final coverColorsProvider = FutureProvider.family<CoverPalette?, String?>((
  ref,
  coverUrl,
) async {
  if (coverUrl == null || coverUrl.isEmpty) return null;

  // 检查缓存
  final cached = _colorCache.get(coverUrl);
  if (cached != null) return cached;

  try {
    // 使用 UrlHelper 处理封面 URL（自动拼接 baseUrl + access_token）
    // 显式传 width 走服务端 ?w= 缩略图：取色仅需 100×100，无需下载全尺寸封面
    // （3~4MB）。否则 NetworkImage 全尺寸下载 + 主 isolate 解码会在弱网/NAS 拥堵
    // 场景下阻塞主线程触发 ANR（songloft-org/songloft-player#39）。该路径是
    // d3012f6（显示控件走 ?w=）遗漏的取色入口，故在此补齐。
    const paletteDecodeWidth = 100;
    final displayUrl = UrlHelper.buildCoverUrl(
      coverUrl,
      width: paletteDecodeWidth,
    );
    final paletteGenerator = await PaletteGenerator.fromImageProvider(
      NetworkImage(displayUrl),
      size: const Size(100, 100), // 缩小尺寸加速提取
      maximumColorCount: 16,
    );

    // 基于 darkMutedColor（遮罩色）的亮度决定前景色
    // 与歌单详情页 _buildHeaderBackground 中的 overlayColor 逻辑保持一致
    final overlayColor = paletteGenerator.darkMutedColor?.color ?? Colors.black;
    final onImageColor =
        overlayColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;

    final palette = CoverPalette(
      dominantColor: paletteGenerator.dominantColor?.color ?? Colors.grey,
      vibrantColor: paletteGenerator.vibrantColor?.color,
      lightVibrantColor: paletteGenerator.lightVibrantColor?.color,
      darkMutedColor: paletteGenerator.darkMutedColor?.color,
      mutedColor: paletteGenerator.mutedColor?.color,
      onImageColor: onImageColor,
    );

    // 写入缓存
    _colorCache.put(coverUrl, palette);
    return palette;
  } catch (e) {
    debugPrint('[ColorExtraction] Failed to extract colors from $coverUrl: $e');
    return null;
  }
});

/// FNV-1a 32-bit hash — deterministic across platforms unlike String.hashCode
int _fnv1a32(String input) {
  var hash = 0x811c9dc5;
  for (var i = 0; i < input.length; i++) {
    hash ^= input.codeUnitAt(i);
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

/// Generate a deterministic CoverPalette from song metadata.
/// Used as fallback when no cover art is available.
CoverPalette generatePaletteFromMetadata({
  required int songId,
  required String title,
  String? artist,
}) {
  final seed = '$songId|$title|${artist ?? ''}';
  final hash = _fnv1a32(seed);
  final hue = (hash % 360).abs().toDouble();

  final dominantColor = HSLColor.fromAHSL(1.0, hue, 0.5, 0.4).toColor();
  final vibrantColor = HSLColor.fromAHSL(1.0, hue, 0.7, 0.5).toColor();
  final lightVibrantColor = HSLColor.fromAHSL(1.0, hue, 0.6, 0.7).toColor();
  final darkMutedColor = HSLColor.fromAHSL(1.0, hue, 0.3, 0.2).toColor();
  final mutedColor = HSLColor.fromAHSL(1.0, hue, 0.25, 0.35).toColor();

  return CoverPalette(
    dominantColor: dominantColor,
    vibrantColor: vibrantColor,
    lightVibrantColor: lightVibrantColor,
    darkMutedColor: darkMutedColor,
    mutedColor: mutedColor,
    onImageColor: Colors.white,
  );
}

/// Unified palette provider for player background.
/// Returns cover-extracted palette when available, otherwise metadata-derived.
final playerBackgroundPaletteProvider =
    FutureProvider.family<CoverPalette, Song>((ref, song) async {
      if (song.coverUrl != null && song.coverUrl!.isNotEmpty) {
        final coverPalette = await ref.watch(
          coverColorsProvider(song.coverUrl).future,
        );
        if (coverPalette != null) return coverPalette;
      }
      return generatePaletteFromMetadata(
        songId: song.id,
        title: song.title,
        artist: song.artist,
      );
    });
