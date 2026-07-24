import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../config/app_config.dart';
import 'patch_update_service.dart' show PatchUpdateService;

/// 解析「本渠道最新 Release」的补丁资产下载地址（无基线模型）。
///
/// - **dev**：滚动 tag `dev` 固定,直接拼 `releases/download/dev/<name>`。
/// - **stable**：查 GitHub `/releases/latest`（dev 是 prerelease,latest 天然返回最新
///   正式版）拿其资产,按文件名取 `browser_download_url`。
///
/// 渠道由编译期 [AppConfig.frontendVersion] 决定,仓库为 [AppConfig.frontendUpdateRepo]
/// （bundle=父仓库）。前端补丁 manifest（`manifest-<abi>.json`）与后端补丁 manifest
/// （`backend-manifest-<abi>.json`）都用它解析,保证「任意非最新 → 最新」。
class ChannelReleaseResolver {
  ChannelReleaseResolver({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
              headers: {'Accept': 'application/vnd.github.v3+json'},
            ),
          );

  final Dio _dio;

  bool get _isDev => AppConfig.frontendVersion == 'dev';

  /// stable latest release 的资产名→下载地址缓存（单会话内一次检查里复用,避免前后端
  /// 各查一次 /releases/latest）。
  Map<String, String>? _stableAssets;

  /// 解析某资产（如 `manifest-arm64-v8a.json`）在本渠道最新 Release 的下载 URL（未套
  /// 代理）。找不到返回 null。[githubProxy] 用于给 stable 的 API 请求套代理。
  Future<String?> assetUrl(String assetName, {String? githubProxy}) async {
    if (_isDev) {
      return 'https://github.com/${AppConfig.frontendUpdateRepo}'
          '/releases/download/dev/$assetName';
    }
    final assets = await _stableAssetMap(githubProxy);
    return assets?[assetName];
  }

  Future<Map<String, String>?> _stableAssetMap(String? githubProxy) async {
    if (_stableAssets != null) return _stableAssets;
    try {
      const rawApi =
          'https://api.github.com/repos/${AppConfig.frontendUpdateRepo}/releases/latest';
      final url = PatchUpdateService.applyProxy(rawApi, githubProxy);
      final resp = await _dio.get<dynamic>(url);
      final data = resp.data;
      if (data is! Map) return null;
      final assets = data['assets'];
      if (assets is! List) return null;
      final map = <String, String>{};
      for (final a in assets) {
        if (a is Map) {
          final name = a['name'] as String?;
          final dl = a['browser_download_url'] as String?;
          if (name != null && dl != null && dl.isNotEmpty) map[name] = dl;
        }
      }
      _stableAssets = map;
      return map;
    } catch (e) {
      debugPrint('[ChannelResolver] 解析 latest release 失败: $e');
      return null;
    }
  }
}
