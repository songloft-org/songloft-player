import 'dart:typed_data';

import '../../../../shared/models/song.dart';
import '../playlist.dart';

/// 歌单仓库抽象接口
///
/// 定义歌单数据访问的契约，具体实现由 data 层的 [PlaylistRepository] 提供。
abstract class IPlaylistRepository {
  /// 获取歌单列表
  Future<PlaylistListResponse> getPlaylists({
    String? type,
    String? excludeLabels,
    String? keyword,
    int limit = 20,
    int offset = 0,
  });

  /// 创建歌单
  Future<Playlist> createPlaylist({
    required String type,
    required String name,
    String? description,
    String? coverPath,
  });

  /// 获取歌单详情
  Future<Playlist> getPlaylist(int id);

  /// 更新歌单
  Future<Playlist> updatePlaylist(
    int id, {
    String? name,
    String? description,
    String? coverPath,
    String? coverUrl,
    int? coverSongId,
  });

  /// 上传歌单封面图片
  Future<Playlist> uploadPlaylistCover(
    int playlistId, {
    Uint8List? bytes,
    String? filePath,
    required String fileName,
  });

  /// 删除歌单
  Future<void> deletePlaylist(int id, {bool deleteSongs = false});

  /// 获取歌单内歌曲
  Future<SongListResponse> getPlaylistSongs(
    int id, {
    int limit = 20,
    int offset = 0,
    String? sort,
    String? order,
    String? keyword,
  });

  /// 向歌单添加歌曲，返回 (added, skipped)
  Future<({int added, int skipped})> addSongsToPlaylist(
    int id,
    List<int> songIds,
  );

  /// 重新排序歌单内歌曲
  Future<void> reorderPlaylistSongs(int id, List<int> songIds);

  /// 服务端排序歌单内歌曲（永久排序）
  Future<void> sortPlaylistSongs(int id, String action);

  /// 重新排序歌单
  Future<void> reorderPlaylists(List<int> playlistIds);

  /// 从歌单移除歌曲
  Future<void> removeSongFromPlaylist(int playlistId, int songId);

  /// 更新歌单最后访问时间
  Future<void> touchPlaylist(int id);

  /// 更新歌单视图排序偏好
  Future<void> updatePlaylistSort(
    int id, {
    required String sortBy,
    required String sortOrder,
  });

  /// 设置歌单可见性
  Future<Playlist> setPlaylistVisibility(int id, {required bool hidden});

  /// 设置歌单置顶状态
  Future<Playlist> setPlaylistPinned(int id, {required bool pinned});

  /// 批量删除歌单
  Future<int> batchDeletePlaylists(List<int> ids, {bool deleteSongs = false});
}
