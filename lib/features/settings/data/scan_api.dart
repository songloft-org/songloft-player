import 'package:dio/dio.dart';

import '../../../config/app_config.dart';
import '../../../core/network/api_exceptions.dart';

/// 扫描进度模型
class ScanProgress {
  final String
  status; // 'idle', 'scanning', 'importing', 'splitting_cue', 'creating_playlists', 'completed', 'failed', 'cancelling', 'cancelled'
  final String? currentFile;
  final int discoveredFiles;
  final int totalFiles;
  final int scannedFiles;
  final int importedFiles;
  final int skippedFiles;
  final int failedFiles;
  final int cueSplitSources;
  final int localSongCount;

  ScanProgress({
    required this.status,
    this.currentFile,
    this.discoveredFiles = 0,
    required this.totalFiles,
    required this.scannedFiles,
    required this.importedFiles,
    required this.skippedFiles,
    required this.failedFiles,
    this.cueSplitSources = 0,
    this.localSongCount = 0,
  });

  factory ScanProgress.fromJson(Map<String, dynamic> json) {
    return ScanProgress(
      status: json['status'] as String? ?? 'idle',
      currentFile: json['current_file'] as String?,
      discoveredFiles: json['discovered_files'] as int? ?? 0,
      totalFiles: json['total_files'] as int? ?? 0,
      scannedFiles: json['scanned_files'] as int? ?? 0,
      importedFiles: json['imported_files'] as int? ?? 0,
      skippedFiles: json['skipped_files'] as int? ?? 0,
      failedFiles: json['failed_files'] as int? ?? 0,
      cueSplitSources: json['cue_split_sources'] as int? ?? 0,
      localSongCount: json['local_song_count'] as int? ?? 0,
    );
  }

  /// 默认空闲状态
  static ScanProgress get idle => ScanProgress(
    status: 'idle',
    totalFiles: 0,
    scannedFiles: 0,
    importedFiles: 0,
    skippedFiles: 0,
    failedFiles: 0,
  );

  /// 计算进度百分比 0-100
  int get progress => totalFiles > 0 ? (scannedFiles * 100 ~/ totalFiles) : 0;

  /// 是否正在扫描（包括 scanning、importing、splitting_cue、creating_playlists 阶段）
  bool get isScanning =>
      status == 'scanning' ||
      status == 'importing' ||
      status == 'splitting_cue' ||
      status == 'creating_playlists' ||
      status == 'cancelling';

  /// 是否处于自动创建歌单阶段
  bool get isCreatingPlaylists => status == 'creating_playlists';

  /// 是否处于 CUE 整轨切分阶段
  bool get isSplittingCue => status == 'splitting_cue';

  /// 是否完成
  bool get isCompleted => status == 'completed';

  /// 是否出错
  bool get isError => status == 'failed';

  /// 是否已取消
  bool get isCancelled => status == 'cancelled';

  /// 是否空闲
  bool get isIdle => status == 'idle';

  @override
  String toString() =>
      'ScanProgress(status: $status, progress: $progress%, scanned: $scannedFiles/$totalFiles)';
}

/// 扫描 API 服务
class ScanApi {
  final Dio dio;

  ScanApi({required this.dio});

  /// 开始扫描
  /// POST /api/v1/scan
  ///
  /// [paths] 为目录级定向扫描（Issue songloft-org/songloft#262）：为空/null 时扫描整个
  /// 音乐根目录（默认行为）；非空时只扫描给定目录（含子目录）。每个目录须位于音乐根目录之下。
  Future<void> startScan({bool reimport = false, List<String>? paths}) async {
    try {
      final data = <String, dynamic>{'reimport': reimport};
      if (paths != null && paths.isNotEmpty) {
        data['paths'] = paths;
      }
      await dio.post(
        '${AppConfig.apiPrefix}/scan',
        data: data,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 获取扫描进度
  /// GET /api/v1/scan/progress
  Future<ScanProgress> getProgress() async {
    try {
      final response = await dio.get('${AppConfig.apiPrefix}/scan/progress');
      return ScanProgress.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 取消扫描
  /// POST /api/v1/scan/cancel
  Future<void> cancelScan() async {
    try {
      await dio.post('${AppConfig.apiPrefix}/scan/cancel');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 获取指纹计算状态
  Future<FingerprintStatus> getFingerprintStatus() async {
    try {
      final response = await dio.get(
        '${AppConfig.apiPrefix}/scan/fingerprints/status',
      );
      return FingerprintStatus.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 触发批量指纹计算
  Future<void> startFingerprintCompute({bool recomputeAll = false}) async {
    try {
      await dio.post(
        '${AppConfig.apiPrefix}/scan/fingerprints',
        data: recomputeAll ? {'recompute_all': true} : null,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 获取指纹计算进度
  Future<FingerprintProgress> getFingerprintProgress() async {
    try {
      final response = await dio.get(
        '${AppConfig.apiPrefix}/scan/fingerprints/progress',
      );
      return FingerprintProgress.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 获取重复歌曲组
  Future<DuplicatesResult> getDuplicates() async {
    try {
      final response = await dio.get(
        '${AppConfig.apiPrefix}/songs/duplicates',
      );
      return DuplicatesResult.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

/// 指纹状态
class FingerprintStatus {
  final bool chromaprintAvailable;
  final int total;
  final int computed;
  final int missing;

  FingerprintStatus({
    required this.chromaprintAvailable,
    required this.total,
    required this.computed,
    required this.missing,
  });

  factory FingerprintStatus.fromJson(Map<String, dynamic> json) {
    return FingerprintStatus(
      chromaprintAvailable: json['chromaprint_available'] as bool? ?? false,
      total: json['total'] as int? ?? 0,
      computed: json['computed'] as int? ?? 0,
      missing: json['missing'] as int? ?? 0,
    );
  }
}

/// 指纹计算进度
class FingerprintProgress {
  final String status; // idle, running, done
  final int computed;
  final int total;
  final int failed;

  FingerprintProgress({
    required this.status,
    required this.computed,
    required this.total,
    required this.failed,
  });

  factory FingerprintProgress.fromJson(Map<String, dynamic> json) {
    return FingerprintProgress(
      status: json['status'] as String? ?? 'idle',
      computed: json['computed'] as int? ?? 0,
      total: json['total'] as int? ?? 0,
      failed: json['failed'] as int? ?? 0,
    );
  }

  bool get isRunning => status == 'running';
  bool get isDone => status == 'done';
  bool get isIdle => status == 'idle';
  int get progress => total > 0 ? (computed * 100 ~/ total) : 0;
}

/// 重复歌曲
class DuplicateSong {
  final int id;
  final String title;
  final String artist;
  final String album;
  final double duration;
  final String filePath;
  final String format;
  final int bitRate;
  final int fileSize;
  final String coverUrl;
  final String addedAt;

  DuplicateSong({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.filePath,
    required this.format,
    required this.bitRate,
    required this.fileSize,
    required this.coverUrl,
    required this.addedAt,
  });

  factory DuplicateSong.fromJson(Map<String, dynamic> json) {
    return DuplicateSong(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      artist: json['artist'] as String? ?? '',
      album: json['album'] as String? ?? '',
      duration: (json['duration'] as num?)?.toDouble() ?? 0,
      filePath: json['file_path'] as String? ?? '',
      format: json['format'] as String? ?? '',
      bitRate: json['bit_rate'] as int? ?? 0,
      fileSize: json['file_size'] as int? ?? 0,
      coverUrl: json['cover_url'] as String? ?? '',
      addedAt: json['added_at'] as String? ?? '',
    );
  }

  String get fileSizeDisplay {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// 重复组
class DuplicateGroup {
  final String fingerprint;
  final List<DuplicateSong> songs;

  DuplicateGroup({required this.fingerprint, required this.songs});

  factory DuplicateGroup.fromJson(Map<String, dynamic> json) {
    return DuplicateGroup(
      fingerprint: json['fingerprint'] as String? ?? '',
      songs: (json['songs'] as List<dynamic>?)
              ?.map((e) => DuplicateSong.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// 重复检测结果
class DuplicatesResult {
  final List<DuplicateGroup> groups;
  final int totalGroups;
  final int totalDuplicates;

  DuplicatesResult({
    required this.groups,
    required this.totalGroups,
    required this.totalDuplicates,
  });

  factory DuplicatesResult.fromJson(Map<String, dynamic> json) {
    return DuplicatesResult(
      groups: (json['groups'] as List<dynamic>?)
              ?.map((e) => DuplicateGroup.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalGroups: json['total_groups'] as int? ?? 0,
      totalDuplicates: json['total_duplicates'] as int? ?? 0,
    );
  }
}
