import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/core/theme/app_theme.dart';
import 'package:songloft_flutter/l10n/app_localizations.dart';
import 'package:songloft_flutter/shared/layouts/adaptive_scaffold.dart';

/// 回归测试桌面侧边栏折叠动画的稳定性。
///
/// 旧实现把「展开态内容 / 折叠态内容」两棵不同的子树按状态整棵替换，而且内容直接
/// 交给动画中的宽度去 layout，于是折叠时图标先跳到容器正中（240/2 = 120）再滑回
/// 36，展开时整列文字先被挤进 72px 重新折行（还会触发 RenderFlex overflow），
/// 表现为肉眼可见的抖动。现在的实现共用一棵固定宽度的子树、只让裁切边缘移动，
/// 下面这些断言就是为了锁住「动画期间任何元素都不重新定位/重排」这个约束。

class _Harness extends StatefulWidget {
  const _Harness({this.navigationStyle = 'standard'});

  final String navigationStyle;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  bool collapsed = false;

  /// 测试驱动的折叠切换（走正规的 setState 入口）。
  void toggleCollapse() => setState(() => collapsed = !collapsed);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        extensions: [
          SongloftThemeExtension(navigationStyle: widget.navigationStyle),
        ],
      ),
      home: AdaptiveScaffold(
        body: const ColoredBox(color: Colors.black, child: SizedBox.expand()),
        currentIndex: 0,
        onDestinationSelected: (_) {},
        isSidebarCollapsed: collapsed,
        onToggleSidebar: () => setState(() => collapsed = !collapsed),
        destinations: const [
          NavDestination(
            label: '首页',
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
          ),
          NavDestination(
            label: 'A very long plugin name that should ellipsize',
            icon: Icon(Icons.extension_outlined),
            selectedIcon: Icon(Icons.extension),
          ),
        ],
      ),
    );
  }
}

void main() {
  testWidgets('桌面侧栏折叠与展开全过程元素零位移（抖动回归）', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const _Harness());
    await tester.pumpAndSettle();

    final state = tester.state<_HarnessState>(find.byType(_Harness));
    final viewport = find.byKey(const ValueKey('desktop-sidebar-viewport'));
    final icon = find.byIcon(Icons.home);

    final expandedWidth = tester.getSize(viewport).width;
    final expandedIconCenter = tester.getCenter(icon);
    final expandedLabelWidth = tester.getSize(find.text('首页')).width;
    expect(expandedWidth, 240);

    // 逐帧采样：图标位置、标签盒宽度、侧栏宽度都不允许抖动。
    Future<List<double>> sampleFrames({required int frames}) async {
      final widths = <double>[];
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(
          tester.getCenter(icon),
          expandedIconCenter,
          reason: '动画第 ${(i + 1) * 16}ms 图标位置发生位移',
        );
        expect(
          tester.getSize(find.text('首页')).width,
          expandedLabelWidth,
          reason: '动画第 ${(i + 1) * 16}ms 标签被重新布局',
        );
        expect(tester.takeException(), isNull, reason: '动画期间出现布局异常');
        widths.add(tester.getSize(viewport).width);
      }
      return widths;
    }

    state.toggleCollapse();
    final collapseWidths = await sampleFrames(frames: 20);
    await tester.pumpAndSettle();

    // 宽度单调收缩到 72，中途不反弹。
    for (var i = 1; i < collapseWidths.length; i++) {
      expect(collapseWidths[i], lessThanOrEqualTo(collapseWidths[i - 1]));
    }
    expect(collapseWidths.last, lessThan(expandedWidth));
    expect(tester.getSize(viewport).width, 72);
    expect(tester.getCenter(icon), expandedIconCenter);

    state.toggleCollapse();
    final expandWidths = await sampleFrames(frames: 20);
    await tester.pumpAndSettle();

    for (var i = 1; i < expandWidths.length; i++) {
      expect(expandWidths[i], greaterThanOrEqualTo(expandWidths[i - 1]));
    }
    expect(tester.getSize(viewport).width, expandedWidth);
    expect(tester.getCenter(icon), expandedIconCenter);
  });

  testWidgets('胶囊主题下同样零位移，且侧栏平滑盖过底层占位', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const _Harness(navigationStyle: 'capsule'));
    await tester.pumpAndSettle();

    final state = tester.state<_HarnessState>(find.byType(_Harness));
    final icon = find.byIcon(Icons.home);
    final expandedIconCenter = tester.getCenter(icon);
    final expandedLabelWidth = tester.getSize(find.text('首页')).width;

    state.toggleCollapse();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.getCenter(icon), expandedIconCenter);
      expect(tester.getSize(find.text('首页')).width, expandedLabelWidth);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpAndSettle();
    expect(tester.getCenter(icon).dx, 36);

    state.toggleCollapse();
    await tester.pumpAndSettle();
    expect(tester.getCenter(icon), expandedIconCenter);
  });

  testWidgets('折叠态图标居中于 72px 轨道，展开态标签可见', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const _Harness());
    await tester.pumpAndSettle();
    final state = tester.state<_HarnessState>(find.byType(_Harness));

    state.toggleCollapse();
    await tester.pumpAndSettle();

    // 图标中心落在 72 宽轨道正中。
    expect(tester.getCenter(find.byIcon(Icons.home)).dx, 36);

    // 折叠态：文字被完全裁掉（位置已经越过裁切边缘）。
    expect(tester.getTopLeft(find.text('首页')).dx, greaterThanOrEqualTo(72));
  });
}
