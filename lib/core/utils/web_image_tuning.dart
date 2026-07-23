import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

/// Web 端超大列表滚动时的 GPU 纹理压力缓解参数（仅 Web 生效）。
///
/// 背景：Flutter Web CanvasKit 存在已知引擎缺陷（flutter/flutter#184683）——
/// 滚动大歌单 / 播放队列时大量封面 GPU 纹理累积，顶破移动端显存预算 →
/// WebGL context 丢失 → 已上传纹理集体变黑。原生端（Skia）不受影响。
///
/// 本文件集中收紧 **Web 端** 大列表的两个杠杆，降低同时驻留的 GPU 纹理数量与体积；
/// 原生端一律返回"保持默认"的值，画质与行为完全不变。这是**缓解不是根治**，
/// 目标是显著降低触发概率，根治需等 Flutter 引擎修复进 stable。

/// 大列表在 Web 端收紧的 `cacheExtent`（逻辑像素）。
///
/// `ListView` / `CustomScrollView` / `ReorderableListView` 默认 `cacheExtent`
/// 为 250——会在可视区外预构建、预解码更多封面并让其 GPU 纹理常驻。Web 端收紧到
/// 100，减少屏幕外同时驻留的 GPU 纹理数量约一半（仍保留少量缓冲避免快速滚动时白块），
/// 降低顶破显存、丢 WebGL context 的概率。
///
/// 注意：这里降低的是**同时驻留的纹理数**，并非“靠 imageCache 保住字节”。Flutter 的
/// `imageCache`（`main.dart` 调到 2000 项 / 200 MiB）缓存的是**解码后的 ui.Image /
/// GPU 纹理句柄**而非编码字节；一旦 WebGL context 丢失，这些缓存条目会变成**死纹理**，
/// 回滚命中缓存反而画成空白——该场景由 `installWebGLContextRecovery`（context 丢失/
/// 恢复时清空 imageCache 强制重新解码）兜底，二者配合，见 songloft-org/songloft#309。
///
/// 原生端返回 `null`，让框架使用默认 250，行为保持不变。
ScrollCacheExtent? get webListCacheExtent =>
    kIsWeb ? const ScrollCacheExtent.pixels(100) : null;

/// 小尺寸列表封面（播放队列 / 侧边栏等）在 Web 端的解码目标宽度（物理像素）。
///
/// [NetworkCoverImage] 默认按 400 物理像素解码（为卡片 / 网格设计），但队列 / 侧边栏
/// 项封面仅 36–48 逻辑像素，400 解码产生约 17× 于所需的 GPU 纹理体积——播放队列会
/// 镜像整个歌单（可达上千首），是纹理累积的重灾区。Web 端按实际显示尺寸 × dpr 收紧
/// （下限 64 保清晰、上限不超过原 400 默认值）；原生端返回 400 保持画质不变。
int smallCoverDecodeWidth(double displaySize, double devicePixelRatio) {
  if (!kIsWeb) return 400;
  return (displaySize * devicePixelRatio).round().clamp(64, 400);
}
