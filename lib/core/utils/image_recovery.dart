import 'package:flutter/foundation.dart';

/// Web/CanvasKit 图片纹理恢复代次。
///
/// 根因（flutter/flutter#86809 P0、#91881）：CanvasKit 为每个 platform view overlay
/// 建独立 WebGL context，跨 context **不能共享 GPU 纹理**。当含封面列表的页面被导航
/// 盖住（典型：`context.push('/plugin')` 打开插件 WebView，是 platform view）时，页面
/// 并不 dispose、只是不再绘制；其封面 `ui.Image` 的 GPU 纹理在此期间失效。返回时页面
/// 复用、`_ImageState` 不会重新 resolve，直接拿失效纹理绘制成纯黑（解码在框架层
/// “成功”，失败在 GPU 层，`errorWidget` 捕获不到）。
///
/// 修复：每次路由变化（[GoRouter] 的 routerDelegate 监听，覆盖根 + shell 内所有导航）
/// 与 web 回前台（[StartupGate] resume）时自增本代次；[CoverImage] 监听它，代次变化时
/// **驱逐自身封面的 imageCache 条目并换 key 重建**，迫使重新解码 → 把新纹理上传到当前
/// 活动 GL context。
///
/// 为何不用全局 `imageCache.clear()` + `reassembleApplication()`：clear 对已挂载、不
/// 重建的 widget 无效（不会触发重新 resolve）；reassembleApplication 是重锤且会打断
/// 临时状态。按封面精准 evict + 换 key 既能在页面不重建时自愈，又只影响封面本身。
/// 滚动时代次不变，不会随 ListView 瓦片反复驱逐。
///
/// 非 web 平台无多 WebGL context 纹理失效问题，永不自增，[CoverImage] 也不监听。
final ValueNotifier<int> imageRecoveryGeneration = ValueNotifier<int>(0);

/// 触发一次全局封面纹理恢复（仅 web 生效）。
void bumpImageRecovery() {
  if (!kIsWeb) return;
  imageRecoveryGeneration.value++;
}
