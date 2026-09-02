import 'dart:ui';

import 'package:dio/dio.dart';

import '../../../config/app_config.dart';
import '../../../core/network/api_exceptions.dart';

/// 主题包颜色配置
class ThemePackColors {
  final Color seedColor;
  final Color? backgroundColor;
  final Color? surfaceColor;
  final Color? glassColor;

  ThemePackColors({
    required this.seedColor,
    this.backgroundColor,
    this.surfaceColor,
    this.glassColor,
  });

  factory ThemePackColors.fromJson(Map<String, dynamic> json) {
    return ThemePackColors(
      seedColor: _parseColor(json['seedColor'] as String),
      backgroundColor:
          json['backgroundColor'] != null
              ? _parseColor(json['backgroundColor'] as String)
              : null,
      surfaceColor:
          json['surfaceColor'] != null
              ? _parseColor(json['surfaceColor'] as String)
              : null,
      glassColor:
          json['glassColor'] != null
              ? _parseColor(json['glassColor'] as String)
              : null,
    );
  }
}

/// 主题包数据模型
class ThemePack {
  final int id;
  final String themeId;
  final String name;
  final String version;
  final String author;
  final String description;
  final int schemaVersion;
  final ThemePackColors? light;
  final ThemePackColors? dark;
  final List<Color>? playerGradient;
  final double? cardRadius;
  final double? controlRadius;
  final double? navigationRadius;
  final String navigationStyle;
  final String createdAt;
  final String updatedAt;

  ThemePack({
    required this.id,
    required this.themeId,
    required this.name,
    required this.version,
    required this.author,
    required this.description,
    required this.schemaVersion,
    this.light,
    this.dark,
    this.playerGradient,
    this.cardRadius,
    this.controlRadius,
    this.navigationRadius,
    this.navigationStyle = 'standard',
    required this.createdAt,
    required this.updatedAt,
  });

  factory ThemePack.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;

    List<Color>? playerGradient;
    if (data?['playerGradient'] != null) {
      playerGradient =
          (data!['playerGradient'] as List)
              .map((e) => _parseColor(e as String))
              .toList();
    }

    return ThemePack(
      id: json['id'] as int? ?? 0,
      themeId: json['theme_id'] as String,
      name: json['name'] as String,
      version: json['version'] as String? ?? '1.0.0',
      author: json['author'] as String? ?? '',
      description: json['description'] as String? ?? '',
      schemaVersion: json['schema_version'] as int? ?? 1,
      light:
          data?['light'] != null
              ? ThemePackColors.fromJson(data!['light'] as Map<String, dynamic>)
              : null,
      dark:
          data?['dark'] != null
              ? ThemePackColors.fromJson(data!['dark'] as Map<String, dynamic>)
              : null,
      playerGradient: playerGradient,
      cardRadius: (data?['cardRadius'] as num?)?.toDouble(),
      controlRadius: (data?['controlRadius'] as num?)?.toDouble(),
      navigationRadius: (data?['navigationRadius'] as num?)?.toDouble(),
      navigationStyle: data?['navigationStyle'] as String? ?? 'standard',
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }
}

/// 主题包列表项（不含完整 data）
class ThemePackListItem {
  final int id;
  final String themeId;
  final String name;
  final String version;
  final String author;
  final String description;
  final int schemaVersion;
  final String createdAt;
  final String updatedAt;

  ThemePackListItem({
    required this.id,
    required this.themeId,
    required this.name,
    required this.version,
    required this.author,
    required this.description,
    required this.schemaVersion,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ThemePackListItem.fromJson(Map<String, dynamic> json) {
    return ThemePackListItem(
      id: json['id'] as int? ?? 0,
      themeId: json['theme_id'] as String,
      name: json['name'] as String,
      version: json['version'] as String? ?? '1.0.0',
      author: json['author'] as String? ?? '',
      description: json['description'] as String? ?? '',
      schemaVersion: json['schema_version'] as int? ?? 1,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }
}

Color _parseColor(String hex) {
  final buffer = StringBuffer();
  if (hex.startsWith('#')) hex = hex.substring(1);
  if (hex.length == 6) buffer.write('FF');
  buffer.write(hex.toUpperCase());
  return Color(int.parse(buffer.toString(), radix: 16));
}

/// 在线目录中的主题条目
class ThemeCatalogEntry {
  final String id;
  final String name;
  final String version;
  final String author;
  final String description;
  final String url;
  final String sha256;
  final String installState; // not_installed / installed / has_update

  ThemeCatalogEntry({
    required this.id,
    required this.name,
    required this.version,
    required this.author,
    required this.description,
    required this.url,
    required this.sha256,
    required this.installState,
  });

  factory ThemeCatalogEntry.fromJson(Map<String, dynamic> json) {
    return ThemeCatalogEntry(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      version: json['version'] as String? ?? '1.0.0',
      author: json['author'] as String? ?? '',
      description: json['description'] as String? ?? '',
      url: json['url'] as String? ?? '',
      sha256: json['sha256'] as String? ?? '',
      installState: json['install_state'] as String? ?? 'not_installed',
    );
  }
}

/// 目录刷新响应
class ThemeCatalogResponse {
  final List<ThemeCatalogEntry> themes;
  final int total;

  ThemeCatalogResponse({required this.themes, required this.total});

  factory ThemeCatalogResponse.fromJson(Map<String, dynamic> json) {
    final list = json['themes'] as List<dynamic>? ?? [];
    return ThemeCatalogResponse(
      themes:
          list
              .map((e) => ThemeCatalogEntry.fromJson(e as Map<String, dynamic>))
              .toList(),
      total: json['total'] as int? ?? 0,
    );
  }
}

/// 主题包 API 客户端
class ThemePackApi {
  final Dio dio;

  ThemePackApi({required this.dio});

  /// 列出所有主题包
  Future<List<ThemePackListItem>> listThemePacks() async {
    try {
      final response = await dio.get('${AppConfig.apiPrefix}/theme-packs');
      final list = response.data as List<dynamic>;
      return list
          .map((e) => ThemePackListItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 获取主题包详情
  Future<ThemePack> getThemePack(String themeId) async {
    try {
      final response = await dio.get(
        '${AppConfig.apiPrefix}/theme-packs/$themeId',
      );
      return ThemePack.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 导入主题包（接收原始 JSON 字符串）
  Future<ThemePack> importThemePack(String rawJson) async {
    try {
      final response = await dio.post(
        '${AppConfig.apiPrefix}/theme-packs',
        data: rawJson,
        options: Options(contentType: 'application/json'),
      );
      return ThemePack.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 删除主题包
  Future<void> deleteThemePack(String themeId) async {
    try {
      await dio.delete('${AppConfig.apiPrefix}/theme-packs/$themeId');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 获取当前激活的主题包（返回 null 表示默认主题）
  Future<ThemePack?> getActiveThemePack() async {
    try {
      final response = await dio.get(
        '${AppConfig.apiPrefix}/theme-packs/active',
      );
      if (response.data == null) return null;
      return ThemePack.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 设置激活的主题包
  Future<void> setActiveThemePack(String themeId) async {
    try {
      await dio.put(
        '${AppConfig.apiPrefix}/theme-packs/active',
        data: {'theme_id': themeId},
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 清除激活主题包（恢复默认）
  Future<void> clearActiveThemePack() async {
    try {
      await dio.delete('${AppConfig.apiPrefix}/theme-packs/active');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ---------- 在线主题目录 ----------

  /// 刷新在线主题目录
  Future<ThemeCatalogResponse> refreshCatalog({
    String? catalogUrl,
    String? githubProxy,
    bool force = false,
  }) async {
    try {
      final response = await dio.post(
        '${AppConfig.apiPrefix}/theme-packs/catalog/refresh',
        data: {
          if (catalogUrl != null) 'catalog_url': catalogUrl,
          if (githubProxy != null && githubProxy.isNotEmpty)
            'github_proxy': githubProxy,
          'force': force,
        },
      );
      return ThemeCatalogResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 从在线目录安装主题包
  Future<ThemePack> installFromCatalog({
    required String url,
    String? githubProxy,
    String? sha256,
  }) async {
    try {
      final response = await dio.post(
        '${AppConfig.apiPrefix}/theme-packs/catalog/install',
        data: {
          'url': url,
          if (githubProxy != null && githubProxy.isNotEmpty)
            'github_proxy': githubProxy,
          if (sha256 != null) 'sha256': sha256,
        },
      );
      return ThemePack.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
