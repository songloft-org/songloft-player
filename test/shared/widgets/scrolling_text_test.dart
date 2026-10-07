import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songloft_flutter/features/settings/presentation/providers/song_title_scrolling_provider.dart';
import 'package:songloft_flutter/shared/widgets/scrolling_text.dart';

/// 在固定宽度容器内渲染 [ScrollingText]，便于断言溢出滚动行为。
Future<void> _pumpScrollingText(
  WidgetTester tester, {
  required String text,
  required double width,
  Duration pauseDuration = Duration.zero,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Center(
          child: SizedBox(
            width: width,
            child: ScrollingText(text: text, pauseDuration: pauseDuration),
          ),
        ),
      ),
    ),
  );
  // 触发 initState 里的 postFrame 溢出检测
  await tester.pump();
}

/// 容器左边缘：默认测试画布 800 宽，居中 200 宽容器。
double _containerLeft(WidgetTester tester) =>
    tester.getTopLeft(find.byType(ScrollingText)).dx;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('文本不溢出时保持静态不滚动', (tester) async {
    await _pumpScrollingText(tester, text: '短歌名', width: 300);

    final initialLeft = tester.getTopLeft(find.text('短歌名')).dx;
    await tester.pump(const Duration(seconds: 3));

    expect(find.text('短歌名'), findsOneWidget);
    expect(tester.getTopLeft(find.text('短歌名')).dx, initialLeft);
    // 语义标签保持完整歌名，供读屏与列表行 label 合并使用
    expect(find.bySemanticsLabel('短歌名'), findsOneWidget);
  });

  testWidgets('文本溢出时自动水平滚动显示完整内容', (tester) async {
    const longTitle = '孙子兵法与三十六计 第01集 孙子兵法与三十六计 第01集 孙子兵法与三十六计 第01集';
    await _pumpScrollingText(tester, text: longTitle, width: 200);

    final initialLeft = tester.getTopLeft(find.text(longTitle)).dx;
    // 首暂停为 0：pump(Duration.zero) 推进假时钟触发零延迟 Timer 启动 animateTo，
    // 该帧同时作为 ticker 起始帧；再推进 1s 即处于滚动过程中
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(seconds: 1));

    expect(tester.getTopLeft(find.text(longTitle)).dx, lessThan(initialLeft));
  });

  testWidgets('文本变化后重置回开头重新循环', (tester) async {
    const firstTitle = '孙子兵法与三十六计 第01集 孙子兵法与三十六计 第01集 孙子兵法与三十六计 第01集';
    await _pumpScrollingText(tester, text: firstTitle, width: 200);

    await tester.pump(Duration.zero);
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester.getTopLeft(find.text(firstTitle)).dx,
      lessThan(_containerLeft(tester)),
    );

    // 同构树仅换文本：State 复用，走 didUpdateWidget 的重置分支
    const secondTitle = '鬼谷子全集 第02集 鬼谷子全集 第02集 鬼谷子全集 第02集 鬼谷子全集 第02集';
    await _pumpScrollingText(tester, text: secondTitle, width: 200);

    // 换文本后滚动偏移归零，文本左边缘与容器对齐
    expect(
      tester.getTopLeft(find.text(secondTitle)).dx,
      _containerLeft(tester),
    );

    // 消费重启循环挂起的零延迟 Timer，避免测试框架的 pending timer 断言
    await tester.pump(Duration.zero);
  });

  testWidgets('关闭开关停止所有滚动并保留完整读屏标签，开启后恢复', (tester) async {
    const title = '这是一个非常长的歌曲标题，这是一个非常长的歌曲标题，这是一个非常长的歌曲标题';
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Center(
            child: SizedBox(
              width: 120,
              child: Column(
                children: [
                  ScrollingText(text: title, pauseDuration: Duration.zero),
                  ScrollingText(text: title, pauseDuration: Duration.zero),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(seconds: 1));
    final texts = find.text(title);
    final left = tester.getTopLeft(find.byType(ScrollingText).first).dx;
    expect(tester.getTopLeft(texts.first).dx, lessThan(left));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ScrollingText).first),
    );
    await container.read(songTitleScrollingProvider.notifier).setEnabled(false);
    await tester.pump();
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(tester.widget<Text>(texts.first).overflow, TextOverflow.ellipsis);
    expect(find.bySemanticsLabel(title), findsNWidgets(2));
    final staticLeft = tester.getTopLeft(texts.first).dx;
    await tester.pump(const Duration(seconds: 5));
    expect(tester.getTopLeft(texts.first).dx, staticLeft);

    await container.read(songTitleScrollingProvider.notifier).setEnabled(true);
    await tester.pump();
    await tester.pump();
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(SingleChildScrollView), findsNWidgets(2));
    expect(tester.getTopLeft(texts.first).dx, lessThan(staticLeft));
  });

  testWidgets('在开头暂停时关闭会取消待执行计时器', (tester) async {
    await _pumpScrollingText(
      tester,
      text: '非常长的歌名非常长的歌名非常长的歌名非常长的歌名',
      width: 100,
      pauseDuration: const Duration(seconds: 2),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ScrollingText)),
    );
    await container.read(songTitleScrollingProvider.notifier).setEnabled(false);
    await tester.pump();
    expect(find.byType(SingleChildScrollView), findsNothing);
    await tester.pumpWidget(const SizedBox());
    // 不推进计时器也可结束测试：旧循环已取消。
    expect(tester.takeException(), isNull);
  });
}
