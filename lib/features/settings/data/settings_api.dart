import 'package:dio/dio.dart';

import '../../../config/app_config.dart';
import '../../../core/network/api_exceptions.dart';

/// 音乐路径与扫描排除配置（GET/PUT /settings/music-path）
class MusicPathSetting {
  final String path;
  final List<String> excludeDirs;
  final List<String> excludePaths;

  MusicPathSetting({
    required this.path,
    required this.excludeDirs,
    required this.excludePaths,
  });

  factory MusicPathSetting.fromJson(Map<String, dynamic> json) {
    return MusicPathSetting(
      path: json['path'] as String? ?? 'music',
      excludeDirs:
          (json['exclude_dirs'] as List?)?.map((e) => e as String).toList() ??
              <String>[],
      excludePaths:
          (json['exclude_paths'] as List?)?.map((e) => e as String).toList() ??
              <String>[],
    );
  }

  Map<String, dynamic> toJson() => {
        'path': path,
        'exclude_dirs': excludeDirs,
        'exclude_paths': excludePaths,
      };

  MusicPathSetting copyWith({
    String? path,
    List<String>? excludeDirs,
    List<String>? excludePaths,
  }) =>
      MusicPathSetting(
        path: path ?? this.path,
        excludeDirs: excludeDirs ?? this.excludeDirs,
        excludePaths: excludePaths ?? this.excludePaths,
      );
}

/// 业务化设置 API 集合（/api/v1/settings/*）
///
/// 用户可见的功能开关一律走这里；通用 KV 配置仍走 ConfigApi（admin 入口）。
/// 详见后端 AGENTS.md「配置接口规范」。
class SettingsApi {
  final Dio dio;

  SettingsApi({required this.dio});

  // ---------- HLS 反向代理开关 ----------

  Future<bool> getHlsProxyEnabled() async {
    try {
      final response = await dio.get(
        '${AppConfig.apiPrefix}/settings/hls-proxy',
      );
      final data = response.data as Map<String, dynamic>;
      return data['enabled'] as bool? ?? false;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> setHlsProxyEnabled(bool enabled) async {
    try {
      await dio.put(
        '${AppConfig.apiPrefix}/settings/hls-proxy',
        data: {'enabled': enabled},
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ---------- 扫描后自动创建歌单是否包含子目录 ----------

  Future<bool> getScanAutoCreateIncludeSubdirs() async {
    try {
      final response = await dio.get(
        '${AppConfig.apiPrefix}/settings/scan-auto-create-include-subdirs',
      );
      final data = response.data as Map<String, dynamic>;
      return data['enabled'] as bool? ?? false;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> setScanAutoCreateIncludeSubdirs(bool enabled) async {
    try {
      await dio.put(
        '${AppConfig.apiPrefix}/settings/scan-auto-create-include-subdirs',
        data: {'enabled': enabled},
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ---------- 音乐路径与扫描排除 ----------

  Future<MusicPathSetting> getMusicPath() async {
    try {
      final response =
          await dio.get('${AppConfig.apiPrefix}/settings/music-path');
      return MusicPathSetting.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<MusicPathSetting> updateMusicPath(MusicPathSetting setting) async {
    try {
      final response = await dio.put(
        '${AppConfig.apiPrefix}/settings/music-path',
        data: setting.toJson(),
      );
      return MusicPathSetting.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
