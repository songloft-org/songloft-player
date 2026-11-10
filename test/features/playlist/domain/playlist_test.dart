import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/features/playlist/domain/playlist.dart';

void main() {
  test('machine ownership is hidden without discarding user descriptions', () {
    Playlist make(String description) =>
        Playlist.fromJson({'id': 1, 'description': description});
    expect(make('[navidrome:connection:starred]').displayDescription, isNull);
    expect(
      make('说明 [navidrome:connection:starred]').displayDescription,
      '说明 [navidrome:connection:starred]',
    );
    expect(
      make('[another:plugin:value]').displayDescription,
      '[another:plugin:value]',
    );
  });
  group('Playlist.fromJson', () {
    test('parses backend playlist response', () {
      final playlist = Playlist.fromJson({
        'id': 1,
        'type': 'normal',
        'name': '收藏',
        'description': '',
        'cover_url': '/api/v1/playlists/1/cover',
        'labels': ['built_in'],
        'song_count': 12,
        'created_at': '2026-06-29T10:00:00Z',
        'updated_at': '2026-06-29T10:00:00Z',
      });

      expect(playlist.id, 1);
      expect(playlist.labels, ['built_in']);
      expect(playlist.songCount, 12);
      expect(playlist.isBuiltIn, isTrue);
    });

    test('tolerates legacy and loosely typed fields', () {
      final playlist = Playlist.fromJson({
        'id': '2',
        'name': null,
        'labels': '["built_in", 42, "auto_created"]',
        'song_count': '7',
        'created_at': 'not-a-date',
        'updated_at': null,
      });

      expect(playlist.id, 2);
      expect(playlist.name, '');
      expect(playlist.labels, ['built_in', 'auto_created']);
      expect(playlist.songCount, 7);
    });
  });

  test('PlaylistListResponse parses numeric total variants', () {
    final response = PlaylistListResponse.fromJson({
      'playlists': const [],
      'total': '3',
    });

    expect(response.total, 3);
  });
}
