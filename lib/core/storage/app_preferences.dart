import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/server_entry.dart';

/// 应用偏好设置存储
class AppPreferences {
  static const _themeModeKey = 'theme_mode';
  static const _localeKey = 'app_locale';
  static const _apiBaseUrlKey = 'api_base_url';
  static const _apiServersKey = 'api_servers';
  static const _lastUsedDeviceKey = 'last_used_device';
  static const _volumeKey = 'player_volume';
  static const _playModeKey = 'player_play_mode';
  static const _playlistViewModeKey = 'playlist_view_mode';
  static const _lastUsernameKey = 'last_username';
  static const _lastPasswordKey = 'last_password';
  static const _currentIndexKey = 'player_current_index';
  static const _positionMsKey = 'player_position_ms';
  static const _sourcePlaylistIdKey = 'player_source_playlist_id';

  final SharedPreferences _prefs;

  AppPreferences(this._prefs);

  /// 异步创建实例
  static Future<AppPreferences> create() async {
    final prefs = await SharedPreferences.getInstance();
    return AppPreferences(prefs);
  }

  /// 获取主题模式
  ThemeMode getThemeMode() {
    final value = _prefs.getString(_themeModeKey);
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  /// 设置主题模式
  Future<bool> setThemeMode(ThemeMode mode) {
    String value;
    switch (mode) {
      case ThemeMode.light:
        value = 'light';
      case ThemeMode.dark:
        value = 'dark';
      case ThemeMode.system:
        value = 'system';
    }
    return _prefs.setString(_themeModeKey, value);
  }

  /// 获取应用语言。
  /// 返回 null 表示「跟随系统」；否则为 Locale('zh') / Locale('en')。
  Locale? getLocale() {
    final value = _prefs.getString(_localeKey);
    if (value == null || value.isEmpty) return null;
    return Locale(value);
  }

  /// 设置应用语言。传 null 表示「跟随系统」（清除持久化值）。
  Future<bool> setLocale(Locale? locale) {
    if (locale == null) {
      return _prefs.remove(_localeKey).then((_) => true);
    }
    return _prefs.setString(_localeKey, locale.languageCode);
  }

  /// 获取自定义 API 地址（独立部署模式，旧版单地址）
  @Deprecated('使用 getApiServers()；保留仅为迁移使用')
  String? getApiBaseUrl() {
    return _prefs.getString(_apiBaseUrlKey);
  }

  /// 设置自定义 API 地址（旧版单地址）
  @Deprecated('使用 setApiServers()；保留仅为迁移使用')
  Future<bool> setApiBaseUrl(String url) {
    return _prefs.setString(_apiBaseUrlKey, url);
  }

  /// 清除自定义 API 地址（旧版单地址）
  @Deprecated('使用 setApiServers([])；保留仅为迁移使用')
  Future<bool> clearApiBaseUrl() {
    return _prefs.remove(_apiBaseUrlKey);
  }

  /// 获取服务器列表（顺序即启动探测优先级）
  List<ServerEntry> getApiServers() {
    final raw = _prefs.getString(_apiServersKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(ServerEntry.fromJson)
          .toList(growable: false);
    } catch (e) {
      debugPrint('[AppPreferences] 解析 api_servers 失败: $e');
      return const [];
    }
  }

  /// 设置服务器列表，按 url 去重（保留首次出现的 entry）。
  Future<bool> setApiServers(List<ServerEntry> servers) {
    final seen = <String>{};
    final deduped = <ServerEntry>[];
    for (final s in servers) {
      if (seen.add(s.url)) deduped.add(s);
    }
    final encoded = jsonEncode(deduped.map((s) => s.toJson()).toList());
    return _prefs.setString(_apiServersKey, encoded);
  }

  /// 幂等：若新 key 为空且旧 `api_base_url` 有值，promote 为单条 ServerEntry，
  /// 然后清除旧 key。已迁移过的设备多次调用无副作用。
  Future<void> migrateLegacyApiBaseUrl() async {
    final hasNew = _prefs.containsKey(_apiServersKey);
    final legacy = _prefs.getString(_apiBaseUrlKey);
    if (legacy == null || legacy.isEmpty) {
      // 没有旧值，无须迁移
      if (_prefs.containsKey(_apiBaseUrlKey)) {
        await _prefs.remove(_apiBaseUrlKey);
      }
      return;
    }
    if (!hasNew) {
      try {
        final url = ServerEntry.normalizeUrl(legacy);
        final entry = ServerEntry(
          id: ServerEntry.generateId(),
          name: '',
          url: url,
        );
        await setApiServers([entry]);
      } catch (e) {
        debugPrint('[AppPreferences] 旧 api_base_url 规范化失败，跳过迁移: $e');
      }
    }
    await _prefs.remove(_apiBaseUrlKey);
  }

  /// 获取最后使用的设备 ID
  String? getLastUsedDevice() {
    return _prefs.getString(_lastUsedDeviceKey);
  }

  /// 设置最后使用的设备 ID
  Future<bool> setLastUsedDevice(String deviceId) {
    return _prefs.setString(_lastUsedDeviceKey, deviceId);
  }

  /// 清除最后使用的设备
  Future<bool> clearLastUsedDevice() {
    return _prefs.remove(_lastUsedDeviceKey);
  }

  /// 获取播放器音量 (0-100)
  /// 返回存储的音量值，默认为 50
  double getVolume() {
    return _prefs.getDouble(_volumeKey) ?? 50.0;
  }

  /// 设置播放器音量 (0-100)
  Future<bool> setVolume(double volume) {
    return _prefs.setDouble(_volumeKey, volume);
  }

  /// 获取播放模式
  /// 返回播放模式字符串，默认为 'order'
  String getPlayMode() {
    return _prefs.getString(_playModeKey) ?? 'order';
  }

  /// 设置播放模式
  Future<bool> setPlayMode(String mode) {
    return _prefs.setString(_playModeKey, mode);
  }

  /// 获取歌单视图模式 ('grid' 或 'list')
  String getPlaylistViewMode() {
    return _prefs.getString(_playlistViewModeKey) ?? 'grid';
  }

  /// 设置歌单视图模式
  Future<bool> setPlaylistViewMode(String mode) {
    return _prefs.setString(_playlistViewModeKey, mode);
  }

  /// 获取上次登录的用户名
  String? getLastUsername() {
    return _prefs.getString(_lastUsernameKey);
  }

  /// 设置上次登录的用户名
  Future<bool> setLastUsername(String username) {
    return _prefs.setString(_lastUsernameKey, username);
  }

  /// 获取上次登录的密码
  String? getLastPassword() {
    return _prefs.getString(_lastPasswordKey);
  }

  /// 设置上次登录的密码
  Future<bool> setLastPassword(String password) {
    return _prefs.setString(_lastPasswordKey, password);
  }

  /// 本地缓存大小上限 key
  static const _audioQualityKey = 'player_audio_quality';

  /// 获取音质偏好
  /// 返回 'original'(默认)、'128'、'192'、'320'
  String getAudioQuality() {
    return _prefs.getString(_audioQualityKey) ?? 'original';
  }

  /// 设置音质偏好
  Future<bool> setAudioQuality(String quality) {
    return _prefs.setString(_audioQualityKey, quality);
  }

  static const _insecureTlsKey = 'network_insecure_tls';

  /// 是否忽略 HTTPS 证书校验（默认 false，安全）
  bool getInsecureTls() {
    return _prefs.getBool(_insecureTlsKey) ?? false;
  }

  /// 设置是否忽略 HTTPS 证书校验
  Future<bool> setInsecureTls(bool value) {
    return _prefs.setBool(_insecureTlsKey, value);
  }

  static const _localCacheMaxSizeKey = 'local_cache_max_size';

  /// 获取本地缓存大小上限（字节），默认 1 GB，0 表示不限制
  int getLocalCacheMaxSize() {
    return _prefs.getInt(_localCacheMaxSizeKey) ?? (1024 * 1024 * 1024);
  }

  /// 设置本地缓存大小上限（字节），0 表示不限制
  Future<bool> setLocalCacheMaxSize(int maxSize) {
    return _prefs.setInt(_localCacheMaxSizeKey, maxSize);
  }

  int getCurrentIndex() {
    return _prefs.getInt(_currentIndexKey) ?? -1;
  }

  Future<bool> setCurrentIndex(int index) {
    return _prefs.setInt(_currentIndexKey, index);
  }

  int getPositionMs() {
    return _prefs.getInt(_positionMsKey) ?? 0;
  }

  Future<bool> setPositionMs(int ms) {
    return _prefs.setInt(_positionMsKey, ms);
  }

  int? getSourcePlaylistId() {
    return _prefs.getInt(_sourcePlaylistIdKey);
  }

  Future<bool> setSourcePlaylistId(int? id) {
    if (id == null) return _prefs.remove(_sourcePlaylistIdKey).then((_) => true);
    return _prefs.setInt(_sourcePlaylistIdKey, id);
  }

  Future<void> clearPlaybackState() async {
    await _prefs.remove(_currentIndexKey);
    await _prefs.remove(_positionMsKey);
    await _prefs.remove(_sourcePlaylistIdKey);
  }

  static const _shortcutsEnabledKey = 'shortcuts_enabled';
  static const _shortcutBindingsKey = 'shortcut_bindings';

  /// 桌面播放快捷键总开关（默认启用）
  bool getShortcutsEnabled() {
    return _prefs.getBool(_shortcutsEnabledKey) ?? true;
  }

  Future<bool> setShortcutsEnabled(bool value) {
    return _prefs.setBool(_shortcutsEnabledKey, value);
  }

  static const _autoPlayOnLaunchKey = 'player_auto_play_on_launch';

  /// 打开客户端后是否自动继续播放上次的歌曲（默认关闭）。
  /// 纯本地设置，不参与服务器偏好同步（songloft-org/songloft-player#19）。
  bool getAutoPlayOnLaunch() {
    return _prefs.getBool(_autoPlayOnLaunchKey) ?? false;
  }

  Future<bool> setAutoPlayOnLaunch(bool value) {
    return _prefs.setBool(_autoPlayOnLaunchKey, value);
  }

  static const _autoEnterLyricsOnLaunchKey =
      'player_auto_enter_lyrics_on_launch';

  static const _webDebugConsoleKey = 'web_debug_console';

  /// 打开客户端后是否自动进入全屏歌词界面（默认关闭）。与「自动播放」相互独立：
  /// 只要启动后成功恢复出上次的歌曲，就按屏幕分辨率进入对应的全屏歌词界面。
  /// 纯本地设置，不参与服务器偏好同步（songloft-org/songloft-player#19）。
  bool getAutoEnterLyricsOnLaunch() {
    return _prefs.getBool(_autoEnterLyricsOnLaunchKey) ?? false;
  }

  Future<bool> setAutoEnterLyricsOnLaunch(bool value) {
    return _prefs.setBool(_autoEnterLyricsOnLaunchKey, value);
  }

  static const _notificationLyricInTitleKey =
      'player_notification_lyric_in_title';

  /// 系统媒体通知（通知栏/锁屏/桌面媒体控件）里歌词的显示位置（默认开启）。
  /// 开启：标题行显示当前歌词、歌名归副标题；关闭：标题行显示歌名、副标题显示纯歌词。
  /// 纯本地设置，不参与服务器偏好同步。
  bool getNotificationLyricInTitle() {
    return _prefs.getBool(_notificationLyricInTitleKey) ?? true;
  }

  Future<bool> setNotificationLyricInTitle(bool value) {
    return _prefs.setBool(_notificationLyricInTitleKey, value);
  }

  bool getWebDebugConsole() {
    return _prefs.getBool(_webDebugConsoleKey) ?? false;
  }

  Future<bool> setWebDebugConsole(bool value) {
    return _prefs.setBool(_webDebugConsoleKey, value);
  }

  /// 快捷键绑定表（原始 JSON 字符串，解析在 provider 层做）。null 表示从未自定义。
  String? getShortcutBindings() {
    return _prefs.getString(_shortcutBindingsKey);
  }

  Future<bool> setShortcutBindings(String json) {
    return _prefs.setString(_shortcutBindingsKey, json);
  }

  Future<bool> clearShortcutBindings() {
    return _prefs.remove(_shortcutBindingsKey);
  }

  /// 清除所有偏好设置
  Future<bool> clear() {
    return _prefs.clear();
  }
}
