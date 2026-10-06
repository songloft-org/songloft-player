import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/features/dlna/domain/dlna_state.dart';
import 'package:songloft_flutter/features/dlna/presentation/providers/dlna_provider.dart';
import 'package:songloft_flutter/features/dlna/presentation/widgets/cast_button.dart';
import 'package:songloft_flutter/l10n/app_localizations.dart';

final _longError =
    'Exception: request http://192.168.2.111:25826/upnp/service/AVTransport/Control '
    'error, status 500\n<s:Fault><errorCode>716</errorCode>'
    '<errorDescription>Resource not found</errorDescription>\n'
    '${List.filled(80, '<res>https://server/play?access_token=private-token&amp;quality=original</res>').join('\n')}'
    '\n</s:Fault>';

class _Dlna extends DlnaNotifier {
  final selected = <String>[];

  @override
  DlnaState build() => DlnaState(
    error: _longError,
    devices: List.generate(
      20,
      (i) => DlnaDeviceInfo(
        id: 'device-$i',
        name: '电视 ${i + 1}',
        location: 'http://192.168.2.${i + 100}:25826',
      ),
    ),
  );

  @override
  Future<void> startDiscovery() async {}

  @override
  Future<void> castToDevice(DlnaDeviceInfo device) async {
    selected.add(device.id);
  }
}

Future<_Dlna> _openSheet(
  WidgetTester tester, {
  Size size = const Size(320, 568),
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final notifier = _Dlna();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [dlnaStateProvider.overrideWith(() => notifier)],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
        home: const Scaffold(body: Center(child: CastButton())),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('投屏'));
  await tester.pumpAndSettle();
  return notifier;
}

void main() {
  for (final scenario in [
    (name: 'small portrait', size: const Size(320, 568), scale: 1.0),
    (name: 'landscape', size: const Size(568, 320), scale: 1.0),
    (name: 'large text', size: const Size(320, 568), scale: 2.0),
  ]) {
    testWidgets(
      '${scenario.name}: long SOAP error leaves devices scrollable and selectable',
      (tester) async {
        final notifier = await _openSheet(
          tester,
          size: scenario.size,
          scale: scenario.scale,
        );
        expect(tester.takeException(), isNull);
        expect(find.text(_longError), findsNothing);
        expect(find.text('投屏出错，请重试'), findsOneWidget);
        expect(find.text('电视 1').hitTestable(), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('电视 20'),
          150,
          scrollable: find.byType(Scrollable),
        );
        await tester.tap(find.text('电视 20'));
        await tester.pumpAndSettle();
        expect(notifier.selected, ['device-19']);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'error details preserve SOAP, redact tokens and scroll independently',
    (tester) async {
      await _openSheet(tester);
      await tester.tap(find.byTooltip('错误详情'));
      await tester.pumpAndSettle();
      final details =
          tester.widget<SelectableText>(find.byType(SelectableText)).data!;
      expect(details, contains('<errorCode>716</errorCode>'));
      expect(details, contains('Resource not found'));
      expect(details, endsWith('</s:Fault>'));
      expect(details, contains('access_token=***'));
      expect(details, isNot(contains('private-token')));
      final scrollable =
          find
              .descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(Scrollable),
              )
              .first;
      await tester.drag(scrollable, const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(
        tester.state<ScrollableState>(scrollable).position.pixels,
        greaterThan(0),
      );
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('电视 1').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dismiss only clears the error and keeps the device list', (
    tester,
  ) async {
    final notifier = await _openSheet(tester);
    await tester.tap(find.byTooltip('关闭提示'));
    await tester.pumpAndSettle();
    expect(notifier.state.error, isNull);
    expect(notifier.state.devices, hasLength(20));
    expect(find.text('投屏出错，请重试'), findsNothing);
    expect(find.text('电视 1').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
