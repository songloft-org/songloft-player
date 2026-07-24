import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_patcher/flutter_patcher.dart' show FlutterPatcher;
import 'package:path_provider/path_provider.dart';

import '../../config/app_config.dart';
import '../backend/embedded_backend_service.dart';
import '../utils/platform_utils.dart';
import 'channel_release_resolver.dart';
import 'patch_update_service.dart' show PatchUpdateService;
import 'version_compare.dart';

/// Bundle 版 Android 后端热更（替换 `libgojni.so`）的补丁元数据。
///
/// 对应父仓库 Release 的 `backend-manifest-<abi>.json` 的 `backend` 字段。
class BackendPatchInfo {
  /// 展示 + 忽略键（如 `2.11.1-b1`）。
  final String patchLabel;

  /// 补丁 .so 通过 `GET /api/v1/version` 上报的语义版本（stable 比较用；dev 为 `dev`）。
  final String version;

  /// 补丁 .so 的 git commit（dev 比较主键）。
  final String gitCommit;

  /// 补丁 .so 的构建时间（dev 回退比较）。
  final String buildTime;

  /// 目标 ABI（arm64-v8a / armeabi-v7a）。
  final String abi;

  /// `libgojni-<abi>.so` 的原始（未套代理）下载地址。
  final String soUrl;

  /// .so 的 md5（小写 hex）。
  final String md5;

  /// .so 字节数（可选，展示用）。
  final int size;

  const BackendPatchInfo({
    required this.patchLabel,
    required this.version,
    required this.gitCommit,
    required this.buildTime,
    required this.abi,
    required this.soUrl,
    required this.md5,
    this.size = 0,
  });

  static BackendPatchInfo? fromManifest(Map<String, dynamic> json) {
    final b = json['backend'];
    if (b is! Map) return null;
    final m = Map<String, dynamic>.from(b);
    final soUrl = (m['soUrl'] ?? m['so_url'] ?? '') as String;
    if (soUrl.isEmpty) return null;
    final gitCommit = (m['gitCommit'] ?? m['git_commit'] ?? '') as String;
    return BackendPatchInfo(
      // 无独立 patchLabel 时用 version/gitCommit 兜底作展示 + 忽略键。
      patchLabel: (m['patchLabel'] ??
          m['patch_label'] ??
          m['version'] ??
          gitCommit ??
          '') as String,
      version: (m['version'] ?? m['baseVersion'] ?? m['base_version'] ?? '')
          as String,
      gitCommit: gitCommit,
      buildTime: (m['buildTime'] ?? m['build_time'] ?? '') as String,
      abi: (m['abi'] ?? '') as String,
      soUrl: soUrl,
      md5: (m['md5'] ?? '') as String,
      size: (m['size'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 运行中后端的版本信息（取自 `GET /api/v1/version`）。
class _RunningBackendVersion {
  final String version;
  final String gitCommit;
  final String buildTime;
  const _RunningBackendVersion(this.version, this.gitCommit, this.buildTime);
}

/// Bundle 版 Android 后端热更服务（换 `libgojni.so`）。
///
/// 设计见 docs/cn/backend_hotupdate.md：
/// - 仅在 Android 且 [AppConfig.hasEmbeddedBackend] 且本地模式后端运行时生效，其余
///   平台 [isSupported] 为 false、所有方法安全 no-op。
/// - 补丁托管在**父仓库** [AppConfig.frontendUpdateRepo] 的 Release，按渠道取 tag、
///   按 ABI 取 `backend-manifest-<abi>.json`。
/// - 「当前后端版本」运行期取自 `GET /api/v1/version`（不是编译期常量）。dev 比 git
///   commit、stable 比版本号。
/// - 下载 .so → md5 校验 → 交原生 `stageBackendPatch` 落地 → 冷重启进程后由自定义
///   Application 预加载。校验/回滚/黑名单由原生 `BackendPatchManager` 负责。
class BackendPatchService {
  BackendPatchService({
    required Dio appDio,
    Dio? githubDio,
    ChannelReleaseResolver? resolver,
  }) : _appDio = appDio,
       _githubDio =
           githubDio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(seconds: 30),
             ),
           ),
       _resolver = resolver ?? ChannelReleaseResolver();

  /// 用于访问本地后端 `/api/v1/version` 的 client（本地模式下 baseUrl 指向 127.0.0.1）。
  final Dio _appDio;

  /// 用于抓 manifest / 下载 .so 的 client。
  final Dio _githubDio;

  /// 本渠道最新 Release 解析（dev→dev tag；stable→/releases/latest）。
  final ChannelReleaseResolver _resolver;

  /// 仅 Android + 内嵌后端构建时支持。
  bool get isSupported =>
      PlatformUtils.isAndroid && AppConfig.hasEmbeddedBackend;

  /// 检查本渠道最新是否有匹配当前 ABI 的后端补丁（无 versionCode 绑定）。
  ///
  /// [githubProxy] 抓 manifest 的代理前缀（可空）。返回的 [BackendPatchInfo] 的
  /// `soUrl` 为原始地址，下载前由调用方按用户当时所选代理套上。无更新 / 不支持 /
  /// 出错 → null。兼容性由「导出面冻结（CI 守卫）+ 崩溃回滚」保证,不再按 versionCode 判定。
  Future<BackendPatchInfo?> checkPatch({String? githubProxy}) async {
    if (!isSupported) return null;
    try {
      // 后端未运行时无从比较，直接跳过（本地模式尚未启动等）。
      final running = await _fetchRunningVersion();
      if (running == null) return null;

      final abi = await FlutterPatcher.deviceAbi;
      if (abi.isEmpty) return null;

      final rawUrl = await _resolver.assetUrl(
        'backend-manifest-$abi.json',
        githubProxy: githubProxy,
      );
      if (rawUrl == null) return null;
      final resp = await _githubDio.get<dynamic>(
        PatchUpdateService.applyProxy(rawUrl, githubProxy),
      );
      final map = _asMap(resp.data);
      if (map == null) return null;
      if (map['hasUpdate'] != true && map['has_update'] != true) return null;

      final info = BackendPatchInfo.fromManifest(map);
      if (info == null) return null;

      // ABI 匹配（唯一硬前置；不再绑定 versionCode）。
      if (info.abi.isNotEmpty && info.abi != abi) return null;

      // 分渠道比较是否更新。
      const isDev = AppConfig.frontendVersion == 'dev';
      final newer = isRemoteNewer(
        isDev: isDev,
        localVersion: running.version,
        remoteVersion: info.version,
        localGitCommit: running.gitCommit,
        remoteGitCommit: info.gitCommit,
        localBuildTime: parseBuildTime(running.buildTime),
        remoteBuildTime: parseBuildTime(info.buildTime),
      );
      if (!newer) return null;

      return info;
    } catch (e) {
      debugPrint('[BackendPatch] checkPatch 失败: $e');
      return null;
    }
  }

  /// 下载 .so → md5 校验 → 交原生落地为「待生效补丁」。成功返回 true，冷重启后生效。
  Future<bool> downloadAndStage(
    BackendPatchInfo info, {
    String? githubProxy,
    void Function(double? fraction)? onProgress,
  }) async {
    if (!isSupported) return false;
    File? tmp;
    try {
      final dir = await getApplicationSupportDirectory();
      final tmpDir = Directory('${dir.path}/backend_patch_tmp');
      await tmpDir.create(recursive: true);
      tmp = File('${tmpDir.path}/libgojni.so.part');
      if (await tmp.exists()) await tmp.delete();

      final url = PatchUpdateService.applyProxy(info.soUrl, githubProxy);
      await _githubDio.download(
        url,
        tmp.path,
        onReceiveProgress: (received, total) {
          onProgress?.call(total > 0 ? received / total : null);
        },
      );

      // md5 校验（流式）。
      if (info.md5.isNotEmpty) {
        final actual = await _md5OfFile(tmp);
        if (actual.toLowerCase() != info.md5.toLowerCase()) {
          debugPrint('[BackendPatch] md5 不匹配: 期望 ${info.md5} 实际 $actual');
          await tmp.delete().catchError((_) => tmp!);
          return false;
        }
      }

      final ok = await EmbeddedBackendService.stageBackendPatch(
        soPath: tmp.path,
        patchLabel: info.patchLabel,
        version: info.version,
        gitCommit: info.gitCommit,
        md5: info.md5,
      );
      return ok;
    } catch (e) {
      debugPrint('[BackendPatch] downloadAndStage 失败: $e');
      try {
        if (tmp != null && await tmp.exists()) await tmp.delete();
      } catch (_) {}
      return false;
    }
  }

  /// 重启后新进程里调用：后端已起来且 `/api/v1/version` 的 git_commit 与已 stage 的
  /// 补丁一致 → 确认（标 confirmed，清零 bootAttempts）。用于崩溃回滚状态机。
  Future<void> confirmIfHealthy() async {
    if (!isSupported) return;
    try {
      final active = await EmbeddedBackendService.getActiveBackendPatch();
      if (active == null) return; // 无待生效补丁（或已回滚）
      if (active['state'] == 'confirmed') return;
      final running = await _fetchRunningVersion();
      if (running == null) return;
      final activeCommit = (active['gitCommit'] ?? '') as String;
      // git_commit 能对上说明补丁确实加载生效了 → 确认。
      if (activeCommit.isEmpty || running.gitCommit == activeCommit) {
        await EmbeddedBackendService.confirmBackendPatch();
      }
    } catch (e) {
      debugPrint('[BackendPatch] confirmIfHealthy 失败: $e');
    }
  }

  Future<_RunningBackendVersion?> _fetchRunningVersion() async {
    try {
      final resp = await _appDio.get<dynamic>('${AppConfig.apiPrefix}/version');
      final map = _asMap(resp.data);
      if (map == null) return null;
      return _RunningBackendVersion(
        (map['version'] ?? '') as String,
        (map['git_commit'] ?? '') as String,
        (map['build_time'] ?? '') as String,
      );
    } catch (_) {
      return null;
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

  static Future<String> _md5OfFile(File file) async {
    final digest = await file
        .openRead()
        .transform(crypto.md5)
        .first;
    return digest.toString();
  }
}
