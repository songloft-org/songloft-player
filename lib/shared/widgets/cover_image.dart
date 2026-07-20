import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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

  /// 诊断日志用的短标识：优先取 /songs/{id}/cover 的 id，否则取去掉 query 的路径。
  /// 避免打印含 access_token 的超长 URL。
  static String _tag(String url) {
    final m = RegExp(r'/songs/(\d+)/cover').firstMatch(url);
    if (m != null) return 'song ${m.group(1)}';
    final q = url.indexOf('?');
    return q > 0 ? url.substring(0, q) : url;
  }

  /// 临时诊断（仅 web，节流 1.5s）：打印 imageCache 状态，观察重新进列表时缓存是否
  /// 被淘汰/清空（size/live 跌落）——判断是否为 LRU 淘汰触发重解码。
  static DateTime _lastCacheDump = DateTime.fromMillisecondsSinceEpoch(0);
  static void _maybeDumpCache() {
    if (!kIsWeb) return;
    final now = DateTime.now();
    if (now.difference(_lastCacheDump).inMilliseconds < 1500) return;
    _lastCacheDump = now;
    final c = PaintingBinding.instance.imageCache;
    debugPrint(
      '[Cover] cache size=${c.currentSize}/${c.maximumSize} '
      'bytes=${c.currentSizeBytes}/${c.maximumSizeBytes} '
      'live=${c.liveImageCount} pending=${c.pendingImageCount}',
    );
  }

  @override
  Widget build(BuildContext context) {
    // 使用 UrlHelper 处理封面 URL（自动拼接 baseUrl + access_token）
    final displayUrl =
        coverUrl != null && coverUrl!.isNotEmpty
            ? UrlHelper.buildCoverUrl(coverUrl!)
            : null;

    // 按显示尺寸的物理像素解码（而非原图全分辨率），大幅降低单张解码内存与 CPU 开销，
    // 让更多封面能塞进 imageCache 不被淘汰——直接缓解切 tab/筛选重建时的重解码风暴
    // （封面丢失变黑/占位图标的根因）。封面为方形，仅限宽即可等比缩放。
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final decodeWidth = (size * dpr).clamp(64.0, 1024.0).round();

    _maybeDumpCache();

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
                  memCacheWidth: decodeWidth,
                  maxWidthDiskCache: decodeWidth,
                  // ==== 临时诊断日志（仅 web）：区分封面"正常/黑/icon"三态走的代码路径 ====
                  // imageBuilder 被调用 = 解码成功、ImageInfo 就绪（若此时仍显示黑 →
                  //   纹理/渲染层问题）；errorWidget 被调用 = 加载真失败（显示 icon），
                  //   error 打出具体类型与内容；placeholder = 仍在加载中。
                  imageBuilder: (context, imageProvider) {
                    if (kIsWeb) {
                      debugPrint('[Cover] OK   ${_tag(displayUrl)}');
                    }
                    return Image(image: imageProvider, fit: fit);
                  },
                  placeholder: (context, url) {
                    if (kIsWeb) {
                      debugPrint('[Cover] LOAD ${_tag(displayUrl)}');
                    }
                    return _buildPlaceholder(context);
                  },
                  errorWidget: (context, url, error) {
                    if (kIsWeb) {
                      debugPrint(
                        '[Cover] ERR  ${_tag(displayUrl)} :: '
                        '${error.runtimeType} :: $error',
                      );
                    }
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
