// 插件 iframe 指针事件挂起桥（songloft-org/songloft#451）。
//
// Flutter Web 中插件 iframe（HtmlElementView）位于 Flutter canvas 之上，
// 与 Flutter 弹出层（如底部导航“更多”溢出菜单）几何重叠区域的点击会被
// iframe 截获，浮层重叠区无法点击。需要把浮层盖住 iframe 的时段暴露给
// 共享代码（如 AdaptiveScaffold），由它弹出前挂起、关闭后恢复。
export 'plugin_iframe_gate_stub.dart'
    if (dart.library.html) 'plugin_iframe_gate_web.dart';
