import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/shared/models/library_stats.dart';

void main() {
  group('LibraryStats.fromJson', () {
    test('完整载荷逐字段映射', () {
      final stats = LibraryStats.fromJson(const {
        'total_songs': 1284,
        'local_songs': 1102,
        'remote_songs': 168,
        'radio_songs': 14,
        'total_duration': 331620.5,
        'total_file_size': 90409742336,
        'artist_count': 243,
        'album_count': 388,
        'genre_count': 27,
      });

      expect(stats.totalSongs, 1284);
      expect(stats.localSongs, 1102);
      expect(stats.remoteSongs, 168);
      expect(stats.radioSongs, 14);
      expect(stats.totalDuration, 331620.5);
      expect(stats.totalFileSize, 90409742336);
      expect(stats.artistCount, 243);
      expect(stats.albumCount, 388);
      expect(stats.genreCount, 27);
    });

    test('整数编码的 total_duration 不抛异常', () {
      // 后端是 Go float64，encoding/json 把整数值写成 `9643`（无小数点），
      // jsonDecode 出来就是 int —— `as double` 会在这里运行时抛。
      final stats = LibraryStats.fromJson(const {'total_duration': 9643});
      expect(stats.totalDuration, 9643.0);
    });

    test('空对象与 null 字段全部落回 0', () {
      expect(LibraryStats.fromJson(const {}).totalSongs, 0);
      expect(LibraryStats.fromJson(const {'total_songs': null}).totalSongs, 0);
      expect(
        LibraryStats.fromJson(const {'total_duration': null}).totalDuration,
        0,
      );
    });
  });

  group('hasFileSize', () {
    test('仅在占用非零时为 true', () {
      expect(LibraryStats.empty.hasFileSize, isFalse);
      expect(const LibraryStats(totalFileSize: 0).hasFileSize, isFalse);
      expect(const LibraryStats(totalFileSize: 1).hasFileSize, isTrue);
    });
  });

  test('empty 是全零快照', () {
    const stats = LibraryStats.empty;
    expect(stats.totalSongs, 0);
    expect(stats.localSongs, 0);
    expect(stats.remoteSongs, 0);
    expect(stats.radioSongs, 0);
    expect(stats.totalDuration, 0);
    expect(stats.totalFileSize, 0);
    expect(stats.artistCount, 0);
    expect(stats.albumCount, 0);
    expect(stats.genreCount, 0);
  });
}
