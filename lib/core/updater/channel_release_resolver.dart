import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../config/app_config.dart';
import '../network/github_proxy_fallback.dart';

/// 解析「本渠道最新 Release」的补丁资产下载地址（无基线模型）。
///
/// - **dev**：滚动 tag `dev` 固定,直接拼 `releases/download/dev/<name>`。
/// - **stable**：查 GitHub `/releases/latest`（dev 是 prerelease,latest 天然返回最新
///   正式版）拿其资产,按文件名取 `browser_download_url`。
///
/// 渠道由编译期 [AppConfig.frontendVersion] 决定,仓库为 [AppConfig.frontendUpdateRepo]
/// （标准版和 Bundle 都为本仓库）。标准版前端 manifest（`manifest-<abi>.json`）、Bundle
/// 前端 manifest（`bundle-manifest-<abi>.json`）与后端 manifest
/// （`bundle-backend-manifest-<abi>.json`）都用它解析，保证「任意非最新 → 最新」。
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
  ///
  /// 缓存的是 **Future 而不是结果**:前后端两个 checkPatch 是在同一个 `Future.wait`
  /// 里并发起跑的,若按「判空 → await → 回填」写,两者都会在回填之前读到 null,于是
  /// 各打一次 /releases/latest —— 共用 resolver 的意义就没了,GitHub 未认证 API 的
  /// 60 次/小时额度也双倍消耗。记忆化 Future 让第二个调用方直接搭上第一次请求。
  Future<Map<String, String>?>? _stableAssetsFuture;

  /// 解析某资产（如 `bundle-manifest-arm64-v8a.json`）在本渠道最新 Release 的下载 URL
  /// （未套代理）。找不到返回 null。[githubProxy] 用于给 stable 的 API 请求套代理。
  Future<String?> assetUrl(String assetName, {String? githubProxy}) async {
    if (_isDev) {
      return 'https://github.com/${AppConfig.frontendUpdateRepo}'
          '/releases/download/dev/$assetName';
    }
    final assets = await _stableAssetMap(githubProxy);
    return assets?[assetName];
  }

  Future<Map<String, String>?> _stableAssetMap(String? githubProxy) {
    final f = _stableAssetsFuture ??= _fetchStableAssetMap(githubProxy);
    // 失败（null）不长期缓存：代理+直连都挂时清掉记忆,让下一次检查有机会重查。
    f.then((v) {
      if (v == null && identical(_stableAssetsFuture, f)) {
        _stableAssetsFuture = null;
      }
    });
    return f;
  }

  Future<Map<String, String>?> _fetchStableAssetMap(String? githubProxy) async {
    try {
      const rawApi =
          'https://api.github.com/repos/${AppConfig.frontendUpdateRepo}/releases/latest';
      // /releases/latest 是滚动内容,击穿代理缓存(见 withCacheBuster)。
      final resp = await githubGetWithProxyFallback<dynamic>(
        _dio,
        withCacheBuster(rawApi),
        proxy: githubProxy,
      );
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
      return map;
    } catch (e) {
      debugPrint('[ChannelResolver] 解析 latest release 失败: $e');
      return null;
    }
  }
}
