import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_patcher/flutter_patcher.dart';

import '../../config/app_config.dart';
import '../utils/platform_utils.dart';

/// 自托管 Android 热更新（flutter_patcher）的防御式封装。
///
/// 设计（见 docs/cn/flutter_patcher_hotupdate.md）：
/// - 补丁托管在 GitHub Release,路径按**当前构建渠道**取:
///   - stable（`FRONTEND_VERSION=x.y.z`）→ tag `vx.y.z`
///   - dev（`FRONTEND_VERSION=dev`）→ 滚动 tag `dev`
///   渠道由编译期 [AppConfig.frontendVersion] 决定,dev 只查 dev、stable 只查 stable,
///   **不跨渠道**。
/// - manifest（`manifest-<abi>.json`,PatchCheckResult 形状,含绝对 patchUrl）与
///   patch 包（`patch-<abi>.zip`）都在同一 Release。
/// - **手动构造 PatchInfo 以支持 GitHub 代理**:抓 manifest 与下载 patch 都套用户
///   选择的代理前缀（拼接同 frontend_version_api）。
/// - 仅 Android 生效;其余平台 [isSupported] 为 false,所有方法安全 no-op。
class PatchUpdateService {
  PatchUpdateService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ),
          );

  final Dio _dio;

  /// 当前平台是否支持热更新（仅 Android)。
  bool get isSupported => PlatformUtils.isAndroid;

  /// 给 GitHub URL 套代理前缀（空则直连）。规则同 `frontend_version_api._applyProxy`。
  static String applyProxy(String rawUrl, String? proxy) {
    if (proxy == null || proxy.isEmpty) return rawUrl;
    final prefix = proxy.endsWith('/') ? proxy : '$proxy/';
    return '$prefix$rawUrl';
  }

  /// 当前构建渠道对应的 Release tag:dev → `dev`;stable → `v<version>`。
  static String _releaseTag(String version) =>
      version == 'dev' ? 'dev' : 'v$version';

  /// `manifest-<abi>.json` 的原始（未套代理）URL。
  static String manifestUrl(String version, String abi) {
    final tag = _releaseTag(version);
    return 'https://github.com/${AppConfig.frontendUpdateRepo}'
        '/releases/download/$tag/manifest-$abi.json';
  }

  /// 检查是否有匹配当前 versionCode 的补丁。
  ///
  /// [githubProxy] 用于抓取 manifest 的代理前缀（可空=直连）。返回的 [PatchInfo]
  /// 的 `patchUrl` 为**原始绝对 GitHub 地址（未套代理）** —— 下载前由调用方按用户
  /// 当时所选代理用 [applyProxy] 套上,以便对话框里改代理即时生效。无更新 / 不支持 /
  /// 出错 → null。
  Future<PatchInfo?> checkPatch({String? githubProxy}) async {
    if (!isSupported) return null;
    const version = AppConfig.frontendVersion;
    if (version.isEmpty) return null;
    try {
      final abi = await FlutterPatcher.deviceAbi;
      final url = applyProxy(manifestUrl(version, abi), githubProxy);
      final resp = await _dio.get<dynamic>(url);
      final data = resp.data;
      final Map<String, dynamic>? map = data is Map
          ? Map<String, dynamic>.from(data)
          : data is String && data.trim().isNotEmpty
          ? Map<String, dynamic>.from(jsonDecode(data) as Map)
          : null;
      if (map == null) return null;

      final result = PatchCheckResult.fromJson(map);
      final patch = result.patch;
      if (!result.hasUpdate || patch == null) return null;

      // 原样返回（patchUrl 为绝对 GitHub 地址,未套代理,由调用方下载前再套）。
      return patch;
    } catch (e) {
      debugPrint('[Patcher] checkPatch 失败: $e');
      return null;
    }
  }

  /// 下载并安装补丁（阻塞到完成)。成功返回 true,冷启动生效。
  Future<bool> applyPatch(
    PatchInfo patch, {
    void Function(PatchApplyProgress)? onProgress,
  }) async {
    if (!isSupported) return false;
    try {
      final result = await FlutterPatcher.applyPatch(
        patch,
        onProgress: onProgress,
      );
      if (!result.ok) {
        debugPrint('[Patcher] applyPatch 失败: ${result.error}');
      }
      return result.ok;
    } catch (e) {
      debugPrint('[Patcher] applyPatch 异常: $e');
      return false;
    }
  }
}
