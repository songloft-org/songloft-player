import 'package:flutter/material.dart';

/// 播放队列"自动定位到当前播放项"的共享滚动逻辑。
///
/// 队列项为固定高度（封面主导），故可用 `index * itemExtent` 估算 offset，
/// 无需引入 `scrollable_positioned_list`（其不兼容 `ReorderableListView` 的拖拽排序）。
/// 移动端底部弹窗与桌面端侧边栏共用本 mixin，仅 [queueItemExtent] 不同。
mixin QueueAutoScrollMixin {
  /// 队列项固定高度（px），由使用方按各自布局提供。
  double get queueItemExtent;

  /// 目标 offset：让当前项落在视口约 1/3 处（中部偏上），并钳制到合法范围。
  double _targetOffset(ScrollController controller, int index) {
    final position = controller.position;
    final raw = index * queueItemExtent - position.viewportDimension / 3;
    return raw.clamp(0.0, position.maxScrollExtent);
  }

  /// 打开队列时：直接（无动画）定位到当前播放项。
  void jumpQueueToCurrent(ScrollController controller, int index) {
    if (index < 0 || !controller.hasClients) return;
    controller.jumpTo(_targetOffset(controller, index));
  }

  /// 方案 B：仅当当前项已滚出可视区时才平滑跟随，不打断用户手动浏览。
  void followQueueIfOffscreen(ScrollController controller, int index) {
    if (index < 0 || !controller.hasClients) return;
    final position = controller.position;
    final itemTop = index * queueItemExtent;
    final itemBottom = itemTop + queueItemExtent;
    final visibleTop = position.pixels;
    final visibleBottom = position.pixels + position.viewportDimension;
    // 当前项完整位于可视区内 → 保持不动
    if (itemTop >= visibleTop && itemBottom <= visibleBottom) return;
    controller.animateTo(
      _targetOffset(controller, index),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
}
