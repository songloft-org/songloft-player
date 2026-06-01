import 'package:dio/dio.dart';

import '../../../config/app_config.dart';
import '../../../shared/models/song.dart';

/// 歌曲 API 客户端
class SongsApi {
  final Dio dio;

  SongsApi(this.dio);

  /// 获取歌曲列表
  /// [type] 歌曲类型：local, remote, radio（可选）
  /// [keyword] 搜索关键词（可选）
  /// [pathPrefix] 按 file_path 前缀过滤（可选，如 music/Pop）
  /// [limit] 每页数量，默认 20
  /// [offset] 偏移量，默认 0
  Future<SongListResponse> getSongs({
    String? type,
    String? keyword,
    String? pathPrefix,
    int limit = 20,
    int offset = 0,
  }) async {
    final queryParams = <String, dynamic>{'limit': limit, 'offset': offset};
    if (type != null && type.isNotEmpty) {
      queryParams['type'] = type;
    }
    if (keyword != null && keyword.isNotEmpty) {
      queryParams['keyword'] = keyword;
    }
    if (pathPrefix != null && pathPrefix.isNotEmpty) {
      queryParams['path_prefix'] = pathPrefix;
    }

    final response = await dio.get<Map<String, dynamic>>(
      '${AppConfig.apiPrefix}/songs',
      queryParameters: queryParams,
    );
    return SongListResponse.fromJson(response.data!);
  }

  /// 获取匹配过滤条件的歌曲 ID 列表（用于「全选当前筛选」场景）
  /// 返回字段：ids（int 列表）、total（int）
  Future<List<int>> getSongIds({
    String? type,
    String? keyword,
    String? pathPrefix,
  }) async {
    final queryParams = <String, dynamic>{};
    if (type != null && type.isNotEmpty) {
      queryParams['type'] = type;
    }
    if (keyword != null && keyword.isNotEmpty) {
      queryParams['keyword'] = keyword;
    }
    if (pathPrefix != null && pathPrefix.isNotEmpty) {
      queryParams['path_prefix'] = pathPrefix;
    }

    final response = await dio.get<Map<String, dynamic>>(
      '${AppConfig.apiPrefix}/songs/ids',
      queryParameters: queryParams,
    );
    final raw = (response.data?['ids'] as List<dynamic>? ?? const []);
    return raw.map((e) => (e as num).toInt()).toList();
  }

  /// 获取单首歌曲详情
  Future<Song> getSong(int id) async {
    final response = await dio.get<Map<String, dynamic>>(
      '${AppConfig.apiPrefix}/songs/$id',
    );
    return Song.fromJson(response.data!);
  }

  /// 批量创建网络歌曲
  ///
  /// 返回 `{songs: List<Song>, count: int}`
  Future<List<Song>> createRemoteSongs(List<Map<String, dynamic>> items) async {
    final response = await dio.post<Map<String, dynamic>>(
      '${AppConfig.apiPrefix}/songs/remote',
      data: items,
    );
    final list = response.data!['songs'] as List<dynamic>;
    return list.map((e) => Song.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 创建单首网络歌曲（便捷方法，内部调用批量接口）
  Future<Song> createRemoteSong({
    required String title,
    String? artist,
    String? album,
    required String url,
    String? coverUrl,
    double? duration,
  }) async {
    final songs = await createRemoteSongs([
      {
        'title': title,
        'artist': artist,
        'album': album,
        'url': url,
        'cover_url': coverUrl,
        'duration': duration,
      },
    ]);
    return songs.first;
  }

  /// 批量创建电台歌曲
  Future<List<Song>> createRadioSongs(List<Map<String, dynamic>> items) async {
    final response = await dio.post<Map<String, dynamic>>(
      '${AppConfig.apiPrefix}/songs/radio',
      data: items,
    );
    final list = response.data!['songs'] as List<dynamic>;
    return list.map((e) => Song.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 创建单首电台歌曲（便捷方法，内部调用批量接口）
  Future<Song> createRadioSong({
    required String title,
    String? artist,
    required String url,
    String? coverUrl,
  }) async {
    final songs = await createRadioSongs([
      {
        'title': title,
        'artist': artist,
        'url': url,
        'cover_url': coverUrl,
      },
    ]);
    return songs.first;
  }

  /// 更新歌曲
  Future<Song> updateSong(
    int id, {
    String? title,
    String? artist,
    String? album,
    String? url,
    String? coverUrl,
    double? duration,
    bool? isLive,
  }) async {
    final data = <String, dynamic>{};
    if (title != null) data['title'] = title;
    if (artist != null) data['artist'] = artist;
    if (album != null) data['album'] = album;
    if (url != null) data['url'] = url;
    if (coverUrl != null) data['cover_url'] = coverUrl;
    if (duration != null) data['duration'] = duration;
    if (isLive != null) data['is_live'] = isLive;

    final response = await dio.put<Map<String, dynamic>>(
      '${AppConfig.apiPrefix}/songs/$id',
      data: data,
    );
    return Song.fromJson(response.data!);
  }

  /// 删除歌曲
  Future<void> deleteSong(int id) async {
    await dio.delete('${AppConfig.apiPrefix}/songs/$id');
  }

  /// 批量删除歌曲
  /// POST /api/v1/songs/batch-delete
  Future<int> batchDeleteSongs(List<int> ids) async {
    final response = await dio.post<Map<String, dynamic>>(
      '${AppConfig.apiPrefix}/songs/batch-delete',
      data: {'ids': ids},
    );
    return response.data?['deleted'] as int? ?? 0;
  }

  /// 清理无效歌曲
  Future<int> cleanSongs() async {
    final response = await dio.post<Map<String, dynamic>>(
      '${AppConfig.apiPrefix}/songs/clean',
    );
    return response.data?['cleaned'] as int? ?? 0;
  }
}
