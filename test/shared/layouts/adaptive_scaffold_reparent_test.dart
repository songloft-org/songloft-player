import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/config/app_config.dart';
import 'package:songloft_flutter/shared/layouts/adaptive_scaffold.dart';

/// 回归测试 songloft-org/songloft-player#20：
/// 拖窗跨响应式断点时，AdaptiveScaffold 会返回祖先结构完全不同的 widget 树
/// （mobile: Scaffold.body；tablet: Row > NavigationRail > … > Expanded(child: body)）。
/// ShellLayout 用稳定 GlobalKey 包裹 body，使插件页子树在断点切换时被
/// reparent（保留 State）而非 dispose+重建（会导致 InAppWebView reload、播放中断）。
///
/// 这里用一个记录 initState 次数的 spy widget 代替真实的 InAppWebView
/// （平台视图无法在 widget test 中渲染），直接验证 reparent 语义。

int _spyInits = 0;

class _Spy extends StatefulWidget {
  const _Spy();

  @override
  State<_Spy> createState() => _SpyState();
}

class _SpyState extends State<_Spy> {
  @override
  void initState() {
    super.initState();
    _spyInits++;
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

Widget _harness(Widget body) {
  return MaterialApp(
    home: AdaptiveScaffold(
      body: body,
      currentIndex: 0,
      onDestinationSelected: (_) {},
      destinations: const [
        NavDestination(
          label: '首页',
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
        ),
        NavDestination(
          label: '库',
          icon: Icon(Icons.library_music_outlined),
          selectedIcon: Icon(Icons.library_music),
        ),
      ],
    ),
  );
}

/// 设置真实测试渲染表面尺寸，使 screenType 与实际布局空间一致，避免溢出误报。
void _setSurface(WidgetTester tester, double width) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, 800);
}

void main() {
  // AdaptiveScaffold 经 context.screenType → isTv 读取 AppConfig.isTvMode（late final），
  // 需在此显式赋值一次，避免 LateInitializationError。非 TV 断点下不影响布局。
  AppConfig.isTvMode = false;

  testWidgets(
    '稳定 GlobalKey 包裹的 body 跨断点切换时被 reparent（State 保留）',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      _spyInits = 0;
      final bodyKey = GlobalKey();
      Widget body() => KeyedSubtree(key: bodyKey, child: const _Spy());

      // 500px -> mobile 布局（Scaffold.body）
      _setSurface(tester, 500);
      await tester.pumpWidget(_harness(body()));
      expect(_spyInits, 1);

      // 700px -> tablet 布局（Row > NavigationRail > … > Expanded(child: body)）
      _setSurface(tester, 700);
      await tester.pumpWidget(_harness(body()));
      await tester.pump();

      // 未重建：initState 仍只跑过一次
      expect(_spyInits, 1);
    },
  );

  testWidgets(
    '无稳定 key 时 body 跨断点被重建（复现 #20 缺陷，作为对照）',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      _spyInits = 0;
      Widget body() => const _Spy();

      _setSurface(tester, 500);
      await tester.pumpWidget(_harness(body()));
      expect(_spyInits, 1);

      _setSurface(tester, 700);
      await tester.pumpWidget(_harness(body()));
      await tester.pump();

      // 祖先结构变化导致 Element 无法按位置复用 -> dispose + 重建
      expect(_spyInits, 2);
    },
  );
}
