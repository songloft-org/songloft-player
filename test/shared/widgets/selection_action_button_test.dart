import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/l10n/app_localizations.dart';
import 'package:songloft_flutter/shared/widgets/selection_action_button.dart';

/// 渲染一整套多选态动作（加歌单/管理标签/删除/全选），用于验证窄屏不溢出。
Future<void> _pumpSelectionAppBar(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                tooltip: l10n.libraryExitSelection,
                onPressed: () {},
              ),
              title: Text(l10n.librarySelectedCount(3)),
              actions: [
                SelectionActionButton(
                  icon: Icons.playlist_add,
                  label: l10n.addToPlaylist,
                  onPressed: () {},
                ),
                SelectionActionButton(
                  icon: Icons.label_outline,
                  label: l10n.manageTags,
                  onPressed: () {},
                ),
                SelectionActionButton(
                  icon: Icons.delete,
                  label: l10n.libraryDeleteWithCount(3),
                  color: Theme.of(context).colorScheme.error,
                  onPressed: () {},
                ),
                TextButton(onPressed: () {}, child: Text(l10n.selectAll)),
              ],
            ),
          );
        },
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('窄屏多选工具栏退化成图标按钮且不溢出', (tester) async {
    await _pumpSelectionAppBar(tester, 360);

    expect(tester.takeException(), isNull);
    // 窄屏不渲染文字，只保留 tooltip
    expect(find.text('管理标签'), findsNothing);
    expect(find.byTooltip('管理标签'), findsOneWidget);
    expect(find.byTooltip('添加到歌单'), findsOneWidget);
    expect(find.byTooltip('删除(3)'), findsOneWidget);
  });

  testWidgets('宽屏多选工具栏显示文字标签', (tester) async {
    await _pumpSelectionAppBar(tester, 1000);

    expect(tester.takeException(), isNull);
    expect(find.text('管理标签'), findsOneWidget);
    expect(find.text('添加到歌单'), findsOneWidget);
    expect(find.text('删除(3)'), findsOneWidget);
  });

  testWidgets('禁用态不套用自定义颜色', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SelectionActionButton(
            icon: Icons.delete,
            label: '删除',
            color: Colors.red,
            onPressed: null,
          ),
        ),
      ),
    );

    final icon = tester.widget<Icon>(find.byIcon(Icons.delete));
    expect(icon.color, isNull);
  });
}
