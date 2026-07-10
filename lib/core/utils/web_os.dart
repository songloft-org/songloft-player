// 浏览器所在操作系统检测（仅在 Web 平台有意义），用于按访客设备推荐客户端下载。
//
// 条件导出：Web 平台走 web_os_web.dart（读 navigator.userAgent），
// 其它平台走 web_os_stub.dart（恒返回 unknown，避免把 package:web 牵入原生构建）。
export 'web_os_stub.dart' if (dart.library.js_interop) 'web_os_web.dart';

/// 浏览器所在操作系统。非 Web 平台一律为 [WebOS.unknown]。
enum WebOS { android, ios, windows, macos, linux, unknown }
