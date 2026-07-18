import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/lyric_provider.dart';
import '../providers/player_provider.dart';
import 'karaoke_line.dart';

/// 视频/MV 界面的字幕叠加层。
///
/// 复用 [lyricStateProvider] 的当前歌词行,以字幕形式居中显示在画面底部。
/// 当前行含逐字数据时以 K 歌方式逐字高亮([KaraokeLine]),否则整行显示。
/// 通过 [subtitleEnabledProvider] 控制显隐;开关关闭、无歌词或当前无对应行时
/// 返回 [SizedBox.shrink]。白字 + 多重描边阴影,保证在任意画面上均可读。
class VideoSubtitleOverlay extends ConsumerWidget {
  const VideoSubtitleOverlay({super.key, this.fontSize = 20});

  /// 字幕字号(全屏横屏可传更大值)。
  final double fontSize;

  /// 多向阴影模拟描边,保证白字在亮色画面上仍可读。
  static const List<Shadow> _outline = [
    Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
    Shadow(color: Colors.black54, blurRadius: 8),
    Shadow(color: Colors.black45, blurRadius: 2, offset: Offset(1, 0)),
    Shadow(color: Colors.black45, blurRadius: 2, offset: Offset(-1, 0)),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(subtitleEnabledProvider);
    if (!enabled) return const SizedBox.shrink();

    final line = ref.watch(
      lyricStateProvider.select((s) => s.currentLine),
    );

    final hasText = line != null && line.text.isNotEmpty;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: !hasText
          ? const SizedBox.shrink()
          : line.hasWords
              // 逐字 K 歌字幕:已唱=高亮色,未唱=白色,均带描边
              ? KaraokeLine(
                  key: ValueKey('kw_${line.time.inMilliseconds}'),
                  line: line,
                  activeColor: Theme.of(context).colorScheme.primary,
                  inactiveColor: Colors.white,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  shadows: _outline,
                )
              : Text(
                  line.text,
                  key: ValueKey(line.text),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    shadows: _outline,
                  ),
                ),
    );
  }
}
