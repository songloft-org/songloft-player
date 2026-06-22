import 'package:dio/dio.dart';

import '../../../config/app_config.dart';
import '../../../core/network/api_exceptions.dart';

/// 音乐路径与扫描排除配置（GET/PUT /settings/music-path）
class MusicPathSetting {
  final String path;
  final List<String> excludeDirs;
  final List<String> excludePaths;
  final List<String> autoCreateExcludeDirs;

  MusicPathSetting({
    required this.path,
    required this.excludeDirs,
    required this.excludePaths,
    required this.autoCreateExcludeDirs,
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
      autoCreateExcludeDirs:
          (json['auto_create_exclude_dirs'] as List?)?.map((e) => e as String).toList() ??
          <String>[],
    );
  }

  Map<String, dynamic> toJson() => {
    'path': path,
    'exclude_dirs': excludeDirs,
    'exclude_paths': excludePaths,
    'auto_create_exclude_dirs': autoCreateExcludeDirs,
  };

  MusicPathSetting copyWith({
    String? path,
    List<String>? excludeDirs,
    List<String>? excludePaths,
    List<String>? autoCreateExcludeDirs,
  }) => MusicPathSetting(
    path: path ?? this.path,
    excludeDirs: excludeDirs ?? this.excludeDirs,
    excludePaths: excludePaths ?? this.excludePaths,
    autoCreateExcludeDirs: autoCreateExcludeDirs ?? this.autoCreateExcludeDirs,
  );
}

/// 自动扫描配置（GET/PUT /settings/auto-scan）
class AutoScanSetting {
  final bool enabled;
  final int intervalSeconds;

  AutoScanSetting({required this.enabled, required this.intervalSeconds});

  factory AutoScanSetting.fromJson(Map<String, dynamic> json) {
    return AutoScanSetting(
      enabled: json['enabled'] as bool? ?? false,
      intervalSeconds: json['interval_seconds'] as int? ?? 3600,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'interval_seconds': intervalSeconds,
  };

  AutoScanSetting copyWith({bool? enabled, int? intervalSeconds}) =>
      AutoScanSetting(
        enabled: enabled ?? this.enabled,
        intervalSeconds: intervalSeconds ?? this.intervalSeconds,
      );
}

/// 插件订阅源配置
class PluginRegistryConfig {
  final String url;
  final String name;
  final bool enabled;
  final String token;

  PluginRegistryConfig({
    required this.url,
    required this.name,
    this.enabled = true,
    this.token = '',
  });

  factory PluginRegistryConfig.fromJson(Map<String, dynamic> json) {
    return PluginRegistryConfig(
      url: json['url'] as String? ?? '',
      name: json['name'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
      token: json['token'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'url': url,
    'name': name,
    'enabled': enabled,
    if (token.isNotEmpty) 'token': token,
  };

  PluginRegistryConfig copyWith({
    String? url,
    String? name,
    bool? enabled,
    String? token,
  }) =>
      PluginRegistryConfig(
        url: url ?? this.url,
        name: name ?? this.name,
        enabled: enabled ?? this.enabled,
        token: token ?? this.token,
      );
}

/// 插件 Tab 条目
class PluginTabEntry {
  final int pluginId;
  final String entryPath;
  final String name;

  PluginTabEntry({
    required this.pluginId,
    required this.entryPath,
    required this.name,
  });

  factory PluginTabEntry.fromJson(Map<String, dynamic> json) {
    return PluginTabEntry(
      pluginId: json['plugin_id'] as int? ?? 0,
      entryPath: json['entry_path'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'plugin_id': pluginId,
    'entry_path': entryPath,
    'name': name,
  };

  PluginTabEntry copyWith({int? pluginId, String? entryPath, String? name}) =>
      PluginTabEntry(
        pluginId: pluginId ?? this.pluginId,
        entryPath: entryPath ?? this.entryPath,
        name: name ?? this.name,
      );
}

/// 底部导航栏 Tab 配置
class TabConfig {
  final bool showLibrary;
  final bool showPlaylists;
  final List<PluginTabEntry> pluginTabs;

  TabConfig({
    required this.showLibrary,
    required this.showPlaylists,
    required this.pluginTabs,
  });

  factory TabConfig.defaultConfig() =>
      TabConfig(showLibrary: true, showPlaylists: true, pluginTabs: []);

  factory TabConfig.fromJson(Map<String, dynamic> json) {
    return TabConfig(
      showLibrary: json['show_library'] as bool? ?? true,
      showPlaylists: json['show_playlists'] as bool? ?? true,
      pluginTabs:
          (json['plugin_tabs'] as List?)
              ?.map((e) => PluginTabEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          <PluginTabEntry>[],
    );
  }

  Map<String, dynamic> toJson() => {
    'show_library': showLibrary,
    'show_playlists': showPlaylists,
    'plugin_tabs': pluginTabs.map((e) => e.toJson()).toList(),
  };

  TabConfig copyWith({
    bool? showLibrary,
    bool? showPlaylists,
    List<PluginTabEntry>? pluginTabs,
  }) => TabConfig(
    showLibrary: showLibrary ?? this.showLibrary,
    showPlaylists: showPlaylists ?? this.showPlaylists,
    pluginTabs: pluginTabs ?? this.pluginTabs,
  );

  int get optionalCount =>
      (showLibrary ? 1 : 0) + (showPlaylists ? 1 : 0) + pluginTabs.length;

  int get totalCount => 2 + optionalCount; // 首页 + 设置 + 可选项
}

/// 用户偏好设置（跨设备同步）
class UserPreferences {
  final String themeMode;
  final String playMode;
  final String playlistViewMode;
  final String audioQuality;
  final int localCacheMaxSize;
  final double volume;

  UserPreferences({
    required this.themeMode,
    required this.playMode,
    required this.playlistViewMode,
    required this.audioQuality,
    required this.localCacheMaxSize,
    required this.volume,
  });

  factory UserPreferences.defaults() => UserPreferences(
    themeMode: 'system',
    playMode: 'order',
    playlistViewMode: 'grid',
    audioQuality: 'original',
    localCacheMaxSize: 1073741824,
    volume: 50.0,
  );

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      themeMode: json['theme_mode'] as String? ?? 'system',
      playMode: json['play_mode'] as String? ?? 'order',
      playlistViewMode: json['playlist_view_mode'] as String? ?? 'grid',
      audioQuality: json['audio_quality'] as String? ?? 'original',
      localCacheMaxSize: json['local_cache_max_size'] as int? ?? 1073741824,
      volume: (json['volume'] as num?)?.toDouble() ?? 50.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'theme_mode': themeMode,
    'play_mode': playMode,
    'playlist_view_mode': playlistViewMode,
    'audio_quality': audioQuality,
    'local_cache_max_size': localCacheMaxSize,
    'volume': volume,
  };

  bool isAllDefaults() {
    final d = UserPreferences.defaults();
    return themeMode == d.themeMode &&
        playMode == d.playMode &&
        playlistViewMode == d.playlistViewMode &&
        audioQuality == d.audioQuality &&
        localCacheMaxSize == d.localCacheMaxSize &&
        volume == d.volume;
  }
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

  // ---------- 扫描后自动创建歌单（按目录结构生成歌单） ----------

  Future<bool> getScanAutoCreatePlaylists() async {
    try {
      final response = await dio.get(
        '${AppConfig.apiPrefix}/settings/scan-auto-create-playlists',
      );
      final data = response.data as Map<String, dynamic>;
      return data['enabled'] as bool? ?? true;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> setScanAutoCreatePlaylists(bool enabled) async {
    try {
      await dio.put(
        '${AppConfig.apiPrefix}/settings/scan-auto-create-playlists',
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

  // ---------- 扫描标题来源 ----------

  Future<String> getScanTitleSource() async {
    try {
      final response = await dio.get(
        '${AppConfig.apiPrefix}/settings/scan-title-source',
      );
      final data = response.data as Map<String, dynamic>;
      return data['title_source'] as String? ?? 'tag';
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> setScanTitleSource(String titleSource) async {
    try {
      await dio.put(
        '${AppConfig.apiPrefix}/settings/scan-title-source',
        data: {'title_source': titleSource},
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ---------- 音乐路径与扫描排除 ----------

  Future<MusicPathSetting> getMusicPath() async {
    try {
      final response = await dio.get(
        '${AppConfig.apiPrefix}/settings/music-path',
      );
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

  // ---------- 日志等级（debug / info / warn / error） ----------

  Future<String> getLogLevel() async {
    try {
      final response = await dio.get(
        '${AppConfig.apiPrefix}/settings/log-level',
      );
      final data = response.data as Map<String, dynamic>;
      return data['level'] as String? ?? 'info';
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> setLogLevel(String level) async {
    try {
      await dio.put(
        '${AppConfig.apiPrefix}/settings/log-level',
        data: {'level': level},
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ---------- 插件订阅源 ----------

  Future<List<PluginRegistryConfig>> getPluginRegistries() async {
    try {
      final response = await dio.get(
        '${AppConfig.apiPrefix}/settings/plugin-registries',
      );
      final data = response.data as Map<String, dynamic>;
      final list = data['registries'] as List<dynamic>? ?? [];
      return list
          .map((e) => PluginRegistryConfig.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<PluginRegistryConfig>> updatePluginRegistries(
    List<PluginRegistryConfig> registries,
  ) async {
    try {
      final response = await dio.put(
        '${AppConfig.apiPrefix}/settings/plugin-registries',
        data: {'registries': registries.map((r) => r.toJson()).toList()},
      );
      final data = response.data as Map<String, dynamic>;
      final list = data['registries'] as List<dynamic>? ?? [];
      return list
          .map((e) => PluginRegistryConfig.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ---------- HTTP 代理 ----------

  Future<String> getHttpProxy() async {
    try {
      final response = await dio.get(
        '${AppConfig.apiPrefix}/settings/http-proxy',
      );
      final data = response.data as Map<String, dynamic>;
      return data['proxy'] as String? ?? '';
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> setHttpProxy(String proxy) async {
    try {
      await dio.put(
        '${AppConfig.apiPrefix}/settings/http-proxy',
        data: {'proxy': proxy},
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ---------- 自动扫描配置 ----------

  Future<AutoScanSetting> getAutoScan() async {
    try {
      final response = await dio.get(
        '${AppConfig.apiPrefix}/settings/auto-scan',
      );
      return AutoScanSetting.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> setAutoScan(AutoScanSetting setting) async {
    try {
      await dio.put(
        '${AppConfig.apiPrefix}/settings/auto-scan',
        data: setting.toJson(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ---------- 底部导航栏 Tab 配置 ----------

  Future<TabConfig> getTabConfig() async {
    try {
      final response = await dio.get(
        '${AppConfig.apiPrefix}/settings/tab-config',
      );
      return TabConfig.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<TabConfig> updateTabConfig(TabConfig config) async {
    try {
      final response = await dio.put(
        '${AppConfig.apiPrefix}/settings/tab-config',
        data: config.toJson(),
      );
      return TabConfig.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ---------- 用户偏好（跨设备同步） ----------

  Future<UserPreferences> getUserPreferences() async {
    try {
      final response = await dio.get(
        '${AppConfig.apiPrefix}/settings/user-preferences',
      );
      return UserPreferences.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<UserPreferences> updateUserPreferences(
    UserPreferences prefs,
  ) async {
    try {
      final response = await dio.put(
        '${AppConfig.apiPrefix}/settings/user-preferences',
        data: prefs.toJson(),
      );
      return UserPreferences.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ---------- 刷新远程歌曲元数据 ----------

  Future<void> startMetadataRefresh() async {
    try {
      await dio.post('${AppConfig.apiPrefix}/songs/refresh-metadata');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<MetadataRefreshProgress> getMetadataRefreshProgress() async {
    try {
      final response = await dio.get(
        '${AppConfig.apiPrefix}/songs/refresh-metadata/progress',
      );
      return MetadataRefreshProgress.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> cancelMetadataRefresh() async {
    try {
      await dio.post('${AppConfig.apiPrefix}/songs/refresh-metadata/cancel');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

/// 远程歌曲元数据刷新进度
class MetadataRefreshProgress {
  final String status;
  final int total;
  final int processed;
  final int failed;

  const MetadataRefreshProgress({
    required this.status,
    required this.total,
    required this.processed,
    required this.failed,
  });

  static const idle = MetadataRefreshProgress(
    status: 'idle',
    total: 0,
    processed: 0,
    failed: 0,
  );

  factory MetadataRefreshProgress.fromJson(Map<String, dynamic> json) {
    return MetadataRefreshProgress(
      status: json['status'] as String? ?? 'idle',
      total: json['total'] as int? ?? 0,
      processed: json['processed'] as int? ?? 0,
      failed: json['failed'] as int? ?? 0,
    );
  }

  bool get isIdle => status == 'idle';
  bool get isRunning => status == 'running' || status == 'cancelling';
  bool get isDone => status == 'done' || status == 'cancelled' || status == 'failed';
  int get completedCount => processed + failed;
  double get progress => total > 0 ? completedCount / total : 0;
}
