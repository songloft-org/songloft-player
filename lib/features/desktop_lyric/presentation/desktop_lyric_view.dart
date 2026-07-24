import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/storage/app_preferences.dart';
import '../../../l10n/app_localizations.dart';
import '../desktop_lyric_font_size.dart';
import '../desktop_lyric_ipc.dart';

/// 桌面歌词悬浮窗的唯一 UI（songloft-org/songloft#318）。
///
/// 负责：读取本地配置并设置窗口样式（frameless/透明/置顶/跳过任务栏）、
/// 恢复/持久化窗口位置、通过 [desktopLyricChannel] 接收主窗口推送的歌词与配置、
/// 未锁定时支持拖动和右键菜单（锁定/隐藏）。
class DesktopLyricView extends StatefulWidget {
  const DesktopLyricView({super.key});

  @override
  State<DesktopLyricView> createState() => _DesktopLyricViewState();
}

class _DesktopLyricViewState extends State<DesktopLyricView>
    with WindowListener {
  static const _windowSize = Size(800, 120);

  AppPreferences? _prefs;
  String _current = '';
  String _next = '';
  bool _locked = false;
  DesktopLyricFontSize _fontSize = DesktopLyricFontSize.medium;
  double _opacity = 0.4;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    unawaited(_init());
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    desktopLyricChannel.setMethodCallHandler(null);
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await AppPreferences.create();
    _prefs = prefs;
    _locked = prefs.getDesktopLyricLocked();
    _fontSize = DesktopLyricFontSizeX.fromStorageValue(
      prefs.getDesktopLyricFontSize(),
    );
    _opacity = prefs.getDesktopLyricOpacity();

    await windowManager.setAsFrameless();
    await windowManager.setBackgroundColor(Colors.transparent);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setSkipTaskbar(true);
    await windowManager.setHasShadow(false);
    await windowManager.setResizable(false);
    await windowManager.setBounds(await _computeInitialBounds());
    if (_locked) {
      await windowManager.setIgnoreMouseEvents(true, forward: true);
    }

    await desktopLyricChannel.setMethodCallHandler(_handleMethodCall);

    if (mounted) setState(() {});

    await windowManager.show();
    unawaited(desktopLyricChannel.invokeMethod(kDesktopLyricMethodReady));
  }

  Future<Rect> _computeInitialBounds() async {
    final displays = await screenRetriever.getAllDisplays();
    final savedX = _prefs?.getDesktopLyricPosX() ?? -1;
    final savedY = _prefs?.getDesktopLyricPosY() ?? -1;
    if (savedX >= 0 && savedY >= 0 && _isOnAnyDisplay(savedX, savedY, displays)) {
      return Rect.fromLTWH(
        savedX,
        savedY,
        _windowSize.width,
        _windowSize.height,
      );
    }
    // 从未设置过位置，或上次保存的位置所在屏幕已经不存在（比如拔掉了副屏）——
    // 回退到主屏底部居中，避免悬浮窗出现在用户找不到的地方。
    final primary = await screenRetriever.getPrimaryDisplay();
    final screenSize = primary.size;
    final origin = primary.visiblePosition ?? Offset.zero;
    final x = origin.dx + (screenSize.width - _windowSize.width) / 2;
    final y = origin.dy + screenSize.height * 0.85 - _windowSize.height / 2;
    return Rect.fromLTWH(x, y, _windowSize.width, _windowSize.height);
  }

  /// 判断 (x, y) 是否落在任意一个显示器的可见范围内（逻辑像素）。
  bool _isOnAnyDisplay(double x, double y, List<Display> displays) {
    for (final display in displays) {
      final origin = display.visiblePosition ?? Offset.zero;
      final size = display.visibleSize ?? display.size;
      final rect = Rect.fromLTWH(origin.dx, origin.dy, size.width, size.height);
      if (rect.contains(Offset(x, y))) return true;
    }
    return false;
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case kDesktopLyricMethodUpdateLyric:
        final args = call.arguments as Map;
        if (!mounted) return null;
        setState(() {
          _current = args['current'] as String? ?? '';
          _next = args['next'] as String? ?? '';
        });
      case kDesktopLyricMethodUpdateConfig:
        final args = call.arguments as Map;
        final locked = args['locked'] as bool? ?? _locked;
        final fontSize = args['fontSize'] as String?;
        final opacity = args['opacity'] as double?;
        if (locked != _locked) {
          await windowManager.setIgnoreMouseEvents(locked, forward: true);
        }
        if (!mounted) return null;
        setState(() {
          _locked = locked;
          if (fontSize != null) {
            _fontSize = DesktopLyricFontSizeX.fromStorageValue(fontSize);
          }
          if (opacity != null) _opacity = opacity;
        });
      case kDesktopLyricMethodClose:
        await _persistPosition();
        await windowManager.close();
    }
    return null;
  }

  Future<void> _persistPosition() async {
    final prefs = _prefs;
    if (prefs == null) return;
    final bounds = await windowManager.getBounds();
    await prefs.setDesktopLyricPosition(bounds.left, bounds.top);
  }

  Future<void> _toggleLock(bool locked) async {
    await windowManager.setIgnoreMouseEvents(locked, forward: true);
    await _prefs?.setDesktopLyricLocked(locked);
    if (mounted) setState(() => _locked = locked);
    unawaited(
      desktopLyricChannel.invokeMethod(kDesktopLyricMethodLockToggled, {
        'locked': locked,
      }),
    );
  }

  void _requestHide() {
    unawaited(desktopLyricChannel.invokeMethod(kDesktopLyricMethodHideRequested));
  }

  Future<void> _showContextMenu(Offset globalPosition) async {
    final l10n = AppLocalizations.of(context);
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx,
        globalPosition.dy,
      ),
      items: [
        PopupMenuItem(value: 'lock', child: Text(l10n.desktopLyricContextLock)),
        PopupMenuItem(value: 'hide', child: Text(l10n.desktopLyricContextHide)),
      ],
    );
    switch (selected) {
      case 'lock':
        await _toggleLock(true);
      case 'hide':
        _requestHide();
    }
  }

  @override
  void onWindowMoved() {
    unawaited(_persistPosition());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasLyric = _current.isNotEmpty || _next.isNotEmpty;
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: _locked ? null : (_) => windowManager.startDragging(),
        onSecondaryTapUp:
            _locked ? null : (details) => _showContextMenu(details.globalPosition),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: _opacity),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hasLyric ? _current : l10n.desktopLyricNoLyric,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: _fontSize.mainTextSize,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_next.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _next,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: _fontSize.subTextSize,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
