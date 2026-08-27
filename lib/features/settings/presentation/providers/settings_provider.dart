import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../l10n/l10n_holder.dart';
import '../../../../core/storage/preference_sync_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../desktop_lyric/android_floating_lyric_controller.dart';
import '../../../desktop_lyric/desktop_lyric_controller.dart';
import '../../../desktop_lyric/desktop_lyric_font_size.dart';
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
/// 带上已记住的 GitHub 代理，并加 30s 超时（后端代理失败会降级直连重试，
/// 最坏 12s+12s），避免网络不通时长时间转圈
final upgradeCheckProvider = FutureProvider<UpgradeCheck>((ref) async {
  final upgradeApi = ref.watch(upgradeApiProvider);
  final proxy = await ref.watch(githubProxyProvider.future);
  return upgradeApi
      .checkUpgrade(githubProxy: proxy.isNotEmpty ? proxy : null)
      .timeout(const Duration(seconds: 30));
});

/// 获取服务端版本号 + git commit + 构建时间。用于给开发版标注具体编译时刻，
/// 方便核对当前跑的到底是不是最新 dev 构建（缺失/unknown 时为 null）。
final serverVersionProvider = FutureProvider<
  ({String version, String? gitCommit, String? buildTime})
>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('${AppConfig.apiPrefix}/version');
  final data = response.data as Map<String, dynamic>;
  final version = data['version'] as String?;
  final commit = data['git_commit'] as String?;
  final built = data['build_time'] as String?;
  return (
    version:
        (version != null && version.isNotEmpty) ? version : l10n.commonUnknown,
    gitCommit:
        (commit != null && commit != 'unknown' && commit.isNotEmpty)
            ? commit
            : null,
    buildTime:
        (built != null && built != 'unknown' && built.isNotEmpty)
            ? built
            : null,
  );
});

/// 检查前端（客户端）更新
/// 带上已记住的 GitHub 代理（FrontendVersionApi 自带 10s 超时）
final frontendVersionCheckProvider = FutureProvider<FrontendVersionCheck>((
  ref,
) async {
  final api = ref.watch(frontendVersionApiProvider);
  final proxy = await ref.watch(githubProxyProvider.future);
  return api.checkUpdate(githubProxy: proxy.isNotEmpty ? proxy : null);
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
      pushPreferencesToServer(ref.read(dioProvider));
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
// Locale Provider
// ============================================================================

/// 应用语言 Notifier。
/// state 为 null 表示「跟随系统」；否则为 Locale('zh') / Locale('en')。
/// 仅本地持久化（SharedPreferences），不同步服务端。
class LocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() {
    _loadLocale();
    return null;
  }

  /// 从 AppPreferences 加载语言设置
  Future<void> _loadLocale() async {
    try {
      final prefs = await ref.read(appPreferencesProvider.future);
      state = prefs.getLocale();
    } catch (e) {
      // 加载失败使用默认值（跟随系统）
      state = null;
    }
  }

  /// 设置语言。传 null 表示「跟随系统」。
  Future<void> setLocale(Locale? locale) async {
    state = locale;
    try {
      final prefs = await ref.read(appPreferencesProvider.future);
      await prefs.setLocale(locale);
    } catch (e) {
      // 保存失败忽略
    }
  }
}

/// 应用语言 Provider
final localeProvider = NotifierProvider<LocaleNotifier, Locale?>(
  LocaleNotifier.new,
);

// ============================================================================
// Auto Update Check Provider
// ============================================================================

/// 「启动时自动检查更新」开关 Notifier（热更补丁 + 整包新版本提示）。
///
/// 缺省开启。关掉后启动路径完全不打网络，用户改由设置页「检查客户端更新」手动触发。
/// 仅本地持久化（SharedPreferences），不同步服务端 —— 这是设备本地策略。
class AutoUpdateCheckNotifier extends Notifier<bool> {
  /// 用户是否已经动过开关。`_load()` 是异步的，若它的续体在用户点击之后才落地，
  /// 会把刚设的值覆盖回旧的持久化值 —— 那时界面显示的和实际存的正好相反。
  bool _userTouched = false;

  @override
  bool build() {
    _userTouched = false;
    _load();
    return true;
  }

  Future<void> _load() async {
    try {
      final prefs = await ref.read(appPreferencesProvider.future);
      if (_userTouched) return; // 用户已表态，不拿旧值盖掉
      state = prefs.isAutoUpdateCheckEnabled();
    } catch (e) {
      if (!_userTouched) state = true; // 加载失败使用默认值（开启）
    }
  }

  Future<void> setEnabled(bool enabled) async {
    _userTouched = true;
    state = enabled;
    try {
      final prefs = await ref.read(appPreferencesProvider.future);
      await prefs.setAutoUpdateCheckEnabled(enabled);
    } catch (e) {
      // 保存失败忽略
    }
  }
}

/// 「启动时自动检查更新」开关 Provider
final autoUpdateCheckProvider = NotifierProvider<AutoUpdateCheckNotifier, bool>(
  AutoUpdateCheckNotifier.new,
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
  ///
  /// [paths] 非空时只扫描给定目录（目录级定向扫描），为空/null 时全库扫描。
  Future<void> startScan({bool reimport = false, List<String>? paths}) async {
    try {
      await _scanApi.startScan(reimport: reimport, paths: paths);
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
// Auto-Fingerprint Provider
// ============================================================================

/// 「扫描后自动计算音频指纹」总开关 Notifier。
/// 默认关闭：指纹只服务于「重复歌曲检测」和插件歌词/封面搜索，
/// 全库自动计算会在扫描完成后继续长时间占用 CPU。
/// 业务端点：GET/PUT /api/v1/settings/scan-auto-fingerprint
class ScanAutoFingerprintNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final api = ref.watch(settingsApiProvider);
    try {
      return await api.getScanAutoFingerprint();
    } catch (_) {
      return false;
    }
  }

  Future<void> setValue(bool value) async {
    state = AsyncValue.data(value);
    try {
      final api = ref.read(settingsApiProvider);
      await api.setScanAutoFingerprint(value);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

/// 「扫描后自动计算音频指纹」Provider
final scanAutoFingerprintProvider =
    AsyncNotifierProvider<ScanAutoFingerprintNotifier, bool>(
      ScanAutoFingerprintNotifier.new,
    );

// ============================================================================
// 标签同步写入文件 Provider
// ============================================================================

/// 「标签同步写入文件」开关 Notifier。
/// 开启后修改标签时自动将标签写入音频文件的 SONGLOFT_TAGS 字段。
/// 业务端点：GET/PUT /api/v1/settings/tag-sync-to-file
class TagSyncToFileNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final api = ref.watch(settingsApiProvider);
    try {
      return await api.getTagSyncToFile();
    } catch (_) {
      return false;
    }
  }

  Future<void> setValue(bool value) async {
    state = AsyncValue.data(value);
    try {
      final api = ref.read(settingsApiProvider);
      await api.setTagSyncToFile(value);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

/// 「标签同步写入文件」Provider
final tagSyncToFileProvider =
    AsyncNotifierProvider<TagSyncToFileNotifier, bool>(
      TagSyncToFileNotifier.new,
    );

// ============================================================================
// 歌单创建方式 Provider
// ============================================================================

/// 歌单创建方式 Notifier。
/// directory：按文件夹；top_level：按顶层文件夹合并；bubble_up：包含子目录。
/// 业务端点：GET/PUT /api/v1/settings/scan-playlist-mode
class ScanPlaylistModeNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    final api = ref.watch(settingsApiProvider);
    try {
      return await api.getScanPlaylistMode();
    } catch (_) {
      return 'directory';
    }
  }

  Future<void> setValue(String value) async {
    state = AsyncValue.data(value);
    try {
      final api = ref.read(settingsApiProvider);
      await api.setScanPlaylistMode(value);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

/// 歌单创建方式 Provider
final scanPlaylistModeProvider =
    AsyncNotifierProvider<ScanPlaylistModeNotifier, String>(
      ScanPlaylistModeNotifier.new,
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
// 音量均衡 Provider
// ============================================================================

/// EBU R128 音量均衡配置（开关 + 目标响度）。
/// 启用后服务端对不含显式 normalize 参数的播放请求自动执行 loudnorm 滤镜，
/// 消除不同音源之间的响度落差。需要 ffmpeg，会增加 CPU 和首次播放延迟。
/// 目标响度（LUFS）默认 -16，用户可自定义（-40 ~ -5，songloft-org/songloft-player#38）。
/// 业务端点：GET/PUT /api/v1/settings/volume-normalize
class VolumeNormalizeNotifier extends AsyncNotifier<VolumeNormalizeSetting> {
  @override
  Future<VolumeNormalizeSetting> build() async {
    final api = ref.watch(settingsApiProvider);
    try {
      return await api.getVolumeNormalize();
    } catch (_) {
      return const VolumeNormalizeSetting(enabled: false);
    }
  }

  /// 切换开关，响度保持当前值不变。
  Future<void> setEnabled(bool value) async {
    final current = state.value ?? const VolumeNormalizeSetting(enabled: false);
    state = AsyncValue.data(current.copyWith(enabled: value));
    try {
      final api = ref.read(settingsApiProvider);
      final updated = await api.setVolumeNormalize(
        VolumeNormalizeSetting(enabled: value, loudness: current.loudness),
      );
      state = AsyncValue.data(updated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// 设置目标响度（LUFS），开关保持当前值。前端先校验 [-40, -5]，越界抛错。
  Future<void> setLoudness(double value) async {
    if (value < -40 || value > -5) {
      throw ArgumentError('loudness $value 越界，需在 -40 ~ -5 LUFS');
    }
    final current = state.value ?? const VolumeNormalizeSetting(enabled: false);
    state = AsyncValue.data(current.copyWith(loudness: value));
    try {
      final api = ref.read(settingsApiProvider);
      final updated = await api.setVolumeNormalize(
        VolumeNormalizeSetting(enabled: current.enabled, loudness: value),
      );
      state = AsyncValue.data(updated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

/// 音量均衡配置 Provider
final volumeNormalizeProvider =
    AsyncNotifierProvider<VolumeNormalizeNotifier, VolumeNormalizeSetting>(
      VolumeNormalizeNotifier.new,
    );

// ============================================================================
// 私网代理白名单 Provider
// ============================================================================

/// 私网代理白名单 Notifier。
/// 白名单为空时 /proxy 拒绝一切私网地址（SSRF 防护）；填入单 IP / CIDR 网段后，
/// 目标解析到的私网地址命中白名单即放行（如公网 Songloft 代理内网 WebDAV）。
/// 业务端点：GET/PUT /api/v1/settings/proxy-private-allowlist
class ProxyPrivateAllowlistNotifier extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async {
    final api = ref.watch(settingsApiProvider);
    try {
      return await api.getProxyPrivateAllowlist();
    } catch (_) {
      return <String>[];
    }
  }

  /// 覆盖式保存白名单。后端校验失败（非法条目）时抛出，交由调用方提示。
  Future<void> setValue(List<String> allowlist) async {
    final api = ref.read(settingsApiProvider);
    final saved = await api.setProxyPrivateAllowlist(allowlist);
    state = AsyncValue.data(saved);
  }
}

/// 私网代理白名单 Provider
final proxyPrivateAllowlistProvider =
    AsyncNotifierProvider<ProxyPrivateAllowlistNotifier, List<String>>(
      ProxyPrivateAllowlistNotifier.new,
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

/// GitHub 更新代理 Notifier。
/// 检查更新 / 升级使用的 GitHub 代理前缀，记住上次使用的选择。
/// 业务端点：GET/PUT /api/v1/settings/github-proxy
class GithubProxyNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    final api = ref.watch(settingsApiProvider);
    try {
      return await api.getGithubProxy();
    } catch (_) {
      return '';
    }
  }

  Future<void> setValue(String value) async {
    // 与当前值相同时无需重复写入
    if (state.value == value) return;
    // 乐观更新，供检查更新等即时读取；保留数据态。
    state = AsyncValue.data(value);
    try {
      final api = ref.read(settingsApiProvider);
      await api.setGithubProxy(value);
    } catch (_) {
      // 持久化失败不影响本次会话使用，保留乐观值即可。
      // 本 Provider 被 upgradeCheckProvider 依赖，绝不能进入 error 态导致检查更新级联失败。
    }
  }
}

/// GitHub 更新代理 Provider
final githubProxyProvider = AsyncNotifierProvider<GithubProxyNotifier, String>(
  GithubProxyNotifier.new,
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
// 曲库浏览视图配置 Provider
// ============================================================================

/// 曲库浏览视图（显示 + 顺序）配置 Notifier。
/// 业务端点：GET/PUT /api/v1/settings/library-browse
class LibraryBrowseConfigNotifier extends AsyncNotifier<LibraryBrowseConfig> {
  @override
  Future<LibraryBrowseConfig> build() async {
    final api = ref.watch(settingsApiProvider);
    try {
      return await api.getLibraryBrowseConfig();
    } catch (_) {
      return LibraryBrowseConfig.defaultConfig();
    }
  }

  Future<void> updateConfig(LibraryBrowseConfig config) async {
    state = AsyncValue.data(config);
    try {
      final api = ref.read(settingsApiProvider);
      final saved = await api.updateLibraryBrowseConfig(config);
      state = AsyncValue.data(saved);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

/// 曲库浏览视图配置 Provider
final libraryBrowseConfigProvider =
    AsyncNotifierProvider<LibraryBrowseConfigNotifier, LibraryBrowseConfig>(
      LibraryBrowseConfigNotifier.new,
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

  /// 确认执行上传升级
  Future<void> confirmUploadUpgrade() async {
    try {
      await _upgradeApi.confirmUploadUpgrade();
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

// ============================================================================
// Audio Quality Provider (客户端本地偏好)
// ============================================================================

/// 音质偏好 Notifier
class AudioQualityNotifier extends Notifier<String> {
  @override
  String build() {
    _load();
    return 'original';
  }

  Future<void> _load() async {
    try {
      final prefs = await ref.read(appPreferencesProvider.future);
      state = prefs.getAudioQuality();
    } catch (_) {
      state = 'original';
    }
  }

  Future<void> setQuality(String quality) async {
    state = quality;
    try {
      final prefs = await ref.read(appPreferencesProvider.future);
      await prefs.setAudioQuality(quality);
      pushPreferencesToServer(ref.read(dioProvider));
    } catch (_) {}
  }
}

/// 音质偏好 Provider
final audioQualityProvider = NotifierProvider<AudioQualityNotifier, String>(
  AudioQualityNotifier.new,
);

/// 「打开客户端后自动播放」开关（纯本地，不同步服务器，
/// songloft-org/songloft-player#19）
class AutoPlayOnLaunchNotifier extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    try {
      final prefs = await ref.read(appPreferencesProvider.future);
      state = prefs.getAutoPlayOnLaunch();
    } catch (_) {
      state = false;
    }
  }

  Future<void> setEnabled(bool value) async {
    state = value;
    try {
      final prefs = await ref.read(appPreferencesProvider.future);
      await prefs.setAutoPlayOnLaunch(value);
      // 注意：本地设置，刻意不调用 pushPreferencesToServer
    } catch (_) {}
  }
}

/// 打开客户端后自动播放 Provider
final autoPlayOnLaunchProvider =
    NotifierProvider<AutoPlayOnLaunchNotifier, bool>(
      AutoPlayOnLaunchNotifier.new,
    );

/// 全局字体缩放（纯本地，不同步服务器，songloft-org/songloft#418）
class FontScaleNotifier extends Notifier<double> {
  @override
  double build() {
    _load();
    return 1.0;
  }

  Future<void> _load() async {
    try {
      final prefs = await ref.read(appPreferencesProvider.future);
      state = prefs.getFontScale();
    } catch (_) {
      state = 1.0;
    }
  }

  Future<void> setScale(double scale) async {
    state = scale;
    try {
      final prefs = await ref.read(appPreferencesProvider.future);
      await prefs.setFontScale(scale);
    } catch (_) {}
  }
}

final fontScaleProvider = NotifierProvider<FontScaleNotifier, double>(
  FontScaleNotifier.new,
);

/// 「打开客户端后自动进入全屏歌词」开关（纯本地，不同步服务器，与自动播放独立，
/// songloft-org/songloft-player#19）
class AutoEnterLyricsOnLaunchNotifier extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    try {
      final prefs = await ref.read(appPreferencesProvider.future);
      state = prefs.getAutoEnterLyricsOnLaunch();
    } catch (_) {
      state = false;
    }
  }

  Future<void> setEnabled(bool value) async {
    state = value;
    try {
      final prefs = await ref.read(appPreferencesProvider.future);
      await prefs.setAutoEnterLyricsOnLaunch(value);
      // 注意：本地设置，刻意不调用 pushPreferencesToServer
    } catch (_) {}
  }
}

/// 打开客户端后自动进入全屏歌词 Provider
final autoEnterLyricsOnLaunchProvider =
    NotifierProvider<AutoEnterLyricsOnLaunchNotifier, bool>(
      AutoEnterLyricsOnLaunchNotifier.new,
    );

/// 「系统媒体通知里歌词显示在标题行」开关（纯本地，不同步服务器）。
/// 开启（默认）：标题=歌词、副标题="歌名 - 艺术家"；关闭：标题=歌名、副标题=纯歌词。
class NotificationLyricInTitleNotifier extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return true;
  }

  Future<void> _load() async {
    try {
      final prefs = await ref.read(appPreferencesProvider.future);
      state = prefs.getNotificationLyricInTitle();
    } catch (_) {
      state = true;
    }
  }

  Future<void> setEnabled(bool value) async {
    state = value;
    try {
      final prefs = await ref.read(appPreferencesProvider.future);
      await prefs.setNotificationLyricInTitle(value);
      // 注意：本地设置，刻意不调用 pushPreferencesToServer
    } catch (_) {}
  }
}

/// 系统媒体通知歌词显示位置 Provider
final notificationLyricInTitleProvider =
    NotifierProvider<NotificationLyricInTitleNotifier, bool>(
      NotificationLyricInTitleNotifier.new,
    );

// ============================================================================
// 悬浮歌词窗口 Provider（Windows 桌面窗口 / Android 系统悬浮窗共用一套开关，
// 纯本地设置，songloft-org/songloft#318）
// ============================================================================

bool get _desktopLyricSupported =>
    !kIsWeb && (Platform.isWindows || Platform.isAndroid);

/// 悬浮窗已打开时，把当前锁定/字号/透明度整体推给它实时生效。
Future<void> _pushDesktopLyricConfig(Ref ref) async {
  if (!_desktopLyricSupported) return;
  final locked = ref.read(desktopLyricLockedProvider);
  final fontSize = ref.read(desktopLyricFontSizeProvider);
  final opacity = ref.read(desktopLyricOpacityProvider);
  if (!kIsWeb && Platform.isAndroid) {
    await ref
        .read(androidFloatingLyricControllerProvider)
        .pushConfig(locked: locked, fontSize: fontSize, opacity: opacity);
  } else {
    await ref
        .read(desktopLyricControllerProvider)
        .pushConfig(locked: locked, fontSize: fontSize, opacity: opacity);
  }
}

/// 打开悬浮窗（按平台分发）。**Android 的权限申请只发生在这里**——也就是
/// 用户真的把设置页开关打开的这一刻，绝不在启动时或其它任何地方主动申请。
/// 返回 false 表示没打开成功（Android 用户拒绝了权限，或当前平台不支持）。
Future<bool> _openDesktopLyric(Ref ref) async {
  if (!kIsWeb && Platform.isAndroid) {
    var granted = (await Permission.systemAlertWindow.status).isGranted;
    if (!granted) {
      granted = (await Permission.systemAlertWindow.request()).isGranted;
    }
    if (!granted) return false;
    return ref.read(androidFloatingLyricControllerProvider).open();
  }
  if (!kIsWeb && Platform.isWindows) {
    await ref.read(desktopLyricControllerProvider).open();
    return true;
  }
  return false;
}

Future<void> _closeDesktopLyric(Ref ref) async {
  if (!kIsWeb && Platform.isAndroid) {
    await ref.read(androidFloatingLyricControllerProvider).close();
  } else if (!kIsWeb && Platform.isWindows) {
    await ref.read(desktopLyricControllerProvider).close();
  }
}

/// 桌面歌词总开关
class DesktopLyricEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    try {
      final prefs = await ref.read(appPreferencesProvider.future);
      final enabled = prefs.getDesktopLyricEnabled();
      if (!enabled || !_desktopLyricSupported) {
        if (prefs.getDesktopLyricOpening()) {
          // 开关未落盘就崩在 open() 里的残留哨兵，顺手清掉
          await prefs.setDesktopLyricOpening(false);
        }
        state = enabled;
        return;
      }
      if (prefs.getDesktopLyricOpening()) {
        // 上次进程死在 open() 半途（原生崩溃）。自动关掉开关，否则每次进设置页都会
        // 重走同一条崩溃路径，用户在界面上永远碰不到这个开关。详见 getDesktopLyricOpening。
        await prefs.setDesktopLyricOpening(false);
        await prefs.setDesktopLyricEnabled(false);
        state = false;
        return;
      }
      if (!kIsWeb && Platform.isAndroid) {
        // 启动时只检查权限状态，绝不主动申请；权限已被用户在系统设置里
        // 收回的话就静默关掉开关，不弹权限申请打扰用户。
        final granted = (await Permission.systemAlertWindow.status).isGranted;
        if (!granted) {
          state = false;
          await prefs.setDesktopLyricEnabled(false);
          return;
        }
        final opened =
            await ref.read(androidFloatingLyricControllerProvider).open();
        state = opened;
        if (!opened) {
          // 权限够但悬浮窗没建成功（部分厂商 ROM 限制等），别让开关显示假的开启状态
          await prefs.setDesktopLyricEnabled(false);
        }
        return;
      }
      // Windows：上次退出前是开启状态，启动时自动恢复悬浮窗
      state = true;
      await prefs.setDesktopLyricOpening(true);
      await ref.read(desktopLyricControllerProvider).open();
      await prefs.setDesktopLyricOpening(false);
    } catch (_) {
      state = false;
    }
  }

  Future<void> setEnabled(bool value) async {
    try {
      final prefs = await ref.read(appPreferencesProvider.future);
      if (value) {
        if (_desktopLyricSupported) {
          // 哨兵包住 open()：崩在半途时下次启动能自愈（见 getDesktopLyricOpening）
          await prefs.setDesktopLyricOpening(true);
          final opened = await _openDesktopLyric(ref);
          await prefs.setDesktopLyricOpening(false);
          if (!opened) {
            // Android 用户拒绝了悬浮窗权限：开关维持关闭，不落盘
            state = false;
            return;
          }
        }
        state = true;
        await prefs.setDesktopLyricEnabled(true);
      } else {
        state = false;
        await prefs.setDesktopLyricEnabled(false);
        // 注意：本地设置，刻意不调用 pushPreferencesToServer
        if (_desktopLyricSupported) {
          await _closeDesktopLyric(ref);
        }
      }
    } catch (_) {}
  }
}

final desktopLyricEnabledProvider =
    NotifierProvider<DesktopLyricEnabledNotifier, bool>(
      DesktopLyricEnabledNotifier.new,
    );

/// 桌面歌词锁定位置开关（锁定后点击穿透、不可拖动）
class DesktopLyricLockedNotifier extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    try {
      final prefs = await ref.read(appPreferencesProvider.future);
      state = prefs.getDesktopLyricLocked();
    } catch (_) {
      state = false;
    }
  }

  Future<void> setLocked(bool value) async {
    state = value;
    try {
      final prefs = await ref.read(appPreferencesProvider.future);
      await prefs.setDesktopLyricLocked(value);
      await _pushDesktopLyricConfig(ref);
    } catch (_) {}
  }
}

final desktopLyricLockedProvider =
    NotifierProvider<DesktopLyricLockedNotifier, bool>(
      DesktopLyricLockedNotifier.new,
    );

/// 桌面歌词字号档位
class DesktopLyricFontSizeNotifier extends Notifier<DesktopLyricFontSize> {
  @override
  DesktopLyricFontSize build() {
    _load();
    return DesktopLyricFontSize.medium;
  }

  Future<void> _load() async {
    try {
      final prefs = await ref.read(appPreferencesProvider.future);
      state = DesktopLyricFontSizeX.fromStorageValue(
        prefs.getDesktopLyricFontSize(),
      );
    } catch (_) {
      state = DesktopLyricFontSize.medium;
    }
  }

  Future<void> setFontSize(DesktopLyricFontSize value) async {
    state = value;
    try {
      final prefs = await ref.read(appPreferencesProvider.future);
      await prefs.setDesktopLyricFontSize(value.storageValue);
      await _pushDesktopLyricConfig(ref);
    } catch (_) {}
  }
}

final desktopLyricFontSizeProvider =
    NotifierProvider<DesktopLyricFontSizeNotifier, DesktopLyricFontSize>(
      DesktopLyricFontSizeNotifier.new,
    );

/// 桌面歌词背景透明度 (0.0~0.8)
class DesktopLyricOpacityNotifier extends Notifier<double> {
  @override
  double build() {
    _load();
    return 0.4;
  }

  Future<void> _load() async {
    try {
      final prefs = await ref.read(appPreferencesProvider.future);
      state = prefs.getDesktopLyricOpacity();
    } catch (_) {
      state = 0.4;
    }
  }

  Future<void> setOpacity(double value) async {
    state = value;
    try {
      final prefs = await ref.read(appPreferencesProvider.future);
      await prefs.setDesktopLyricOpacity(value);
      await _pushDesktopLyricConfig(ref);
    } catch (_) {}
  }
}

final desktopLyricOpacityProvider =
    NotifierProvider<DesktopLyricOpacityNotifier, double>(
      DesktopLyricOpacityNotifier.new,
    );

// ============================================================================
// Web 调试控制台 Provider（仅 Web 端使用，纯本地设置）
// ============================================================================

class WebDebugConsoleNotifier extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    try {
      final prefs = await ref.read(appPreferencesProvider.future);
      state = prefs.getWebDebugConsole();
    } catch (_) {
      state = false;
    }
  }

  Future<void> setEnabled(bool value) async {
    state = value;
    try {
      final prefs = await ref.read(appPreferencesProvider.future);
      await prefs.setWebDebugConsole(value);
    } catch (_) {}
  }
}

final webDebugConsoleProvider = NotifierProvider<WebDebugConsoleNotifier, bool>(
  WebDebugConsoleNotifier.new,
);

// ============================================================================
// 网络歌曲标题来源 Provider
// ============================================================================

/// 业务端点：GET/PUT /api/v1/settings/remote-title-source
class RemoteTitleSourceNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    final api = ref.watch(settingsApiProvider);
    try {
      return await api.getRemoteTitleSource();
    } catch (_) {
      return 'filename';
    }
  }

  Future<void> setValue(String value) async {
    final previous = state.value ?? 'filename';
    state = AsyncValue.data(value);
    try {
      final api = ref.read(settingsApiProvider);
      await api.setRemoteTitleSource(value);
    } catch (_) {
      state = AsyncValue.data(previous);
      rethrow;
    }
  }
}

final remoteTitleSourceProvider =
    AsyncNotifierProvider<RemoteTitleSourceNotifier, String>(
      RemoteTitleSourceNotifier.new,
    );

// ============================================================================
// Metadata Refresh Provider
// ============================================================================

class MetadataRefreshNotifier extends Notifier<MetadataRefreshProgress> {
  late SettingsApi _api;
  Timer? _pollTimer;

  @override
  MetadataRefreshProgress build() {
    _api = ref.watch(settingsApiProvider);
    ref.onDispose(() {
      _stopPolling();
    });
    return MetadataRefreshProgress.idle;
  }

  Future<void> startRefresh() async {
    try {
      await _api.startMetadataRefresh();
      state = const MetadataRefreshProgress(
        status: 'running',
        total: 0,
        processed: 0,
        failed: 0,
      );
      _startPolling();
    } catch (_) {}
  }

  Future<void> refreshProgress() async {
    try {
      final progress = await _api.getMetadataRefreshProgress();
      state = progress;
      if (progress.isDone) {
        _stopPolling();
      }
    } catch (_) {}
  }

  Future<void> cancel() async {
    try {
      await _api.cancelMetadataRefresh();
      _stopPolling();
      await refreshProgress();
    } catch (_) {}
  }

  void _startPolling() {
    _stopPolling();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => refreshProgress(),
    );
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }
}

final metadataRefreshProvider =
    NotifierProvider<MetadataRefreshNotifier, MetadataRefreshProgress>(
      MetadataRefreshNotifier.new,
    );
