import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../providers/player_provider.dart';

/// 打开全屏播放器（顶层路由 `/player`）。
///
/// 用真实路由而非命令式 `Navigator.push`，让浏览器/系统返回键在 Web 上也能
/// 关闭播放器（移动端 Web 命令式 pageless route 不产生浏览器历史条目）。
/// 带**双开守卫**：当前已在 `/player` 时不重复 push。
/// [initialPage] 仅移动端有效（0 封面 / 1 歌词），通过 query 参数传递以兼容
/// Web 刷新与深链；非移动端的路由构建器会忽略它。
void openFullPlayer(BuildContext context, {int initialPage = 0}) {
  if (GoRouterState.of(context).uri.path == AppRoutes.player) return;
  final query = initialPage != 0 ? '?page=$initialPage' : '';
  context.push('${AppRoutes.player}$query');
}

/// 关闭全屏播放器。
///
/// 仅当播放器路由处于栈顶时才 pop，避免误关叠加其上的 bottom sheet
/// （队列/均衡器/音轨/睡眠定时）；无返回栈时回退首页，防止空栈。
void dismissFullPlayer(BuildContext context, WidgetRef ref) {
  // showFullPlayer 目前无人消费，留作一致性记账（无害）。
  ref.read(playerStateProvider.notifier).closeFullPlayer();
  if (!context.mounted) return;
  final route = ModalRoute.of(context);
  if (route != null && !route.isCurrent) return;
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(AppRoutes.home);
  }
}

/// 全屏播放器 State 的公共兜底行为：Web 冷加载 `/player` 但无队列可恢复时退出。
///
/// 播放队列会在启动时**异步**恢复（`_restorePlaybackState`），故进入时若无歌曲，
/// 短暂等待恢复；超时仍无歌曲则退出，避免停在空白死页。恢复出歌曲后应调用
/// [cancelFullPlayerAutoExit] 取消定时器。
mixin FullPlayerAutoExit<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  Timer? _autoExitTimer;

  void scheduleFullPlayerAutoExit() {
    if (ref.read(playerStateProvider).hasSong) return;
    _autoExitTimer?.cancel();
    _autoExitTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || ref.read(playerStateProvider).hasSong) return;
      dismissFullPlayer(context, ref);
    });
  }

  void cancelFullPlayerAutoExit() {
    _autoExitTimer?.cancel();
    _autoExitTimer = null;
  }

  @override
  void dispose() {
    _autoExitTimer?.cancel();
    super.dispose();
  }
}
