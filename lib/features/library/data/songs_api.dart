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
    String? lyricRemoteUrl,
  }) async {
    final songs = await createRemoteSongs([
      {
        'title': title,
        'artist': artist,
        'album': album,
        'url': url,
        'cover_url': coverUrl,
        'duration': duration,
        if (lyricRemoteUrl != null && lyricRemoteUrl.isNotEmpty) ...{
          'lyric': lyricRemoteUrl,
          'lyric_source': 'url',
        },
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

  /// 更新歌曲歌词
  ///
  /// PUT /api/v1/songs/{id}/lyrics
  ///
  /// [lyricSource] 必填，常见值：'manual'（用户手动调整,scanner 不会覆盖）、
  /// 'cached'（远程歌词缓存到本地）、'url'（运行时从 URL 拉取，传 lyricRemoteUrl）。
  /// [lyric]/[tlyric]/[rlyric]/[lxlyric] 仅在非 url 来源时生效；它们会被后端
  /// 包成 LyricPayload JSON 写入 songs.lyric 列。
  ///
  /// 返回 `fileWriteStatus`：'written' / 'skipped' / 'failed' —— 表示后端
  /// 是否把元数据回写到本地音频文件，由调用方按状态显示对应 toast。
  Future<({String fileWriteStatus})> updateSongLyrics(
    int id, {
    required String lyricSource,
    String? lyric,
    String? tlyric,
    String? rlyric,
    String? lxlyric,
    String? lyricRemoteUrl,
  }) async {
    final data = <String, dynamic>{
      'lyric_source': lyricSource,
      if (lyric != null) 'lyric': lyric,
      if (tlyric != null) 'tlyric': tlyric,
      if (rlyric != null) 'rlyric': rlyric,
      if (lxlyric != null) 'lxlyric': lxlyric,
      if (lyricRemoteUrl != null) 'lyric_remote_url': lyricRemoteUrl,
    };
    final response = await dio.put<Map<String, dynamic>>(
      '${AppConfig.apiPrefix}/songs/$id/lyrics',
      data: data,
    );
    final status = response.data?['file_write_status'] as String? ?? 'skipped';
    return (fileWriteStatus: status);
  }

  /// 删除歌曲
  Future<void> deleteSong(int id, {bool deleteFiles = false}) async {
    await dio.delete(
      '${AppConfig.apiPrefix}/songs/$id',
      queryParameters: deleteFiles ? {'delete_files': 'true'} : null,
    );
  }

  /// 批量删除歌曲
  /// POST /api/v1/songs/batch-delete
  Future<int> batchDeleteSongs(List<int> ids, {bool deleteFiles = false}) async {
    final response = await dio.post<Map<String, dynamic>>(
      '${AppConfig.apiPrefix}/songs/batch-delete',
      data: {'ids': ids, 'delete_files': deleteFiles},
    );
    return response.data?['deleted'] as int? ?? 0;
  }

  /// 通知后端歌曲播放事件（触发 JS 插件播放事件广播）
  /// [type] 事件类型：play（开始播放）、finish（播放完成）、skip（用户跳过）
  Future<void> songPlayed(int id, {String type = 'finish'}) async {
    await dio.post(
      '${AppConfig.apiPrefix}/songs/$id/played',
      queryParameters: {'source': 'songloft-player', 'type': type},
    );
  }

  /// 清理无效歌曲
  Future<int> cleanSongs() async {
    final response = await dio.post<Map<String, dynamic>>(
      '${AppConfig.apiPrefix}/songs/clean',
    );
    return response.data?['cleaned'] as int? ?? 0;
  }
}
