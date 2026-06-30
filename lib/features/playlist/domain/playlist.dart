import 'dart:convert';

/// 歌单实体模型
class Playlist {
  final int id;
  final String type; // 'normal' 或 'radio'
  final String name;
  final String? description;
  final String? coverUrl; // 封面URL（后端统一处理）
  final List<String> labels; // ["built_in"] 或 ["auto_created"]
  final int songCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Playlist({
    required this.id,
    required this.type,
    required this.name,
    this.description,
    this.coverUrl,
    this.labels = const [],
    this.songCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: _intFromJson(json['id']),
      type: json['type'] as String? ?? 'normal',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      coverUrl: json['cover_url'] as String?,
      labels: _labelsFromJson(json['labels']),
      songCount: _intFromJson(json['song_count']),
      createdAt: _dateTimeFromJson(json['created_at']),
      updatedAt: _dateTimeFromJson(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'name': name,
      'description': description,
      'cover_url': coverUrl,
      'labels': labels,
      'song_count': songCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Playlist copyWith({
    int? id,
    String? type,
    String? name,
    String? description,
    String? coverPath,
    String? coverUrl,
    List<String>? labels,
    int? songCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Playlist(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      description: description ?? this.description,
      coverUrl: coverUrl ?? this.coverUrl,
      labels: labels ?? this.labels,
      songCount: songCount ?? this.songCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 带缓存刷新参数的封面 URL
  ///
  /// 封面端点路径固定（/api/v1/playlists/{id}/cover），内容更新后 URL 不变，
  /// 追加 updatedAt 时间戳使浏览器和图片缓存自动失效。
  String? get coverImageUrl {
    final url = coverUrl;
    if (url == null || url.isEmpty) return null;
    return '$url?_t=${updatedAt.millisecondsSinceEpoch}';
  }

  /// 是否是内置歌单
  bool get isBuiltIn => labels.contains('built_in');

  /// 是否是自动创建的歌单
  bool get isAutoCreated => labels.contains('auto_created');

  /// 是否是隐藏歌单
  bool get isHidden => labels.contains('hidden');

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Playlist && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

int _intFromJson(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

List<String> _labelsFromJson(dynamic value) {
  if (value == null) return [];
  if (value is String) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) {
        return decoded.whereType<String>().toList();
      }
    } on FormatException {
      return [];
    }
    return [];
  }
  if (value is List) {
    return value.whereType<String>().toList();
  }
  return [];
}

DateTime _dateTimeFromJson(dynamic value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  return DateTime.now();
}

/// 歌单列表响应
class PlaylistListResponse {
  final List<Playlist> playlists;
  final int total;

  const PlaylistListResponse({required this.playlists, required this.total});

  factory PlaylistListResponse.fromJson(Map<String, dynamic> json) {
    final playlistsList =
        (json['playlists'] as List<dynamic>?)
            ?.map((e) => Playlist.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    final total = _intFromJson(json['total']);
    return PlaylistListResponse(
      playlists: playlistsList,
      total: total == 0 ? playlistsList.length : total,
    );
  }
}
