/// 插件页渲染层的**引擎无关**契约（songloft-org/songloft#341）。
///
/// 插件页历史上只有一种 native 实现（`flutter_inappwebview`），渲染逻辑与
/// 页面 chrome 混在两个近乎重复的 State 里。引入 WebF 作为备选引擎后，
/// 需要一层薄抽象把「谁来渲染」与「外面套什么壳」分开：
///
///   - [PluginRenderController]：宿主页面能对渲染面做的操作
///   - `PluginRenderView`：引擎无关的壳（加载态 / 超时 / 错误 UI / 重试）
///   - `PluginRenderSurface*`：各引擎自己的渲染面 + 宿主桥 + 主题下推
library;

/// 单个插件声明的渲染引擎。
///
/// **不是用户偏好**：由插件自己的 `plugin.json` 里的 `render_engine` 字段声明，
/// 后端经 `GET /api/v1/jsplugins` 的 `render_engine` 透传。设置页刻意不提供
/// 全局覆盖开关 —— 插件作者才知道自家页面在哪个引擎下正常，用户级开关只会让
/// 「某个插件坏了」变成「所有插件一起坏」。
///
/// 仅 native 平台有意义：Web 端永远走 iframe（`*_stub.dart`），WebF 不支持
/// Flutter Web（其 `lib/` 内有 39 处无条件 `import 'dart:ffi'`，是编译失败而
/// 非运行时降级）。
enum PluginRenderEngine {
  /// `flutter_inappwebview`，插件未声明时的默认。
  webView,

  /// WebF，渲染进 Flutter 管线、零 platform view。
  webF;

  /// 解析 manifest / API 里的 `render_engine` 字段。
  ///
  /// 缺失（老服务端不返回该字段）、空串、大小写变体与非法值一律回落到
  /// [webView]：那是随时能跑的保守默认，而 WebF 是 0.x beta，不该因为一个
  /// 拼错的字段就把插件推上去。
  static PluginRenderEngine fromManifestValue(String? value) =>
      value?.trim().toLowerCase() == 'webf'
          ? PluginRenderEngine.webF
          : PluginRenderEngine.webView;

  /// 该引擎的渲染面是否是独立的原生表面（platform view）。
  ///
  /// 为 true 时宿主要额外伺候一堆平台细节：Windows 上 WebView2 是独立 HWND，
  /// 最小化后不自动收起、残留拦截桌面右键（songloft-org/songloft#293），
  /// `Offstage` 收不起来，必须把整个渲染面移出 widget 树才能销毁。
  ///
  /// WebF 产出的是普通 Flutter RenderObject（`WebFRootViewport extends
  /// MultiChildRenderObjectWidget`），没有独立原生表面，这类补丁全都不需要。
  bool get usesPlatformView => this == PluginRenderEngine.webView;
}

/// 给插件页 URL 的**路径**补上尾斜杠。
///
/// 后端给每个插件页注入 `<base href="/api/v1/jsplugin/<entryPath>/">`，页面里的
/// `static/js/app.bundle.js` 之类相对引用全靠它解析。**WebF 不采纳 `<base href>`**，
/// 而是按文档 URL 所在目录解析 —— 无尾斜杠时 `/api/v1/jsplugin/subsonic` 的目录是
/// `/api/v1/jsplugin/`，于是脚本被求到 `/api/v1/jsplugin/static/js/...`，那条路径
/// 不匹配任何免鉴权静态路由，落到需要 JWT 的兜底路由拿 401，整页白屏（实测）。
///
/// 补上尾斜杠后目录恰好等于 base href 声明的值，两种解析方式结果一致。
/// 后端本来就注册了带尾斜杠的路由，所以这对 InAppWebView 与浏览器都是无害的
/// ——刻意不做引擎分支，避免两条链路的 URL 形态漂移。
String ensurePluginPathTrailingSlash(String url) {
  final uri = Uri.parse(url);
  if (uri.path.endsWith('/')) return url;
  return uri.replace(path: '${uri.path}/').toString();
}

/// 宿主页面对渲染面的操作句柄。
///
/// 由具体引擎实现，经 `PluginRenderView` 的 `onControllerReady` 回调交给宿主。
abstract class PluginRenderController {
  /// 页面内若还有可回退的历史则回退，并返回 `true`；
  /// 否则返回 `false`，由宿主决定是退出路由还是退出应用。
  ///
  /// 之所以是「回退与否的判断 + 动作」打包成一个方法、而不是暴露
  /// `canGoBack()` + `goBack()` 两个原语：WebF 侧**没有** `canGoBack`
  /// （`module/history.dart` 的 case 列表里只有 length/state/back/forward/
  /// pushState/replaceState/go，controller 上也没有 `goBack()`），只能由页面内
  /// 的 JS 自己判断后回报结果，拆成两步在那边无法原子实现。
  Future<bool> goBackIfPossible();

  /// 释放渲染面持有的输入焦点。
  ///
  /// 原生 WebView 即使被 `Offstage` 隐藏，仍可能在系统层面握着键盘焦点、
  /// 抢走 Flutter 的输入法上下文，所以 Tab 切走时要主动释放。
  void clearFocus();

  /// 告诉页面它现在可见 / 不可见，语义等价于 Web 的 `document.visibilityState`。
  ///
  /// **必须由宿主显式推，页面自己发现不了。** 移动端与 Web 的插件 Tab 靠
  /// `shell_layout.dart` 的 `Offstage` 保活：切走时 controller 不销毁、页面 JS
  /// 状态完整保留，而 WebF 的 viewport 取的是 FlutterView 物理尺寸，所以连
  /// `resize` 都不会有——**从页面的角度看，「切 Tab」这件事完全不存在**。
  ///
  /// 而 WebF 全库只有一个 `document.visibilityChange()` 调用点，挂在
  /// `didChangeAppLifecycleState`（`view_controller.dart`）上，只有**整个 App**
  /// 前后台切换才派发。于是插件页里 `addEventListener('visibilitychange', …)`
  /// 在 Tab 切换场景是死代码——miot 的封面「切走再回来就永久丢失」就是这么来的
  /// （songloft-org/songloft-plugin-miot#86）：页面把一次瞬时的图片加载失败闩锁住，
  /// 而唯一的复位路径永远不会触发。
  ///
  /// 桌面端切走即销毁渲染面（不走 Offstage），这条通知对它无害但也无用。
  void setPageVisible(bool visible);
}
