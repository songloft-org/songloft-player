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

    // 相对路径：拼接 resolvedBaseUrl + basePath + access_token
    // 用 resolvedBaseUrl（入口域名 302 解析后的真实地址）而非 baseUrl（身份 URL）：
    // 播放/封面流由播放器内核/Image 直接请求，走不了 Dio 的重定向重解析拦截器，且带
    // access_token 查询参数，跨 host 的 302 不保证保留 query，故必须直连真实地址
    // （songloft-org/songloft-player#22）。取舍：若播放中途 STUN 端口突变会断当前流，
    // 此时 API 拦截器已在后台刷新 resolvedBaseUrl，切歌/重播即用新端口恢复。
    final token = SecureStorageService.cachedAccessToken ?? '';
    final separator = url.contains('?') ? '&' : '?';
    final fullUrl =
        '${AppConfig.resolvedBaseUrl}${AppConfig.basePath}$url${separator}access_token=$token';

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
  /// [hlsDirect] 为 true 时追加 `hls=direct`：让后端对 HLS 电台强制 302 直连源站、
  /// 绕过本机 HLS 反代（即使反代开关已开）。原生 player 自带 HLS 解析且无 CORS 限制，
  /// 直连可避免直播切片经反代往返后过期导致 404（songloft-org/songloft#249）；
  /// 后端对非 HLS 电台忽略此参数，故传入无害。浏览器不应传（需反代解决 CORS）。
  /// [audioTrack] 非空且 >= 0 时追加 `track=N`（audio-relative index），让后端抽取该音轨
  /// 播放（Web 双音轨切换，songloft-org/songloft#298）；此时**不再附加 format**——容器由后端
  /// 据音轨编码决定（AAC → m4a 无损 remux，否则 → mp3），避免与抽轨容器判定冲突。
  static String buildSongUrl(
    String url, {
    String? songFormat,
    String? quality,
    bool hlsDirect = false,
    int? audioTrack,
  }) {
    var result = buildResourceUrl(url);
    if (result.isEmpty) return '';
    if (audioTrack != null && audioTrack >= 0) {
      result += '${result.contains('?') ? '&' : '?'}track=$audioTrack';
    } else {
      final transcode = AudioFormatHelper.getTranscodeFormat(songFormat);
      if (transcode != null) {
        result += '${result.contains('?') ? '&' : '?'}format=$transcode';
      }
    }
    if (quality != null && quality.isNotEmpty && quality != 'original') {
      result += '${result.contains('?') ? '&' : '?'}quality=$quality';
    }
    if (hlsDirect) {
      result += '${result.contains('?') ? '&' : '?'}hls=direct';
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
