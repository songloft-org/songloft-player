import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
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
    // Web 端追加 ?w=decodeWidth 让服务端缩略。
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
                ? _buildImage(displayUrl, decodeWidth)
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

  Widget _buildImage(String url, int decodeWidth) {
    // Web 端用 Image.network：走 NetworkImage → XHR 下载字节 →
    // instantiateImageCodecFromBuffer → CanvasKit MakeImageFromEncoded。
    // 此路径不涉及 <img crossOrigin="anonymous"> 元素，规避了 CanvasKit 的
    // MakeLazyImageFromTextureSourceWithInfo 对 tainted image 返回 null →
    // ImageCodecException('Failed to create image from Image.decode') 的问题
    // （songloft-org/songloft#309）。也不依赖 flutter_cache_manager 的 web
    // 内存管线（之前 HttpGet 模式滚回/队列重建 stall 的根源），改用 Flutter 内置
    // PaintingBinding.instance.imageCache（2000 条/200 MiB）。纹理体积由服务端
    // ?w= 缩略控制（URL 已带），浏览器 HTTP 缓存（max-age=1年）兜底网络层。
    //
    // 原生平台继续用 CachedNetworkImage：其磁盘缓存在移动端有实际意义，
    // memCacheWidth 也可正常降采样。
    if (kIsWeb) {
      return Image.network(
        url,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildPlaceholder(context);
        },
        errorBuilder: (context, error, stackTrace) {
          CoverDiagnostics.logError(url, error);
          return _buildPlaceholder(context);
        },
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      memCacheWidth: decodeWidth,
      maxWidthDiskCache: decodeWidth,
      placeholder: (context, url) => _buildPlaceholder(context),
      errorWidget: (context, url, error) {
        CoverDiagnostics.logError(url, error);
        return _buildPlaceholder(context);
      },
    );
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
