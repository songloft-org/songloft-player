import 'dart:io';

import 'package:flutter/foundation.dart';

class AudioFormatHelper {
  AudioFormatHelper._();

  static const _webFormats = {
    'mp3', 'flac', 'ogg', 'm4a', 'aac', 'wav', 'opus',
  };
  static const _iosFormats = {
    'mp3', 'flac', 'm4a', 'aac', 'wav', 'alac', 'aiff',
  };
  static const _androidFormats = {
    'mp3', 'flac', 'ogg', 'm4a', 'aac', 'wav', 'opus',
  };

  static String? getTranscodeFormat(String? songFormat) {
    if (songFormat == null || songFormat.isEmpty) return null;
    final fmt = _normalizeFormat(songFormat.toLowerCase());
    if (fmt == null) return null;
    // Matroska 音频容器（songloft-org/songloft#297）：libmpv 原生支持多音轨枚举与切换
    // （media_kit 的 Player.state.tracks.audio + setAudioTrack），所有原生平台（含
    // iOS/Android，均走 media_kit/libmpv 后端）不转码，直出原容器以保留多音轨（原唱/伴奏）。
    // 仅 Web（浏览器不支持 mka 容器、无法原生切轨）转码为 mp3 播放首条音轨，切轨在 Web 不可用。
    if (fmt == 'mka') {
      return kIsWeb ? 'mp3' : null;
    }
    final supported = _getPlatformFormats();
    if (supported.isEmpty) return null;
    if (supported.contains(fmt)) return null;
    return 'mp3';
  }

  /// 判断该格式在 Web 端是否为「可能含多音轨、需走后端抽轨播放」的容器
  /// （songloft-org/songloft#298）。当前即 mka（原唱/伴奏双音轨卡拉 OK 容器）：
  /// 浏览器不认 Matroska 容器、也无多轨枚举/切换 API，故 Web 统一走后端 ?track= 抽轨
  /// （AAC 无损 remux 成 m4a，否则转 mp3）。原生端由 libmpv 直接切轨，不走此路径，返回 false。
  static bool isWebMultiTrackContainer(String? songFormat) {
    if (!kIsWeb) return false;
    if (songFormat == null || songFormat.isEmpty) return false;
    return _normalizeFormat(songFormat.toLowerCase()) == 'mka';
  }

  /// 将服务端返回的 format 字段归一化为音频格式名。
  /// 兼容旧数据中可能存储的 tag 格式名（如 "ID3v2.3"）。
  static String? _normalizeFormat(String fmt) {
    if (fmt.startsWith('id3v')) return 'mp3';
    switch (fmt) {
      case 'mpeg':
      case 'mp3':
        return 'mp3';
      case 'mp4':
      case 'm4a':
      case 'aac':
      case 'mov': // QuickTime/ISO-BMFF 同族容器（如 bilibili 下载源），按 m4a 处理
        return 'm4a';
      case 'ogg':
      case 'vorbis':
        return 'ogg';
      case 'flac':
        return 'flac';
      case 'wav':
      case 'wave':
        return 'wav';
      case 'wma':
      case 'asf':
        return 'wma';
      case 'ape':
        return 'ape';
      case 'opus':
        return 'opus';
      // Matroska 音频容器（songloft-org/songloft#297）：原生平台由 libmpv 直接播放并支持
      // 多音轨切换，Web 转码为 mp3。分平台处理见 getTranscodeFormat 的 mka 分支。
      case 'mka':
        return 'mka';
      default:
        return null;
    }
  }

  static Set<String> _getPlatformFormats() {
    if (kIsWeb) return _webFormats;
    if (Platform.isIOS) return _iosFormats;
    if (Platform.isAndroid) return _androidFormats;
    return {};
  }
}
