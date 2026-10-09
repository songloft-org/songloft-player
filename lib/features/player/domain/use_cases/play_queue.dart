import 'dart:collection';

import '../../../../shared/models/song.dart';

/// 播放队列操作结果
class PlayQueueRemoveResult {
  final PlayQueue queue;
  final bool shouldStop;
  final Song? currentSong;

  const PlayQueueRemoveResult({
    required this.queue,
    required this.shouldStop,
    required this.currentSong,
  });
}

/// 不可变的播放队列值对象。
///
/// 每次操作返回新的 [PlayQueue] 实例，不修改原有对象。
/// 纯 Dart 实现，不依赖任何 Flutter 框架。
class PlayQueue {
  final List<Song> songs;
  final int currentIndex;

  const PlayQueue({required this.songs, required this.currentIndex});

  /// 空队列常量
  static const empty = PlayQueue(songs: [], currentIndex: -1);

  /// 当前播放的歌曲，队列为空或索引无效时返回 null
  Song? get currentSong {
    if (currentIndex < 0 || currentIndex >= songs.length) return null;
    return songs[currentIndex];
  }

  /// 队列是否为空
  bool get isEmpty => songs.isEmpty;

  /// 队列长度
  int get length => songs.length;

  /// 追加歌曲到队列末尾，按 (id, type) 去重
  PlayQueue add(List<Song> newSongs) {
    if (newSongs.isEmpty) return this;

    final updatedSongs = [...songs];
    for (final song in newSongs) {
      final exists = updatedSongs.any(
        (s) => s.id == song.id && s.type == song.type,
      );
      if (!exists) {
        updatedSongs.add(song);
      }
    }

    return PlayQueue(songs: updatedSongs, currentIndex: currentIndex);
  }

  /// 在指定位置插入歌曲，调整 currentIndex
  PlayQueue insert(int position, Song song) {
    final updatedSongs = List<Song>.from(songs);
    final safePosition = position.clamp(0, updatedSongs.length);
    updatedSongs.insert(safePosition, song);

    // 插入位置在当前歌曲之前或等于当前位置时，索引后移
    int newCurrentIndex = currentIndex;
    if (currentIndex >= 0 && safePosition <= currentIndex) {
      newCurrentIndex++;
    }

    return PlayQueue(songs: updatedSongs, currentIndex: newCurrentIndex);
  }

  /// 安排歌曲紧接当前曲播放；已有歌曲移位，当前曲允许额外安排一次重播。
  PlayQueue playNext(Song song) {
    int existingIndex = -1;
    for (int i = 0; i < songs.length; i++) {
      if (i != currentIndex &&
          songs[i].id == song.id &&
          songs[i].type == song.type) {
        existingIndex = i;
        break;
      }
    }
    if (existingIndex < 0) return insert(currentIndex + 1, song);
    final target =
        existingIndex <= currentIndex ? currentIndex : currentIndex + 1;
    return move(existingIndex, target.clamp(0, songs.length - 1));
  }

  /// 根据歌曲身份映射编辑前后的索引，优先保留当前曲的对应关系。
  /// 重复歌曲按出现顺序匹配，复杂度 O(n)。
  Map<int, int> indexMappingTo(PlayQueue updated) {
    final mapping = <int, int>{};
    final positions = <(int, String), ListQueue<int>>{};
    final current = currentSong;
    final nextCurrent = updated.currentSong;
    final preservesCurrent =
        current != null &&
        nextCurrent != null &&
        current.id == nextCurrent.id &&
        current.type == nextCurrent.type;
    if (preservesCurrent) mapping[currentIndex] = updated.currentIndex;
    for (int i = 0; i < updated.songs.length; i++) {
      if (preservesCurrent && i == updated.currentIndex) continue;
      final song = updated.songs[i];
      (positions[(song.id, song.type)] ??= ListQueue<int>()).add(i);
    }
    for (int i = 0; i < songs.length; i++) {
      if (preservesCurrent && i == currentIndex) continue;
      final candidates = positions[(songs[i].id, songs[i].type)];
      if (candidates != null && candidates.isNotEmpty) {
        mapping[i] = candidates.removeFirst();
      }
    }
    return mapping;
  }

  /// 删除指定位置的歌曲，返回操作结果（包含新队列、是否应停止、新的当前歌曲）
  PlayQueueRemoveResult removeAt(int index) {
    if (index < 0 || index >= songs.length) {
      return PlayQueueRemoveResult(
        queue: this,
        shouldStop: false,
        currentSong: currentSong,
      );
    }

    final updatedSongs = List<Song>.from(songs);
    updatedSongs.removeAt(index);

    int newIndex = currentIndex;
    Song? newSong = currentSong;
    bool shouldStop = false;

    if (index == currentIndex) {
      // 删除的是当前播放的歌曲
      if (updatedSongs.isEmpty) {
        newIndex = -1;
        newSong = null;
        shouldStop = true;
      } else if (index >= updatedSongs.length) {
        newIndex = updatedSongs.length - 1;
        newSong = updatedSongs[newIndex];
      } else {
        newSong = updatedSongs[newIndex];
      }
    } else if (index < currentIndex) {
      // 删除的在当前之前
      newIndex--;
    }

    return PlayQueueRemoveResult(
      queue: PlayQueue(songs: updatedSongs, currentIndex: newIndex),
      shouldStop: shouldStop,
      currentSong: newSong,
    );
  }

  /// 将 oldIndex 处歌曲移动到 newIndex（移除后的最终目标索引）
  PlayQueue move(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return this;
    if (oldIndex < 0 || oldIndex >= songs.length) return this;
    if (newIndex < 0 || newIndex >= songs.length) return this;

    final updatedSongs = List<Song>.from(songs);
    final song = updatedSongs.removeAt(oldIndex);
    updatedSongs.insert(newIndex, song);

    // 调整当前索引，保持跟踪当前歌曲
    int newCurrentIndex = currentIndex;
    if (oldIndex == currentIndex) {
      newCurrentIndex = newIndex;
    } else {
      if (oldIndex < currentIndex && newIndex >= currentIndex) {
        newCurrentIndex--;
      } else if (oldIndex > currentIndex && newIndex <= currentIndex) {
        newCurrentIndex++;
      }
    }

    return PlayQueue(songs: updatedSongs, currentIndex: newCurrentIndex);
  }

  /// 判断队列中是否已有该歌曲 (by id + type)
  bool contains(Song song) {
    return songs.any((s) => s.id == song.id && s.type == song.type);
  }

  /// 查找歌曲在队列中的位置，未找到返回 -1
  int indexOf(Song song) {
    for (int i = 0; i < songs.length; i++) {
      if (songs[i].id == song.id && songs[i].type == song.type) {
        return i;
      }
    }
    return -1;
  }

  /// 跳转到指定位置
  PlayQueue jumpTo(int index) {
    if (index < 0 || index >= songs.length) return this;
    return PlayQueue(songs: songs, currentIndex: index);
  }
}
