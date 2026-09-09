/// 非 Web 平台空实现。
///
/// 原生平台的插件 WebView（flutter_inappwebview）与 Flutter 浮层的层级、
/// 命中测试由引擎合成器管理，无需 DOM 层面的挂起。见
/// `plugin_iframe_gate_web.dart` 与 songloft-org/songloft#451。
void setPluginIframePointerEventsSuspended(bool suspended) {}
