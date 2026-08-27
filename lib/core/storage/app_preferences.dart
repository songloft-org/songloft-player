import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/player/domain/playback_context.dart';
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
  static const _sourceContextKey = 'player_source_context';
  // 热更新「忽略此版本」：分别记忆被忽略的补丁版本、被忽略的整包客户端版本
  static const _ignoredPatchVersionKey = 'ignored_patch_version';
  static const _ignoredClientVersionKey = 'ignored_client_version';
  // Bundle 版 Android 后端热更（换 libgojni.so）被忽略的补丁版本
  static const _ignoredBackendPatchVersionKey = 'ignored_backend_patch_version';
  // 启动更新检查的跨会话节流时间戳 + 「启动时自动检查」开关
  static const _lastPatchCheckAtKey = 'last_patch_check_at';
  static const _autoUpdateCheckKey = 'auto_update_check_enabled';

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

  /// 被忽略的补丁版本（热更新「忽略此版本」）；无则 null
  String? getIgnoredPatchVersion() => _prefs.getString(_ignoredPatchVersionKey);

  /// 记住忽略某个补丁版本
  Future<bool> setIgnoredPatchVersion(String version) =>
      _prefs.setString(_ignoredPatchVersionKey, version);

  /// 被忽略的整包客户端版本（「不兼容」提示的忽略）；无则 null
  String? getIgnoredClientVersion() =>
      _prefs.getString(_ignoredClientVersionKey);

  /// 记住忽略某个整包客户端版本
  Future<bool> setIgnoredClientVersion(String version) =>
      _prefs.setString(_ignoredClientVersionKey, version);

  /// 被忽略的后端补丁版本（Bundle 版 Android 后端热更「忽略此版本」）；无则 null
  String? getIgnoredBackendPatchVersion() =>
      _prefs.getString(_ignoredBackendPatchVersionKey);

  /// 记住忽略某个后端补丁版本
  Future<bool> setIgnoredBackendPatchVersion(String version) =>
      _prefs.setString(_ignoredBackendPatchVersionKey, version);

  /// 上次启动更新检查的时刻（millisecondsSinceEpoch）；从未检查过为 0
  int getLastPatchCheckAt() => _prefs.getInt(_lastPatchCheckAtKey) ?? 0;

  /// 记住本次启动更新检查的时刻
  Future<bool> setLastPatchCheckAt(int millisSinceEpoch) =>
      _prefs.setInt(_lastPatchCheckAtKey, millisSinceEpoch);

  /// 启动时是否自动检查更新（热更补丁 + 整包新版本提示）；缺省开启
  bool isAutoUpdateCheckEnabled() =>
      _prefs.getBool(_autoUpdateCheckKey) ?? true;

  /// 设置启动时是否自动检查更新
  Future<bool> setAutoUpdateCheckEnabled(bool enabled) =>
      _prefs.setBool(_autoUpdateCheckKey, enabled);

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

  /// 播放来源已泛化为 [PlaybackContext]，请改用 [getSourceContext]。
  /// 保留仅为兼容可能残留的旧调用方。
  @Deprecated('改用 getSourceContext()')
  int? getSourcePlaylistId() {
    return _prefs.getInt(_sourcePlaylistIdKey);
  }

  /// 播放来源已泛化为 [PlaybackContext]，请改用 [setSourceContext]。
  ///
  /// 单独调用本方法会让新 key `player_source_context` 与旧 key 不一致，
  /// 导致 [getSourceContext] 读回过期的上下文 —— 写入一律走 [setSourceContext]。
  @Deprecated('改用 setSourceContext()，否则新旧 key 会不一致')
  Future<bool> setSourcePlaylistId(int? id) {
    if (id == null) {
      return _prefs.remove(_sourcePlaylistIdKey).then((_) => true);
    }
    return _prefs.setInt(_sourcePlaylistIdKey, id);
  }

  /// 读取播放队列的来源上下文。
  ///
  /// 新 key 缺失时回退到旧的 `player_source_playlist_id`，让升级前保存的播放状态
  /// 仍能恢复出歌单上下文。
  PlaybackContext? getSourceContext() {
    final raw = _prefs.getString(_sourceContextKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          final ctx = PlaybackContext.fromJson(decoded);
          if (ctx != null) return ctx;
        }
      } catch (_) {
        // 损坏的 JSON 当作没有上下文，不阻塞播放状态恢复
      }
    }
    final legacyId = _prefs.getInt(_sourcePlaylistIdKey);
    return legacyId == null ? null : PlaybackContext.playlist(legacyId);
  }

  /// 写入播放队列的来源上下文。
  ///
  /// 同时维护旧的 `player_source_playlist_id`：Android 热更新回滚到旧版
  /// `libapp.so` 后，旧代码只认得那个 key。
  Future<void> setSourceContext(PlaybackContext? context) async {
    if (context == null) {
      await _prefs.remove(_sourceContextKey);
      await _prefs.remove(_sourcePlaylistIdKey);
      return;
    }
    await _prefs.setString(_sourceContextKey, jsonEncode(context.toJson()));
    final playlistId = context.playlistId;
    if (playlistId == null) {
      await _prefs.remove(_sourcePlaylistIdKey);
    } else {
      await _prefs.setInt(_sourcePlaylistIdKey, playlistId);
    }
  }

  Future<void> clearPlaybackState() async {
    await _prefs.remove(_currentIndexKey);
    await _prefs.remove(_positionMsKey);
    await _prefs.remove(_sourcePlaylistIdKey);
    await _prefs.remove(_sourceContextKey);
  }

  // ── 每个播放上下文（歌单/分面维度）最后播放的歌曲 ──

  static const _contextLastSongKey = 'context_last_song_map';
  static const _contextLastSongMaxEntries = 200;

  String _contextKey(PlaybackContext ctx) => '${ctx.type}:${ctx.key}';

  Map<String, int> _getContextLastSongMap() {
    final raw = _prefs.getString(_contextLastSongKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded.map((k, v) => MapEntry(k, v as int));
      }
    } catch (_) {}
    return {};
  }

  Future<void> setLastPlayedSong(PlaybackContext ctx, int songId) async {
    final map = _getContextLastSongMap();
    final key = _contextKey(ctx);
    map.remove(key);
    map[key] = songId;
    while (map.length > _contextLastSongMaxEntries) {
      map.remove(map.keys.first);
    }
    await _prefs.setString(_contextLastSongKey, jsonEncode(map));
  }

  int? getLastPlayedSong(PlaybackContext ctx) {
    return _getContextLastSongMap()[_contextKey(ctx)];
  }

  Future<void> clearLastPlayedSong(PlaybackContext ctx) async {
    final map = _getContextLastSongMap();
    if (map.remove(_contextKey(ctx)) != null) {
      await _prefs.setString(_contextLastSongKey, jsonEncode(map));
    }
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

  static const _desktopLyricEnabledKey = 'desktop_lyric_enabled';
  static const _desktopLyricLockedKey = 'desktop_lyric_locked';
  static const _desktopLyricFontSizeKey = 'desktop_lyric_font_size';
  static const _desktopLyricOpacityKey = 'desktop_lyric_opacity';
  static const _desktopLyricPosXKey = 'desktop_lyric_pos_x';
  static const _desktopLyricPosYKey = 'desktop_lyric_pos_y';
  static const _desktopLyricOpeningKey = 'desktop_lyric_opening';

  /// 桌面歌词悬浮窗总开关（默认关闭，目前仅 Windows 支持，songloft-org/songloft#318）。
  /// 纯本地设置，不参与服务器偏好同步。
  bool getDesktopLyricEnabled() {
    return _prefs.getBool(_desktopLyricEnabledKey) ?? false;
  }

  Future<bool> setDesktopLyricEnabled(bool value) {
    return _prefs.setBool(_desktopLyricEnabledKey, value);
  }

  /// 「正在打开悬浮窗」哨兵：open() 前置 true、返回后清 false。
  ///
  /// 悬浮窗要拉起独立 Flutter engine 并调一串原生窗口 API，任何一环原生崩溃都会让整个
  /// 进程无声消失（songloft-org/songloft#318 就是 setSkipTaskbar 空指针）。开关此时已落盘
  /// 为 true，下次进设置页又会自动 open —— 用户被锁在「进设置页必崩」里，界面上根本没
  /// 机会关掉它。启动时读到残留的 true 说明上次没能走完 open()，据此自动关掉开关自救。
  /// 只覆盖 open() 那一小段窗口期，窗口正常存活期间被杀进程不会误判。
  bool getDesktopLyricOpening() {
    return _prefs.getBool(_desktopLyricOpeningKey) ?? false;
  }

  Future<bool> setDesktopLyricOpening(bool value) {
    return _prefs.setBool(_desktopLyricOpeningKey, value);
  }

  /// 桌面歌词窗口是否锁定位置（锁定后点击穿透、不可拖动，默认关闭）。
  bool getDesktopLyricLocked() {
    return _prefs.getBool(_desktopLyricLockedKey) ?? false;
  }

  Future<bool> setDesktopLyricLocked(bool value) {
    return _prefs.setBool(_desktopLyricLockedKey, value);
  }

  /// 桌面歌词字号档位：'small' / 'medium'（默认） / 'large'
  String getDesktopLyricFontSize() {
    return _prefs.getString(_desktopLyricFontSizeKey) ?? 'medium';
  }

  Future<bool> setDesktopLyricFontSize(String value) {
    return _prefs.setString(_desktopLyricFontSizeKey, value);
  }

  /// 桌面歌词背景透明度 (0.0~0.8)，默认 0.4
  double getDesktopLyricOpacity() {
    return _prefs.getDouble(_desktopLyricOpacityKey) ?? 0.4;
  }

  Future<bool> setDesktopLyricOpacity(double value) {
    return _prefs.setDouble(_desktopLyricOpacityKey, value);
  }

  /// 桌面歌词窗口上次拖动后的位置；-1 表示从未设置过，使用默认位置
  double getDesktopLyricPosX() {
    return _prefs.getDouble(_desktopLyricPosXKey) ?? -1;
  }

  double getDesktopLyricPosY() {
    return _prefs.getDouble(_desktopLyricPosYKey) ?? -1;
  }

  Future<void> setDesktopLyricPosition(double x, double y) async {
    await _prefs.setDouble(_desktopLyricPosXKey, x);
    await _prefs.setDouble(_desktopLyricPosYKey, y);
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

  static const _fontScaleKey = 'app_font_scale';

  /// 全局字体缩放倍率（0.85 / 1.0 / 1.15 / 1.3），默认 1.0。
  /// 纯本地设置，不参与服务器偏好同步。
  double getFontScale() {
    return _prefs.getDouble(_fontScaleKey) ?? 1.0;
  }

  Future<bool> setFontScale(double scale) {
    return _prefs.setDouble(_fontScaleKey, scale);
  }

  static const _miniPlayerControlsKey = 'player_mini_controls';

  /// 迷你播放条显示哪些按钮：'playOnly' / 'prevNext'（默认） / 'prevNextMode'。
  /// 纯本地设置，不参与服务器偏好同步（songloft-org/songloft-player#25）。
  String getMiniPlayerControls() {
    return _prefs.getString(_miniPlayerControlsKey) ?? 'prevNext';
  }

  Future<bool> setMiniPlayerControls(String value) {
    return _prefs.setString(_miniPlayerControlsKey, value);
  }

  static const _homeGridColumnsKey = 'home_grid_columns';
  static const _homeGridRowsKey = 'home_grid_rows';

  /// 首页宽屏歌单网格每行列数；0 = 自动（跟随响应式断点）。
  ///
  /// 返回 null 表示从未设置，默认值由 `HomeGridConfig.fromStorage` 决定 ——
  /// 这样默认值只有一处定义，core 层也不用反向依赖 features。
  /// 纯本地设置，不参与服务器偏好同步（songloft-org/songloft#332）。
  int? getHomeGridColumns() {
    return _prefs.getInt(_homeGridColumnsKey);
  }

  Future<bool> setHomeGridColumns(int value) {
    return _prefs.setInt(_homeGridColumnsKey, value);
  }

  /// 首页宽屏歌单网格显示行数；0 = 全部（不截断）。返回 null 表示从未设置。
  int? getHomeGridRows() {
    return _prefs.getInt(_homeGridRowsKey);
  }

  Future<bool> setHomeGridRows(int value) {
    return _prefs.setInt(_homeGridRowsKey, value);
  }

  /// 清除所有偏好设置
  Future<bool> clear() {
    return _prefs.clear();
  }
}
