import 'dart:math';

import '../player_state.dart';

/// 播放模式解析器：负责根据当前播放模式计算下一首/上一首索引，
/// 以及维护随机播放已播放历史和预选缓存。
///
/// 纯 Dart 有状态类，不依赖 Flutter 或 Riverpod。
class PlayModeResolver {
  PlayModeResolver({required PlayMode mode, Random? random})
    : _mode = mode,
      _random = random ?? Random();

  final Random _random;
  PlayMode _mode;

  /// 随机模式下已播放的索引集合
  final Set<int> _playedIndices = {};

  /// 预选的下一首索引缓存
  int? _preSelectedNextIndex;

  // 索引只在当前队列内有效；队列编辑时由 remapQueue 按歌曲身份映射。
  final List<int> _history = [];
  int _historyCursor = -1;
  int? _navigationCursor;
  final List<int> _priorityIndices = [];

  bool get hasPriorityNext => _priorityIndices.isNotEmpty;

  /// 手动安排的歌曲先于播放模式和历史前进，最近指定的最先播放。
  void prioritizeNext(int index) {
    _priorityIndices.remove(index);
    _priorityIndices.insert(0, index);
    _preSelectedNextIndex = null;
  }

  /// 只修改索引对应关系，保留播放历史及尚未消费的手动安排。
  void remapQueue(Map<int, int> indices) {
    final history = <int>[];
    int cursor = -1;
    int? navigationCursor;
    for (int i = 0; i < _history.length; i++) {
      final mapped = indices[_history[i]];
      if (mapped == null) continue;
      history.add(mapped);
      if (i <= _historyCursor) cursor = history.length - 1;
      if (i == _navigationCursor) navigationCursor = history.length - 1;
    }
    _history
      ..clear()
      ..addAll(history);
    _historyCursor = cursor;
    _navigationCursor = navigationCursor;
    final played =
        _playedIndices.map((i) => indices[i]).whereType<int>().toSet();
    _playedIndices
      ..clear()
      ..addAll(played);
    final priority =
        _priorityIndices.map((i) => indices[i]).whereType<int>().toList();
    _priorityIndices
      ..clear()
      ..addAll(priority);
    _preSelectedNextIndex = null;
  }

  /// 失败的歌曲不进入历史，也不立即重复选择它。
  void markFailed(int index) {
    _playedIndices.add(index);
    _priorityIndices.remove(index);
    _preSelectedNextIndex = null;
    final failedCursor = _navigationCursor;
    if (failedCursor != null && failedCursor > _historyCursor) {
      _history.removeAt(failedCursor);
    }
    _navigationCursor = null;
  }

  int get _effectiveHistoryCursor => _navigationCursor ?? _historyCursor;

  int? get _forwardIndex =>
      _effectiveHistoryCursor + 1 < _history.length
          ? _history[_effectiveHistoryCursor + 1]
          : null;

  /// 当前播放模式
  PlayMode get mode => _mode;

  /// 获取预选的下一首索引
  int? get preSelectedIndex => _preSelectedNextIndex;

  /// 根据当前模式计算下一首索引。
  /// 返回 null 表示播放停止（顺序模式到末尾、singlePlay 等情况）。
  int? nextIndex({required int currentIndex, required int length}) {
    if (length <= 0) return null;
    if (hasPriorityNext) {
      _navigationCursor = null;
      _preSelectedNextIndex = null;
      return _priorityIndices.removeAt(0);
    }
    if (_mode == PlayMode.random && _forwardIndex != null) {
      final index = _forwardIndex;
      _navigationCursor = _effectiveHistoryCursor + 1;
      _preSelectedNextIndex = null;
      return index;
    }
    _navigationCursor = null;

    switch (_mode) {
      case PlayMode.order:
        final next = currentIndex + 1;
        return next < length ? next : null;
      case PlayMode.loop:
        return (currentIndex + 1) % length;
      case PlayMode.single:
      case PlayMode.singlePlay:
        return currentIndex;
      case PlayMode.random:
        final index =
            _preSelectedNextIndex ??
            _getRandomIndex(currentIndex: currentIndex, length: length);
        _preSelectedNextIndex = null;
        return index;
    }
  }

  /// 根据当前模式计算上一首索引。
  /// 非随机模式超过 3 秒时重播当前曲；随机模式始终按实际播放历史回退。
  /// 返回 null 表示无法再往前（顺序模式在第一首且 position <= 3s）。
  int? prevIndex({
    required int currentIndex,
    required int length,
    required Duration currentPosition,
  }) {
    if (length <= 0) return null;

    if (_mode == PlayMode.random) {
      _preSelectedNextIndex = null;
      final cursor = _effectiveHistoryCursor;
      // 正在加载的新歌尚未进入历史，上一首应是最后实际听过的歌曲。
      final unrecordedCurrent =
          _navigationCursor == null &&
          cursor >= 0 &&
          _history[cursor] != currentIndex;
      final previousCursor = unrecordedCurrent ? cursor : cursor - 1;
      if (previousCursor < 0) return null;
      _navigationCursor = previousCursor;
      return _history[previousCursor];
    }
    _navigationCursor = null;

    // 超过 3 秒，重播当前歌曲（seek to start）
    if (currentPosition.inSeconds > 3) {
      return currentIndex;
    }

    switch (_mode) {
      case PlayMode.order:
        final prev = currentIndex - 1;
        return prev >= 0 ? prev : null;
      case PlayMode.loop:
        return (currentIndex - 1 + length) % length;
      case PlayMode.single:
      case PlayMode.singlePlay:
        return currentIndex;
      case PlayMode.random:
        return null; // 随机模式已在上方按历史处理。
    }
  }

  /// 预选下一首索引并缓存。
  /// 返回预选的索引值（也可通过 [preSelectedIndex] 获取）。
  int? preSelectNext({required int currentIndex, required int length}) {
    if (length <= 0 || currentIndex < 0) {
      _preSelectedNextIndex = null;
      return null;
    }

    if (hasPriorityNext) {
      return _preSelectedNextIndex = _priorityIndices.first;
    }
    if (_mode == PlayMode.random && _forwardIndex != null) {
      return _preSelectedNextIndex = _forwardIndex;
    }

    switch (_mode) {
      case PlayMode.order:
        final next = currentIndex + 1;
        _preSelectedNextIndex = next < length ? next : null;
        break;
      case PlayMode.loop:
        _preSelectedNextIndex = (currentIndex + 1) % length;
        break;
      case PlayMode.random:
        _preSelectedNextIndex = _getRandomIndex(
          currentIndex: currentIndex,
          length: length,
        );
        break;
      case PlayMode.single:
      case PlayMode.singlePlay:
        _preSelectedNextIndex = null;
        break;
    }

    return _preSelectedNextIndex;
  }

  /// 模式切换时调用，清除已播放历史和预选缓存。
  void onModeChanged(PlayMode newMode) {
    _mode = newMode;
    _playedIndices.clear();
    _history.clear();
    _historyCursor = -1;
    _navigationCursor = null;
    _preSelectedNextIndex = null;
  }

  /// 队列变更时调用，重置内部状态。
  void onQueueChanged() {
    onModeChanged(_mode);
    _priorityIndices.clear();
  }

  /// 播放成功后记录历史；历史导航提交游标，重试不新增条目。
  void markPlayed(int index) {
    if (index < 0) return;
    _playedIndices.add(index);
    _priorityIndices.remove(index);
    final navigation = _navigationCursor;
    _navigationCursor = null;
    if (navigation != null &&
        navigation < _history.length &&
        _history[navigation] == index) {
      _historyCursor = navigation;
      return;
    }
    if (_historyCursor >= 0 && _history[_historyCursor] == index) return;
    _history.removeRange(_historyCursor + 1, _history.length);
    _history.add(index);
    _historyCursor = _history.length - 1;
  }

  /// 获取随机索引（避免重复，直到全部播完再重置）
  int _getRandomIndex({required int currentIndex, required int length}) {
    if (length <= 1) return 0;

    // 如果所有歌曲都播放过，重置
    if (_playedIndices.length >= length) {
      _playedIndices.clear();
      // 保留当前索引，避免重置后立即重复当前歌曲
      if (currentIndex >= 0 && currentIndex < length) {
        _playedIndices.add(currentIndex);
      }
    }

    // 获取未播放的索引列表
    final availableIndices =
        List<int>.generate(length, (i) => i)
            .where((i) => i != currentIndex && !_playedIndices.contains(i))
            .toList();

    if (availableIndices.isEmpty) {
      _playedIndices.clear();
      if (currentIndex >= 0 && currentIndex < length) {
        _playedIndices.add(currentIndex);
      }
      final candidates =
          List<int>.generate(
            length,
            (i) => i,
          ).where((i) => i != currentIndex).toList();
      return candidates[_random.nextInt(candidates.length)];
    }

    return availableIndices[_random.nextInt(availableIndices.length)];
  }
}
