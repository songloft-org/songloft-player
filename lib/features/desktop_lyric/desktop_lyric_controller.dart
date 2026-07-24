import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../player/presentation/providers/lyric_provider.dart';
import '../settings/presentation/providers/settings_provider.dart';
import 'desktop_lyric_font_size.dart';
import 'desktop_lyric_ipc.dart';

/// 主窗口侧管理桌面歌词悬浮窗的生命周期（songloft-org/songloft#318）。
///
/// 负责创建/关闭悬浮子窗口、把 [lyricStateProvider] 的歌词文本推给它、接收悬浮窗
/// 右键菜单发回的锁定/隐藏请求。字号/透明度/锁定的**初始值**悬浮窗自己读
/// AppPreferences，这里的 [pushConfig] 只用于窗口已打开时的**实时**联动。
class DesktopLyricController {
  DesktopLyricController(this._ref) {
    desktopLyricChannel.setMethodCallHandler(_handleMethodCall);
  }

  final Ref _ref;
  WindowController? _windowController;
  ProviderSubscription<LyricState>? _lyricSub;
  String _lastCurrent = '';
  String _lastNext = '';

  bool get isOpen => _windowController != null;

  Future<void> open() async {
    if (isOpen) return;
    _windowController = await WindowController.create(
      const WindowConfiguration(arguments: kDesktopLyricWindowArguments),
    );
    _lastCurrent = '';
    _lastNext = '';
    _lyricSub = _ref.listen<LyricState>(lyricStateProvider, (prev, next) {
      _maybePushLyric(next);
    });
  }

  Future<void> close() async {
    if (!isOpen) return;
    _lyricSub?.close();
    _lyricSub = null;
    try {
      await desktopLyricChannel.invokeMethod(kDesktopLyricMethodClose);
    } catch (_) {
      // 悬浮窗可能已经被用户从任务管理器杀掉，忽略即可
    }
    _windowController = null;
  }

  /// 悬浮窗已打开时，把最新的锁定/字号/透明度推给它实时生效。
  Future<void> pushConfig({
    required bool locked,
    required DesktopLyricFontSize fontSize,
    required double opacity,
  }) async {
    if (!isOpen) return;
    try {
      await desktopLyricChannel.invokeMethod(kDesktopLyricMethodUpdateConfig, {
        'locked': locked,
        'fontSize': fontSize.storageValue,
        'opacity': opacity,
      });
    } catch (_) {}
  }

  void _maybePushLyric(LyricState state) {
    if (!isOpen) return;
    final current = state.currentLyricText;
    final next = state.nextLyricText;
    if (current == _lastCurrent && next == _lastNext) return;
    _lastCurrent = current;
    _lastNext = next;
    unawaited(
      desktopLyricChannel
          .invokeMethod(kDesktopLyricMethodUpdateLyric, {
            'current': current,
            'next': next,
          })
          .catchError((_) {}),
    );
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case kDesktopLyricMethodReady:
        // 悬浮窗刚连上，可能错过了创建瞬间的推送，补一次当前状态
        _maybePushLyric(_ref.read(lyricStateProvider));
      case kDesktopLyricMethodLockToggled:
        final args = call.arguments as Map;
        final locked = args['locked'] as bool? ?? false;
        await _ref.read(desktopLyricLockedProvider.notifier).setLocked(locked);
      case kDesktopLyricMethodHideRequested:
        await _ref.read(desktopLyricEnabledProvider.notifier).setEnabled(false);
    }
    return null;
  }
}

/// 全局单例：整个 App 生命周期内只有一个桌面歌词 Controller。
final desktopLyricControllerProvider = Provider<DesktopLyricController>((ref) {
  return DesktopLyricController(ref);
});
