import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'presentation/desktop_lyric_app.dart';

/// 桌面歌词悬浮窗子 engine 的入口（songloft-org/songloft#318）。
///
/// 由 main.dart 在检测到当前 engine 是桌面歌词窗口时调用，只做窗口管理初始化，
/// 不跑 AudioService/SMTC/Tracely/托盘/单实例检测等主窗口专属逻辑。
Future<void> runDesktopLyricWindow() async {
  await windowManager.ensureInitialized();
  runApp(const DesktopLyricApp());
}
