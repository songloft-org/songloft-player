import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/core/network/api_client.dart';
import 'package:songloft_flutter/features/player/domain/player_state.dart';
import 'package:songloft_flutter/features/player/presentation/providers/player_provider.dart';
import 'package:songloft_flutter/features/playlist/presentation/playlist_detail_page.dart';
import 'package:songloft_flutter/features/playlist/presentation/providers/playlist_provider.dart';
import 'package:songloft_flutter/features/playlist/presentation/widgets/playlist_song_tile.dart';
import 'package:songloft_flutter/l10n/app_localizations.dart';

class _IdlePlayer extends PlayerNotifier {
  @override
  PlayerState build() => const PlayerState();
}

// Exercise the real API, repository and pagination notifier at the HTTP boundary.
class _PlaylistServer {
  _PlaylistServer(
    this.sort,
    this.order, {
    this.labels = const ['auto_created'],
  });
  String sort;
  String order;
  final List<String> labels;
  List<int> positions = [1, 2, 3, 4];
  final requests = <RequestOptions>[];

  Dio get dio {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          requests.add(request);
          final path = request.path;
          Object data = <String, dynamic>{};
          if (request.method == 'GET' && path.endsWith('/songs')) {
            final query = request.queryParameters;
            final ids = query['sort'] == 'position' ? positions : [4, 2, 1, 3];
            final sorted =
                query['order'] == 'desc' ? ids.reversed.toList() : ids;
            final offset = query['offset'] as int;
            data = {
              'total': sorted.length,
              'songs':
                  sorted
                      .skip(offset)
                      .map(
                        (id) => {
                          'id': id,
                          'type': 'local',
                          'title': 'Track $id',
                        },
                      )
                      .toList(),
            };
          } else if (request.method == 'GET' && path.endsWith('/42')) {
            data = {
              'id': 42,
              'type': 'normal',
              'name': 'Mp3',
              'labels': labels,
              'song_count': positions.length,
              'sort_by': sort,
              'sort_order': order,
            };
          } else if (request.method == 'PUT' &&
              path.endsWith('/songs/reorder')) {
            positions = List<int>.from(request.data['song_ids'] as List);
          } else if (request.method == 'PUT' && path.endsWith('/sort')) {
            sort = request.data['sort_by'] as String;
            order = request.data['sort_order'] as String;
          } else {
            throw StateError('Unexpected request: ${request.method} $path');
          }
          handler.resolve(
            Response(requestOptions: request, statusCode: 200, data: data),
          );
        },
      ),
    );
    return dio;
  }
}

Future<ProviderContainer> _open(
  WidgetTester tester,
  _PlaylistServer server, {
  Size size = const Size(1200, 1000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      dioProvider.overrideWithValue(server.dio),
      playerStateProvider.overrideWith(_IdlePlayer.new),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        locale: Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PlaylistDetailPage(playlistId: '42'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _menu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('排序'));
  await tester.pumpAndSettle();
}

List<int> _visibleIds(WidgetTester tester) =>
    tester
        .widgetList<PlaylistSongTile>(find.byType(PlaylistSongTile))
        .map((tile) => tile.song.id)
        .toList();

void main() {
  for (final width in [500.0, 1440.0]) {
    for (final upward in [false, true]) {
      testWidgets(
        'edge drag scrolls ${upward ? 'up' : 'down'} at width $width',
        (tester) async {
          final server = _PlaylistServer('position', 'asc')
            ..positions = List.generate(80, (i) => i + 1);
          await _open(tester, server, size: Size(width, 700));
          await _menu(tester);
          await tester.ensureVisible(find.text('手动排序'));
          await tester.tap(find.text('手动排序'));
          await tester.pumpAndSettle();
          final scrollable =
              find
                  .descendant(
                    of: find.byType(CustomScrollView),
                    matching: find.byType(Scrollable),
                  )
                  .first;
          final position = tester.state<ScrollableState>(scrollable).position;
          position.jumpTo(upward ? 1800 : 700);
          await tester.pumpAndSettle();
          final viewport = tester.getRect(find.byType(CustomScrollView).first);
          final handles =
              find
                  .byType(ReorderableDragStartListener)
                  .evaluate()
                  .map((e) => find.byWidget(e.widget))
                  .where(
                    (f) =>
                        tester.getCenter(f).dy > viewport.top + 90 &&
                        tester.getCenter(f).dy < viewport.bottom - 90,
                  )
                  .toList();
          expect(handles, isNotEmpty);
          final handle = upward ? handles.first : handles.last;
          final tile = tester.widget<PlaylistSongTile>(
            find
                .ancestor(of: handle, matching: find.byType(PlaylistSongTile))
                .first,
          );
          final movedId = tile.song.id;
          final start = tester.getCenter(handle);
          final before = position.pixels;
          final gesture = await tester.startGesture(start);
          await gesture.moveBy(const Offset(0, 5));
          await tester.pump();
          await gesture.moveTo(
            Offset(start.dx, upward ? viewport.top + 12 : viewport.bottom - 12),
          );
          for (var i = 0; i < 60; i++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          expect(
            upward ? before - position.pixels : position.pixels - before,
            greaterThan(200),
          );
          await gesture.up();
          await tester.pumpAndSettle();
          await tester.tap(find.text('完成'));
          await tester.pumpAndSettle();
          expect(
            server.positions.toSet(),
            List.generate(80, (i) => i + 1).toSet(),
          );
          expect(
            upward
                ? server.positions.indexOf(movedId) < movedId - 1
                : server.positions.indexOf(movedId) > movedId - 1,
            isTrue,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  for (final field in [
    'position',
    'added_at',
    'file_modified_at',
    'title',
    'artist',
    'duration',
    'file_size',
  ]) {
    for (final order in ['asc', 'desc']) {
      testWidgets('scanned playlist offers manual sorting from $field $order', (
        tester,
      ) async {
        await _open(tester, _PlaylistServer(field, order));
        final before = _visibleIds(tester);
        await _menu(tester);
        expect(find.text('手动排序'), findsOneWidget);
        await tester.ensureVisible(find.text('手动排序'));
        await tester.tap(find.text('手动排序'));
        await tester.pumpAndSettle();
        expect(find.byType(SliverReorderableList), findsOneWidget);
        expect(_visibleIds(tester), before);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'manual drag from file time saves full order and custom ascending view',
    (tester) async {
      final server = _PlaylistServer('file_modified_at', 'asc');
      final container = await _open(tester, server);
      await _menu(tester);
      await tester.ensureVisible(find.text('手动排序'));
      await tester.tap(find.text('手动排序'));
      await tester.pumpAndSettle();
      final list = tester.widget<SliverReorderableList>(
        find.byType(SliverReorderableList),
      );
      list.onReorderItem!(0, 3);
      await tester.pump();
      expect(_visibleIds(tester), [2, 1, 3, 4]);
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
      expect(server.positions, [2, 1, 3, 4]);
      expect(
        server.requests
            .where((r) => r.path.endsWith('/songs/reorder'))
            .single
            .data,
        {
          'song_ids': [2, 1, 3, 4],
        },
      );
      expect(server.sort, 'position');
      expect(server.order, 'asc');
      expect(
        container.read(playlistSongsProvider(42)).value!.items.map((s) => s.id),
        [2, 1, 3, 4],
      );
      expect(_visibleIds(tester), [2, 1, 3, 4]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cancel keeps saved view and positions; search still hides permanent sorting',
    (tester) async {
      final server = _PlaylistServer('title', 'desc', labels: []);
      final container = await _open(tester, server);
      await _menu(tester);
      await tester.ensureVisible(find.text('手动排序'));
      await tester.tap(find.text('手动排序'));
      await tester.pumpAndSettle();
      tester
          .widget<SliverReorderableList>(find.byType(SliverReorderableList))
          .onReorderItem!(0, 3);
      await tester.pump();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(server.requests.where((r) => r.method == 'PUT'), isEmpty);
      expect(server.positions, [1, 2, 3, 4]);
      expect(server.sort, 'title');
      expect(server.order, 'desc');
      final search = container
          .read(playlistSongsProvider(42).notifier)
          .search('Track');
      await tester.pumpAndSettle();
      await search;
      await _menu(tester);
      expect(find.text('手动排序'), findsNothing);
      expect(find.text('随机排序'), findsNothing);
    },
  );
}
