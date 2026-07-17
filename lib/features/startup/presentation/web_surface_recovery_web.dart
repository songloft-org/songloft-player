import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// 遍历页面(含 shadow root)上的所有 `<canvas>`,统计 WebGL context 已丢失的
/// 数量,仅用于**诊断记录**(不做任何干预)。
///
/// 说明:早期版本曾对已丢失的 canvas 主动补发合成 `webglcontextlost` 事件,试图
/// 促使引擎重建。但 3.41+ 的新 surface 架构在处理 `webglcontextlost` 时存在
/// LateInitializationError 崩溃(flutter/flutter#184683,修复 #185116 尚未进入
/// stable),主动派发反而会**故意触发该崩溃**。故这里退回为只观测、不干预,
/// 由引擎自身的 context-lost 恢复机制 + resume 时的 scheduleForcedFrame 处理。
///
/// 返回检测到 context 已丢失的画布数量。
int reportLostWebGlContexts() {
  final canvases = <web.HTMLCanvasElement>[];
  _collectCanvases(web.document, canvases);

  var lost = 0;
  for (final canvas in canvases) {
    if (_isContextLost(canvas)) lost++;
  }

  if (lost > 0) {
    debugPrint(
      '[WebSurfaceRecovery] 检测到 $lost/${canvases.length} 个 canvas 的 WebGL '
      'context 已丢失(诊断);等待引擎恢复 + scheduleForcedFrame 重绘',
    );
  }
  return lost;
}

/// 同时具备 `querySelectorAll` 的根节点(Document / ShadowRoot 等)统一视图。
extension type _QueryRoot(JSObject _) implements JSObject {
  external web.NodeList querySelectorAll(String selectors);
}

/// 收集 [root] 下所有 `<canvas>`,并递归进入每个元素的(open)shadow root。
void _collectCanvases(JSObject root, List<web.HTMLCanvasElement> out) {
  final q = root as _QueryRoot;

  final direct = q.querySelectorAll('canvas');
  for (var i = 0; i < direct.length; i++) {
    final node = direct.item(i);
    if (node != null && node.isA<web.HTMLCanvasElement>()) {
      out.add(node as web.HTMLCanvasElement);
    }
  }

  final all = q.querySelectorAll('*');
  for (var i = 0; i < all.length; i++) {
    final node = all.item(i);
    if (node != null && node.isA<web.Element>()) {
      final shadow = (node as web.Element).shadowRoot;
      if (shadow != null) {
        _collectCanvases(shadow, out);
      }
    }
  }
}

bool _isContextLost(web.HTMLCanvasElement canvas) {
  final ctx = canvas.getContext('webgl2') ?? canvas.getContext('webgl');
  if (ctx == null) return false;
  return (ctx as web.WebGLRenderingContext).isContextLost();
}
