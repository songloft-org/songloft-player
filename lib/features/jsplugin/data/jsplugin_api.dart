import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../config/app_config.dart';
import '../../../core/network/api_exceptions.dart';

/// JS 插件模型
class JSPlugin {
  final int id;
  final String? name;
  final String? version;
  final String? description;
  final String? author;
  final String? homepage;
  final String? entryPath;
  final String? main;
  final String? icon;
  final List<String> permissions;
  final String filePath;
  final String status; // 'active', 'inactive', 'error'
  final DateTime createdAt;
  final DateTime updatedAt;

  JSPlugin({
    required this.id,
    this.name,
    this.version,
    this.description,
    this.author,
    this.homepage,
    this.entryPath,
    this.main,
    this.icon,
    this.permissions = const [],
    required this.filePath,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory JSPlugin.fromJson(Map<String, dynamic> json) {
    return JSPlugin(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String?,
      version: json['version'] as String?,
      description: json['description'] as String?,
      author: json['author'] as String?,
      homepage: json['homepage'] as String?,
      entryPath: json['entry_path'] as String?,
      main: json['main'] as String?,
      icon: json['icon'] as String?,
      permissions:
          (json['permissions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      filePath: json['file_path'] as String? ?? '',
      status: json['status'] as String? ?? 'inactive',
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String)
              : DateTime.now(),
      updatedAt:
          json['updated_at'] != null
              ? DateTime.parse(json['updated_at'] as String)
              : DateTime.now(),
    );
  }

  /// 是否激活
  bool get isActive => status == 'active';

  /// 是否出错
  bool get isError => status == 'error';

  /// 显示名称
  String get displayName => name ?? filePath.split('/').last;

  /// 完整图标 URL（通过免认证静态路由访问）
  String? get iconUrl {
    if (icon == null || icon!.isEmpty || entryPath == null) return null;
    return '${AppConfig.baseUrl}${AppConfig.basePath}/api/v1/jsplugin/$entryPath/static/$icon';
  }

  @override
  String toString() => 'JSPlugin(id: $id, name: $displayName, status: $status)';
}

/// 单个 JS 插件上传结果
class JSPluginUploadResult {
  final String fileName;
  final JSPlugin? plugin;
  final String? error;
  final bool success;

  JSPluginUploadResult({
    required this.fileName,
    this.plugin,
    this.error,
    required this.success,
  });

  factory JSPluginUploadResult.fromJson(Map<String, dynamic> json) {
    return JSPluginUploadResult(
      fileName: json['file_name'] as String? ?? '',
      plugin:
          json['plugin'] != null
              ? JSPlugin.fromJson(json['plugin'] as Map<String, dynamic>)
              : null,
      error: json['error'] as String?,
      success: json['success'] as bool? ?? false,
    );
  }
}

/// 批量 JS 插件上传响应
class JSPluginUploadResponse {
  final int total;
  final int success;
  final int failed;
  final List<JSPluginUploadResult> results;
  final String message;

  JSPluginUploadResponse({
    required this.total,
    required this.success,
    required this.failed,
    required this.results,
    required this.message,
  });

  factory JSPluginUploadResponse.fromJson(Map<String, dynamic> json) {
    return JSPluginUploadResponse(
      total: json['total'] as int? ?? 0,
      success: json['success'] as int? ?? 0,
      failed: json['failed'] as int? ?? 0,
      results:
          (json['results'] as List<dynamic>?)
              ?.map(
                (e) => JSPluginUploadResult.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      message: json['message'] as String? ?? '',
    );
  }
}

/// 单个插件批量更新结果
class JSPluginBatchUpdateResult {
  final int pluginId;
  final String pluginName;
  final String entryPath;
  final bool success;
  final bool hasUpdate;
  final String currentVersion;
  final String newVersion;
  final String? error;

  JSPluginBatchUpdateResult({
    required this.pluginId,
    required this.pluginName,
    required this.entryPath,
    required this.success,
    required this.hasUpdate,
    required this.currentVersion,
    required this.newVersion,
    this.error,
  });

  factory JSPluginBatchUpdateResult.fromJson(Map<String, dynamic> json) {
    return JSPluginBatchUpdateResult(
      pluginId: (json['plugin_id'] as num?)?.toInt() ?? 0,
      pluginName: json['plugin_name'] as String? ?? '',
      entryPath: json['entry_path'] as String? ?? '',
      success: json['success'] as bool? ?? false,
      hasUpdate: json['has_update'] as bool? ?? false,
      currentVersion: json['current_version'] as String? ?? '',
      newVersion: json['new_version'] as String? ?? '',
      error: json['error'] as String?,
    );
  }
}

/// 批量更新响应
class JSPluginBatchUpdateResponse {
  final int total;
  final int updated;
  final int failed;
  final int skipped;
  final List<JSPluginBatchUpdateResult> results;
  final String message;

  JSPluginBatchUpdateResponse({
    required this.total,
    required this.updated,
    required this.failed,
    required this.skipped,
    required this.results,
    required this.message,
  });

  factory JSPluginBatchUpdateResponse.fromJson(Map<String, dynamic> json) {
    return JSPluginBatchUpdateResponse(
      total: json['total'] as int? ?? 0,
      updated: json['updated'] as int? ?? 0,
      failed: json['failed'] as int? ?? 0,
      skipped: json['skipped'] as int? ?? 0,
      results: (json['results'] as List<dynamic>?)
              ?.map((e) =>
                  JSPluginBatchUpdateResult.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      message: json['message'] as String? ?? '',
    );
  }
}

/// JS 插件更新检查结果
class JSPluginUpdateCheck {
  final bool hasUpdate;
  final String currentVersion;
  final String remoteVersion;
  final String downloadUrl;

  JSPluginUpdateCheck({
    required this.hasUpdate,
    required this.currentVersion,
    required this.remoteVersion,
    required this.downloadUrl,
  });

  factory JSPluginUpdateCheck.fromJson(Map<String, dynamic> json) {
    return JSPluginUpdateCheck(
      hasUpdate: json['has_update'] as bool? ?? false,
      currentVersion: json['current_version'] as String? ?? '',
      remoteVersion: json['remote_version'] as String? ?? '',
      downloadUrl: json['download_url'] as String? ?? '',
    );
  }
}

/// 插件注册表中的插件条目
class RegistryPluginEntry {
  final String name;
  final String entryPath;
  final String version;
  final String? description;
  final String? author;
  final String? homepage;
  final String? icon;
  final String downloadUrl;
  final bool installed;
  final String? installedVersion;
  final bool hasUpdate;

  RegistryPluginEntry({
    required this.name,
    required this.entryPath,
    required this.version,
    this.description,
    this.author,
    this.homepage,
    this.icon,
    required this.downloadUrl,
    this.installed = false,
    this.installedVersion,
    this.hasUpdate = false,
  });

  factory RegistryPluginEntry.fromJson(Map<String, dynamic> json) {
    return RegistryPluginEntry(
      name: json['name'] as String? ?? '',
      entryPath: json['entry_path'] as String? ?? '',
      version: json['version'] as String? ?? '',
      description: json['description'] as String?,
      author: json['author'] as String?,
      homepage: json['homepage'] as String?,
      icon: json['icon'] as String?,
      downloadUrl: json['download_url'] as String? ?? '',
      installed: json['installed'] as bool? ?? false,
      installedVersion: json['installed_version'] as String?,
      hasUpdate: json['has_update'] as bool? ?? false,
    );
  }
}

/// 注册表刷新响应
class RegistryRefreshResponse {
  final List<RegistryPluginEntry> plugins;
  final int total;
  final int page;
  final int pageSize;
  final List<String> warnings;

  RegistryRefreshResponse({
    required this.plugins,
    required this.total,
    required this.page,
    required this.pageSize,
    this.warnings = const [],
  });

  factory RegistryRefreshResponse.fromJson(Map<String, dynamic> json) {
    return RegistryRefreshResponse(
      plugins: (json['plugins'] as List<dynamic>?)
              ?.map((e) =>
                  RegistryPluginEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 20,
      warnings: (json['warnings'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }
}

/// JS 插件 API 服务
class JSPluginApi {
  final Dio dio;

  JSPluginApi({required this.dio});

  /// 获取所有 JS 插件
  /// GET /api/v1/jsplugins
  Future<List<JSPlugin>> getPlugins() async {
    try {
      final response = await dio.get('${AppConfig.apiPrefix}/jsplugins');
      final list = response.data['plugins'] as List<dynamic>? ?? [];
      return list
          .map((e) => JSPlugin.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 获取单个 JS 插件
  /// GET /api/v1/jsplugins/{id}
  Future<JSPlugin> getPlugin(int id) async {
    try {
      final response = await dio.get('${AppConfig.apiPrefix}/jsplugins/$id');
      final data = response.data as Map<String, dynamic>;
      return JSPlugin.fromJson(data['plugin'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 上传 JS 插件（从文件路径，适用于原生平台）
  /// POST /api/v1/jsplugins/upload (multipart)
  Future<JSPluginUploadResponse> uploadPlugin(
    String filePath,
    String fileName,
  ) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
      });
      final response = await dio.post(
        '${AppConfig.apiPrefix}/jsplugins/upload',
        data: formData,
      );
      return JSPluginUploadResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 上传 JS 插件（从字节数据，适用于 Web 平台）
  /// POST /api/v1/jsplugins/upload (multipart)
  Future<JSPluginUploadResponse> uploadPluginBytes(
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: fileName),
      });
      final response = await dio.post(
        '${AppConfig.apiPrefix}/jsplugins/upload',
        data: formData,
      );
      return JSPluginUploadResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 删除 JS 插件
  /// DELETE /api/v1/jsplugins/{id}
  Future<void> deletePlugin(int id) async {
    try {
      await dio.delete('${AppConfig.apiPrefix}/jsplugins/$id');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 启用 JS 插件
  /// POST /api/v1/jsplugins/{id}/enable
  Future<JSPlugin> enablePlugin(int id) async {
    try {
      final response = await dio.post(
        '${AppConfig.apiPrefix}/jsplugins/$id/enable',
      );
      final data = response.data as Map<String, dynamic>;
      return JSPlugin.fromJson(data['plugin'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 禁用 JS 插件
  /// POST /api/v1/jsplugins/{id}/disable
  Future<JSPlugin> disablePlugin(int id) async {
    try {
      final response = await dio.post(
        '${AppConfig.apiPrefix}/jsplugins/$id/disable',
      );
      final data = response.data as Map<String, dynamic>;
      return JSPlugin.fromJson(data['plugin'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 检查 JS 插件更新
  /// GET /api/v1/jsplugins/{id}/check-update
  Future<JSPluginUpdateCheck> checkUpdate(int id, {String? githubProxy}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (githubProxy != null && githubProxy.isNotEmpty) {
        queryParams['github_proxy'] = githubProxy;
      }
      final response = await dio.get(
        '${AppConfig.apiPrefix}/jsplugins/$id/check-update',
        queryParameters: queryParams,
      );
      return JSPluginUpdateCheck.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 执行 JS 插件更新
  /// POST /api/v1/jsplugins/{id}/update
  Future<void> updatePlugin(
    int id, {
    String? githubProxy,
    bool force = false,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (githubProxy != null && githubProxy.isNotEmpty) {
        body['github_proxy'] = githubProxy;
      }
      if (force) {
        body['force'] = true;
      }
      await dio.post('${AppConfig.apiPrefix}/jsplugins/$id/update', data: body);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 批量更新所有插件
  /// POST /api/v1/jsplugins/update-all
  Future<JSPluginBatchUpdateResponse> updateAllPlugins({
    String? githubProxy,
    bool force = false,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (githubProxy != null && githubProxy.isNotEmpty) {
        body['github_proxy'] = githubProxy;
      }
      if (force) {
        body['force'] = true;
      }
      final response = await dio.post(
        '${AppConfig.apiPrefix}/jsplugins/update-all',
        data: body,
      );
      return JSPluginBatchUpdateResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 刷新插件注册表
  /// POST /api/v1/jsplugins/registry/refresh
  Future<RegistryRefreshResponse> refreshRegistry({
    required String registryUrl,
    int page = 1,
    int pageSize = 20,
    String? search,
    String? githubProxy,
  }) async {
    try {
      final body = <String, dynamic>{
        'registry_url': registryUrl,
        'page': page,
        'page_size': pageSize,
      };
      if (search != null && search.isNotEmpty) {
        body['search'] = search;
      }
      if (githubProxy != null && githubProxy.isNotEmpty) {
        body['github_proxy'] = githubProxy;
      }
      final response = await dio.post(
        '${AppConfig.apiPrefix}/jsplugins/registry/refresh',
        data: body,
      );
      return RegistryRefreshResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 从注册表安装插件
  /// POST /api/v1/jsplugins/registry/install
  Future<JSPluginUploadResponse> installFromRegistry({
    required String downloadUrl,
    String? githubProxy,
  }) async {
    try {
      final body = <String, dynamic>{'download_url': downloadUrl};
      if (githubProxy != null && githubProxy.isNotEmpty) {
        body['github_proxy'] = githubProxy;
      }
      final response = await dio.post(
        '${AppConfig.apiPrefix}/jsplugins/registry/install',
        data: body,
      );
      return JSPluginUploadResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
