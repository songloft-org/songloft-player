import 'package:dio/dio.dart';

import '../../../config/app_config.dart';
import '../../../l10n/l10n_holder.dart';

/// 前端版本检查结果模型
class FrontendVersionCheck {
  /// 是否有更新
  final bool hasUpdate;

  /// 当前版本
  final String currentVersion;

  /// 最新版本
  final String latestVersion;

  /// 发布页面 URL
  final String releaseUrl;

  /// 更新说明
  final String? releaseNotes;

  /// 发布时间
  final DateTime? publishedAt;

  /// Release 资源列表（各平台安装包下载地址）
  final List<ReleaseAsset> assets;

  FrontendVersionCheck({
    required this.hasUpdate,
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseUrl,
    this.releaseNotes,
    this.publishedAt,
    this.assets = const [],
  });

  String get latestVersionDisplay =>
      latestVersion == 'dev' ? l10n.settingsFrontendVerDevVersion : 'v$latestVersion';

  @override
  String toString() =>
      'FrontendVersionCheck(hasUpdate: $hasUpdate, current: $currentVersion, latest: $latestVersion)';
}

/// GitHub Release 资源文件
class ReleaseAsset {
  final String name;
  final String downloadUrl;
  final int size;

  const ReleaseAsset({
    required this.name,
    required this.downloadUrl,
    required this.size,
  });
}

/// 前端版本检测 API
/// 通过 GitHub API 获取最新 Release 信息，与本地版本号对比
class FrontendVersionApi {
  final Dio _dio;

  /// GitHub API 地址
  static const String _latestReleaseApiUrl =
      'https://api.github.com/repos/${AppConfig.frontendRepo}/releases/latest';
  static const String _devReleaseApiUrl =
      'https://api.github.com/repos/${AppConfig.frontendRepo}/releases/tags/dev';

  /// 主仓库 dev 版本信息（包含 git_commit 和 build_time）
  static const String _devVersionJsonUrl =
      'https://github.com/songloft-org/songloft/releases/download/dev/version.json';

  FrontendVersionApi({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
              headers: {'Accept': 'application/vnd.github.v3+json'},
            ),
          );

  /// 检查前端是否有新版本
  /// [githubProxy] 可选的 GitHub 代理前缀（如 https://ghproxy.com/）
  Future<FrontendVersionCheck> checkUpdate({String? githubProxy}) async {
    try {
      const currentVersion = AppConfig.frontendVersion;
      const isDev = currentVersion == 'dev';
      const rawUrl = isDev ? _devReleaseApiUrl : _latestReleaseApiUrl;
      final url = _applyProxy(rawUrl, githubProxy);
      final response = await _dio.get(url);
      final data = response.data as Map<String, dynamic>;

      // 解析 tag_name，去掉 v 前缀
      final tagName = data['tag_name'] as String? ?? '';
      final latestVersion = _normalizeVersion(tagName);

      // 解析发布说明，将 gitmoji 短代码转换为 Unicode emoji
      final rawNotes = data['body'] as String?;
      final releaseNotes = rawNotes != null ? _convertGitmoji(rawNotes) : null;

      // 解析发布时间
      DateTime? publishedAt;
      final publishedAtStr = data['published_at'] as String?;
      if (publishedAtStr != null) {
        publishedAt = DateTime.tryParse(publishedAtStr);
      }

      // 发布页面 URL
      final releaseUrl =
          data['html_url'] as String? ?? AppConfig.frontendReleasesUrl;

      // 解析资源列表
      final assets = _parseAssets(data['assets']);

      // dev 版本：从主仓库 version.json 获取 git_commit 和 build_time 进行精确比较
      String? remoteGitCommit;
      DateTime? remoteBuildTime;
      if (isDev) {
        final versionInfo = await _fetchDevVersionInfo(githubProxy);
        if (versionInfo != null) {
          remoteGitCommit = versionInfo['git_commit'] as String?;
          final bt = versionInfo['build_time'] as String?;
          if (bt != null) {
            remoteBuildTime = _parseBuildTime(bt);
          }
        }
      }

      // 判断是否有更新
      // dev 版本仅使用 version.json 的精确 build_time，不回退到 published_at
      // （published_at 是 release 发布时间，总是远晚于实际构建时间，会导致误判）
      final hasUpdate = _isNewerVersion(
        currentVersion,
        latestVersion,
        latestBuildTime: remoteBuildTime,
        remoteGitCommit: remoteGitCommit,
      );

      return FrontendVersionCheck(
        hasUpdate: hasUpdate,
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        releaseUrl: releaseUrl,
        releaseNotes: releaseNotes,
        publishedAt: publishedAt,
        assets: assets,
      );
    } on DioException catch (e) {
      throw Exception(l10n.settingsFrontendVerCheckFailed(e.message ?? ''));
    } catch (e) {
      throw Exception(l10n.settingsFrontendVerCheckFailed(e.toString()));
    }
  }

  /// 对 URL 拼接代理前缀
  static String _applyProxy(String rawUrl, String? proxyPrefix) {
    if (proxyPrefix == null || proxyPrefix.isEmpty) return rawUrl;
    final prefix = proxyPrefix.endsWith('/') ? proxyPrefix : '$proxyPrefix/';
    return '$prefix$rawUrl';
  }

  /// 对外暴露的代理拼接方法，供 UI 层使用
  static String applyProxy(String rawUrl, String? proxyPrefix) {
    return _applyProxy(rawUrl, proxyPrefix);
  }

  /// 获取主仓库 dev release 的 version.json，用于 git_commit / build_time 精确比较。
  /// 失败时返回 null，调用方回退到 published_at 比较。
  Future<Map<String, dynamic>?> _fetchDevVersionInfo(String? githubProxy) async {
    try {
      final url = _applyProxy(_devVersionJsonUrl, githubProxy);
      final response = await _dio.get(url);
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
    } catch (_) {
      // version.json 不可达时静默回退
    }
    return null;
  }

  /// 解析 GitHub Release 的 assets 列表
  static List<ReleaseAsset> _parseAssets(dynamic assetsData) {
    if (assetsData is! List) return [];
    return assetsData
        .whereType<Map<String, dynamic>>()
        .map(
          (a) => ReleaseAsset(
            name: a['name'] as String? ?? '',
            downloadUrl: a['browser_download_url'] as String? ?? '',
            size: a['size'] as int? ?? 0,
          ),
        )
        .where((a) => a.downloadUrl.isNotEmpty)
        .toList();
  }

  /// 去掉版本号前缀 v/V
  static String _normalizeVersion(String version) {
    if (version.startsWith('v') || version.startsWith('V')) {
      return version.substring(1);
    }
    return version;
  }

  static DateTime? _parseBuildTime(String buildTime) {
    if (buildTime.isEmpty || buildTime == 'unknown') return null;
    return DateTime.tryParse(buildTime.replaceFirst('_', 'T'));
  }

  /// 判断远程版本是否比当前版本更新。
  /// dev 客户端优先比较 git commit，其次比较构建时间；正式版只比较版本号。
  static bool _isNewerVersion(
    String current,
    String latest, {
    DateTime? latestBuildTime,
    String? remoteGitCommit,
  }) {
    if (latest.isEmpty) return false;
    if (current == 'dev') {
      if (latest != 'dev') return false;
      // 优先比较 git commit
      if (remoteGitCommit != null &&
          remoteGitCommit.isNotEmpty &&
          AppConfig.frontendGitCommit != 'unknown') {
        return remoteGitCommit != AppConfig.frontendGitCommit;
      }
      // 回退到构建时间比较
      if (latestBuildTime == null) return false;
      final currentBuildTime = _parseBuildTime(AppConfig.frontendBuildTime);
      if (currentBuildTime == null) return false;
      // 同一次 CI 的 build_time 可能因不同 job 产生数分钟偏差，
      // 真正的新版本至少相隔数十分钟；10 分钟内视为同一次构建。
      final diff = latestBuildTime.difference(currentBuildTime);
      if (diff.inMinutes.abs() < 10) return false;
      return latestBuildTime.isAfter(currentBuildTime);
    }
    if (latest == 'dev') return false;

    // 简单的版本号比较（语义化版本）
    final currentParts =
        current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final latestParts =
        latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    // 补齐长度
    while (currentParts.length < 3) {
      currentParts.add(0);
    }
    while (latestParts.length < 3) {
      latestParts.add(0);
    }

    for (int i = 0; i < 3; i++) {
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }

    return false; // 版本相同
  }

  /// 将 gitmoji 短代码（如 :sparkles:）转换为 Unicode emoji
  static String _convertGitmoji(String text) {
    const gitmojiMap = <String, String>{
      ':sparkles:': '✨',
      ':bug:': '🐛',
      ':memo:': '📝',
      ':rocket:': '🚀',
      ':lipstick:': '💄',
      ':tada:': '🎉',
      ':white_check_mark:': '✅',
      ':lock:': '🔒',
      ':bookmark:': '🔖',
      ':rotating_light:': '🚨',
      ':construction:': '🚧',
      ':green_heart:': '💚',
      ':arrow_down:': '⬇️',
      ':arrow_up:': '⬆️',
      ':pushpin:': '📌',
      ':construction_worker:': '👷',
      ':chart_with_upwards_trend:': '📈',
      ':recycle:': '♻️',
      ':heavy_plus_sign:': '➕',
      ':heavy_minus_sign:': '➖',
      ':wrench:': '🔧',
      ':hammer:': '🔨',
      ':globe_with_meridians:': '🌐',
      ':pencil2:': '✏️',
      ':poop:': '💩',
      ':rewind:': '⏪',
      ':twisted_rightwards_arrows:': '🔀',
      ':package:': '📦',
      ':alien:': '👽',
      ':truck:': '🚚',
      ':page_facing_up:': '📄',
      ':boom:': '💥',
      ':bento:': '🍱',
      ':wheelchair:': '♿',
      ':bulb:': '💡',
      ':beers:': '🍻',
      ':speech_balloon:': '💬',
      ':card_file_box:': '🗃️',
      ':loud_sound:': '🔊',
      ':mute:': '🔇',
      ':busts_in_silhouette:': '👥',
      ':children_crossing:': '🚸',
      ':building_construction:': '🏗️',
      ':iphone:': '📱',
      ':clown_face:': '🤡',
      ':egg:': '🥚',
      ':see_no_evil:': '🙈',
      ':camera_flash:': '📸',
      ':alembic:': '⚗️',
      ':mag:': '🔍',
      ':label:': '🏷️',
      ':seedling:': '🌱',
      ':triangular_flag_on_post:': '🚩',
      ':goal_net:': '🥅',
      ':dizzy:': '💫',
      ':wastebasket:': '🗑️',
      ':passport_control:': '🛂',
      ':adhesive_bandage:': '🩹',
      ':monocle_face:': '🧐',
      ':coffin:': '⚰️',
      ':test_tube:': '🧪',
      ':necktie:': '👔',
      ':stethoscope:': '🩺',
      ':bricks:': '🧱',
      ':technologist:': '🧑‍💻',
      ':fire:': '🔥',
      ':art:': '🎨',
      ':zap:': '⚡',
      ':ambulance:': '🚑',
      ':pencil:': '📝',
      ':checkered_flag:': '🏁',
      ':hammer_and_wrench:': '🛠️',
    };

    var result = text;
    for (final entry in gitmojiMap.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    return result;
  }
}
