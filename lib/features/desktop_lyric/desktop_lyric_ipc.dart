import 'package:desktop_multi_window/desktop_multi_window.dart';

/// 主窗口 <-> 桌面歌词悬浮窗 IPC 协议（songloft-org/songloft#318）。
///
/// 悬浮窗运行在独立的 Flutter engine 里，不共享主窗口的 Riverpod ProviderScope，
/// 双方通过同一个 bidirectional [WindowMethodChannel] 通信：各自在启动时
/// setMethodCallHandler 注册一次，之后都可以用 invokeMethod 调对方。
///
/// 字号/透明度/锁定/位置这些配置的**初始值**不走 IPC —— 悬浮窗自己的 engine
/// 直接新建一份 [AppPreferences]（同一份磁盘存储）在启动时读取；IPC 只用于
/// 窗口已经打开时的**实时**联动（配置变化、歌词滚动）。

/// 创建悬浮子窗口时传入的 arguments 哨兵值，main() 据此判断"这是桌面歌词窗口"。
const String kDesktopLyricWindowArguments = 'songloft_desktop_lyric';

/// method: 子 -> 主。悬浮窗完成初始化并注册好 handler 后发出，
/// 主窗口收到后立即补推一次当前歌词，避免窗口刚打开时空白。
const String kDesktopLyricMethodReady = 'ready';

/// method: 主 -> 子。payload: `{"current": String, "next": String}`。
/// 仅在文本真的变化时推送。
const String kDesktopLyricMethodUpdateLyric = 'updateLyric';

/// method: 主 -> 子。payload: `{"locked": bool, "fontSize": String, "opacity": double}`。
/// 对应设置项变化时推送。
const String kDesktopLyricMethodUpdateConfig = 'updateConfig';

/// method: 主 -> 子。悬浮窗收到后先把当前位置存进本地 AppPreferences，
/// 再调用 `windowManager.close()` 关闭自己。
const String kDesktopLyricMethodClose = 'close';

/// method: 子 -> 主。payload: `{"locked": bool}`。用户在悬浮窗右键菜单点了锁定/解锁，
/// 主窗口据此同步设置页的开关状态。
const String kDesktopLyricMethodLockToggled = 'onLockToggled';

/// method: 子 -> 主。用户在悬浮窗右键菜单点了"隐藏桌面歌词"。
const String kDesktopLyricMethodHideRequested = 'onHideRequested';

/// 主窗口和悬浮窗共用的双向 channel。
const WindowMethodChannel desktopLyricChannel = WindowMethodChannel(
  'songloft.desktop_lyric',
  mode: ChannelMode.bidirectional,
);
