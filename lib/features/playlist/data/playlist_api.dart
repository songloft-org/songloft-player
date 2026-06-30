import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../config/app_config.dart';
import '../../../shared/models/song.dart';
import '../domain/playlist.dart';

/// 歌单 API 客户端
class PlaylistApi {
  final Dio dio;

  PlaylistApi(this.dio);

  /// 获取歌单列表
  /// GET /api/v1/playlists?type=normal&limit=20&offset=0
  Future<PlaylistListResponse> getPlaylists({
    String? type,
    String? excludeLabels,
    int limit = 20,
    int offset = 0,
  }) async {
    final queryParams = <String, dynamic>{'limit': limit, 'offset': offset};
    if (type != null) {
      queryParams['type'] = type;
    }
    if (excludeLabels != null) {
      queryParams['exclude_labels'] = excludeLabels;
    }

    final response = await dio.get(
      '${AppConfig.apiPrefix}/playlists',
      queryParameters: queryParams,
    );
    return PlaylistListResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// 创建歌单
  /// POST /api/v1/playlists
  Future<Playlist> createPlaylist({
    required String type,
    required String name,
    String? description,
    String? coverPath,
  }) async {
    final data = <String, dynamic>{'type': type, 'name': name};
    if (description != null) {
      data['description'] = description;
    }
    if (coverPath != null) {
      data['cover_path'] = coverPath;
    }

    final response = await dio.post(
      '${AppConfig.apiPrefix}/playlists',
      data: data,
    );
    return Playlist.fromJson(response.data as Map<String, dynamic>);
  }

  /// 获取歌单详情
  /// GET /api/v1/playlists/{id}
  Future<Playlist> getPlaylist(int id) async {
    final response = await dio.get('${AppConfig.apiPrefix}/playlists/$id');
    return Playlist.fromJson(response.data as Map<String, dynamic>);
  }

  /// 更新歌单
  /// PUT /api/v1/playlists/{id}
  Future<Playlist> updatePlaylist(
    int id, {
    String? name,
    String? description,
    String? coverPath,
    String? coverUrl,
    int? coverSongId,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) {
      data['name'] = name;
    }
    if (description != null) {
      data['description'] = description;
    }
    if (coverSongId != null) {
      data['cover_song_id'] = coverSongId;
    } else {
      if (coverPath != null) {
        data['cover_path'] = coverPath;
      }
      if (coverUrl != null) {
        data['cover_url'] = coverUrl;
      }
    }

    final response = await dio.put(
      '${AppConfig.apiPrefix}/playlists/$id',
      data: data,
    );
    return Playlist.fromJson(response.data as Map<String, dynamic>);
  }

  /// 上传歌单封面图片
  /// Web 平台使用 bytes，原生平台使用 filePath
  /// POST /api/v1/playlists/{id}/cover
  Future<Playlist> uploadPlaylistCover(
    int playlistId, {
    Uint8List? bytes,
    String? filePath,
    required String fileName,
  }) async {
    late final MultipartFile multipartFile;
    if (bytes != null) {
      multipartFile = MultipartFile.fromBytes(bytes, filename: fileName);
    } else if (filePath != null) {
      multipartFile = await MultipartFile.fromFile(
        filePath,
        filename: fileName,
      );
    } else {
      throw ArgumentError('Either bytes or filePath must be provided');
    }

    final formData = FormData.fromMap({'file': multipartFile});

    final response = await dio.post(
      '${AppConfig.apiPrefix}/playlists/$playlistId/cover',
      data: formData,
    );
    return Playlist.fromJson(response.data as Map<String, dynamic>);
  }

  /// 删除歌单
  /// DELETE /api/v1/playlists/{id}
  Future<void> deletePlaylist(int id) async {
    await dio.delete('${AppConfig.apiPrefix}/playlists/$id');
  }

  /// 获取歌单内歌曲
  /// GET /api/v1/playlists/{id}/songs?limit=20&offset=0&sort=position&order=asc&keyword=
  Future<SongListResponse> getPlaylistSongs(
    int id, {
    int limit = 20,
    int offset = 0,
    String? sort,
    String? order,
    String? keyword,
  }) async {
    final params = <String, dynamic>{'limit': limit, 'offset': offset};
    if (sort != null && sort.isNotEmpty) params['sort'] = sort;
    if (order != null && order.isNotEmpty) params['order'] = order;
    if (keyword != null && keyword.isNotEmpty) params['keyword'] = keyword;
    final response = await dio.get(
      '${AppConfig.apiPrefix}/playlists/$id/songs',
      queryParameters: params,
    );
    return SongListResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// 向歌单添加歌曲
  /// POST /api/v1/playlists/{id}/songs
  /// 返回 (added, skipped)：实际新增数量与因已存在或类型不兼容被跳过的数量
  Future<({int added, int skipped})> addSongsToPlaylist(
    int id,
    List<int> songIds,
  ) async {
    final response = await dio.post<Map<String, dynamic>>(
      '${AppConfig.apiPrefix}/playlists/$id/songs',
      data: {'song_ids': songIds},
    );
    final data = response.data ?? const <String, dynamic>{};
    return (
      added: (data['added'] as num?)?.toInt() ?? 0,
      skipped: (data['skipped'] as num?)?.toInt() ?? 0,
    );
  }

  /// 重新排序歌单内歌曲
  /// PUT /api/v1/playlists/{id}/songs/reorder
  Future<void> reorderPlaylistSongs(int id, List<int> songIds) async {
    await dio.put(
      '${AppConfig.apiPrefix}/playlists/$id/songs/reorder',
      data: {'song_ids': songIds},
    );
  }

  /// 重新排序歌单
  /// PUT /api/v1/playlists/reorder
  Future<void> reorderPlaylists(List<int> playlistIds) async {
    await dio.put(
      '${AppConfig.apiPrefix}/playlists/reorder',
      data: {'playlist_ids': playlistIds},
    );
  }

  /// 从歌单移除歌曲
  /// DELETE /api/v1/playlists/{id}/songs/{songId}
  Future<void> removeSongFromPlaylist(int playlistId, int songId) async {
    await dio.delete(
      '${AppConfig.apiPrefix}/playlists/$playlistId/songs/$songId',
    );
  }

  /// 更新歌单最后访问时间
  /// POST /api/v1/playlists/{id}/touch
  Future<void> touchPlaylist(int id) async {
    await dio.post('${AppConfig.apiPrefix}/playlists/$id/touch');
  }

  /// 设置歌单可见性
  /// PUT /api/v1/playlists/{id}/visibility
  Future<Playlist> setPlaylistVisibility(int id, {required bool hidden}) async {
    final response = await dio.put(
      '${AppConfig.apiPrefix}/playlists/$id/visibility',
      data: {'hidden': hidden},
    );
    return Playlist.fromJson(response.data as Map<String, dynamic>);
  }

  /// 批量删除歌单
  /// POST /api/v1/playlists/batch-delete
  Future<Map<String, dynamic>> batchDeletePlaylists(List<int> ids) async {
    final response = await dio.post(
      '${AppConfig.apiPrefix}/playlists/batch-delete',
      data: {'ids': ids},
    );
    return response.data as Map<String, dynamic>;
  }

}
