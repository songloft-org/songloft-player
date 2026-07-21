import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart'
    show ImageRenderMethodForWeb;
import 'package:flutter/material.dart';

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
    // 使用 UrlHelper 处理封面 URL（自动拼接 baseUrl + access_token）
    final displayUrl =
        coverUrl != null && coverUrl!.isNotEmpty
            ? UrlHelper.buildCoverUrl(coverUrl!)
            : null;

    // 按显示尺寸的物理像素解码（而非原图全分辨率），大幅降低单张解码内存与 GPU 纹理。
    // 封面为方形，仅限宽即可等比缩放。详见下方 imageRenderMethodForWeb 注释。
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final decodeWidth = (size * dpr).clamp(64.0, 1024.0).round();

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
                  // web 走字节解码路径（HttpGet），而非默认的 <img> 惰性纹理
                  // （HtmlImage）。默认路径下 memCacheWidth 不生效，封面按原图全分辨率
                  // 上传为 GPU 纹理（~1.5MB/张），大量封面纹理累积挤爆移动端 GPU 显存
                  // → CanvasKit 的 WebGL context 被丢弃 → 已上传纹理失效（封面变黑）、
                  // 新解码抛 ImageCodecException（封面变占位图标）。HttpGet 路径下
                  // memCacheWidth 生效，封面缩到显示尺寸解码（数十 KB），大幅降压；
                  // 且字节可在 context 恢复后重解码，比 <img> 惰性纹理更抗 context 丢失。
                  // 直接用 CachedNetworkImage 渲染封面的其它组件见 [NetworkCoverImage]。
                  imageRenderMethodForWeb: ImageRenderMethodForWeb.HttpGet,
                  memCacheWidth: decodeWidth,
                  maxWidthDiskCache: decodeWidth,
                  placeholder: (context, url) => _buildPlaceholder(context),
                  errorWidget:
                      (context, url, error) => _buildPlaceholder(context),
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
