import 'package:web/web.dart' as web;

import 'web_os.dart';

/// Web 平台：根据浏览器 User-Agent 推断访客操作系统。
///
/// 判定顺序有讲究：Android 的 UA 里同时含 "Linux"，必须先于 Linux 命中；
/// iPadOS 13+ 的 Safari 会把自己伪装成桌面 Mac，故对 Mac + 触摸屏额外判为 iOS。
WebOS detectWebOS() {
  final ua = web.window.navigator.userAgent.toLowerCase();

  if (ua.contains('android')) return WebOS.android;
  if (ua.contains('iphone') || ua.contains('ipad') || ua.contains('ipod')) {
    return WebOS.ios;
  }
  if (ua.contains('windows')) return WebOS.windows;
  if (ua.contains('mac')) {
    // iPadOS 伪装成 Mac：Mac 桌面无触摸屏，maxTouchPoints > 1 基本可判为 iPad。
    if (web.window.navigator.maxTouchPoints > 1) return WebOS.ios;
    return WebOS.macos;
  }
  if (ua.contains('linux')) return WebOS.linux;
  return WebOS.unknown;
}
