import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/lyric_provider.dart';
import '../providers/player_provider.dart';

/// 视频/MV 界面的字幕叠加层。
///
/// 复用 [lyricStateProvider] 的当前歌词行,以字幕形式居中显示在画面底部。
/// 通过 [subtitleEnabledProvider] 控制显隐;开关关闭、无歌词或当前无对应行时
/// 返回 [SizedBox.shrink]。白字 + 多重描边阴影,保证在任意画面上均可读。
class VideoSubtitleOverlay extends ConsumerWidget {
  const VideoSubtitleOverlay({super.key, this.fontSize = 20});

  /// 字幕字号(全屏横屏可传更大值)。
  final double fontSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(subtitleEnabledProvider);
    if (!enabled) return const SizedBox.shrink();

    final text = ref.watch(
      lyricStateProvider.select((s) => s.currentLyricText),
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: text.isEmpty
          ? const SizedBox.shrink()
          : Text(
              text,
              key: ValueKey(text),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                height: 1.3,
                shadows: const [
                  // 多向阴影模拟描边,保证白字在亮色画面上仍可读
                  Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
                  Shadow(color: Colors.black54, blurRadius: 8),
                  Shadow(color: Colors.black45, blurRadius: 2, offset: Offset(1, 0)),
                  Shadow(color: Colors.black45, blurRadius: 2, offset: Offset(-1, 0)),
                ],
              ),
            ),
    );
  }
}
