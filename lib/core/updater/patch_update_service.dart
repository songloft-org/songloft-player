import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_patcher/flutter_patcher.dart';

import '../../config/app_config.dart';
import '../utils/platform_utils.dart';
import 'channel_release_resolver.dart';
import 'version_compare.dart';

/// 自托管 Android 热更新（flutter_patcher，换 `libapp.so`）的防御式封装。
///
/// 设计（见 docs/cn/backend_hotupdate.md 的「无基线」模型）：
/// - **无基线**：客户端查**本渠道最新** Release（dev→滚动 tag `dev`；stable→
///   `/releases/latest`），由 [ChannelReleaseResolver] 解析,任意非最新 → 最新。
/// - **兼容键取代 versionCode**：libapp.so（Dart AOT）真正绑定的是 **Flutter 引擎版本**,
///   用编译期 [AppConfig.flutterBinding] 与 manifest 的 `flutterBinding` 比对;相同即兼容,
///   返回的 [PatchInfo] `targetVersionCode` 置 **null** 让 flutter_patcher 绑定到当前设备
///   versionCode（不再跨 versionCode 被丢弃）;不同 → 不热更（交整包分支引导下 APK）。
/// - 比较：dev 比 git commit hash;stable 比版本号（[isRemoteNewer]）。已应用同补丁
///   （`currentVersion == patchLabel`）跳过。
/// - **代理**：抓 manifest 与下载 patch 都套用户所选代理前缀。仅 Android;其余平台
///   [isSupported] 为 false,所有方法安全 no-op。
class PatchUpdateService {
  PatchUpdateService({Dio? dio, ChannelReleaseResolver? resolver})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ),
          ),
      _resolver = resolver ?? ChannelReleaseResolver();

  final Dio _dio;
  final ChannelReleaseResolver _resolver;

  /// 当前平台是否支持热更新（仅 Android)。
  bool get isSupported => PlatformUtils.isAndroid;

  /// 给 GitHub URL 套代理前缀（空则直连）。规则同 `frontend_version_api._applyProxy`。
  static String applyProxy(String rawUrl, String? proxy) {
    if (proxy == null || proxy.isEmpty) return rawUrl;
    final prefix = proxy.endsWith('/') ? proxy : '$proxy/';
    return '$prefix$rawUrl';
  }

  /// 检查本渠道最新是否有可热更、且引擎兼容的前端补丁。
  ///
  /// [githubProxy] 抓取用代理前缀（可空）。返回的 [PatchInfo] 的 `patchUrl` 为**原始
  /// 绝对地址**,下载前由调用方按用户当时所选代理套上,以便对话框里改代理即时生效;
  /// `targetVersionCode` 为 null（绑定当前设备）。无更新 / 不兼容 / 不支持 / 出错 → null。
  Future<PatchInfo?> checkPatch({String? githubProxy}) async {
    if (!isSupported) return null;
    try {
      final abi = await FlutterPatcher.deviceAbi;
      if (abi.isEmpty) return null;
      final rawUrl = await _resolver.assetUrl(
        'manifest-$abi.json',
        githubProxy: githubProxy,
      );
      if (rawUrl == null) return null;

      final resp = await _dio.get<dynamic>(applyProxy(rawUrl, githubProxy));
      final map = _asMap(resp.data);
      if (map == null) return null;
      if (map['hasUpdate'] != true && map['has_update'] != true) return null;

      final p = map['patch'];
      final patch = p is Map ? Map<String, dynamic>.from(p) : map;
      final patchLabel = (patch['version'] ?? '') as String;
      final patchUrl =
          (patch['patchUrl'] ?? patch['patch_url'] ?? '') as String;
      if (patchLabel.isEmpty || patchUrl.isEmpty) return null;
      final md5 = (patch['md5'] ?? '') as String;
      final gitCommit =
          (patch['gitCommit'] ?? patch['git_commit'] ?? '') as String;
      final manifestBinding =
          (patch['flutterBinding'] ?? patch['flutter_binding'] ?? '') as String;
      final hasSemver = patch.containsKey('semanticVersion') ||
          patch.containsKey('semantic_version');
      final semanticVersion =
          (patch['semanticVersion'] ?? patch['semantic_version'] ?? patchLabel)
              as String;
      final rawVc = patch['targetVersionCode'] ?? patch['target_version_code'];
      final int? manifestVc = rawVc is num
          ? rawVc.toInt()
          : (rawVc is String && rawVc.isNotEmpty ? int.tryParse(rawVc) : null);

      // versionCode 兼容闸:libapp.so 与宿主 APK 的 versionCode 必须一致(flutter_patcher
      // 冷启会丢弃不匹配的补丁)。本项目 versionCode 恒定(pubspec +N 不随构建 bump),故此
      // 闸通常恒真,任意非最新 → 最新都能过;仅当有意 bump 了 versionCode 时才拦(→整包)。
      // versionCode 取自各自构建,非手工挑基线。
      final deviceVc = await FlutterPatcher.appVersionCode;
      if (manifestVc != null && deviceVc != null && manifestVc != deviceVc) {
        return null;
      }

      // 引擎兼容闸:两端都给出 flutterBinding 且不同 → 不兼容(防同 versionCode 但 Flutter
      // 引擎不同导致加载崩溃)→ 交整包分支引导下 APK。
      const appBinding = AppConfig.flutterBinding;
      if (appBinding.isNotEmpty &&
          manifestBinding.isNotEmpty &&
          appBinding != manifestBinding) {
        return null;
      }

      // 分渠道比较是否更新（仅当 manifest 带比较数据时;老式 manifest 无这些字段则
      // 退回「hasUpdate + 已应用守卫」旧行为,不做版本比较,兼容标准版旧发布）。
      if (gitCommit.isNotEmpty || hasSemver) {
        const isDev = AppConfig.frontendVersion == 'dev';
        final newer = isRemoteNewer(
          isDev: isDev,
          localVersion: AppConfig.frontendVersion,
          remoteVersion: semanticVersion,
          localGitCommit: AppConfig.frontendGitCommit,
          remoteGitCommit: gitCommit,
          localBuildTime: parseBuildTime(AppConfig.frontendBuildTime),
          remoteBuildTime: null,
        );
        if (!newer) return null;
      }

      // 已应用过同一补丁（currentVersion == patchLabel）→ 不再重复提示。
      final current = await FlutterPatcher.currentVersion;
      if (current != null && current.isNotEmpty && current == patchLabel) {
        return null;
      }

      // 保留 manifest 的 targetVersionCode（= 构建时的 versionCode），flutter_patcher 按其
      // 绑定;上面已确保它与当前设备一致。
      return PatchInfo(
        version: patchLabel,
        patchUrl: patchUrl,
        md5: md5,
        targetVersionCode: manifestVc,
      );
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

  static Map<String, dynamic>? _asMap(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String && data.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return null;
  }
}
