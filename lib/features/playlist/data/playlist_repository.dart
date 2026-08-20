import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../l10n/l10n_holder.dart';
import '../../../shared/models/song.dart';
import '../domain/playlist.dart';
import '../domain/repositories/playlist_repository_interface.dart';
import 'playlist_api.dart';

/// 歌单仓库
/// 封装 API 调用，添加错误处理
class PlaylistRepository implements IPlaylistRepository {
  final PlaylistApi playlistApi;

  PlaylistRepository(this.playlistApi);

  @override
  Future<PlaylistListResponse> getPlaylists({
    String? type,
    String? excludeLabels,
    String? keyword,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      return await playlistApi.getPlaylists(
        type: type,
        excludeLabels: excludeLabels,
        keyword: keyword,
        limit: limit,
        offset: offset,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<Playlist> createPlaylist({
    required String type,
    required String name,
    String? description,
    String? coverPath,
  }) async {
    try {
      return await playlistApi.createPlaylist(
        type: type,
        name: name,
        description: description,
        coverPath: coverPath,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<Playlist> getPlaylist(int id) async {
    try {
      return await playlistApi.getPlaylist(id);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<Playlist> updatePlaylist(
    int id, {
    String? name,
    String? description,
    String? coverPath,
    String? coverUrl,
    int? coverSongId,
  }) async {
    try {
      return await playlistApi.updatePlaylist(
        id,
        name: name,
        description: description,
        coverPath: coverPath,
        coverUrl: coverUrl,
        coverSongId: coverSongId,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<Playlist> uploadPlaylistCover(
    int playlistId, {
    Uint8List? bytes,
    String? filePath,
    required String fileName,
  }) async {
    try {
      return await playlistApi.uploadPlaylistCover(
        playlistId,
        bytes: bytes,
        filePath: filePath,
        fileName: fileName,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> deletePlaylist(int id, {bool deleteSongs = false}) async {
    try {
      await playlistApi.deletePlaylist(id, deleteSongs: deleteSongs);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<SongListResponse> getPlaylistSongs(
    int id, {
    int limit = 20,
    int offset = 0,
    String? sort,
    String? order,
    String? keyword,
  }) async {
    try {
      return await playlistApi.getPlaylistSongs(
        id,
        limit: limit,
        offset: offset,
        sort: sort,
        order: order,
        keyword: keyword,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<({int added, int skipped})> addSongsToPlaylist(
    int id,
    List<int> songIds,
  ) async {
    try {
      return await playlistApi.addSongsToPlaylist(id, songIds);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> reorderPlaylistSongs(int id, List<int> songIds) async {
    try {
      await playlistApi.reorderPlaylistSongs(id, songIds);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> sortPlaylistSongs(int id, String action) async {
    try {
      await playlistApi.sortPlaylistSongs(id, action);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> reorderPlaylists(List<int> playlistIds) async {
    try {
      await playlistApi.reorderPlaylists(playlistIds);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> removeSongFromPlaylist(int playlistId, int songId) async {
    try {
      await playlistApi.removeSongFromPlaylist(playlistId, songId);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> touchPlaylist(int id) async {
    try {
      await playlistApi.touchPlaylist(id);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> updatePlaylistSort(
    int id, {
    required String sortBy,
    required String sortOrder,
  }) async {
    try {
      await playlistApi.updatePlaylistSort(
        id,
        sortBy: sortBy,
        sortOrder: sortOrder,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<Playlist> setPlaylistVisibility(int id, {required bool hidden}) async {
    try {
      return await playlistApi.setPlaylistVisibility(id, hidden: hidden);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<Playlist> setPlaylistPinned(int id, {required bool pinned}) async {
    try {
      return await playlistApi.setPlaylistPinned(id, pinned: pinned);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<int> batchDeletePlaylists(
    List<int> ids, {
    bool deleteSongs = false,
  }) async {
    try {
      final result = await playlistApi.batchDeletePlaylists(
        ids,
        deleteSongs: deleteSongs,
      );
      return result['deleted'] as int? ?? 0;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// 处理 Dio 异常
  Exception _handleError(DioException e) {
    final response = e.response;
    if (response != null) {
      final statusCode = response.statusCode;
      final data = response.data;
      String message = l10n.playlistErrRequestFailed;
      if (data is Map<String, dynamic> && data.containsKey('error')) {
        message = data['error'] as String;
      } else if (data is Map<String, dynamic> && data.containsKey('message')) {
        message = data['message'] as String;
      }
      return PlaylistException(message, statusCode: statusCode);
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return PlaylistException(l10n.playlistErrTimeout);
      case DioExceptionType.connectionError:
        return PlaylistException(l10n.errorNetworkFailed);
      case DioExceptionType.cancel:
        return PlaylistException(l10n.playlistErrCancelled);
      default:
        if (e.type.name == 'transformTimeout') {
          return PlaylistException(l10n.playlistErrTimeout);
        }
        return PlaylistException(l10n.playlistErrNetwork('${e.message}'));
    }
  }
}

/// 歌单异常
class PlaylistException implements Exception {
  final String message;
  final int? statusCode;

  PlaylistException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
