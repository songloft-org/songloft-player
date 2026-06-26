import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// iOS Live Activity（灵动岛）服务
///
/// 通过 MethodChannel 与 iOS 原生层通信，管理 Live Activity 生命周期。
/// 非 iOS 平台或不支持的 iOS 版本静默返回。
class LiveActivityService {
  static final LiveActivityService _instance = LiveActivityService._();
  factory LiveActivityService() => _instance;
  LiveActivityService._();

  static const _channel = MethodChannel(
    'com.songloft.songloftFlutter/liveActivity',
  );

  bool? _supported;

  bool get _isApplicable => !kIsWeb && Platform.isIOS;

  /// 清除 isSupported 缓存，下次调用时重新检查。
  /// 在 app 回到前台时调用，以便捕获用户在系统设置中开关 Live Activity。
  void clearSupportedCache() {
    _supported = null;
  }

  /// 检查当前设备是否支持 Live Activity
  Future<bool> isSupported() async {
    if (!_isApplicable) return false;
    if (_supported != null) return _supported!;
    try {
      _supported = await _channel.invokeMethod<bool>('isSupported') ?? false;
      debugPrint('[LiveActivity] isSupported: $_supported');
    } on MissingPluginException {
      _supported = false;
      debugPrint('[LiveActivity] isSupported: plugin not found');
    } catch (e) {
      debugPrint('[LiveActivity] isSupported check failed: $e');
      _supported = false;
    }
    return _supported!;
  }

  /// 开始一个 Live Activity（灵动岛显示）
  Future<void> startActivity({
    required String title,
    required String artist,
    String? lyricLine,
    String? artUrl,
  }) async {
    if (!await isSupported()) {
      debugPrint('[LiveActivity] startActivity skipped: not supported');
      return;
    }
    try {
      debugPrint('[LiveActivity] startActivity: $title - $artist');
      await _channel.invokeMethod('startActivity', {
        'title': title,
        'artist': artist,
        'lyricLine': lyricLine ?? '',
        'artUrl': artUrl ?? '',
      });
    } catch (e) {
      debugPrint('[LiveActivity] startActivity failed: $e');
    }
  }

  /// 更新当前歌词行
  Future<void> updateLyric(String lyricLine, String? nextLine) async {
    if (!_isApplicable || _supported == false) return;
    try {
      await _channel.invokeMethod('updateLyric', {
        'lyricLine': lyricLine,
        'nextLine': nextLine ?? '',
      });
    } catch (e) {
      debugPrint('[LiveActivity] updateLyric failed: $e');
    }
  }

  /// 更新播放状态
  Future<void> updatePlaybackState({
    required bool isPlaying,
    required double progress,
  }) async {
    if (!_isApplicable || _supported == false) return;
    try {
      await _channel.invokeMethod('updatePlaybackState', {
        'isPlaying': isPlaying,
        'progress': progress,
      });
    } catch (e) {
      debugPrint('[LiveActivity] updatePlaybackState failed: $e');
    }
  }

  /// 结束 Live Activity
  Future<void> endActivity() async {
    if (!_isApplicable || _supported == false) return;
    try {
      await _channel.invokeMethod('endActivity');
    } catch (e) {
      debugPrint('[LiveActivity] endActivity failed: $e');
    }
  }
}
