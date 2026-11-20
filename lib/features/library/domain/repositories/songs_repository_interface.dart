import '../../../../shared/models/artist.dart';
import '../../../../shared/models/song.dart';

/// 歌曲仓库抽象接口
///
/// 定义歌曲数据访问的契约，具体实现由 data 层的 [SongsRepository] 提供。
abstract class ISongsRepository {
  /// 获取歌曲列表
  Future<SongListResponse> getSongs({
    String? type,
    String? keyword,
    String? pathPrefix,
    String? excludePlaylistLabels,
    int limit = 20,
    int offset = 0,
    String? sort,
    String? order,
  });

  /// 获取匹配过滤条件的歌曲 ID 列表
  Future<List<int>> getSongIds({
    String? type,
    String? keyword,
    String? pathPrefix,
    String? excludePlaylistLabels,
    String? sort,
    String? order,
  });

  /// 获取单首歌曲
  Future<Song> getSong(int id);

  /// 创建网络歌曲
  Future<Song> createRemoteSong({
    required String title,
    String? artist,
    String? album,
    required String url,
    String? coverUrl,
    double? duration,
    String? lyricRemoteUrl,
    bool isVideo = false,
  });

  /// 创建电台歌曲
  Future<Song> createRadioSong({
    required String title,
    String? artist,
    required String url,
    String? coverUrl,
    bool isVideo = false,
    RadioMode radioMode = RadioMode.automatic,
  });

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
    bool? isVideo,
    RadioMode? radioMode,
  });

  /// 批量设置电台播放模式。
  Future<int> batchUpdateRadioMode(
    List<int> ids, {
    required RadioMode radioMode,
    bool? isVideo,
  });

  /// 更新歌曲歌词
  Future<({String fileWriteStatus})> updateSongLyrics(
    int id, {
    required String lyricSource,
    String? lyric,
    String? tlyric,
    String? rlyric,
    String? lxlyric,
    String? lyricRemoteUrl,
  });

  /// 写入本地歌曲标签
  Future<({String fileWrite})> writeSongTags(
    int id, {
    String? title,
    String? artist,
    String? album,
    bool renameFile = false,
  });

  /// 获取歌曲参与歌手（多值，已拆分）
  Future<List<SongArtist>> getSongArtists(int id);

  /// 全量更新歌曲参与歌手（PUT /songs/{id}/artists）
  Future<List<SongArtist>> setSongArtists(int id, List<ArtistInput> artists);

  /// 删除歌曲
  Future<void> deleteSong(int id, {bool deleteFiles = false});

  /// 批量删除歌曲
  Future<int> batchDeleteSongs(List<int> ids, {bool deleteFiles = false});

  /// 清理无效歌曲
  Future<int> cleanSongs();
}
