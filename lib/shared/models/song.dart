/// 歌曲模型
class Song {
  final int id;
  final String type; // 'local', 'remote', 'radio'
  final String title;
  final String? artist;
  final String? album;
  final int year; // 发行年份，0 表示未知
  final String? genre; // 流派
  final String? language; // 语种
  final String? style; // 风格
  final double duration;
  final String? filePath;
  final String? url;
  final String? coverUrl; // 封面URL（后端统一处理）
  final String? lyricUrl; // 歌词URL（后端统一处理，有歌词时为 /api/v1/songs/{id}/lyric，无歌词时为空）
  final String? lyricRemoteUrl; // 歌词原始 URL（lyric_source=url 时的原始 URL）
  final int fileSize;
  final String? format;
  final int bitRate;
  final int sampleRate;
  final String? sourceUrl;
  final String? sourceCoverUrl;
  final bool isLive;
  final DateTime addedAt;
  final DateTime updatedAt;

  const Song({
    required this.id,
    required this.type,
    required this.title,
    this.artist,
    this.album,
    this.year = 0,
    this.genre,
    this.language,
    this.style,
    required this.duration,
    this.filePath,
    this.url,
    this.coverUrl,
    this.lyricUrl,
    this.lyricRemoteUrl,
    this.fileSize = 0,
    this.format,
    this.bitRate = 0,
    this.sampleRate = 0,
    this.sourceUrl,
    this.sourceCoverUrl,
    this.isLive = false,
    required this.addedAt,
    required this.updatedAt,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'] as int,
      type: json['type'] as String? ?? 'local',
      title: json['title'] as String,
      artist: json['artist'] as String?,
      album: json['album'] as String?,
      year: json['year'] as int? ?? 0,
      genre: json['genre'] as String?,
      language: json['language'] as String?,
      style: json['style'] as String?,
      duration: (json['duration'] as num?)?.toDouble() ?? 0.0,
      filePath: json['file_path'] as String?,
      url: json['url'] as String?,
      coverUrl: json['cover_url'] as String?,
      lyricUrl: json['lyric_url'] as String?,
      lyricRemoteUrl: json['lyric_remote_url'] as String?,
      fileSize: json['file_size'] as int? ?? 0,
      format: json['format'] as String?,
      bitRate: json['bit_rate'] as int? ?? 0,
      sampleRate: json['sample_rate'] as int? ?? 0,
      sourceUrl: json['source_url'] as String?,
      sourceCoverUrl: json['source_cover_url'] as String?,
      isLive: json['is_live'] as bool? ?? false,
      addedAt:
          json['added_at'] != null
              ? DateTime.parse(json['added_at'] as String)
              : DateTime.now(),
      updatedAt:
          json['updated_at'] != null
              ? DateTime.parse(json['updated_at'] as String)
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'artist': artist,
      'album': album,
      'year': year,
      'genre': genre,
      'language': language,
      'style': style,
      'duration': duration,
      'file_path': filePath,
      'url': url,
      'cover_url': coverUrl,
      'lyric_url': lyricUrl,
      'lyric_remote_url': lyricRemoteUrl,
      'file_size': fileSize,
      'format': format,
      'bit_rate': bitRate,
      'sample_rate': sampleRate,
      'source_url': sourceUrl,
      'source_cover_url': sourceCoverUrl,
      'is_live': isLive,
      'added_at': addedAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Song copyWith({
    int? id,
    String? type,
    String? title,
    String? artist,
    String? album,
    int? year,
    String? genre,
    String? language,
    String? style,
    double? duration,
    String? filePath,
    String? url,
    String? coverUrl,
    String? lyricUrl,
    String? lyricRemoteUrl,
    int? fileSize,
    String? format,
    int? bitRate,
    int? sampleRate,
    String? sourceUrl,
    String? sourceCoverUrl,
    bool? isLive,
    DateTime? addedAt,
    DateTime? updatedAt,
  }) {
    return Song(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      year: year ?? this.year,
      genre: genre ?? this.genre,
      language: language ?? this.language,
      style: style ?? this.style,
      duration: duration ?? this.duration,
      filePath: filePath ?? this.filePath,
      url: url ?? this.url,
      coverUrl: coverUrl ?? this.coverUrl,
      lyricUrl: lyricUrl ?? this.lyricUrl,
      lyricRemoteUrl: lyricRemoteUrl ?? this.lyricRemoteUrl,
      fileSize: fileSize ?? this.fileSize,
      format: format ?? this.format,
      bitRate: bitRate ?? this.bitRate,
      sampleRate: sampleRate ?? this.sampleRate,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      sourceCoverUrl: sourceCoverUrl ?? this.sourceCoverUrl,
      isLive: isLive ?? this.isLive,
      addedAt: addedAt ?? this.addedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Song && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// 标签分类聚合项：某维度的一个取值及其歌曲数量（如 genre="Rock", count=42）。
class SongFacet {
  final String value;
  final int count;

  const SongFacet({required this.value, required this.count});

  factory SongFacet.fromJson(Map<String, dynamic> json) {
    return SongFacet(
      value: json['value'] as String? ?? '',
      count: json['count'] as int? ?? 0,
    );
  }
}

/// 歌曲列表响应
class SongListResponse {
  final List<Song> songs;
  final int total;

  const SongListResponse({required this.songs, required this.total});

  factory SongListResponse.fromJson(Map<String, dynamic> json) {
    final songsList =
        (json['songs'] as List<dynamic>?)
            ?.map((e) => Song.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return SongListResponse(
      songs: songsList,
      total: json['total'] as int? ?? songsList.length,
    );
  }
}
