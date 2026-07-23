import 'dart:js_interop';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// WebGL context 丢失/恢复时清空 Flutter 的 imageCache（songloft-org/songloft#309）。
///
/// 背景：Flutter Web CanvasKit 在 GPU 显存压力下会丢失 WebGL context。beta 3.47
/// （引擎修复 flutter/flutter#185116）修好了 context 丢失时 CkSurface 崩溃的问题，
/// 当前**可见**画面会随 context 恢复被引擎重绘。但 Flutter 的 `imageCache` 缓存的是
/// **解码后的 `ui.Image`（CanvasKit SkImage / GPU 纹理句柄）而非原始编码字节**——
/// 离屏但仍驻留缓存的封面，其 GPU 纹理随旧 context 一起失效；回滚重新进入视口时同步
/// 命中 imageCache，拿到的是**死纹理**，画成空白且不再触发重新解码，表现为用户反馈的
/// “回滚封面不显示”。
///
/// 这里在 context 丢失/恢复时清空 imageCache，把这些死纹理条目清掉：回滚时 cache
/// miss → 从 `cached_network_image` 的字节缓存重新解码、上传到新 context 的纹理 →
/// 正常显示（字节仍在本地，无需重新联网）。这是配合引擎修复的应用层收尾，不是引擎
/// 级根治。
///
/// `webglcontextlost` / `webglcontextrestored` 事件不冒泡、只在承载 GL context 的
/// canvas 上派发，应用层拿不到该 canvas 引用，故用**捕获阶段**监听（addEventListener
/// 第三参 `true`）挂在 window 上——非冒泡事件的捕获阶段仍会从根节点向下经过 window，
/// 因此能捕到。两个事件都清一次：`lost` 时纹理已死、尽早清掉离屏死条目；`restored`
/// 时（若引擎以恢复而非重建 canvas 的方式处理）再兜底清一次。
bool _installed = false;

void installWebGLContextRecovery() {
  if (_installed) return;
  _installed = true;

  void onContextEvent(web.Event event) {
    final cache = PaintingBinding.instance.imageCache;
    // clearLiveImages 释放当前 live 句柄，clear 清掉 keepAlive 缓存条目；
    // 两级都清后，下一次 resolve 一律 cache miss → 重新解码到新 context 的纹理。
    cache.clearLiveImages();
    cache.clear();
    // 触发一帧，让当前挂载的图片尽快重新解码绘制。
    WidgetsBinding.instance.scheduleFrame();
    debugPrint('[WebGLRecovery] ${event.type}：已清空 imageCache 以重新解码封面');
  }

  final listener = onContextEvent.toJS;
  web.window.addEventListener('webglcontextlost', listener, true.toJS);
  web.window.addEventListener('webglcontextrestored', listener, true.toJS);
}
