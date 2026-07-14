/// 桌面端可绑定快捷键的播放控制动作。
///
/// 枚举名（[Enum.name]）用作持久化 JSON 的稳定 key，**不要**随意重命名；
/// 新增动作直接追加即可（旧存档缺失的动作会在读取时补默认，见
/// `shortcut_settings_provider.dart`）。
enum PlayerShortcutAction {
  /// 播放 / 暂停切换
  playPause,

  /// 下一首
  playNext,

  /// 上一首
  playPrev,

  /// 快进（seek + N 秒）
  seekForward,

  /// 快退（seek - N 秒）
  seekBackward,

  /// 音量增大
  volumeUp,

  /// 音量减小
  volumeDown,

  /// 静音切换
  toggleMute,
}

/// 长按可连续触发的动作（seek / 音量）。播放/暂停、切歌、静音只响应首次按下，
/// 忽略 [KeyRepeatEvent]，避免长按疯狂重触。
const kRepeatableShortcutActions = <PlayerShortcutAction>{
  PlayerShortcutAction.seekForward,
  PlayerShortcutAction.seekBackward,
  PlayerShortcutAction.volumeUp,
  PlayerShortcutAction.volumeDown,
};
