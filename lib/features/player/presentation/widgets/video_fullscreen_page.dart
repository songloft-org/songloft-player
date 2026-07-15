import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/song.dart';
import 'video_player_surface.dart';

/// 移动端横屏全屏视频页。
///
/// 进入时锁定横屏 + 沉浸式(隐藏状态栏/导航栏),退出时恢复竖屏与常规系统 UI,
/// 确保返回后 App 不会卡在横屏。画面与控制层复用 [VideoPlayerSurface](传
/// `isFullscreen: true`)。仅供移动端(Android/iOS)调用。
class VideoFullscreenPage extends ConsumerStatefulWidget {
  const VideoFullscreenPage({super.key, required this.song});

  final Song song;

  static Future<void> show(BuildContext context, Song song) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (context, animation, secondaryAnimation) =>
            VideoFullscreenPage(song: song),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  ConsumerState<VideoFullscreenPage> createState() =>
      _VideoFullscreenPageState();
}

class _VideoFullscreenPageState extends ConsumerState<VideoFullscreenPage> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    // 恢复竖屏与常规系统 UI(edgeToEdge 与 App 默认一致)。
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: VideoPlayerSurface(song: widget.song, isFullscreen: true),
    );
  }
}
