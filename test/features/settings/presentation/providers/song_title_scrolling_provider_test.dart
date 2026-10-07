import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songloft_flutter/core/storage/app_preferences.dart';
import 'package:songloft_flutter/features/auth/presentation/providers/auth_provider.dart';
import 'package:songloft_flutter/features/settings/presentation/providers/song_title_scrolling_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> load(ProviderContainer container) async {
    container.read(songTitleScrollingProvider);
    await container.read(appPreferencesProvider.future);
    await Future<void>.delayed(Duration.zero);
  }

  test('缺省开启，关闭后新容器回读本地偏好', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await load(container);
    expect(container.read(songTitleScrollingProvider), isTrue);
    await container.read(songTitleScrollingProvider.notifier).setEnabled(false);
    expect(
      (await AppPreferences.create()).isSongTitleScrollingEnabled(),
      isFalse,
    );
    final restored = ProviderContainer();
    addTearDown(restored.dispose);
    await load(restored);
    expect(restored.read(songTitleScrollingProvider), isFalse);
  });

  test('初始化读取未完成时点击，旧偏好不会覆盖选择', () async {
    final pending = Completer<AppPreferences>();
    final container = ProviderContainer(
      overrides: [appPreferencesProvider.overrideWith((ref) => pending.future)],
    );
    addTearDown(container.dispose);
    container.read(songTitleScrollingProvider);
    final saved = container
        .read(songTitleScrollingProvider.notifier)
        .setEnabled(false);
    expect(container.read(songTitleScrollingProvider), isFalse);
    pending.complete(await AppPreferences.create());
    await saved;
    expect(container.read(songTitleScrollingProvider), isFalse);
    expect(
      (await AppPreferences.create()).isSongTitleScrollingEnabled(),
      isFalse,
    );
  });

  test('快速开关按顺序保存最后一次选择', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await load(container);
    final notifier = container.read(songTitleScrollingProvider.notifier);
    await Future.wait([
      notifier.setEnabled(false),
      notifier.setEnabled(true),
      notifier.setEnabled(false),
    ]);
    expect(container.read(songTitleScrollingProvider), isFalse);
    expect(
      (await AppPreferences.create()).isSongTitleScrollingEnabled(),
      isFalse,
    );
  });

  test('读取失败保留默认值且仍可在会话内切换', () async {
    final container = ProviderContainer(
      overrides: [
        appPreferencesProvider.overrideWith(
          (ref) => throw StateError('prefs unavailable'),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(songTitleScrollingProvider), isTrue);
    await container.read(songTitleScrollingProvider.notifier).setEnabled(false);
    expect(container.read(songTitleScrollingProvider), isFalse);
  });
}
