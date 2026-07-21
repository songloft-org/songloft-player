/// 插件 iframe 抖动/重载诊断（songloft-org/songloft#278）——**仅 Web 平台**。
///
/// 背景：#278 的 widget 树修复（稳定 GlobalKey + 只按 tabConfig 裁剪保活）之后，
/// 仍有用户偶发抖动，但维护者本地无法复现。已核实 Flutter 3.44 CanvasKit 引擎的
/// 平台视图 embedder 有两条会把承载 iframe 的 DOM 子树从 sceneHost 上
/// `remove()` 再 `insertBefore()` 的路径：
///   ① `_reconstructClipViewsChain`：平台视图**祖先 clip 数量变化**的那一帧触发；
///   ② `_updateDomForNewComposition`：**合成层序变化**的那一帧触发。
/// 浏览器里把 `<iframe>` 从 DOM 摘下再挂回 = 强制重载整张页面（表现为抖动 +
/// 重载期间插件请求偶发报错），且与 widget 是否重建无关，GlobalKey 保不住。
///
/// 本诊断把「iframe 每次 load、以及触发那一帧的 clip 数量/尺寸/祖先链」打到浏览器
/// console，用于让能复现的用户抓取确切触发点，再做最小精准修复。
///
/// **默认开启**：抖动为间歇性且刷新后常无法复现，若要求用户先设开关再刷新会丢失现场，
/// 故直接默认打点，用户跑 dev 版复现即可、无需任何操作。开销极小（仅进插件 Tab 建
/// iframe 时打一次 + 真发生 reload 时才打，非每帧）。需静音时在浏览器 console 执行
/// `localStorage.setItem('sl_iframe_diag','off')`。
///
/// ⚠️ 这是定位 #278 期间的**临时埋点**：前端 dev/正式版均为 release 构建、无便捷的
/// 「仅 dev」门控，故正式版 console 也会打几行。**根因确定后应连同本文件与其调用一起
/// 移除**。
library;

import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// 每个 label 的 viewId（工厂）创建次数——用于区分「widget 树反复重建 iframe」
/// 与「引擎摘挂同一 iframe 重载」两种根因。
final _viewIdCreations = <String, int>{};

bool get _enabled {
  try {
    // 默认开启；仅显式 opt-out 时静音。
    return web.window.localStorage.getItem('sl_iframe_diag') != 'off';
  } catch (_) {
    return true;
  }
}

void _log(String msg) => web.console.warn(msg.toJS);

/// 统计 iframe 到 sceneHost 之间 `flt-clip` 祖先数量——即引擎
/// `_reconstructClipViewsChain` 里判定摘挂的 `currentClippingCount`。
/// 若两次 reload 之间该值变化，则确证是路径①（clip 数量翻动）。
int _clipAncestorCount(web.Element el) {
  var count = 0;
  web.Element? node = el.parentElement;
  var hops = 0;
  while (node != null && hops < 32) {
    final tag = node.tagName.toLowerCase();
    if (tag == 'flt-clip') count++;
    if (tag == 'flt-scene-host' || tag == 'body') break;
    node = node.parentElement;
    hops++;
  }
  return count;
}

/// 记录 iframe 到根的祖先标签链（截断，便于判断是否发生了 reparent 换父）。
String _ancestorChain(web.Element el) {
  final parts = <String>[];
  web.Element? node = el.parentElement;
  var hops = 0;
  while (node != null && hops < 8) {
    parts.add(node.tagName.toLowerCase());
    if (node.tagName.toLowerCase() == 'flt-scene-host') break;
    node = node.parentElement;
    hops++;
  }
  return parts.join('>');
}

/// 为一个插件 iframe 挂载诊断。应在 view factory 内、iframe 创建后立即调用。
/// [label] 形如 `tab:<entryPath>` 或 `webview:<hash>`，[viewId] 为平台视图 id。
void attachPluginIframeDiagnostics(
  web.HTMLIFrameElement iframe,
  String label,
  int viewId,
) {
  if (!_enabled) return;

  final creations = (_viewIdCreations[label] ?? 0) + 1;
  _viewIdCreations[label] = creations;
  _log(
    '[sl-iframe-diag][$label] NEW-VIEWID viewId=$viewId '
    'factoryCreations=$creations '
    '(>1 说明 widget 树在重建 iframe；若始终=1 而下方 RELOAD 递增，则是引擎摘挂)',
  );

  var loadCount = 0;
  var lastLoadMs = 0;
  var lastClips = -1;

  iframe.addEventListener(
    'load',
    ((web.Event _) {
      loadCount++;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final dt = lastLoadMs == 0 ? 0 : nowMs - lastLoadMs;
      lastLoadMs = nowMs;

      final rect = iframe.getBoundingClientRect();
      final clips = _clipAncestorCount(iframe);
      final clipChanged = lastClips >= 0 && clips != lastClips;
      lastClips = clips;

      final w = rect.width.round();
      final h = rect.height.round();
      final iw = web.window.innerWidth;
      final ih = web.window.innerHeight;

      if (loadCount == 1) {
        _log(
          '[sl-iframe-diag][$label] LOAD#1(initial) '
          'clips=$clips size=${w}x$h win=${iw}x$ih '
          'connected=${iframe.isConnected} chain=${_ancestorChain(iframe)}',
        );
      } else {
        // 非首次 load = iframe 被重载（#278 的抖动症状）。
        _log(
          '[sl-iframe-diag][$label] RELOAD#${loadCount - 1} dt=${dt}ms '
          'clips=$clips clipChanged=$clipChanged '
          'size=${w}x$h win=${iw}x$ih connected=${iframe.isConnected} '
          'chain=${_ancestorChain(iframe)} '
          '${clipChanged ? "=> 命中路径①(clip数量翻动)" : "=> clip未变,疑路径②(合成层序)"}',
        );
      }
    }).toJS,
  );
}
