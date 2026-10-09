import '../../../../shared/models/song.dart';
import '../player_state.dart';

/// 预加载决策结果
class PrefetchDecision {
  final bool shouldPrefetch;
  final Song? songToPrefetch;
  final int? nextIndex;

  const PrefetchDecision({
    required this.shouldPrefetch,
    this.songToPrefetch,
    this.nextIndex,
  });

  const PrefetchDecision.skip()
    : shouldPrefetch = false,
      songToPrefetch = null,
      nextIndex = null;
}

/// 预加载策略：纯决策逻辑，不负责网络请求执行。
///
/// 从 PlayerNotifier 中提取的预加载决策，包含两个评估入口：
/// - [evaluateAfterPlay]：播放成功后立即评估是否预加载下一首
/// - [evaluateLateStagePrefetch]：播放进度接近末尾时评估保险预加载
class PrefetchStrategy {
  bool _lateStageFired = false;

  /// 播放成功后评估是否需要预加载下一首。
  ///
  /// 决策规则：
  /// - 歌单为空或只有 1 首 → skip
  /// - single/singlePlay 模式且没有手动下一首 → skip
  /// - preSelectedNextIndex 为 null 或越界 → skip
  /// - 下一首歌 url 为空或非后端相对路径 → skip
  /// - 下一首歌是本地歌曲 → skip（无需网络预热）
  PrefetchDecision evaluateAfterPlay({
    required List<Song> playlist,
    required int currentIndex,
    required int? preSelectedNextIndex,
    required PlayMode playMode,
    bool hasPriorityNext = false,
  }) {
    // 歌单为空或只有 1 首
    if (playlist.isEmpty || playlist.length <= 1) {
      return const PrefetchDecision.skip();
    }

    // 单曲模式只有手动指定下一首时才预加载。
    if (!hasPriorityNext &&
        (playMode == PlayMode.single || playMode == PlayMode.singlePlay)) {
      return const PrefetchDecision.skip();
    }

    // 下一首索引不存在或越界
    if (preSelectedNextIndex == null ||
        preSelectedNextIndex < 0 ||
        preSelectedNextIndex >= playlist.length) {
      return const PrefetchDecision.skip();
    }

    final nextSong = playlist[preSelectedNextIndex];

    // 下一首歌没有远程 URL
    if (nextSong.url == null || nextSong.url!.isEmpty) {
      return const PrefetchDecision.skip();
    }

    // 外部完整 URL 无法预热（不走后端缓存）
    if (!nextSong.url!.startsWith('/')) {
      return const PrefetchDecision.skip();
    }

    // 本地歌曲无需网络预热
    if (nextSong.type == 'local') {
      return const PrefetchDecision.skip();
    }

    return PrefetchDecision(
      shouldPrefetch: true,
      songToPrefetch: nextSong,
      nextIndex: preSelectedNextIndex,
    );
  }

  /// 播放进度接近末尾时评估是否需要保险预加载。
  ///
  /// 决策规则：
  /// - 已经触发过 → skip
  /// - duration <= 0 → skip
  /// - duration < 60s → skip（短歌不值得 late stage prefetch）
  /// - 剩余时间 > 30s → skip
  /// - 满足条件后标记已触发，委托给 [evaluateAfterPlay] 做后续判断
  PrefetchDecision evaluateLateStagePrefetch({
    required Duration currentPosition,
    required Duration duration,
    required List<Song> playlist,
    required int currentIndex,
    required int? preSelectedNextIndex,
    required PlayMode playMode,
    bool hasPriorityNext = false,
  }) {
    // 已经触发过
    if (_lateStageFired) {
      return const PrefetchDecision.skip();
    }

    // 无有效时长
    if (duration <= Duration.zero) {
      return const PrefetchDecision.skip();
    }

    // 短歌不值得 late stage prefetch
    if (duration < const Duration(seconds: 60)) {
      return const PrefetchDecision.skip();
    }

    // 剩余时间 > 30s，还不到触发时机
    if (duration - currentPosition > const Duration(seconds: 30)) {
      return const PrefetchDecision.skip();
    }

    // 标记已触发
    _lateStageFired = true;

    // 委托给 evaluateAfterPlay 做歌曲级别判断
    return evaluateAfterPlay(
      playlist: playlist,
      currentIndex: currentIndex,
      preSelectedNextIndex: preSelectedNextIndex,
      playMode: playMode,
      hasPriorityNext: hasPriorityNext,
    );
  }

  /// 切歌时重置 late-stage 标记
  void onSongChanged() {
    _lateStageFired = false;
  }

  /// 当前 late-stage 是否已触发（仅供测试/调试读取）
  bool get lateStageFired => _lateStageFired;
}
