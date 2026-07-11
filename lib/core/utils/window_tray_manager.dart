import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../../l10n/l10n_holder.dart';
import 'file_logger.dart';

class WindowTrayManager with WindowListener, TrayListener {
  static final WindowTrayManager _instance = WindowTrayManager._internal();

  factory WindowTrayManager() {
    return _instance;
  }

  WindowTrayManager._internal();

  /// 退出前的清理回调（如释放音频资源），由 main.dart 注入
  Future<void> Function()? onBeforeExit;

  bool _isExiting = false;
  Future<void>? _exitFuture;

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

  /// 修复 Windows 高 DPI 下启动时「窗口一半白屏、resize/全屏后恢复」的问题。
  ///
  /// 根因：首帧渲染的 Flutter surface 尺寸与窗口客户区不匹配，白色区域为未绘制部分，
  /// 直到一次 resize 触发引擎按客户区重排才恢复。首帧渲染后主动做一次尺寸抖动强制重排。
  /// 手法与 window_manager 内部 setFullScreen 的修复一致（见其 GitHub issue #311）。
  static void fixInitialSurfaceSize() {
    if (kIsWeb || !Platform.isWindows) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 200));
      try {
        final size = await windowManager.getSize();
        await windowManager.setSize(size + const Offset(1, 1));
        await windowManager.setSize(size);
      } catch (e) {
        debugPrint('[WindowTrayManager] 首帧尺寸修复失败: $e');
      }
    });
  }

  Future<void> _initTray() async {
    String getIconPath() {
      if (Platform.isWindows) {
        final exeDir = File(Platform.resolvedExecutable).parent.path;
        final buildPath =
            '$exeDir\\data\\flutter_assets\\windows\\runner\\resources\\app_icon.ico';
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
        label: l10nOrNull?.coreTrayOpen ?? '打开 Songloft',
      ),
    ];
    if (FileLogger.logDir != null) {
      menuItems.add(
        MenuItem(
          key: 'open_logs',
          label: l10nOrNull?.coreTrayOpenLogs ?? '打开日志目录',
        ),
      );
    }
    menuItems.addAll([
      MenuItem.separator(),
      MenuItem(key: 'exit_app', label: l10nOrNull?.coreTrayExit ?? '退出'),
    ]);
    Menu menu = Menu(items: menuItems);
    await trayManager.setContextMenu(menu);
    await trayManager.setToolTip('Songloft');
  }

  @override
  void onWindowClose() async {
    if (_isExiting) return;

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
      await exitApp();
    }
  }

  Future<void> exitApp() {
    _exitFuture ??= _exitApp();
    return _exitFuture!;
  }

  Future<void> _exitApp() async {
    _isExiting = true;

    try {
      await onBeforeExit?.call();
    } catch (e, stackTrace) {
      debugPrint('[WindowTrayManager] onBeforeExit error: $e');
      debugPrint('[WindowTrayManager] Stack trace: $stackTrace');
    }

    windowManager.removeListener(this);
    trayManager.removeListener(this);

    try {
      await trayManager.destroy();
    } catch (e) {
      debugPrint('[WindowTrayManager] tray destroy error: $e');
    }

    try {
      await windowManager.setPreventClose(false);
      await windowManager.close();
    } catch (e) {
      debugPrint('[WindowTrayManager] window close error: $e');
      await windowManager.destroy();
    }
  }

  Future<void> _restoreWindow() async {
    if (_isExiting) return;

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
