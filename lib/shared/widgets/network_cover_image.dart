import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../core/utils/cover_diagnostics.dart';
import '../../core/utils/url_helper.dart';

/// 封面网络图统一封装：Web 走 Image.network（XHR + CanvasKit 解码），原生走 CachedNetworkImage。
///
/// 用于 [CoverImage] 覆盖不到的、直接用 `CachedNetworkImage` 渲染封面的场景
/// （专辑/歌手网格、首页歌单轮播、hero 卡片、歌单详情、播放队列等）。
///
/// Web 端不再经 `createImageCodecFromUrl` 的 `<img crossOrigin="anonymous">` 路径——
/// CanvasKit 的 `MakeLazyImageFromTextureSourceWithInfo` 对此类元素可能返回 null，
/// 导致 `ImageCodecException('Failed to create image from Image.decode')`。
/// 改用 `Image.network`（NetworkImage → XHR → `instantiateImageCodecFromBuffer`）
/// 绕过 `<img>` 元素，也不依赖 flutter_cache_manager 的 web 内存管线（之前 HttpGet
/// 模式滚回/队列重建时 stall 的根源）。纹理体积由服务端 `?w=` 缩略控制。
/// 见 songloft-org/songloft#309。
class NetworkCoverImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final PlaceholderWidgetBuilder? placeholder;
  final LoadingErrorWidgetBuilder? errorWidget;

  /// 解码目标宽度（物理像素）。封面卡片一般显示 <200 逻辑像素，400 物理像素在高
  /// DPR 屏也足够清晰，同时远小于原图，显著降低 GPU 纹理与解码开销。
  final int decodeWidth;

  const NetworkCoverImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.decodeWidth = 400,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = UrlHelper.appendCoverWidth(imageUrl, decodeWidth);

    if (kIsWeb) {
      return Image.network(
        resolvedUrl,
        fit: fit,
        width: width,
        height: height,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          if (placeholder != null) return placeholder!(context, resolvedUrl);
          return const SizedBox.shrink();
        },
        errorBuilder: (context, error, stackTrace) {
          CoverDiagnostics.logError(resolvedUrl, error);
          if (errorWidget != null) return errorWidget!(context, resolvedUrl, error);
          return const SizedBox.shrink();
        },
      );
    }

    return CachedNetworkImage(
      imageUrl: resolvedUrl,
      fit: fit,
      width: width,
      height: height,
      memCacheWidth: decodeWidth,
      maxWidthDiskCache: decodeWidth,
      placeholder: placeholder,
      errorWidget: (context, url, error) {
        CoverDiagnostics.logError(url, error);
        if (errorWidget != null) return errorWidget!(context, url, error);
        return const SizedBox.shrink();
      },
    );
  }
}
