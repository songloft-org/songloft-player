import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

/// Web/CanvasKit 专用：shell 内导航切换时驱逐全局图片缓存，修复列表封面切页面
/// 回来变黑。
///
/// 根因（flutter/flutter#86809 P0、#91881）：CanvasKit 为每个 platform view
/// overlay 建独立 WebGL context，而 WebGL 跨 context **不能共享 GPU 纹理**。含封面
/// 列表的页面（曲库/首页/歌单等）被导航切走时整棵 dispose，其已解码的 `ui.Image`
/// 失去 live 绘制引用，但仍以「稳定 URL（含会话内固定的 access_token）」为键驻留
/// 全局 `imageCache`；页面缺席期间 CanvasKit 重配合成表面，丢弃了这些无人绘制的
/// 纹理。返回该页时全新的 `CachedNetworkImage.resolve()` 同步命中 `imageCache`，
/// 取回**同一张纹理已失效的 `ui.Image`** → 直接绘制为纯黑（解码在框架层「成功」，
/// 失败发生在 GPU 绘制层，故 `errorWidget` 捕获不到，显示的是黑而非占位图标）。
///
/// 修复：每次 shell 内导航都清空 `imageCache`（含 live 记录），迫使目标页全新的封面
/// widget cache miss → 从 `flutter_cache_manager` 字节缓存重新解码（不重新走网络）→
/// 把新纹理上传到当前活动 GrContext。NavigatorObserver 回调早于目标页首帧 build，
/// 故驱逐一定先于封面 resolve。
///
/// 仅换 widget key 或 reassemble 都不够：provider 相等键是 URL，仍会命中同一死图，
/// **必须驱逐缓存条目**才会触发重解码。
///
/// 仅 web 生效：原生平台无多 WebGL context 纹理失效问题，清缓存只会白白重解码。
/// 常驻播放器（裸 `Image.network`）不受影响——其 `_ImageState` 仍持有当前 `ImageInfo`
/// 继续绘制，`clearLiveImages()` 只是不再把该 completer 交给新请求，下一帧照常热重传。
class WebImageCacheGuard extends NavigatorObserver {
  void _evict() {
    if (!kIsWeb) return;
    final cache = PaintingBinding.instance.imageCache;
    cache.clear();
    cache.clearLiveImages();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _evict();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _evict();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _evict();
}
