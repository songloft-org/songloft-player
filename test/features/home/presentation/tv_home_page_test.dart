import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/features/home/presentation/tv_home_page.dart';
import 'package:songloft_flutter/features/player/presentation/providers/player_provider.dart';
import 'package:songloft_flutter/features/playlist/presentation/providers/playlist_provider.dart';
import 'package:songloft_flutter/l10n/app_localizations.dart';

void main() {
  testWidgets('TvHomePage renders quick navigation cards', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playlistListProvider(null).overrideWith(
            () => _EmptyPlaylistsNotifier(null),
          ),
          playlistListProvider('normal').overrideWith(
            () => _EmptyPlaylistsNotifier('normal'),
          ),
          playlistListProvider('radio').overrideWith(
            () => _EmptyPlaylistsNotifier('radio'),
          ),
          playerStateProvider.overrideWith(
            () => throw UnimplementedError('mock'),
          ),
          isPlayingProvider.overrideWith((ref) => false),
          sourcePlaylistIdProvider.overrideWith((ref) => null),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TvHomePage(),
        ),
      ),
    );

    // Let the FutureProvider resolve
    await tester.pumpAndSettle();

    expect(find.text('Songloft'), findsOneWidget);
    expect(find.text('本地音乐'), findsOneWidget);
    expect(find.text('播放列表'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });
}

/// Notifier that returns an empty playlist state
class _EmptyPlaylistsNotifier extends PaginatedPlaylistsNotifier {
  _EmptyPlaylistsNotifier(super.typeArg);

  @override
  Future<PaginatedPlaylistsState> build() async {
    return const PaginatedPlaylistsState(
      items: [],
      totalCount: 0,
      hasMore: false,
      isLoadingMore: false,
    );
  }
}
