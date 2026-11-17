import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/core/network/api_client.dart';
import 'package:songloft_flutter/features/player/domain/player_state.dart';
import 'package:songloft_flutter/features/player/presentation/providers/player_provider.dart';
import 'package:songloft_flutter/features/player/presentation/widgets/playlist_resume_card.dart';
import 'package:songloft_flutter/features/playlist/presentation/playlist_detail_page.dart';
import 'package:songloft_flutter/features/playlist/presentation/widgets/playlist_song_tile.dart';
import 'package:songloft_flutter/l10n/app_localizations.dart';
import 'package:songloft_flutter/shared/models/song.dart';

// Record the command at the page boundary; queue_navigation_test exercises the
// real notifier's preservation of playback, context, and priority ordering.
class _Player extends PlayerNotifier {
  final scheduled = <Song>[];
  int playCalls = 0;

  @override
  PlayerState build() => const PlayerState();

  @override
  Future<void> playSongNext(Song song) async => scheduled.add(song);

  @override
  Future<void> playPlaylistFromLoaded({
    required List<Song> loadedSongs,
    required int startIndex,
    required int playlistId,
    required int total,
    String sort = 'position',
    String order = 'asc',
    String keyword = '',
  }) async => playCalls++;
}

void main() {
  for (final playlistId in [1, 42]) {
    for (final width in [500.0, 1280.0]) {
      for (final locale in ['zh', 'en', 'es']) {
        testWidgets(
          'playlist $playlistId, width $width, $locale schedules only the chosen song',
          (tester) async {
            tester.view.physicalSize = Size(width, 900);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final player = _Player();
            final requests = <RequestOptions>[];
            final dio = Dio();
            dio.interceptors.add(
              InterceptorsWrapper(
                onRequest: (request, handler) {
                  requests.add(request);
                  final Object data;
                  if (request.path.endsWith('/songs')) {
                    data = {
                      'total': 200,
                      'songs': [
                        {'id': 101, 'type': 'local', 'title': 'Chosen song'},
                        {'id': 102, 'type': 'remote', 'title': 'Other song'},
                      ],
                    };
                  } else if (request.path.endsWith('/$playlistId')) {
                    data = {
                      'id': playlistId,
                      'type': 'normal',
                      'name': playlistId == 1 ? 'Favorites' : 'Test playlist',
                      'labels': playlistId == 1 ? ['built_in'] : <String>[],
                      'song_count': 200,
                    };
                  } else {
                    throw StateError('Unexpected request: ${request.path}');
                  }
                  handler.resolve(
                    Response(
                      requestOptions: request,
                      statusCode: 200,
                      data: data,
                    ),
                  );
                },
              ),
            );
            final container = ProviderContainer(
              overrides: [
                dioProvider.overrideWithValue(dio),
                playerStateProvider.overrideWith(() => player),
                playlistProgressProvider.overrideWith((ref, id) async => null),
              ],
            );
            addTearDown(container.dispose);
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: MaterialApp(
                  locale: Locale(locale),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: PlaylistDetailPage(playlistId: '$playlistId'),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final tile = find.byType(PlaylistSongTile).first;
            final l10n = AppLocalizations.of(tester.element(tile));
            final before = requests.length;
            await tester.tap(
              find.descendant(of: tile, matching: find.byIcon(Icons.more_vert)),
            );
            await tester.pumpAndSettle();
            expect(find.text(l10n.libraryPlayNext), findsOneWidget);
            await tester.tap(find.text(l10n.libraryPlayNext));
            await tester.pumpAndSettle();
            expect(player.scheduled.map((song) => song.id), [101]);
            expect(player.playCalls, 0);
            expect(
              requests.length,
              before,
              reason: 'Do not load or modify the source playlist',
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
