import '../../../core/storage/song_cache_service.dart' show PlaybackSource;
import '../../../shared/models/song.dart';

/// 播放模式
enum PlayMode {
  /// 顺序播放
  order,

  /// 列表循环
  loop,

  /// 单曲循环
  single,

  /// 随机播放
  random,

  /// 单曲播放（播完停止）
  singlePlay;

  /// 从字符串解析播放模式
  static PlayMode fromString(String value) {
    switch (value) {
      case 'order':
        return PlayMode.order;
      case 'loop':
        return PlayMode.loop;
      case 'single':
        return PlayMode.single;
      case 'random':
        return PlayMode.random;
      case 'singlePlay':
        return PlayMode.singlePlay;
      default:
        return PlayMode.order;
    }
  }

  /// 转换为字符串（用于存储）
  String toStorageString() {
    switch (this) {
      case PlayMode.order:
        return 'order';
      case PlayMode.loop:
        return 'loop';
      case PlayMode.single:
        return 'single';
      case PlayMode.random:
        return 'random';
      case PlayMode.singlePlay:
        return 'singlePlay';
    }
  }
}

/// 睡眠定时触发模式
enum SleepTimerMode {
  /// 按时长倒计时，到点 pause
  duration,

  /// 播完 N 首歌曲后 pause
  afterSongs,
}

/// 睡眠定时状态。三种模式互斥单选。
class SleepTimerStatus {
  final SleepTimerMode mode;

  /// 仅 [SleepTimerMode.duration] 模式有效：剩余倒计时
  final Duration? remaining;

  /// 仅 [SleepTimerMode.afterSongs] 模式有效：剩余首数（含当前正在播放的曲）
  final int? remainingSongs;

  const SleepTimerStatus({
    required this.mode,
    this.remaining,
    this.remainingSongs,
  });

  SleepTimerStatus copyWith({Duration? remaining, int? remainingSongs}) {
    return SleepTimerStatus(
      mode: mode,
      remaining: remaining ?? this.remaining,
      remainingSongs: remainingSongs ?? this.remainingSongs,
    );
  }
}

/// 播放器状态
class PlayerState {
  final Song? currentSong;
  final List<Song> playlist;
  final int currentIndex;
  final bool isPlaying;
  final double volume; // 0-100
  final Duration currentTime;
  final Duration duration;
  final PlayMode playMode;
  final bool isBuffering;
  final bool showFullPlayer; // 移动端全屏播放器
  final bool showPlaylistDrawer; // 播放列表抽屉
  final SleepTimerStatus? sleepTimer; // 当前已设定的睡眠定时（互斥单选）
  final double? previousVolume; // 静音前的音量（用于恢复）
  final String? errorMessage; // 当前错误消息，UI 层监听后显示 SnackBar
  final String? infoMessage; // 当前信息提示（如"正在缓存"），UI 层监听后显示普通 SnackBar
  final bool isRetrying; // 是否正在重试中
  final int? sourcePlaylistId; // 当前播放队列的来源歌单 ID
  final PlaybackSource playbackSource; // 当前歌曲播放来源（本地缓存 / 远端流串）

  const PlayerState({
    this.currentSong,
    this.playlist = const [],
    this.currentIndex = -1,
    this.isPlaying = false,
    this.volume = 50,
    this.currentTime = Duration.zero,
    this.duration = Duration.zero,
    this.playMode = PlayMode.order,
    this.isBuffering = false,
    this.showFullPlayer = false,
    this.showPlaylistDrawer = false,
    this.sleepTimer,
    this.previousVolume,
    this.errorMessage,
    this.infoMessage,
    this.isRetrying = false,
    this.sourcePlaylistId,
    this.playbackSource = PlaybackSource.unknown,
  });

  /// 初始状态
  static const PlayerState initial = PlayerState();

  /// 从存储的偏好设置创建初始状态
  static PlayerState fromPreferences({double? volume, PlayMode? playMode}) {
    return PlayerState(
      volume: volume ?? 50.0,
      playMode: playMode ?? PlayMode.order,
    );
  }

  /// 是否有下一首
  bool get hasNext {
    if (playlist.isEmpty) return false;
    if (playMode == PlayMode.loop || playMode == PlayMode.random) return true;
    // singlePlay 和 order 模式下，判断是否还有下一首
    return currentIndex < playlist.length - 1;
  }

  /// 是否有上一首
  bool get hasPrev {
    if (playlist.isEmpty) return false;
    if (playMode == PlayMode.loop || playMode == PlayMode.random) return true;
    // singlePlay 和 order 模式下，判断是否还有上一首
    return currentIndex > 0;
  }

  /// 是否有当前歌曲
  bool get hasSong => currentSong != null;

  /// 下一首歌曲（仅顺序模式下）
  Song? get nextSong {
    if (!hasNext || playlist.isEmpty) return null;
    final nextIndex = (currentIndex + 1) % playlist.length;
    return playlist[nextIndex];
  }

  /// 播放进度 (0.0 - 1.0)
  double get progress {
    if (duration.inMilliseconds <= 0) return 0;
    return (currentTime.inMilliseconds / duration.inMilliseconds).clamp(
      0.0,
      1.0,
    );
  }

  /// 是否静音
  bool get isMuted => volume == 0;

  /// 播放按钮是否显示"加载中"转圈：正在缓冲，或正在重试等待后台缓存完成。
  /// isRetrying 不能并入 isBuffering——后者由 playerStateStream 每次事件覆盖，
  /// 重试等待期会被 idle 事件重置为 false；故用独立标志合并出该派生值。
  bool get showBufferingIndicator => isBuffering || isRetrying;

  /// 复制并修改
  PlayerState copyWith({
    Song? currentSong,
    List<Song>? playlist,
    int? currentIndex,
    bool? isPlaying,
    double? volume,
    Duration? currentTime,
    Duration? duration,
    PlayMode? playMode,
    bool? isBuffering,
    bool? showFullPlayer,
    bool? showPlaylistDrawer,
    SleepTimerStatus? sleepTimer,
    double? previousVolume,
    String? errorMessage,
    String? infoMessage,
    bool? isRetrying,
    int? sourcePlaylistId,
    PlaybackSource? playbackSource,
    bool clearCurrentSong = false,
    bool clearSleepTimer = false,
    bool clearPreviousVolume = false,
    bool clearErrorMessage = false,
    bool clearInfoMessage = false,
    bool clearSourcePlaylistId = false,
  }) {
    return PlayerState(
      currentSong: clearCurrentSong ? null : (currentSong ?? this.currentSong),
      playlist: playlist ?? this.playlist,
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      volume: volume ?? this.volume,
      currentTime: currentTime ?? this.currentTime,
      duration: duration ?? this.duration,
      playMode: playMode ?? this.playMode,
      isBuffering: isBuffering ?? this.isBuffering,
      showFullPlayer: showFullPlayer ?? this.showFullPlayer,
      showPlaylistDrawer: showPlaylistDrawer ?? this.showPlaylistDrawer,
      sleepTimer: clearSleepTimer ? null : (sleepTimer ?? this.sleepTimer),
      previousVolume:
          clearPreviousVolume ? null : (previousVolume ?? this.previousVolume),
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      infoMessage:
          clearInfoMessage ? null : (infoMessage ?? this.infoMessage),
      isRetrying: isRetrying ?? this.isRetrying,
      sourcePlaylistId: clearSourcePlaylistId
          ? null
          : (sourcePlaylistId ?? this.sourcePlaylistId),
      playbackSource: playbackSource ?? this.playbackSource,
    );
  }

  @override
  String toString() {
    final errorInfo = errorMessage != null ? ', error: $errorMessage' : '';
    return 'PlayerState(song: ${currentSong?.title}, index: $currentIndex, playing: $isPlaying, mode: $playMode$errorInfo)';
  }
}
