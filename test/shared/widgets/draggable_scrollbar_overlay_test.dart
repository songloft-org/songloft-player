import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:songloft_flutter/shared/widgets/draggable_scrollbar_overlay.dart';

/// 探针：暴露自己的 State 实例，用于判断子树是否被重建。
class _Probe extends StatefulWidget {
  const _Probe();
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  static int instances = 0;
  @override
  void initState() {
    super.initState();
    instances++;
  }

  @override
  Widget build(BuildContext context) => const SizedBox(height: 10);
}

void main() {
  testWidgets('多个 scroll position 过渡态不会抛出异常', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(1200, 800)),
        child: MaterialApp(
          home: SizedBox(
            width: 320,
            height: 320,
            child: DraggableScrollbarOverlay(
              scrollController: controller,
              totalItemCount: 40,
              child: Stack(
                children: [
                  ListView.builder(
                    controller: controller,
                    itemCount: 40,
                    itemBuilder: (context, index) => Text('first $index'),
                  ),
                  ListView.builder(
                    controller: controller,
                    itemCount: 40,
                    itemBuilder: (context, index) => Text('second $index'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  // songloft-org/songloft#361 回归：歌单页传 `enabled: total > 20`，首次搜索把
  // 结果数从 20 以上压到 20 以下时会翻转该开关，overlay 不得因此重建 child。
  late ScrollController controller;
  setUp(() => controller = ScrollController());
  tearDown(() => controller.dispose());

  Widget host({required int total}) {
    return MediaQuery(
      data: const MediaQueryData(size: Size(400, 800)),
      child: MaterialApp(
        home: Scaffold(
          body: DraggableScrollbarOverlay(
            scrollController: controller,
            totalItemCount: total,
            enabled: total > 20,
            child: const Column(
              children: [_Probe(), TextField(autofocus: true)],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('搜索结果跨过 20 阈值时子树不应被销毁重建', (tester) async {
    _ProbeState.instances = 0;

    // 大歌单：enabled=true，滚动条可用
    await tester.pumpWidget(host(total: 30));
    await tester.pumpAndSettle();
    expect(_ProbeState.instances, 1);

    // 模拟搜索命中少量结果：enabled=false，滚动条隐藏
    await tester.pumpWidget(host(total: 2));
    await tester.pumpAndSettle();

    // 若子树被重建，State 会重新 initState → instances 变 2
    expect(
      _ProbeState.instances,
      1,
      reason: 'enabled 翻转不得销毁重建整个子树（含搜索框 TextField）',
    );
  });

  testWidgets('阈值翻转时 TextField 的输入连接不应被重建', (tester) async {
    final log = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.textInput,
      (call) async {
        log.add(call.method);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.textInput,
        null,
      ),
    );

    await tester.pumpWidget(host(total: 30));
    await tester.pumpAndSettle();
    log.clear();

    await tester.pumpWidget(host(total: 2));
    await tester.pumpAndSettle();

    // TextInput.clearClient / setClient 出现说明连接被断开重连，
    // Windows 平台上这会在 IME 组合期间把拼音重复提交。
    expect(
      log,
      isNot(contains('TextInput.clearClient')),
      reason: '输入连接被断开：$log',
    );
  });
}
