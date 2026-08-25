/// 曲库汇总统计（`GET /api/v1/songs/stats`，对应后端 `database.LibraryStats`）
///
/// 单位按后端实现为准：
/// - [totalDuration] 单位**秒**（后端 `SUM(duration)`，Go 侧是 float64）
/// - [totalFileSize] 单位**字节**，全远程曲库为 0 —— UI 据此隐藏「占用」一行，
///   而不是打印毫无信息量的「0 B」
class LibraryStats {
  final int totalSongs;
  final int localSongs;
  final int remoteSongs;
  final int radioSongs;

  /// 曲库总时长，单位秒。
  final double totalDuration;

  /// 本地文件总占用，单位字节；无本地文件的曲库为 0。
  final int totalFileSize;

  final int artistCount;
  final int albumCount;
  final int genreCount;

  const LibraryStats({
    this.totalSongs = 0,
    this.localSongs = 0,
    this.remoteSongs = 0,
    this.radioSongs = 0,
    this.totalDuration = 0,
    this.totalFileSize = 0,
    this.artistCount = 0,
    this.albumCount = 0,
    this.genreCount = 0,
  });

  /// 全零快照：加载中与请求失败时的兜底值，让统计面板降级为「都是 0」而不是消失。
  static const LibraryStats empty = LibraryStats();

  /// 是否有本地文件占用空间——为 false 时统计面板不渲染「占用」那一行。
  bool get hasFileSize => totalFileSize > 0;

  /// 每个字段独立容错：一个脏字段不该让首页统计面板整块抛异常。
  ///
  /// 数字统一走 `as num?` 再转换，不写 `as int` / `as double`：Go 的
  /// `encoding/json` 把整数值的 float64 写成 `9643`（无小数点），jsonDecode
  /// 出来就是 int，`as double` 会在运行时抛（与 `Song.fromJson` 的 duration 同坑）。
  factory LibraryStats.fromJson(Map<String, dynamic> json) {
    int asInt(String key) => (json[key] as num?)?.toInt() ?? 0;
    return LibraryStats(
      totalSongs: asInt('total_songs'),
      localSongs: asInt('local_songs'),
      remoteSongs: asInt('remote_songs'),
      radioSongs: asInt('radio_songs'),
      totalDuration: (json['total_duration'] as num?)?.toDouble() ?? 0,
      totalFileSize: asInt('total_file_size'),
      artistCount: asInt('artist_count'),
      albumCount: asInt('album_count'),
      genreCount: asInt('genre_count'),
    );
  }
}
