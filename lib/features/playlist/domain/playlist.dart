import 'dart:convert';

/// 歌单实体模型
class Playlist {
  final int id;
  final String type; // 'normal' 或 'radio'
  final String name;
  final String? description;
  final String? coverUrl; // 封面URL（后端统一处理）
  final List<String> labels; // ["built_in"] 或 ["auto_created"]
  final String sortBy; // 视图排序字段
  final String sortOrder; // 视图排序方向
  final int songCount;
  final DateTime? pinnedAt; // 置顶时间，null 表示未置顶
  final DateTime createdAt;
  final DateTime updatedAt;

  const Playlist({
    required this.id,
    required this.type,
    required this.name,
    this.description,
    this.coverUrl,
    this.labels = const [],
    this.sortBy = 'position',
    this.sortOrder = 'asc',
    this.songCount = 0,
    this.pinnedAt,
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
      sortBy: json['sort_by'] as String? ?? 'position',
      sortOrder: json['sort_order'] as String? ?? 'asc',
      songCount: _intFromJson(json['song_count']),
      pinnedAt: _nullableDateTimeFromJson(json['pinned_at']),
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
      'sort_by': sortBy,
      'sort_order': sortOrder,
      'song_count': songCount,
      'pinned_at': pinnedAt?.toIso8601String(),
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
    String? sortBy,
    String? sortOrder,
    int? songCount,
    DateTime? pinnedAt,
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
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
      songCount: songCount ?? this.songCount,
      pinnedAt: pinnedAt ?? this.pinnedAt,
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

  /// 是否已置顶
  bool get isPinned => pinnedAt != null;

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

/// 与 [_dateTimeFromJson] 不同，缺失/为空时返回 null 而非兜底 `DateTime.now()`——
/// pinned_at 语义是"未置顶"，不能被误兜底成"刚刚置顶"。
DateTime? _nullableDateTimeFromJson(dynamic value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
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
