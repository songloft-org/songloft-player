import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'desktop_lyric_view.dart';

/// 桌面歌词悬浮窗子 engine 的根 Widget（songloft-org/songloft#318）。
///
/// 不带路由、不接主窗口的 ProviderScope——悬浮窗运行在独立的 Flutter engine 里，
/// 只需要透明背景 + AppLocalizations（右键菜单文案跟随语言）。
class DesktopLyricApp extends StatelessWidget {
  const DesktopLyricApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      themeMode: ThemeMode.dark,
      theme: ThemeData(scaffoldBackgroundColor: Colors.transparent),
      builder: (context, child) => ColoredBox(
        color: Colors.transparent,
        child: child,
      ),
      home: const DesktopLyricView(),
    );
  }
}
