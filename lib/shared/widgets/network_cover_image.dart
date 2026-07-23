import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

import '../../core/utils/cover_diagnostics.dart';
import '../../core/utils/url_helper.dart';

/// 封面网络图统一封装：Web 走浏览器原生 `<img>`（HtmlImage）+ 服务端 `?w=` 缩略。
///
/// 用于 [CoverImage] 覆盖不到的、直接用 `CachedNetworkImage` 渲染封面的场景
/// （专辑/歌手网格、首页歌单轮播、hero 卡片、歌单详情、播放队列等）。
///
/// 缩略策略（songloft-org/songloft#309）：Web 端不再用 `HttpGet`（其经
/// flutter_cache_manager 的 web 内存管线，滚回/队列重建时会静默 stall、封面画成空白），
/// 改回默认 `<img>` 路径拿回浏览器缓存的稳健重显示。`<img>` 会按图片**固有尺寸**上传
/// GPU 纹理、`memCacheWidth` 不生效，故对本机后端封面 URL 追加 `?w=decodeWidth` 让
/// **服务端**把封面缩到显示尺寸（数十 KB），既避免大封面纹理挤爆移动端 GPU 显存变黑，
/// 又规避 HttpGet 的重显示 bug。`memCacheWidth` 保留仅对原生平台降采样有意义。
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
    // Web 端给本机后端封面 URL 追加 ?w=decodeWidth 让服务端缩略（外部/原生原样）。
    final resolvedUrl = UrlHelper.appendCoverWidth(imageUrl, decodeWidth);
    return CachedNetworkImage(
      imageUrl: resolvedUrl,
      fit: fit,
      width: width,
      height: height,
      // Web 走默认 <img>（HtmlImage）；纹理体积由服务端 ?w= 控制。见类文档 #309。
      memCacheWidth: decodeWidth,
      maxWidthDiskCache: decodeWidth,
      placeholder: placeholder,
      // 统一在此记录失败日志（#309 诊断），再委托调用方的 errorWidget（若有）。
      errorWidget: (context, url, error) {
        CoverDiagnostics.logError(url, error);
        if (errorWidget != null) return errorWidget!(context, url, error);
        return const SizedBox.shrink();
      },
    );
  }
}
