import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/cache_api.dart';
import '../../data/config_api.dart';
import '../../data/directory_api.dart';
import '../../data/scan_api.dart';
import '../../data/settings_api.dart';
import '../../data/frontend_version_api.dart';
import '../../data/upgrade_api.dart';
import '../../../playlist/presentation/providers/playlist_provider.dart';

// ============================================================================
// API Providers
// ============================================================================

/// ConfigApi Provider（仅供 admin 通用编辑器使用，不要在业务功能里直接调用）
final configApiProvider = Provider<ConfigApi>((ref) {
  final dio = ref.watch(dioProvider);
  return ConfigApi(dio: dio);
});

/// SettingsApi Provider —— 所有用户可见的功能开关都走这里
final settingsApiProvider = Provider<SettingsApi>((ref) {
  final dio = ref.watch(dioProvider);
  return SettingsApi(dio: dio);
});

/// ScanApi Provider
final scanApiProvider = Provider<ScanApi>((ref) {
  final dio = ref.watch(dioProvider);
  return ScanApi(dio: dio);
});

/// DirectoryApi Provider
final directoryApiProvider = Provider<DirectoryApi>((ref) {
  final dio = ref.watch(dioProvider);
  return DirectoryApi(dio: dio);
});

/// UpgradeApi Provider
final upgradeApiProvider = Provider<UpgradeApi>((ref) {
  final dio = ref.watch(dioProvider);
  return UpgradeApi(dio: dio);
});

/// FrontendVersionApi Provider（使用独立 Dio，不依赖后端认证）
final frontendVersionApiProvider = Provider<FrontendVersionApi>((ref) {
  return FrontendVersionApi();
});

/// CacheApi Provider
final cacheApiProvider = Provider<CacheApi>((ref) {
  final dio = ref.watch(dioProvider);
  return CacheApi(dio: dio);
});

/// 服务端缓存统计
final serverCacheStatsProvider = FutureProvider<CacheStats>((ref) async {
  final cacheApi = ref.watch(cacheApiProvider);
  return cacheApi.getCacheStats();
});

/// 服务端缓存配置
final serverCacheConfigProvider = FutureProvider<CacheConfig>((ref) async {
  final cacheApi = ref.watch(cacheApiProvider);
  return cacheApi.getCacheConfig();
});

/// 网络歌曲自动转本地开关
final autoConvertEnabledProvider = FutureProvider<bool>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(
    '${AppConfig.apiPrefix}/settings/auto-convert',
  );
  final data = response.data as Map<String, dynamic>;
  return data['enabled'] as bool? ?? false;
});

// ============================================================================
// Data Providers
// ============================================================================

/// 获取所有配置
final configsProvider = FutureProvider<List<Config>>((ref) async {
  final configApi = ref.watch(configApiProvider);
  return configApi.getConfigs();
});

/// 指纹计算状态
final fingerprintStatusProvider = FutureProvider<FingerprintStatus>((
  ref,
) async {
  final scanApi = ref.watch(scanApiProvider);
  return scanApi.getFingerprintStatus();
});

/// 重复歌曲组
final duplicatesProvider = FutureProvider<DuplicatesResult>((ref) async {
  final scanApi = ref.watch(scanApiProvider);
  return scanApi.getDuplicates();
});

/// 检查服务端更新
final upgradeCheckProvider = FutureProvider<UpgradeCheck>((ref) async {
  final upgradeApi = ref.watch(upgradeApiProvider);
  return upgradeApi.checkUpgrade();
});

/// 获取服务端版本号
final serverVersionProvider = FutureProvider<String>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('${AppConfig.apiPrefix}/version');
  final data = response.data as Map<String, dynamic>;
  final version = data['version'] as String?;
  if (version != null && version.isNotEmpty) {
    return version;
  }
  return '未知';
});

/// 检查前端（客户端）更新
final frontendVersionCheckProvider = FutureProvider<FrontendVersionCheck>((
  ref,
) async {
  final api = ref.watch(frontendVersionApiProvider);
  return api.checkUpdate();
});

// ============================================================================
// Theme Mode Provider
// ============================================================================

/// 主题模式 Notifier
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _loadThemeMode();
    return ThemeMode.system;
  }

  /// 从 AppPreferences 加载主题模式
  Future<void> _loadThemeMode() async {
    try {
      final prefs = await ref.read(appPreferencesProvider.future);
      state = prefs.getThemeMode();
    } catch (e) {
      // 加载失败使用默认值
      state = ThemeMode.system;
    }
  }

  /// 设置主题模式
  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await ref.read(appPreferencesProvider.future);
      await prefs.setThemeMode(mode);
    } catch (e) {
      // 保存失败忽略
    }
  }
}

/// 主题模式 Provider
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

// ============================================================================
// Scan Progress Provider
// ============================================================================

/// 扫描进度 Notifier
class ScanProgressNotifier extends Notifier<ScanProgress> {
  late ScanApi _scanApi;
  Timer? _pollTimer;

  @override
  ScanProgress build() {
    _scanApi = ref.watch(scanApiProvider);
    ref.onDispose(() {
      _stopPolling();
    });
    return ScanProgress.idle;
  }

  /// 开始扫描
  Future<void> startScan({bool reimport = false}) async {
    try {
      await _scanApi.startScan(reimport: reimport);
      // 开始轮询进度
      _startPolling();
    } catch (e) {
      state = ScanProgress(
        status: 'error',
        totalFiles: 0,
        scannedFiles: 0,
        importedFiles: 0,
        skippedFiles: 0,
        failedFiles: 0,
      );
      rethrow;
    }
  }

  /// 取消扫描
  Future<void> cancelScan() async {
    try {
      await _scanApi.cancelScan();
      _stopPolling();
      state = ScanProgress(
        status: 'cancelled',
        totalFiles: state.totalFiles,
        scannedFiles: state.scannedFiles,
        importedFiles: state.importedFiles,
        skippedFiles: state.skippedFiles,
        failedFiles: state.failedFiles,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// 刷新进度
  Future<void> refreshProgress() async {
    try {
      final previousStatus = state.status;
      state = await _scanApi.getProgress();

      // 如果扫描完成或出错，停止轮询
      if (state.isCompleted || state.isError || state.isCancelled) {
        _stopPolling();
        if (state.isCompleted && previousStatus != 'completed') {
          ref.invalidate(playlistListProvider);
        }
      } else if (state.isScanning && _pollTimer == null) {
        _startPolling();
      }
    } catch (e) {
      // 获取进度失败忽略
    }
  }

  /// 重置状态
  void reset() {
    _stopPolling();
    state = ScanProgress.idle;
  }

  /// 开始轮询
  void _startPolling() {
    _stopPolling();
    // 每 2 秒轮询一次
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      refreshProgress();
    });
    // 立即获取一次
    refreshProgress();
  }

  /// 停止轮询
  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }
}

/// 扫描进度 Provider
final scanProgressProvider =
    NotifierProvider<ScanProgressNotifier, ScanProgress>(
      ScanProgressNotifier.new,
    );

// ============================================================================
// Upgrade Progress Provider
// ============================================================================

// ============================================================================
// 自动扫描 Provider
// ============================================================================

/// 自动扫描配置 Notifier。
/// 业务端点：GET/PUT /api/v1/settings/auto-scan
class AutoScanNotifier extends AsyncNotifier<AutoScanSetting> {
  @override
  Future<AutoScanSetting> build() async {
    final api = ref.watch(settingsApiProvider);
    try {
      return await api.getAutoScan();
    } catch (_) {
      return AutoScanSetting(enabled: false, intervalSeconds: 3600);
    }
  }

  Future<void> setValue(AutoScanSetting value) async {
    state = AsyncValue.data(value);
    try {
      final api = ref.read(settingsApiProvider);
      await api.setAutoScan(value);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

/// 自动扫描配置 Provider
final autoScanProvider =
    AsyncNotifierProvider<AutoScanNotifier, AutoScanSetting>(
      AutoScanNotifier.new,
    );

// ============================================================================
// Auto-Create Playlists Provider
// ============================================================================

/// 「扫描后自动创建歌单」总开关 Notifier。
/// 开启后扫描会按目录结构自动生成歌单；关闭后仅导入歌曲不创建歌单。
/// 业务端点：GET/PUT /api/v1/settings/scan-auto-create-playlists
class AutoCreatePlaylistsNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final api = ref.watch(settingsApiProvider);
    try {
      return await api.getScanAutoCreatePlaylists();
    } catch (_) {
      return true;
    }
  }

  Future<void> setValue(bool value) async {
    state = AsyncValue.data(value);
    try {
      final api = ref.read(settingsApiProvider);
      await api.setScanAutoCreatePlaylists(value);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

/// 「扫描后自动创建歌单」Provider
final autoCreatePlaylistsProvider =
    AsyncNotifierProvider<AutoCreatePlaylistsNotifier, bool>(
      AutoCreatePlaylistsNotifier.new,
    );

// ============================================================================
// Auto-Create Playlists Include Subdirs Provider
// ============================================================================

/// 「扫描后自动创建歌单是否包含子目录」配置 Notifier。
/// 业务端点：GET/PUT /api/v1/settings/scan-auto-create-include-subdirs
class AutoCreateIncludeSubdirsNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final api = ref.watch(settingsApiProvider);
    try {
      return await api.getScanAutoCreateIncludeSubdirs();
    } catch (_) {
      return false;
    }
  }

  /// 切换并持久化
  Future<void> setValue(bool value) async {
    state = AsyncValue.data(value);
    try {
      final api = ref.read(settingsApiProvider);
      await api.setScanAutoCreateIncludeSubdirs(value);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

/// 「扫描后自动创建歌单是否包含子目录」Provider
final autoCreateIncludeSubdirsProvider =
    AsyncNotifierProvider<AutoCreateIncludeSubdirsNotifier, bool>(
      AutoCreateIncludeSubdirsNotifier.new,
    );

// ============================================================================
// 扫描标题来源 Provider
// ============================================================================

/// 扫描标题来源 Notifier。
/// tag：优先使用音频标签中的标题（默认）；filename：始终使用文件名作为标题。
/// 业务端点：GET/PUT /api/v1/settings/scan-title-source
class ScanTitleSourceNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    final api = ref.watch(settingsApiProvider);
    try {
      return await api.getScanTitleSource();
    } catch (_) {
      return 'tag';
    }
  }

  Future<void> setValue(String value) async {
    state = AsyncValue.data(value);
    try {
      final api = ref.read(settingsApiProvider);
      await api.setScanTitleSource(value);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

/// 扫描标题来源 Provider
final scanTitleSourceProvider =
    AsyncNotifierProvider<ScanTitleSourceNotifier, String>(
      ScanTitleSourceNotifier.new,
    );

// ============================================================================
// HLS 电台代理开关 Provider
// ============================================================================

/// HLS 反向代理开关 Notifier。
/// 开启后服务端拉取并改写电台 m3u8、代理切片;绕过 Referer 防盗链/CORS,但走本机带宽。
/// 业务端点：GET/PUT /api/v1/settings/hls-proxy
class HlsProxyEnabledNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final api = ref.watch(settingsApiProvider);
    try {
      return await api.getHlsProxyEnabled();
    } catch (_) {
      return false;
    }
  }

  Future<void> setValue(bool value) async {
    state = AsyncValue.data(value);
    try {
      final api = ref.read(settingsApiProvider);
      await api.setHlsProxyEnabled(value);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

/// HLS 电台代理开关 Provider
final hlsProxyEnabledProvider =
    AsyncNotifierProvider<HlsProxyEnabledNotifier, bool>(
      HlsProxyEnabledNotifier.new,
    );

// ============================================================================
// 日志等级 Provider
// ============================================================================

/// 日志等级 Notifier。
/// 业务端点：GET/PUT /api/v1/settings/log-level
/// 取值：debug / info / warn / error；改后服务端运行时即时切换 slog 全局等级。
class LogLevelNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    final api = ref.watch(settingsApiProvider);
    try {
      return await api.getLogLevel();
    } catch (_) {
      return 'info';
    }
  }

  Future<void> setValue(String value) async {
    state = AsyncValue.data(value);
    try {
      final api = ref.read(settingsApiProvider);
      await api.setLogLevel(value);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

/// 日志等级 Provider
final logLevelProvider = AsyncNotifierProvider<LogLevelNotifier, String>(
  LogLevelNotifier.new,
);

// ============================================================================
// HTTP 代理 Provider
// ============================================================================

/// HTTP 代理 Notifier。
/// 全局 HTTP 代理地址，所有后端外发请求通过此代理转发。
/// 业务端点：GET/PUT /api/v1/settings/http-proxy
class HttpProxyNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    final api = ref.watch(settingsApiProvider);
    try {
      return await api.getHttpProxy();
    } catch (_) {
      return '';
    }
  }

  Future<void> setValue(String value) async {
    state = AsyncValue.data(value);
    try {
      final api = ref.read(settingsApiProvider);
      await api.setHttpProxy(value);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

/// HTTP 代理 Provider
final httpProxyProvider = AsyncNotifierProvider<HttpProxyNotifier, String>(
  HttpProxyNotifier.new,
);

// ============================================================================
// Tab 配置 Provider
// ============================================================================

/// 底部导航栏 Tab 配置 Notifier。
/// 业务端点：GET/PUT /api/v1/settings/tab-config
class TabConfigNotifier extends AsyncNotifier<TabConfig> {
  @override
  Future<TabConfig> build() async {
    final api = ref.watch(settingsApiProvider);
    try {
      return await api.getTabConfig();
    } catch (_) {
      return TabConfig.defaultConfig();
    }
  }

  Future<void> updateConfig(TabConfig config) async {
    state = AsyncValue.data(config);
    try {
      final api = ref.read(settingsApiProvider);
      await api.updateTabConfig(config);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

/// 底部导航栏 Tab 配置 Provider
final tabConfigProvider = AsyncNotifierProvider<TabConfigNotifier, TabConfig>(
  TabConfigNotifier.new,
);

// ============================================================================
// Upgrade Progress Provider
// ============================================================================

/// 升级进度 Notifier
class UpgradeProgressNotifier extends Notifier<UpgradeProgress> {
  late UpgradeApi _upgradeApi;
  Timer? _pollTimer;

  @override
  UpgradeProgress build() {
    _upgradeApi = ref.watch(upgradeApiProvider);
    ref.onDispose(() {
      _stopPolling();
    });
    return UpgradeProgress.idle;
  }

  /// 开始升级
  /// [versionType] 版本类型：'stable' 或 'dev'
  /// [githubProxy] 为 GitHub 代理前缀，为空则直连
  Future<void> startUpgrade({
    required String versionType,
    String? githubProxy,
  }) async {
    try {
      await _upgradeApi.startUpgrade(
        versionType: versionType,
        githubProxy: githubProxy,
      );
      _startPolling();
    } catch (e) {
      state = UpgradeProgress(
        status: 'error',
        progress: 0,
        message: e.toString(),
      );
      rethrow;
    }
  }

  /// 回退到底包版本
  Future<void> resetToBaseImage() async {
    try {
      await _upgradeApi.resetToBaseImage();
      _startPolling();
    } catch (e) {
      state = UpgradeProgress(
        status: 'error',
        progress: 0,
        message: e.toString(),
      );
      rethrow;
    }
  }

  /// 刷新进度
  Future<void> refreshProgress() async {
    try {
      state = await _upgradeApi.getProgress();

      if (state.isCompleted || state.isError) {
        _stopPolling();
      }
    } catch (e) {
      // 获取进度失败忽略
    }
  }

  /// 重置状态
  void reset() {
    _stopPolling();
    state = UpgradeProgress.idle;
  }

  void _startPolling() {
    _stopPolling();
    // 每 1 秒轮询一次（升级过程较快，需要更频繁的轮询）
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      refreshProgress();
    });
    refreshProgress();
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }
}

/// 升级进度 Provider
final upgradeProgressProvider =
    NotifierProvider<UpgradeProgressNotifier, UpgradeProgress>(
      UpgradeProgressNotifier.new,
    );
