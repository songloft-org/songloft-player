import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/core/network/api_client.dart';
import 'package:songloft_flutter/features/settings/data/scan_api.dart';
import 'package:songloft_flutter/features/settings/presentation/widgets/scan_manager.dart';
import 'package:songloft_flutter/l10n/app_localizations.dart';

class _ScanAdapter implements HttpClientAdapter {
  int starts = 0;
  bool failValidation = false;
  bool rejectStart = false;
  bool completed = false;
  List<String>? startedPaths;
  Map<String, dynamic>? scanBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    final endpoint = options.uri.path;
    Object response = {};
    int status = 200;
    if (endpoint.endsWith('/scan/validate')) {
      if (failValidation) {
        status = 500;
        response = {'error': 'unavailable'};
      } else {
        final selected =
            ((options.data as Map)['paths'] as List).cast<String>();
        final roots = selected.isEmpty ? ['/music'] : selected;
        response = {
          'paths': roots.where((p) => !p.startsWith('/music/yt-dlp')).toList(),
          'excluded_directories': [
            for (final path in roots.where(
              (p) => p.startsWith('/music/yt-dlp'),
            ))
              {'path': path, 'rule_type': 'path', 'rule': '/music/yt-dlp'},
          ],
        };
      }
    } else if (endpoint.endsWith('/scan/directories')) {
      response = {
        'root': '/music',
        'directories': [
          {'name': 'yt-dlp', 'path': '/music/yt-dlp', 'has_children': false},
          {'name': 'allowed', 'path': '/music/allowed', 'has_children': false},
        ],
      };
    } else if (endpoint.endsWith('/scan/progress')) {
      response = {
        'status': completed ? 'completed' : 'idle',
        'skipped_files': 3,
        'excluded_directories':
            completed
                ? [
                  {
                    'path': '/music/yt-dlp',
                    'rule_type': 'path',
                    'rule': '/music/yt-dlp',
                  },
                ]
                : [],
      };
    } else if (endpoint.endsWith('/scan')) {
      starts++;
      scanBody = Map<String, dynamic>.from(options.data as Map);
      startedPaths = ((options.data as Map)['paths'] as List?)?.cast<String>();
      if (rejectStart) {
        status = 400;
        response = {'error': '所有扫描目录均被排除'};
      } else {
        completed = true;
      }
    }
    return ResponseBody.fromString(
      jsonEncode(response),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<void> _mount(WidgetTester tester, _ScanAdapter adapter) async {
  await tester.binding.setSurfaceSize(const Size(1200, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))
    ..httpClientAdapter = adapter;
  addTearDown(dio.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [dioProvider.overrideWithValue(dio)],
      child: const MaterialApp(
        locale: Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: ScanManager())),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _selectExcluded(WidgetTester tester) async {
  await tester.tap(find.text('指定目录（可选）'));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(Checkbox).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('选择排除目录立即说明规则，启动时不发送扫描请求', (tester) async {
    final adapter = _ScanAdapter();
    await _mount(tester, adapter);
    await _selectExcluded(tester);
    expect(find.textContaining('命中排除路径：/music/yt-dlp'), findsOneWidget);
    await tester.tap(find.text('扫描选中的 1 个目录'));
    await tester.pumpAndSettle();
    expect(adapter.starts, 0);
    expect(find.text('所有扫描目录均被排除，请先调整排除设置。'), findsOneWidget);
    expect(find.text('扫描选中的 1 个目录'), findsOneWidget);
  });

  testWidgets('混合目录可扫描且结果单独说明排除目录', (tester) async {
    final adapter = _ScanAdapter();
    await _mount(tester, adapter);
    await _selectExcluded(tester);
    await tester.tap(find.byType(Checkbox).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('扫描选中的 2 个目录'));
    await tester.pumpAndSettle();
    expect(adapter.starts, 1);
    expect(adapter.startedPaths, ['/music/yt-dlp', '/music/allowed']);
    expect(find.text('因排除规则跳过 1 个目录'), findsWidgets);
    expect(find.textContaining('命中排除路径：/music/yt-dlp'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('校验失败不能使用旧结果启动，后端拒绝后仍保留操作控件', (tester) async {
    final adapter = _ScanAdapter();
    await _mount(tester, adapter);
    adapter.failValidation = true;
    await tester.tap(find.text('扫描本地音乐'));
    await tester.pumpAndSettle();
    expect(adapter.starts, 0);
    adapter.failValidation = false;
    adapter.rejectStart = true;
    await tester.tap(find.text('扫描本地音乐'));
    await tester.pumpAndSettle();
    expect(adapter.starts, 1);
    expect(find.text('扫描本地音乐'), findsOneWidget);
    expect(find.text('所有扫描目录均被排除'), findsOneWidget);
  });

  test('旧服务端进度缺少诊断时默认为空', () {
    expect(
      ScanProgress.fromJson({'status': 'completed'}).excludedDirectories,
      isEmpty,
    );
  });

  testWidgets('重新导入中的重置手动字段默认关闭并需要显式选择', (tester) async {
    final adapter = _ScanAdapter()..rejectStart = true;
    await _mount(tester, adapter);
    final reset = find.byKey(const Key('scan-reset-metadata-overrides'));
    expect(reset, findsNothing);
    await tester.tap(find.text('重新导入'));
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(reset).value, isFalse);
    await tester.tap(find.text('扫描本地音乐'));
    await tester.pumpAndSettle();
    expect(adapter.scanBody, {'reimport': true});
    await tester.tap(reset);
    await tester.pumpAndSettle();
    adapter.rejectStart = false;
    await tester.tap(find.text('扫描本地音乐'));
    await tester.pumpAndSettle();
    expect(adapter.scanBody, {
      'reimport': true,
      'reset_metadata_overrides': true,
    });
    await tester.pumpWidget(const SizedBox());
  });
}
