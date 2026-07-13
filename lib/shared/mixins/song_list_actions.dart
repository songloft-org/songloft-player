import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/player/presentation/providers/player_provider.dart';

/// 歌曲列表页共享操作 mixin。
///
/// 收敛在「曲库分类页 / 歌单详情页」等 [ConsumerState] 页面间逐字重复的
/// 播放队列维护逻辑，避免多处拷贝导致行为漂移。
mixin SongListActions<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  /// 删除歌曲后，把已删除的歌曲从当前播放队列中同步移除。
  ///
  /// 从队尾向前遍历，避免移除元素导致索引错位。
  void removeDeletedSongsFromPlayerQueue(Set<int> deletedIds) {
    final playerNotifier = ref.read(playerStateProvider.notifier);
    final queue = ref.read(playerStateProvider).playlist;
    for (int i = queue.length - 1; i >= 0; i--) {
      if (deletedIds.contains(queue[i].id)) {
        playerNotifier.removeFromPlaylist(i);
      }
    }
  }
}
