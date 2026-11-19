import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_patcher/flutter_patcher.dart';

import '../../config/app_config.dart';
import '../backend/native_contract_service.dart';
import '../network/github_proxy_fallback.dart';
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
///   返回的 [PatchInfo] 保留 manifest 的 `targetVersionCode`（CI 用 aapt 从分 ABI APK 读的
///   **真实值**——`--split-per-abi` 下 gradle 会改写为「ABI偏移×1000+pubspec基础值」,
///   pubspec `+N` 恒定时同 ABI 的新旧构建值相同,已校验其与当前设备一致,故等价于绑定
///   当前设备）;不同 → 不热更（交整包分支引导下 APK）。
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
  ///
  /// 静态形式,供不想只为读一个平台判定就构造整个 service（会白建一个 Dio）的调用方
  /// 使用 —— 典型是设置页决定要不要走热更检查那一跳。
  static bool get isPlatformSupported => PlatformUtils.isAndroid;

  /// 当前平台是否支持热更新（仅 Android)。
  bool get isSupported => isPlatformSupported;

  /// 给 GitHub URL 套代理前缀（空则直连）。委托共享实现 [applyGithubProxy]。
  static String applyProxy(String rawUrl, String? proxy) =>
      applyGithubProxy(rawUrl, proxy);

  /// 检查本渠道最新是否有可热更、且引擎兼容的前端补丁。
  ///
  /// [githubProxy] 抓取用代理前缀（可空）。返回的 [PatchInfo] 的 `patchUrl` 为**原始
  /// 绝对地址**,下载前由调用方按用户当时所选代理套上,以便对话框里改代理即时生效;
  /// `targetVersionCode` 取自 manifest（已校验与当前设备一致）。无更新 / 不兼容 / 不支持 / 出错 → null。
  Future<PatchInfo?> checkPatch({String? githubProxy}) async {
    if (!isSupported) return null;
    try {
      final abi = await FlutterPatcher.deviceAbi;
      if (abi.isEmpty) return null;
      final manifestName =
          '${AppConfig.hasEmbeddedBackend ? 'bundle-manifest' : 'manifest'}-$abi.json';
      final rawUrl = await _resolver.assetUrl(
        manifestName,
        githubProxy: githubProxy,
      );
      if (rawUrl == null) {
        debugPrint('[Patcher] checkPatch: 渠道 release 无 $manifestName,跳过');
        return null;
      }

      // manifest 是滚动内容,必须击穿代理缓存:陈旧 manifest 的 md5 对不上滚动更新后的
      // 补丁包,是线上 md5Mismatch 的根因。
      final manifestUrl = withCacheBuster(rawUrl);
      debugPrint(
        '[Patcher] checkPatch: 拉取 manifest ${applyProxy(manifestUrl, githubProxy)}',
      );
      final resp = await githubGetWithProxyFallback<dynamic>(
        _dio,
        manifestUrl,
        proxy: githubProxy,
      );
      final map = _asMap(resp.data);
      if (map == null) {
        debugPrint('[Patcher] checkPatch: manifest 解析失败,跳过');
        return null;
      }
      if (map['hasUpdate'] != true && map['has_update'] != true) {
        debugPrint('[Patcher] checkPatch: manifest hasUpdate=false,跳过');
        return null;
      }

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
      final manifestContractHash =
          (patch['contractHash'] ?? patch['contract_hash'] ?? '') as String;
      final hasSemver =
          patch.containsKey('semanticVersion') ||
          patch.containsKey('semantic_version');
      final semanticVersion =
          (patch['semanticVersion'] ?? patch['semantic_version'] ?? patchLabel)
              as String;
      final rawVc = patch['targetVersionCode'] ?? patch['target_version_code'];
      final int? manifestVc =
          rawVc is num
              ? rawVc.toInt()
              : (rawVc is String && rawVc.isNotEmpty
                  ? int.tryParse(rawVc)
                  : null);

      // versionCode 兼容闸:libapp.so 与宿主 APK 的 versionCode 必须一致(flutter_patcher
      // 冷启会丢弃不匹配的补丁)。--split-per-abi 下 gradle 把各 ABI APK 的 versionCode
      // 改写为「ABI偏移×1000+pubspec基础值」(如 arm64-v8a=2001),manifest 由 CI 用 aapt
      // 读分 ABI APK 的真实值;pubspec +N 恒定时同 ABI 新旧构建同值,此闸恒真,任意非
      // 最新 → 最新都能过;仅当有意 bump 了 pubspec +N 时才拦(→整包)。
      final deviceVc = await FlutterPatcher.appVersionCode;
      if (manifestVc != null && deviceVc != null && manifestVc != deviceVc) {
        debugPrint(
          '[Patcher] checkPatch: versionCode 不匹配(manifest=$manifestVc, '
          'device=$deviceVc),不热更 → 整包',
        );
        return null;
      }

      // 引擎兼容闸:两端都给出 flutterBinding 且不同 → 不兼容(防同 versionCode 但 Flutter
      // 引擎不同导致加载崩溃)→ 交整包分支引导下 APK。
      const appBinding = AppConfig.flutterBinding;
      if (appBinding.isNotEmpty &&
          manifestBinding.isNotEmpty &&
          appBinding != manifestBinding) {
        debugPrint(
          '[Patcher] checkPatch: flutterBinding 不匹配(manifest=$manifestBinding, '
          'app=$appBinding),不热更 → 整包',
        );
        return null;
      }

      // 原生契约哈希闸:热更换 libapp.so(全部 Dart),但 Kotlin 插件/自定义 channel 随旧
      // APK 冻结。若补丁的 Dart 调用了旧原生层没有的 MethodChannel 方法 → 运行时崩。
      // 设备侧哈希取自不被热更的 Kotlin(com.songloft/contract),与 manifest 的 dart 哈希
      // 比对,不等即不热更 → 整包。两端任一为空(老宿主/本地开发/老式 manifest)→ 视为
      // 未知,不拦截(降级),同 flutterBinding 闸。见 docs/cn/backend_hotupdate.md。
      final deviceContractHash = await NativeContractService.dartHash();
      if (contractHashBlocks(manifestContractHash, deviceContractHash)) {
        debugPrint(
          '[Patcher] checkPatch: 原生契约哈希不匹配(manifest=$manifestContractHash, '
          'device=$deviceContractHash),不热更 → 整包',
        );
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
        if (!newer) {
          debugPrint(
            '[Patcher] checkPatch: 已是最新(local=${AppConfig.frontendGitCommit}/'
            '${AppConfig.frontendVersion}, remote=$gitCommit/$semanticVersion)',
          );
          return null;
        }
      }

      // 已应用过同一补丁（currentVersion == patchLabel）→ 不再重复提示。
      final current = await FlutterPatcher.currentVersion;
      if (current != null && current.isNotEmpty && current == patchLabel) {
        debugPrint('[Patcher] checkPatch: 补丁 $patchLabel 已应用,跳过');
        return null;
      }

      debugPrint('[Patcher] checkPatch: 发现可热更补丁 $patchLabel');

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
  ///
  /// 约定传入的 [patch] 的 `patchUrl` 为**原始地址**；[githubProxy] 非空时先经
  /// 代理下载，失败则降级为原始 URL 直连重试一次。仍失败时重拉一次 manifest
  /// （[checkPatch]）刷新 md5/patchUrl 再试——防手上的 [patch] 来自陈旧的代理缓存
  /// manifest,与滚动更新后的补丁包必然 md5Mismatch,重试多少次都没用。
  Future<bool> applyPatch(
    PatchInfo patch, {
    String? githubProxy,
    void Function(PatchApplyProgress)? onProgress,
    bool allowManifestRefresh = true,
  }) async {
    if (!isSupported) return false;
    final proxiedUrl = applyProxy(patch.patchUrl, githubProxy);
    var ok = await _applyPatchOnce(
      _withPatchUrl(patch, proxiedUrl),
      onProgress,
    );
    if (!ok && proxiedUrl != patch.patchUrl) {
      debugPrint('[Patcher] applyPatch 经代理失败,降级直连重试: 失败URL=$proxiedUrl');
      ok = await _applyPatchOnce(patch, onProgress);
    }
    if (ok || !allowManifestRefresh) return ok;

    final fresh = await checkPatch(githubProxy: githubProxy);
    if (fresh == null ||
        (fresh.md5 == patch.md5 && fresh.patchUrl == patch.patchUrl)) {
      return false;
    }
    debugPrint(
      '[Patcher] applyPatch 刷新 manifest 后重试: '
      '${patch.version} -> ${fresh.version}',
    );
    return applyPatch(
      fresh,
      githubProxy: githubProxy,
      onProgress: onProgress,
      allowManifestRefresh: false,
    );
  }

  Future<bool> _applyPatchOnce(
    PatchInfo patch,
    void Function(PatchApplyProgress)? onProgress,
  ) async {
    try {
      final result = await FlutterPatcher.applyPatch(
        patch,
        onProgress: onProgress,
      );
      if (!result.ok) {
        debugPrint(
          '[Patcher] applyPatch 失败: ${result.error} '
          '(url=${patch.patchUrl})',
        );
      }
      return result.ok;
    } catch (e) {
      debugPrint('[Patcher] applyPatch 异常: $e (url=${patch.patchUrl})');
      return false;
    }
  }

  static PatchInfo _withPatchUrl(PatchInfo patch, String url) => PatchInfo(
    version: patch.version,
    patchUrl: url,
    md5: patch.md5,
    signature: patch.signature,
    targetVersionCode: patch.targetVersionCode,
    raw: patch.raw,
  );

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
