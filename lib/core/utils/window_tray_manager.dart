import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'file_logger.dart';

class WindowTrayManager with WindowListener, TrayListener {
  static final WindowTrayManager _instance = WindowTrayManager._internal();

  factory WindowTrayManager() {
    return _instance;
  }

  WindowTrayManager._internal();

  /// 退出前的清理回调（如释放音频资源），由 main.dart 注入
  Future<void> Function()? onBeforeExit;

  static Future<void> setup() async {
    if (kIsWeb) return;
    // 目前根据 MVP 计划，仅在 Windows 下开启隐藏到托盘功能
    if (!Platform.isWindows) return;

    await windowManager.ensureInitialized();
    
    // 拦截窗口关闭事件
    await windowManager.setPreventClose(true);

    final manager = WindowTrayManager();
    windowManager.addListener(manager);
    trayManager.addListener(manager);

    await manager._initTray();
  }

  Future<void> _initTray() async {
    String getIconPath() {
      if (Platform.isWindows) {
        final exeDir = File(Platform.resolvedExecutable).parent.path;
        final buildPath = '$exeDir\\data\\flutter_assets\\windows\\runner\\resources\\app_icon.ico';
        if (File(buildPath).existsSync()) {
          return buildPath;
        }
        return 'windows/runner/resources/app_icon.ico';
      }
      return 'assets/icons/app_icon.png';
    }

    await trayManager.setIcon(getIconPath());

    final menuItems = <MenuItem>[
      MenuItem(
        key: 'show_window',
        label: '打开 Songloft',
      ),
    ];
    if (FileLogger.logDir != null) {
      menuItems.add(MenuItem(
        key: 'open_logs',
        label: '打开日志目录',
      ));
    }
    menuItems.addAll([
      MenuItem.separator(),
      MenuItem(
        key: 'exit_app',
        label: '退出',
      ),
    ]);
    Menu menu = Menu(items: menuItems);
    await trayManager.setContextMenu(menu);
    await trayManager.setToolTip('Songloft');
  }

  @override
  void onWindowClose() async {
    // 点击 X 按钮时触发，将窗口隐藏而不是退出
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      windowManager.hide();
    }
  }

  @override
  void onTrayIconMouseDown() {
    _restoreWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    // 右键点击托盘图标：弹出上下文菜单
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    if (menuItem.key == 'show_window') {
      _restoreWindow();
    } else if (menuItem.key == 'open_logs') {
      final dir = FileLogger.logDir;
      if (dir != null) {
        Process.run('explorer', [dir]);
      }
    } else if (menuItem.key == 'exit_app') {
      try {
        await onBeforeExit?.call();
      } catch (e) {
        debugPrint('[WindowTrayManager] onBeforeExit error: $e');
      }
      await windowManager.setPreventClose(false);
      await windowManager.close();
    }
  }

  Future<void> _restoreWindow() async {
    await windowManager.show();
    await windowManager.focus();
    // hide/show 循环后 Flutter 引擎的 IME 上下文可能未正确恢复，
    // 延迟重置焦点以重建输入法连接
    Future.delayed(const Duration(milliseconds: 100), () {
      final currentFocus = FocusManager.instance.primaryFocus;
      if (currentFocus != null && currentFocus.canRequestFocus) {
        currentFocus.unfocus();
        Future.delayed(const Duration(milliseconds: 50), () {
          if (currentFocus.canRequestFocus) {
            currentFocus.requestFocus();
          }
        });
      }
    });
  }
}
