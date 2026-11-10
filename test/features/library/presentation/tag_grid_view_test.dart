import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/features/library/data/song_tags_api.dart';
import 'package:songloft_flutter/features/library/presentation/providers/song_tag_provider.dart';
import 'package:songloft_flutter/features/library/presentation/widgets/tag_grid_view.dart';
import 'package:songloft_flutter/features/playlist/domain/playlist.dart';
import 'package:songloft_flutter/features/playlist/data/playlist_api.dart';
import 'package:songloft_flutter/features/playlist/data/playlist_repository.dart';
import 'package:songloft_flutter/features/playlist/presentation/providers/playlist_provider.dart';
import 'package:songloft_flutter/features/playlist/presentation/providers/playlist_view_provider.dart';
import 'package:songloft_flutter/l10n/app_localizations.dart';

void main() {
  for (final action in ['delete', 'batch-delete', 'hide', 'show']) {
    test('$action 更新共享标签的可见歌单计数', () async {
      final api = _CountTagApi()..count = action == 'show' ? 0 : 1;
      final before = api.count;
      final container = ProviderContainer(
        overrides: [
          songTagsApiProvider.overrideWithValue(api),
          playlistRepositoryProvider.overrideWithValue(_ChangingPlaylists(api)),
        ],
      );
      addTearDown(container.dispose);
      expect(
        (await container.read(
          songTagListProvider.future,
        )).items.single.playlistCount,
        before,
      );
      expect(
        (await container.read(allSongTagsProvider.future)).single.playlistCount,
        before,
      );
      final notifier = container.read(playlistNotifierProvider.notifier);
      if (action == 'delete') {
        expect(await notifier.deletePlaylist(3), isTrue);
      } else if (action == 'batch-delete') {
        expect(await notifier.batchDeletePlaylists([3]), 1);
      } else {
        expect(
          await notifier.setPlaylistVisibility(3, hidden: action == 'hide'),
          isTrue,
        );
      }
      expect(
        (await container.read(
          songTagListProvider.future,
        )).items.single.playlistCount,
        1 - before,
      );
      expect(
        (await container.read(allSongTagsProvider.future)).single.playlistCount,
        1 - before,
      );
    });
  }
  testWidgets('删除共享标签后清除歌单缓存中的旧引用，避免 ID 复用误标', (tester) async {
    final api = _TagApi();
    const query = PlaylistListQuery();
    final container = ProviderContainer(
      overrides: [
        songTagsApiProvider.overrideWithValue(api),
        playlistViewModeProvider.overrideWith(_ListViewMode.new),
        playlistListProvider(query).overrideWith(() => _Playlists(api)),
        playlistDetailProvider(3).overrideWith((ref) async => api.playlist),
      ],
    );
    addTearDown(container.dispose);
    expect(
      (await container.read(
        playlistListProvider(query).future,
      )).items.single.labels,
      ['tag:1'],
    );
    expect((await container.read(playlistDetailProvider(3).future)).labels, [
      'tag:1',
    ]);
    expect(
      (await container.read(songTagsForPlaylistProvider(3).future)).single.id,
      1,
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: TagGridView()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await tester.pumpAndSettle();
    expect(api.deleted, isTrue);
    expect(
      (await container.read(
        playlistListProvider(query).future,
      )).items.single.labels,
      isEmpty,
    );
    expect(
      (await container.read(playlistDetailProvider(3).future)).labels,
      isEmpty,
    );
    expect(
      await container.read(songTagsForPlaylistProvider(3).future),
      isEmpty,
    );
  });
}

class _TagApi extends SongTagsApi {
  _TagApi() : super(Dio());
  bool deleted = false;
  Playlist get playlist => Playlist(
    id: 3,
    type: 'normal',
    name: '收藏-Navidrome',
    labels: deleted ? [] : ['tag:1'],
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  List<SongTag> get tags =>
      deleted
          ? []
          : [const SongTag(id: 1, name: 'Navidrome', playlistCount: 1)];

  @override
  Future<SongTagListResponse> list({
    String? keyword,
    String sort = 'song_count',
    String order = 'desc',
    int limit = 60,
    int offset = 0,
  }) async => SongTagListResponse(tags: tags, total: tags.length);

  @override
  Future<List<SongTag>> getPlaylistTags(int playlistId) async => tags;

  @override
  Future<void> delete(int id) async => deleted = true;
}

class _ListViewMode extends PlaylistViewModeNotifier {
  @override
  PlaylistViewMode build() => PlaylistViewMode.list;
}

class _Playlists extends PaginatedPlaylistsNotifier {
  _Playlists(this.api) : super(const PlaylistListQuery());
  final _TagApi api;

  @override
  Future<PaginatedPlaylistsState> build() async =>
      PaginatedPlaylistsState(items: [api.playlist], totalCount: 1);
}

class _CountTagApi extends _TagApi {
  int count = 1;
  @override
  List<SongTag> get tags => [
    SongTag(id: 1, name: 'Navidrome', playlistCount: count),
  ];
}

class _ChangingPlaylists extends PlaylistRepository {
  _ChangingPlaylists(this.api) : super(PlaylistApi(Dio()));
  final _CountTagApi api;

  @override
  Future<void> deletePlaylist(int id, {bool deleteSongs = false}) async {
    api.count = 0;
  }

  @override
  Future<int> batchDeletePlaylists(
    List<int> ids, {
    bool deleteSongs = false,
  }) async {
    api.count = 0;
    return ids.length;
  }

  @override
  Future<Playlist> setPlaylistVisibility(int id, {required bool hidden}) async {
    api.count = hidden ? 0 : 1;
    return api.playlist;
  }
}
