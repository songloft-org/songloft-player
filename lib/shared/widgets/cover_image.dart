import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../core/utils/image_recovery.dart';
import '../../core/utils/url_helper.dart';

/// 统一封面图组件
/// 所有页面的封面图都使用此组件，支持缓存和占位符
///
/// Web/CanvasKit：监听 [imageRecoveryGeneration]，路由变化 / 回前台时驱逐自身缓存
/// 条目并换 key 重建，修复 CanvasKit 多 WebGL context 跨 context 纹理失效导致的封面
/// 纯黑（flutter/flutter#86809/#91881，详见 image_recovery.dart）。
class CoverImage extends StatefulWidget {
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
  State<CoverImage> createState() => _CoverImageState();
}

class _CoverImageState extends State<CoverImage> {
  /// 当前恢复代次；仅 web 参与，编入 CachedNetworkImage 的 key。
  int _generation = 0;

  /// 使用 UrlHelper 处理封面 URL（自动拼接 baseUrl + access_token）。
  String? get _displayUrl =>
      widget.coverUrl != null && widget.coverUrl!.isNotEmpty
          ? UrlHelper.buildCoverUrl(widget.coverUrl!)
          : null;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _generation = imageRecoveryGeneration.value;
      imageRecoveryGeneration.addListener(_onRecover);
    }
  }

  @override
  void dispose() {
    if (kIsWeb) {
      imageRecoveryGeneration.removeListener(_onRecover);
    }
    super.dispose();
  }

  /// 代次变化（路由切换 / 回前台）时：驱逐本封面在全局 imageCache 里那张 GPU 纹理
  /// 可能已失效的 ui.Image，再换 key 重建 CachedNetworkImage 强制重新解码。先 evict
  /// 再 setState，保证重建后的 resolve 一定 cache miss、从 flutter_cache_manager 字节
  /// 缓存重解码（不重新走网络），把新纹理上传到当前活动 GL context。
  void _onRecover() {
    final url = _displayUrl;
    if (url != null) {
      // CachedNetworkImageProvider 的 imageCache 键就是它自身（obtainKey 返回 this，
      // == 按 url 比较）。includeLive: true 才会同时清 _cache/_pendingImages/_liveImages
      // 三处，否则仍会命中活图里那张死纹理。
      PaintingBinding.instance.imageCache.evict(
        CachedNetworkImageProvider(url),
        includeLive: true,
      );
    }
    if (mounted) {
      setState(() => _generation = imageRecoveryGeneration.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayUrl = _displayUrl;

    final imageWidget = ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: displayUrl != null
            ? CachedNetworkImage(
                // 换 key 强制在恢复代次变化时重建（仅 web 会变；非 web 恒定）。
                key: kIsWeb ? ValueKey('$displayUrl#$_generation') : null,
                imageUrl: displayUrl,
                fit: widget.fit,
                placeholder: (context, url) => _buildPlaceholder(context),
                errorWidget: (context, url, error) => _buildPlaceholder(context),
              )
            : _buildPlaceholder(context),
      ),
    );

    if (widget.semanticLabel != null) {
      return Semantics(
        image: true,
        label: widget.semanticLabel!,
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
          widget.placeholderIcon,
          size: widget.size * 0.5,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
