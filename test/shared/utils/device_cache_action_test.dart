import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/l10n/app_localizations.dart';
import 'package:songloft_flutter/shared/utils/device_cache_action.dart';

void main() {
  Future<void> show(WidgetTester tester, Future<void> Function() action) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder:
                (context) => TextButton(
                  onPressed:
                      () => runDeviceCacheRemoval(
                        context,
                        action,
                        successMessage: '清理成功',
                      ),
                  child: const Text('清理'),
                ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('failed removal reports error without claiming success', (
    tester,
  ) async {
    await show(tester, () async => throw StateError('volume unavailable'));
    await tester.tap(find.text('清理'));
    await tester.pumpAndSettle();
    expect(find.textContaining('清理缓存未完成'), findsOneWidget);
    expect(find.text('清理成功'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'removal failure after leaving page does not use disposed context',
    (tester) async {
      final pending = Completer<void>();
      await show(tester, () => pending.future);
      await tester.tap(find.text('清理'));
      await tester.pumpWidget(const SizedBox());
      pending.completeError(StateError('volume unavailable'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
