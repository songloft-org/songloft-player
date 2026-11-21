import 'package:dio/dio.dart';

import '../../../l10n/l10n_holder.dart';
import '../../../shared/models/artist.dart';
import '../../../shared/models/song.dart';
import '../domain/repositories/songs_repository_interface.dart';
import 'songs_api.dart';

/// 歌曲仓库，封装 API 调用并添加错误处理
class SongsRepository implements ISongsRepository {
  final SongsApi songsApi;

  SongsRepository(this.songsApi);

  @override
  Future<SongListResponse> getSongs({
    String? type,
    String? keyword,
    String? pathPrefix,
    String? excludePlaylistLabels,
    int limit = 20,
    int offset = 0,
    String? sort,
    String? order,
  }) async {
    try {
      return await songsApi.getSongs(
        type: type,
        keyword: keyword,
        pathPrefix: pathPrefix,
        excludePlaylistLabels: excludePlaylistLabels,
        limit: limit,
        offset: offset,
        sort: sort,
        order: order,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<List<int>> getSongIds({
    String? type,
    String? keyword,
    String? pathPrefix,
    String? excludePlaylistLabels,
    String? sort,
    String? order,
  }) async {
    try {
      return await songsApi.getSongIds(
        type: type,
        keyword: keyword,
        pathPrefix: pathPrefix,
        excludePlaylistLabels: excludePlaylistLabels,
        sort: sort,
        order: order,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<Song> getSong(int id) async {
    try {
      return await songsApi.getSong(id);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<Song> createRemoteSong({
    required String title,
    String? artist,
    String? album,
    required String url,
    String? coverUrl,
    double? duration,
    String? lyricRemoteUrl,
    bool isVideo = false,
  }) async {
    try {
      return await songsApi.createRemoteSong(
        title: title,
        artist: artist,
        album: album,
        url: url,
        coverUrl: coverUrl,
        duration: duration,
        lyricRemoteUrl: lyricRemoteUrl,
        isVideo: isVideo,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<Song> createRadioSong({
    required String title,
    String? artist,
    required String url,
    String? coverUrl,
    bool isVideo = false,
    RadioMode radioMode = RadioMode.automatic,
  }) async {
    try {
      return await songsApi.createRadioSong(
        title: title,
        artist: artist,
        url: url,
        coverUrl: coverUrl,
        isVideo: isVideo,
        radioMode: radioMode,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<Song> updateSong(
    int id, {
    String? title,
    String? artist,
    String? album,
    String? url,
    String? coverUrl,
    double? duration,
    bool? isLive,
    bool? isVideo,
    RadioMode? radioMode,
  }) async {
    try {
      return await songsApi.updateSong(
        id,
        title: title,
        artist: artist,
        album: album,
        url: url,
        coverUrl: coverUrl,
        duration: duration,
        isLive: isLive,
        isVideo: isVideo,
        radioMode: radioMode,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<int> batchUpdateRadioMode(
    List<int> ids, {
    required RadioMode radioMode,
    bool? isVideo,
  }) async {
    try {
      return await songsApi.batchUpdateRadioMode(
        ids,
        radioMode: radioMode,
        isVideo: isVideo,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<({String fileWriteStatus})> updateSongLyrics(
    int id, {
    required String lyricSource,
    String? lyric,
    String? tlyric,
    String? rlyric,
    String? lxlyric,
    String? lyricRemoteUrl,
  }) async {
    try {
      return await songsApi.updateSongLyrics(
        id,
        lyricSource: lyricSource,
        lyric: lyric,
        tlyric: tlyric,
        rlyric: rlyric,
        lxlyric: lxlyric,
        lyricRemoteUrl: lyricRemoteUrl,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<({String fileWrite})> writeSongTags(
    int id, {
    String? title,
    String? artist,
    String? album,
    List<String> clearFields = const [],
    bool renameFile = false,
  }) async {
    try {
      return await songsApi.writeSongTags(
        id,
        title: title,
        artist: artist,
        album: album,
        clearFields: clearFields,
        renameFile: renameFile,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<List<SongArtist>> getSongArtists(int id) async {
    try {
      return await songsApi.getSongArtists(id);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<List<SongArtist>> setSongArtists(
    int id,
    List<ArtistInput> artists,
  ) async {
    try {
      return await songsApi.setSongArtists(id, artists);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> deleteSong(int id, {bool deleteFiles = false}) async {
    try {
      await songsApi.deleteSong(id, deleteFiles: deleteFiles);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<int> batchDeleteSongs(
    List<int> ids, {
    bool deleteFiles = false,
  }) async {
    try {
      return await songsApi.batchDeleteSongs(ids, deleteFiles: deleteFiles);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<int> cleanSongs() async {
    try {
      return await songsApi.cleanSongs();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// 处理 Dio 错误
  Exception _handleError(DioException e) {
    final response = e.response;
    if (response != null) {
      final data = response.data;
      if (data is Map<String, dynamic> && data.containsKey('error')) {
        return Exception(data['error']);
      }
      switch (response.statusCode) {
        case 400:
          return Exception(l10n.libraryErrorBadRequest);
        case 401:
          return Exception(l10n.libraryErrorUnauthorized);
        case 403:
          return Exception(l10n.libraryErrorForbidden);
        case 404:
          return Exception(l10n.libraryErrorNotFound);
        case 500:
          return Exception(l10n.libraryErrorServer);
        default:
          return Exception(
            l10n.libraryErrorRequestFailed(response.statusCode ?? 0),
          );
      }
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return Exception(l10n.libraryErrorTimeout);
      case DioExceptionType.connectionError:
        return Exception(l10n.libraryErrorConnection);
      default:
        if (e.type.name == 'transformTimeout') {
          return Exception(l10n.libraryErrorTimeout);
        }
        return Exception(l10n.libraryErrorNetwork(e.message ?? ''));
    }
  }
}
