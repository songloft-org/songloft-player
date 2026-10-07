import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';

/// 设备本地的长歌名滚动开关，不参与服务端偏好同步。
class SongTitleScrollingNotifier extends Notifier<bool> {
  bool _userTouched = false;
  Future<void> _writes = Future<void>.value();

  @override
  bool build() {
    _userTouched = false;
    _load();
    return true;
  }

  Future<void> _load() async {
    try {
      final prefs = await ref.read(appPreferencesProvider.future);
      if (!ref.mounted || _userTouched) return;
      state = prefs.isSongTitleScrollingEnabled();
    } catch (_) {
      // 读取失败保留默认值或用户刚设置的值。
    }
  }

  Future<void> setEnabled(bool enabled) {
    _userTouched = true;
    state = enabled;
    final preferences = ref.read(appPreferencesProvider.future);
    // 串行保存，避免快速切换时旧值最后落盘。
    _writes = _writes.then((_) async {
      try {
        final prefs = await preferences;
        await prefs.setSongTitleScrollingEnabled(enabled);
      } catch (_) {
        // 本地持久化失败不阻塞当前会话的选择。
      }
    });
    return _writes;
  }
}

final songTitleScrollingProvider =
    NotifierProvider<SongTitleScrollingNotifier, bool>(
      SongTitleScrollingNotifier.new,
    );
