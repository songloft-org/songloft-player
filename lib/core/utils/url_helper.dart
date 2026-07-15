import 'package:flutter/foundation.dart';

import '../../config/app_config.dart';
import '../storage/secure_storage.dart';
import 'audio_format_helper.dart';

/// URL 构建工具类
///
/// 统一处理歌曲、封面、歌词等资源的 URL 拼接逻辑：
/// - 相对路径（/api/v1/...）：自动拼接 baseUrl + access_token
/// - 外部完整 URL（http/https）：直接返回
///
/// 所有客户端资源访问都应使用此类，确保认证 token 正确传递。
class UrlHelper {
  /// 构建完整的资源 URL
  ///
  /// [url] 资源 URL，可能是相对路径或完整 URL
  /// 返回：带有 baseUrl 和 access_token 的完整 URL
  static String buildResourceUrl(String url) {
    if (url.isEmpty) return '';

    // 外部 URL 直接返回
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }

    // 相对路径：拼接 baseUrl + basePath + access_token
    final token = SecureStorageService.cachedAccessToken ?? '';
    final separator = url.contains('?') ? '&' : '?';
    final fullUrl =
        '${AppConfig.baseUrl}${AppConfig.basePath}$url${separator}access_token=$token';

    // 该日志在每次构建资源 URL（封面/播放/歌词）时触发，且含 access_token；
    // 仅 debug 构建输出，避免 release 端日志刷屏与凭证明文落盘。
    if (kDebugMode) {
      debugPrint('[UrlHelper] Built resource URL: $fullUrl');
    }
    return fullUrl;
  }

  /// 构建歌曲播放 URL
  ///
  /// [songFormat] 歌曲原始格式（如 "wma"），用于判断当前平台是否需要转码。
  /// 当平台不支持该格式时自动追加 format 参数请求服务端转码。
  /// [quality] 音质偏好（'128'/'192'/'320'），非空且非 'original' 时追加 quality 参数。
  static String buildSongUrl(
    String url, {
    String? songFormat,
    String? quality,
  }) {
    var result = buildResourceUrl(url);
    if (result.isEmpty) return '';
    final transcode = AudioFormatHelper.getTranscodeFormat(songFormat);
    if (transcode != null) {
      result += '${result.contains('?') ? '&' : '?'}format=$transcode';
    }
    if (quality != null && quality.isNotEmpty && quality != 'original') {
      result += '${result.contains('?') ? '&' : '?'}quality=$quality';
    }
    return result;
  }

  /// 构建视频播放 URL（用于应用内视频画面渲染与 DLNA 视频投屏）
  ///
  /// 追加 `media=video`：后端据此直出原容器（不转码，避免 ffmpeg -vn 丢画面），
  /// 并按容器真实类型返回 Content-Type（如 video/mp4）。
  /// 不追加 format/quality —— 视频需要保留完整音视频轨。
  static String buildVideoUrl(String url) {
    final result = buildResourceUrl(url);
    if (result.isEmpty) return '';
    return '$result${result.contains('?') ? '&' : '?'}media=video';
  }

  /// 构建封面图片 URL（兼容旧接口，内部调用 buildResourceUrl）
  static String buildCoverUrl(String coverUrl) {
    return buildResourceUrl(coverUrl);
  }

  /// 构建歌词 URL（兼容旧接口，内部调用 buildResourceUrl）
  static String buildLyricUrl(String lyricUrl) {
    return buildResourceUrl(lyricUrl);
  }
}
