import '../../features/home/presentation/plugin_tab_page_stub.dart';

/// Web 实现：把挂起状态转发给所有活跃插件 iframe 的 pointer-events。
///
/// Flutter Web 中插件 iframe（HtmlElementView）是位于 Flutter canvas 之上的
/// DOM 元素，与 Flutter 弹出层（如“更多”溢出菜单）重叠区域的点击会被
/// iframe 截获（iframe 内文档的事件不会冒泡出 iframe），浮层重叠区无法
/// 点击。浮层显示期间把 iframe 的 pointer-events 切到 none 让事件穿透回
/// Flutter，关闭后恢复（songloft-org/songloft#451）。
void setPluginIframePointerEventsSuspended(bool suspended) {
  PluginTabPage.setPointerEventsSuspended(suspended);
}
