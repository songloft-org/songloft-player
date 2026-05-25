import 'proxy_url.dart';

/// 封面 URL 处理工具
///
/// 新架构(2026):后端 MarshalJSON 已统一处理 CoverURL 字段:
/// - 本地歌曲: /api/v1/songs/{id}/cover
/// - 网络歌曲: 保留原始 CoverURL (外部 CDN)
///
/// 前端只需直接使用 song.coverUrl，无需再手动构建 Base62 编码路径
class CoverUrl {
  /// 构建封面图片 URL
  ///
  /// 简化版:直接使用后端返回的 coverUrl 字段
  /// - 外部 URL 在 Web 平台自动走代理(解决 CORS)
  /// - 本地歌曲已由后端统一为 /api/v1/songs/{id}/cover
  /// - iOS AVPlayer 不支持自定义 Header 认证，使用 URL query parameter
  static String? buildCoverUrl({String? coverUrl, String? coverPath}) {
    // coverPath 参数保留向后兼容，但不再使用
    // 后端 MarshalJSON 已将本地歌曲的 coverUrl 统一为 /api/v1/songs/{id}/cover
    if (coverUrl != null && coverUrl.isNotEmpty) {
      // 外部 URL 在 Web 平台通过后端代理转发，解决 CORS 限制
      if (ProxyUrl.isExternalUrl(coverUrl)) {
        return ProxyUrl.buildProxyUrl(coverUrl);
      }
      return coverUrl;
    }
    return null;
  }
}
