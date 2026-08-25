import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/features/home/presentation/widgets/stats_strip.dart';
import 'package:songloft_flutter/features/library/presentation/providers/songs_provider.dart';
import 'package:songloft_flutter/l10n/app_localizations.dart';
import 'package:songloft_flutter/shared/models/library_stats.dart';

/// 首页底部曲库统计面板。
///
/// 只锁内容与门控逻辑，不做像素级视觉断言（颜色 / 圆角交给截图取证）。
void main() {
  const fixture = LibraryStats(
    totalSongs: 1284,
    localSongs: 1102,
    remoteSongs: 168,
    radioSongs: 14,
    totalDuration: 331620, // 92 小时 7 分
    totalFileSize: 90409742336, // 84.2 GB
    artistCount: 243,
    albumCount: 388,
    genreCount: 27,
  );

  /// 直接 pump 面板本身，不 pump 整页——避免把首页的全部依赖都 mock 一遍。
  ///
  /// 传 create 函数而不是 Override 对象：`Override` 类型没有从 flutter_riverpod
  /// 导出，没法在测试里给它命名。
  Future<void> pumpStrip(
    WidgetTester tester,
    FutureOr<LibraryStats> Function(Ref ref) create,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [libraryStatsProvider.overrideWith(create)],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SingleChildScrollView(child: StatsStrip())),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('四层内容齐全', (tester) async {
    await pumpStrip(tester, (ref) async => fixture);

    // headline
    expect(find.text('1284'), findsOneWidget);
    expect(find.text('首歌曲'), findsOneWidget);
    expect(find.text('92 小时 7 分'), findsOneWidget);

    // 第 2 层：按来源拆分（label 复用 songType* 既有文案）
    expect(find.text('1102'), findsOneWidget);
    expect(find.text('168'), findsOneWidget);
    expect(find.text('14'), findsOneWidget);
    expect(find.text('本地'), findsOneWidget);
    expect(find.text('网络'), findsOneWidget);
    expect(find.text('电台'), findsOneWidget);

    // 第 3 层：曲库维度（label 复用 categoryField* 既有文案）
    expect(find.text('243'), findsOneWidget);
    expect(find.text('388'), findsOneWidget);
    expect(find.text('27'), findsOneWidget);
    expect(find.text('歌手'), findsOneWidget);
    expect(find.text('专辑'), findsOneWidget);
    expect(find.text('流派'), findsOneWidget);

    // footer
    expect(find.text('占用 84.2 GB'), findsOneWidget);
  });

  testWidgets('不足一小时只显示分钟，不出现「小时」', (tester) async {
    await pumpStrip(
      tester,
      (ref) async => const LibraryStats(totalDuration: 420),
    );

    expect(find.text('7 分'), findsOneWidget);
    expect(find.textContaining('小时'), findsNothing);
  });

  testWidgets('占用为 0 时不渲染 footer', (tester) async {
    // 全远程曲库的真实形态：有歌但一个字节本地文件都没有。
    await pumpStrip(
      tester,
      (ref) async =>
          const LibraryStats(totalSongs: 30, remoteSongs: 28, radioSongs: 2),
    );

    expect(find.text('30'), findsOneWidget);
    expect(find.textContaining('占用'), findsNothing);
    expect(find.text('0 B'), findsNothing);
  });

  testWidgets('加载中降级为全零，不抛异常也不消失', (tester) async {
    final never = Completer<LibraryStats>();
    addTearDown(() => never.complete(LibraryStats.empty));

    await pumpStrip(tester, (ref) => never.future);

    expect(find.byType(StatsStrip), findsOneWidget);
    // headline 的 1 个 + 两行 6 格 = 7 个「0」
    expect(find.text('0'), findsNWidgets(7));
    expect(find.text('0 分'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('请求失败同样降级为全零，错误不冒到 widget 层', (tester) async {
    await pumpStrip(tester, (ref) async => throw Exception('boom'));

    expect(find.byType(StatsStrip), findsOneWidget);
    expect(find.text('0'), findsNWidgets(7));
    // .value ?? empty 真的吞掉了错误，没有 uncaught exception。
    expect(tester.takeException(), isNull);
  });
}
