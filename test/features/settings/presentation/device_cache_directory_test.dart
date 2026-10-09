import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songloft_flutter/core/storage/android_song_cache_storage.dart';
import 'package:songloft_flutter/core/storage/app_preferences.dart';
import 'package:songloft_flutter/core/storage/song_cache_service.dart';
import 'package:songloft_flutter/features/settings/presentation/providers/song_cache_provider.dart';
import 'package:songloft_flutter/features/settings/presentation/widgets/device_cache_directory.dart';
import 'package:songloft_flutter/l10n/app_localizations.dart';

class DirectoryPicker extends AndroidSongCacheStorage {
  bool supported = true;
  bool cancelled = false;
  bool writable = true;

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<Map<String, String>?> pickDirectory() async =>
      cancelled
          ? null
          : {
            'uri':
                'content://com.android.externalstorage.documents/tree/primary%3AMusic',
            'label': 'primary:Music',
          };

  @override
  Future<void> validateDirectory(String tree) async {
    if (!writable) throw const FileSystemException('access revoked');
  }
}

void main() {
  late Directory directory;
  late DirectoryPicker picker;
  late AppPreferences preferences;
  late SongCacheService service;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'cache-directory-widget-',
    );
    picker = DirectoryPicker();
    SharedPreferences.setMockInitialValues({});
    preferences = await AppPreferences.create();
    service = SongCacheService.forTesting(
      directory: directory,
      preferences: preferences,
      external: picker,
    );
    await service.load();
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });

  Future<void> show(WidgetTester tester, {String language = 'zh'}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [songCacheServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: SingleChildScrollView(child: DeviceCacheDirectory()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String label) async {
    // Preferences passed to the service originate in setUp's real async zone.
    // Run these interactions there so waiting on those futures can complete.
    await tester.tap(find.text(label));
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();
  }

  testWidgets(
    'select and restore persist the directory and refresh its label',
    (tester) async {
      await show(tester);
      expect(find.text('默认（应用内部目录）'), findsOneWidget);
      await tap(tester, '选择文件夹 / 重新授权');
      expect(find.text('primary:Music'), findsOneWidget);
      expect(preferences.getSongCacheDirectory(), contains('content://'));
      await tap(tester, '恢复默认目录');
      expect(preferences.getSongCacheDirectory(), isNull);
      expect(find.text('默认（应用内部目录）'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('picker cancellation does not report a directory change', (
    tester,
  ) async {
    picker.cancelled = true;
    await show(tester);
    await tap(tester, '选择文件夹 / 重新授权');
    expect(find.text('缓存目录已更新'), findsNothing);
    expect(preferences.getSongCacheDirectory(), isNull);
  });

  testWidgets(
    'old APK shows upgrade guidance with disabled picker in English',
    (tester) async {
      picker.supported = false;
      await show(tester, language: 'en');
      expect(
        find.text(
          'Install the latest client APK to use a custom cache directory.',
        ),
        findsOneWidget,
      );
      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Choose folder / grant access again'),
      );
      expect(button.onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'revoked access keeps the selected directory and allows restoring default',
    (tester) async {
      await tester.runAsync(
        () => service.setDirectory(
          'content://com.android.externalstorage.documents/tree/primary%3AMusic',
          'primary:Music',
        ),
      );
      picker.writable = false;
      await show(tester);
      expect(find.textContaining('目录不可访问或不可写'), findsOneWidget);
      expect(preferences.getSongCacheDirectory(), isNotNull);
      await tap(tester, '恢复默认目录');
      expect(preferences.getSongCacheDirectory(), isNull);
      expect(find.textContaining('目录不可访问或不可写'), findsNothing);
    },
  );
}
