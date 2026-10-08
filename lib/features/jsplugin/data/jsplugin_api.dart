import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../config/app_config.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../l10n/l10n_holder.dart';

/// JS 插件模型
class JSPlugin {
  final int id;
  final String? name;
  final String? version;
  final String? description;
  final String? author;
  final String? homepage;
  final String? updateUrl;
  final String? downloadUrl;
  final String? entryPath;
  final String? main;
  final String? icon;
  final List<String> permissions;
  final String filePath;
  final String status; // 'active', 'inactive', 'error'

  /// 插件 `plugin.json` 声明的渲染引擎（`'webview'`）。
  ///
  /// 老服务端不返回该字段、插件不声明时为 null / 空串，一律按 `webview` 处理
  /// （解析走 `PluginRenderEngine.fromManifestValue`）。原样保留字符串而不在
  /// 这里就转成 enum：data 层不该依赖 presentation 层的渲染枚举。
  final String? renderEngine;
  final DateTime createdAt;
  final DateTime updatedAt;

  JSPlugin({
    required this.id,
    this.name,
    this.version,
    this.description,
    this.author,
    this.homepage,
    this.updateUrl,
    this.downloadUrl,
    this.entryPath,
    this.main,
    this.icon,
    this.permissions = const [],
    required this.filePath,
    required this.status,
    this.renderEngine,
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
      updateUrl:
          json['update_url'] is String ? json['update_url'] as String : null,
      downloadUrl:
          json['download_url'] is String
              ? json['download_url'] as String
              : null,
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
      // 容错：老服务端无此字段；非字符串（后端换类型 / 代理注入脏数据）也不抛。
      renderEngine:
          json['render_engine'] is String
              ? json['render_engine'] as String
              : null,
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
      results:
          (json['results'] as List<dynamic>?)
              ?.map(
                (e) => JSPluginBatchUpdateResult.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
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

  /// 该插件所属订阅源 URL（仅「全部」聚合模式返回），安装时回传给后端解析 token
  final String? sourceUrl;

  /// 该插件所属订阅源名称（仅「全部」聚合模式返回），用于区分 entryPath 相同的条目
  final String? sourceName;

  /// entryPath 之外的身份维度（后端按规范化 author、或 GitHub 仓库兜底算出）。
  /// entryPath 可能被不同作者的插件撞名，故行标识与状态更新都要带上它。
  final String? identity;

  /// 本地已装了同 entryPath 但**不同作者**的插件：安装本条会替换掉它
  final bool conflict;

  /// 占用该 entryPath 的本地插件描述，可直接展示给用户
  final String? conflictWith;

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
    this.sourceUrl,
    this.sourceName,
    this.identity,
    this.conflict = false,
    this.conflictWith,
  });

  /// 商店列表中的稳定行标识。entryPath 单独不够用——同名不同作者的两个插件
  /// 会共用一个 entryPath（songloft-org/songloft#339）。
  String get rowKey => '$entryPath|${identity ?? ''}';

  /// 判断本条目是否就是 (entryPath, identity) 所指的那个插件。
  /// 安装成功后就地更新状态时用它，避免一次点亮所有同 entryPath 的条目。
  bool matches(String otherEntryPath, String? otherIdentity) {
    return entryPath == otherEntryPath &&
        (identity ?? '') == (otherIdentity ?? '');
  }

  RegistryPluginEntry copyWith({
    bool? installed,
    String? installedVersion,
    bool? hasUpdate,
    bool? conflict,
    String? conflictWith,
  }) {
    return RegistryPluginEntry(
      name: name,
      entryPath: entryPath,
      version: version,
      description: description,
      author: author,
      homepage: homepage,
      icon: icon,
      downloadUrl: downloadUrl,
      installed: installed ?? this.installed,
      installedVersion: installedVersion ?? this.installedVersion,
      hasUpdate: hasUpdate ?? this.hasUpdate,
      sourceUrl: sourceUrl,
      sourceName: sourceName,
      identity: identity,
      conflict: conflict ?? this.conflict,
      conflictWith: conflictWith ?? this.conflictWith,
    );
  }

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
      sourceUrl: json['source_url'] as String?,
      sourceName: json['source_name'] as String?,
      identity: json['identity'] as String?,
      conflict: json['conflict'] as bool? ?? false,
      conflictWith: json['conflict_with'] as String?,
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
      plugins:
          (json['plugins'] as List<dynamic>?)
              ?.map(
                (e) => RegistryPluginEntry.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 20,
      warnings:
          (json['warnings'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }
}

/// JS 插件 API 服务
class JSPluginApi {
  // 检查更新/代理回退、下载/直连回退及启用各有独立服务端时限。
  // 单次安装/更新不能沿用普通 API 的 15 秒超时；批量更新逐个处理。
  static const _installTimeout = Duration(minutes: 4);
  static const _batchUpdateTimeout = Duration(minutes: 30);
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
        options: Options(receiveTimeout: _installTimeout),
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
        options: Options(receiveTimeout: _installTimeout),
      );
      return JSPluginUploadResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 删除 JS 插件
  /// DELETE /api/v1/jsplugins/{id}?keep_data=true
  Future<void> deletePlugin(int id, {bool keepData = false}) async {
    try {
      await dio.delete(
        '${AppConfig.apiPrefix}/jsplugins/$id',
        queryParameters: keepData ? {'keep_data': 'true'} : <String, String>{},
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 清理孤儿持久化存储数据
  /// POST /api/v1/jsplugins/storage/cleanup
  Future<String> cleanupOrphanStorage() async {
    try {
      final response = await dio.post(
        '${AppConfig.apiPrefix}/jsplugins/storage/cleanup',
      );
      final data = response.data as Map<String, dynamic>;
      return data['message'] as String? ?? l10n.jspluginCleanupDone;
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
        options: Options(receiveTimeout: const Duration(seconds: 45)),
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
      await dio.post(
        '${AppConfig.apiPrefix}/jsplugins/$id/update',
        data: body,
        options: Options(receiveTimeout: _installTimeout),
      );
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
        options: Options(receiveTimeout: _batchUpdateTimeout),
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
  ///
  /// [force] 为 true 时绕过服务端缓存强制重拉。只有用户主动点「刷新」才该传，
  /// 翻页与搜索必须走缓存——否则每翻一页都会重新递归拉取整棵注册表树。
  Future<RegistryRefreshResponse> refreshRegistry({
    String registryUrl = '',
    bool allSources = false,
    int page = 1,
    int pageSize = 20,
    String? search,
    String? githubProxy,
    String? token,
    bool force = false,
  }) async {
    try {
      final body = <String, dynamic>{'page': page, 'page_size': pageSize};
      // 服务端缓存拉取结果 5 分钟，翻页/搜索直接命中缓存；
      // 只有用户主动刷新时才 force 重拉整棵注册表树
      if (force) {
        body['force'] = true;
      }
      // 聚合「全部」模式：忽略单源 URL 与 token，后端遍历所有启用源
      if (allSources) {
        body['all_sources'] = true;
      } else {
        body['registry_url'] = registryUrl;
        if (token != null && token.isNotEmpty) {
          body['token'] = token;
        }
      }
      if (search != null && search.isNotEmpty) {
        body['search'] = search;
      }
      if (githubProxy != null && githubProxy.isNotEmpty) {
        body['github_proxy'] = githubProxy;
      }
      final response = await dio.post(
        '${AppConfig.apiPrefix}/jsplugins/registry/refresh',
        data: body,
        // 多源聚合会递归拉取注册表与 plugin.json，服务端正常处理时间可能
        // 超过全局 15 秒接收超时。只放宽这个慢端点，避免影响其他 API。
        options: Options(receiveTimeout: const Duration(seconds: 60)),
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
  ///
  /// [overwrite] 为 true 时允许替换掉本地同 entryPath 但不同作者的插件。
  /// 默认 false：这种情况后端返回 409，需用户确认后再带 true 重试。
  Future<JSPluginUploadResponse> installFromRegistry({
    required String downloadUrl,
    String? githubProxy,
    String? token,
    String? sourceUrl,
    bool overwrite = false,
  }) async {
    try {
      final body = <String, dynamic>{'download_url': downloadUrl};
      if (overwrite) {
        body['overwrite'] = true;
      }
      if (githubProxy != null && githubProxy.isNotEmpty) {
        body['github_proxy'] = githubProxy;
      }
      if (token != null && token.isNotEmpty) {
        body['token'] = token;
      }
      // 「全部」模式无本地 token 时，回传来源源 URL 让后端按源解析 token
      if (sourceUrl != null && sourceUrl.isNotEmpty) {
        body['source_url'] = sourceUrl;
      }
      final response = await dio.post(
        '${AppConfig.apiPrefix}/jsplugins/registry/install',
        data: body,
        options: Options(receiveTimeout: _installTimeout),
      );
      return JSPluginUploadResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
