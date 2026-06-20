import 'package:dio/dio.dart';

import '../../../config/app_config.dart';

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
  static const String _apiUrl =
      'https://api.github.com/repos/${AppConfig.frontendRepo}/releases/latest';

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
      final url = _applyProxy(_apiUrl, githubProxy);
      final response = await _dio.get(url);
      final data = response.data as Map<String, dynamic>;

      // 解析 tag_name，去掉 v 前缀
      final tagName = data['tag_name'] as String? ?? '';
      final latestVersion = _normalizeVersion(tagName);
      const currentVersion = AppConfig.frontendVersion;

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

      // 判断是否有更新
      final hasUpdate = _isNewerVersion(currentVersion, latestVersion);

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
      throw Exception('检查前端更新失败: ${e.message}');
    } catch (e) {
      throw Exception('检查前端更新失败: $e');
    }
  }

  /// 对 URL 拼接代理前缀
  static String _applyProxy(String rawUrl, String? proxyPrefix) {
    if (proxyPrefix == null || proxyPrefix.isEmpty) return rawUrl;
    final prefix =
        proxyPrefix.endsWith('/') ? proxyPrefix : '$proxyPrefix/';
    return '$prefix$rawUrl';
  }

  /// 对外暴露的代理拼接方法，供 UI 层使用
  static String applyProxy(String rawUrl, String? proxyPrefix) {
    return _applyProxy(rawUrl, proxyPrefix);
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

  /// 判断远程版本是否比当前版本更新
  /// 当前版本为 'dev' 时始终认为有更新（本地开发环境）
  static bool _isNewerVersion(String current, String latest) {
    if (current == 'dev') return true;
    if (latest.isEmpty) return false;

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
