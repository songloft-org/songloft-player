import 'package:dio/dio.dart';

import '../../../config/app_config.dart';

/// 自定义标签 API 客户端
class SongTagsApi {
  final Dio dio;

  SongTagsApi(this.dio);

  /// 获取标签列表
  Future<SongTagListResponse> list({
    String? keyword,
    String sort = 'song_count',
    String order = 'desc',
    int limit = 60,
    int offset = 0,
  }) async {
    final queryParams = <String, dynamic>{
      'sort': sort,
      'order': order,
      'limit': limit,
      'offset': offset,
    };
    if (keyword != null && keyword.isNotEmpty) {
      queryParams['keyword'] = keyword;
    }
    final response = await dio.get<Map<String, dynamic>>(
      '${AppConfig.apiPrefix}/song-tags',
      queryParameters: queryParams,
    );
    return SongTagListResponse.fromJson(response.data!);
  }

  /// 创建标签
  Future<SongTag> create({required String name, String color = ''}) async {
    final response = await dio.post<Map<String, dynamic>>(
      '${AppConfig.apiPrefix}/song-tags',
      data: {'name': name, 'color': color},
    );
    return SongTag.fromJson(response.data!);
  }

  /// 获取标签详情
  Future<SongTag> get(int id) async {
    final response = await dio.get<Map<String, dynamic>>(
      '${AppConfig.apiPrefix}/song-tags/$id',
    );
    return SongTag.fromJson(response.data!);
  }

  /// 更新标签
  Future<void> update(int id, {String? name, String? color}) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (color != null) data['color'] = color;
    await dio.put('${AppConfig.apiPrefix}/song-tags/$id', data: data);
  }

  /// 删除标签
  Future<void> delete(int id) async {
    await dio.delete('${AppConfig.apiPrefix}/song-tags/$id');
  }

  /// 获取标签下的歌曲 ID 列表
  Future<List<int>> listSongIds(int tagId) async {
    final response = await dio.get<List<dynamic>>(
      '${AppConfig.apiPrefix}/song-tags/$tagId/song-ids',
    );
    return response.data!.cast<int>();
  }

  /// 获取歌曲的标签列表
  Future<List<SongTag>> getSongTags(int songId) async {
    final response = await dio.get<List<dynamic>>(
      '${AppConfig.apiPrefix}/songs/$songId/song-tags',
    );
    return response.data!
        .map((e) => SongTag.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 设置歌曲的标签（全量替换）
  Future<void> setSongTags(int songId, List<int> tagIds) async {
    await dio.put(
      '${AppConfig.apiPrefix}/songs/$songId/song-tags',
      data: {'tag_ids': tagIds},
    );
  }

  /// 批量绑定歌曲到标签
  Future<int> batchBind(int tagId, List<int> songIds) async {
    final response = await dio.post<Map<String, dynamic>>(
      '${AppConfig.apiPrefix}/song-tags/$tagId/bind',
      data: {'song_ids': songIds},
    );
    return response.data!['bound'] as int;
  }

  /// 批量解绑
  Future<int> batchUnbind(int tagId, List<int> songIds) async {
    final response = await dio.post<Map<String, dynamic>>(
      '${AppConfig.apiPrefix}/song-tags/$tagId/unbind',
      data: {'song_ids': songIds},
    );
    return response.data!['unbound'] as int;
  }

  /// 歌单转标签
  Future<FromPlaylistResult> fromPlaylist(int playlistId) async {
    final response = await dio.post<Map<String, dynamic>>(
      '${AppConfig.apiPrefix}/song-tags/from-playlist/$playlistId',
    );
    return FromPlaylistResult.fromJson(response.data!);
  }
}

/// 标签模型
class SongTag {
  final int id;
  final String name;
  final String color;
  final int songCount;
  final String coverUrl;
  final String createdAt;

  const SongTag({
    required this.id,
    required this.name,
    this.color = '',
    this.songCount = 0,
    this.coverUrl = '',
    this.createdAt = '',
  });

  factory SongTag.fromJson(Map<String, dynamic> json) {
    return SongTag(
      id: json['id'] as int,
      name: json['name'] as String,
      color: (json['color'] as String?) ?? '',
      songCount: (json['song_count'] as int?) ?? 0,
      coverUrl: (json['cover_url'] as String?) ?? '',
      createdAt: (json['created_at'] as String?) ?? '',
    );
  }
}

/// 标签列表响应
class SongTagListResponse {
  final List<SongTag> tags;
  final int total;

  const SongTagListResponse({required this.tags, required this.total});

  factory SongTagListResponse.fromJson(Map<String, dynamic> json) {
    final tagsJson = json['tags'] as List<dynamic>? ?? [];
    return SongTagListResponse(
      tags: tagsJson
          .map((e) => SongTag.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as int?) ?? 0,
    );
  }
}

/// 歌单转标签结果
class FromPlaylistResult {
  final SongTag tag;
  final int bound;

  const FromPlaylistResult({required this.tag, required this.bound});

  factory FromPlaylistResult.fromJson(Map<String, dynamic> json) {
    return FromPlaylistResult(
      tag: SongTag.fromJson(json['tag'] as Map<String, dynamic>),
      bound: json['bound'] as int,
    );
  }
}
