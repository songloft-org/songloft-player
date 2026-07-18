import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/features/player/domain/lyric_parser.dart';
import 'package:songloft_flutter/features/player/domain/player_state.dart';
import 'package:songloft_flutter/features/player/presentation/providers/player_provider.dart';
import 'package:songloft_flutter/features/player/presentation/widgets/karaoke_line.dart';

/// 受控的假 PlayerNotifier：跳过真实 build 副作用，仅暴露可写的播放位置/播放态，
/// 便于确定性地驱动逐字高亮。
class _FakePlayerNotifier extends PlayerNotifier {
  @override
  PlayerState build() => const PlayerState(isPlaying: false);

  void setPosition(Duration d) => state = state.copyWith(currentTime: d);
}

/// 从 KaraokeLine 渲染出的 RichText 中取出各**叶子**（含 text）span 的颜色。
/// Text.rich 会把传入的 span 再包一层，故递归收集带 text 的叶子 span。
List<Color?> _spanColors(WidgetTester tester) {
  final rich = tester.widget<RichText>(
    find.descendant(
      of: find.byType(KaraokeLine),
      matching: find.byType(RichText),
    ),
  );
  final colors = <Color?>[];
  void walk(InlineSpan span) {
    if (span is TextSpan) {
      if (span.text != null) colors.add(span.style?.color);
      for (final c in span.children ?? const <InlineSpan>[]) {
        walk(c);
      }
    }
  }

  walk(rich.text);
  return colors;
}

void main() {
  const active = Color(0xFFFF0000); // 红=已唱
  const inactive = Color(0xFF808080); // 灰=未唱

  Future<_FakePlayerNotifier> pumpKaraoke(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [playerStateProvider.overrideWith(_FakePlayerNotifier.new)],
    );
    addTearDown(container.dispose);

    // [00:00.000]<0,1000>A<1000,1000>B → A:[0,1s) B:[1s,2s)
    final line = LyricParser.parseWordByWord(
      '[00:00.000]<0,1000>A<1000,1000>B',
    ).single;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: KaraokeLine(
              line: line,
              activeColor: active,
              inactiveColor: inactive,
              fontSize: 18,
            ),
          ),
        ),
      ),
    );
    return container.read(playerStateProvider.notifier) as _FakePlayerNotifier;
  }

  testWidgets('位置为 0 时两字均未唱（inactive）', (tester) async {
    await pumpKaraoke(tester);
    await tester.pump();
    final colors = _spanColors(tester);
    expect(colors, hasLength(2));
    expect(colors[0], inactive);
    expect(colors[1], inactive);
  });

  testWidgets('进度推进到第二字中段：首字全亮，次字过渡', (tester) async {
    final player = await pumpKaraoke(tester);
    player.setPosition(const Duration(milliseconds: 1500));
    await tester.pump(); // 触发 ref.listen 重锚 + 重绘

    final colors = _spanColors(tester);
    // 首字已唱完 → active
    expect(colors[0], active);
    // 次字处于 [1s,2s) 的 50% → 介于 inactive 与 active 之间
    final mid = colors[1]!;
    expect(mid, isNot(active));
    expect(mid, isNot(inactive));
    expect(mid.r, greaterThan(inactive.r)); // 红分量随进度上升
  });

  testWidgets('位置越过整行末尾：两字全亮', (tester) async {
    final player = await pumpKaraoke(tester);
    player.setPosition(const Duration(seconds: 3));
    await tester.pump();

    final colors = _spanColors(tester);
    expect(colors[0], active);
    expect(colors[1], active);
  });
}
