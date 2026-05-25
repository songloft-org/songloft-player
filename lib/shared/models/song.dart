/// 歌曲模型
class Song {
  final int id;
  final String type; // 'local', 'remote', 'radio'
  final String title;
  final String? artist;
  final String? album;
  final double duration;
  final String? filePath;
  final String? url;
  final String? coverPath;
  final String? coverUrl;
  final String? lyricUrl; // 歌词URL（后端统一处理，有歌词时为 /api/v1/songs/{id}/lyric，无歌词时为空）
  final int fileSize;
  final String? format;
  final int bitRate;
  final int sampleRate;
  final bool isLive;
  final DateTime addedAt;
  final DateTime updatedAt;

  const Song({
    required this.id,
    required this.type,
    required this.title,
    this.artist,
    this.album,
    required this.duration,
    this.filePath,
    this.url,
    this.coverPath,
    this.coverUrl,
    this.lyricUrl,
    this.fileSize = 0,
    this.format,
    this.bitRate = 0,
    this.sampleRate = 0,
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
      duration: (json['duration'] as num?)?.toDouble() ?? 0.0,
      filePath: json['file_path'] as String?,
      url: json['url'] as String?,
      coverPath: json['cover_path'] as String?,
      coverUrl: json['cover_url'] as String?,
      lyricUrl: json['lyric_url'] as String?,
      fileSize: json['file_size'] as int? ?? 0,
      format: json['format'] as String?,
      bitRate: json['bit_rate'] as int? ?? 0,
      sampleRate: json['sample_rate'] as int? ?? 0,
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
      'duration': duration,
      'file_path': filePath,
      'url': url,
      'cover_path': coverPath,
      'cover_url': coverUrl,
      'lyric_url': lyricUrl,
      'file_size': fileSize,
      'format': format,
      'bit_rate': bitRate,
      'sample_rate': sampleRate,
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
    double? duration,
    String? filePath,
    String? url,
    String? coverPath,
    String? coverUrl,
    String? lyricUrl,
    int? fileSize,
    String? format,
    int? bitRate,
    int? sampleRate,
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
      duration: duration ?? this.duration,
      filePath: filePath ?? this.filePath,
      url: url ?? this.url,
      coverPath: coverPath ?? this.coverPath,
      coverUrl: coverUrl ?? this.coverUrl,
      lyricUrl: lyricUrl ?? this.lyricUrl,
      fileSize: fileSize ?? this.fileSize,
      format: format ?? this.format,
      bitRate: bitRate ?? this.bitRate,
      sampleRate: sampleRate ?? this.sampleRate,
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
