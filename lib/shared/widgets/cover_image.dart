import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/utils/cover_diagnostics.dart';
import '../../core/utils/url_helper.dart';

/// 统一封面图组件
/// 所有页面的封面图都使用此组件，支持缓存和占位符
class CoverImage extends StatelessWidget {
  /// 完整的封面 URL（后端统一处理）
  final String? coverUrl;

  /// 图片尺寸（宽高相同，方形）
  final double size;

  /// 圆角半径
  final double borderRadius;

  /// 占位符图标
  final IconData placeholderIcon;

  /// 图片填充方式
  final BoxFit fit;

  /// 无障碍语义标签（为 null 时图片被标记为装饰性，读屏器会跳过）
  final String? semanticLabel;

  const CoverImage({
    super.key,
    this.coverUrl,
    this.size = 48,
    this.borderRadius = 8,
    this.placeholderIcon = Icons.music_note,
    this.fit = BoxFit.cover,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    // 按显示尺寸的物理像素解码（而非原图全分辨率），大幅降低单张解码内存与 GPU 纹理。
    // 封面为方形，仅限宽即可等比缩放。
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final decodeWidth = (size * dpr).clamp(64.0, 1024.0).round();

    // 使用 UrlHelper 处理封面 URL（自动拼接 baseUrl + access_token）。
    // Web 端追加 ?w=decodeWidth 让服务端缩略（见下方 imageRenderMethodForWeb 注释）。
    final displayUrl =
        coverUrl != null && coverUrl!.isNotEmpty
            ? UrlHelper.buildCoverUrl(coverUrl!, width: decodeWidth)
            : null;

    final imageWidget = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: size,
        height: size,
        child:
            displayUrl != null
                ? CachedNetworkImage(
                  imageUrl: displayUrl,
                  fit: fit,
                  // Web 端走默认的浏览器原生 <img>（HtmlImage）路径，不再用 HttpGet。
                  // 此前 HttpGet 是为让 memCacheWidth 生效、缩小 GPU 纹理防显存顶爆变黑；
                  // 但 HttpGet 走 flutter_cache_manager 的 web 内存管线，滚回/队列重建时
                  // 会静默 stall、封面画成空白（songloft-org/songloft#309）。改回 <img>
                  // 拿回浏览器缓存的稳健重显示，纹理体积改由服务端 ?w= 缩略控制（URL 已带）。
                  // memCacheWidth / maxWidthDiskCache 在 web <img> 路径不生效，仅对原生
                  // 平台的解码降采样有意义，保留不影响 web。
                  memCacheWidth: decodeWidth,
                  maxWidthDiskCache: decodeWidth,
                  placeholder: (context, url) => _buildPlaceholder(context),
                  errorWidget: (context, url, error) {
                    CoverDiagnostics.logError(url, error);
                    return _buildPlaceholder(context);
                  },
                )
                : _buildPlaceholder(context),
      ),
    );

    if (semanticLabel != null) {
      return Semantics(
        image: true,
        label: semanticLabel!,
        child: imageWidget,
      );
    }
    return ExcludeSemantics(child: imageWidget);
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          placeholderIcon,
          size: size * 0.5,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
