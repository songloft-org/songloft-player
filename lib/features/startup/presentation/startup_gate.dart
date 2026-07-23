import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../config/app_config.dart';
import '../../../core/backend/embedded_backend_service.dart';
import '../../../core/backend/run_mode_provider.dart';
import '../../../core/network/base_url_provider.dart';
import '../../../core/network/server_entry.dart';
import '../../../core/network/server_probe.dart';
import '../../../core/network/server_redirect_resolver.dart';
import '../../../core/network/servers_provider.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/updater/backend_patch_service.dart';
import '../../../l10n/app_localizations.dart';

/// 启动时显示一个简单 Splash，期间完成：
/// 1. 读取持久化的服务器列表
/// 2. 并行探测可达性（最长 2.5s）
/// 3. 选优先级最高的成功项写入 baseUrlProvider；全失败则 fallback 列表首项
/// 4. 设置 probeOutcomeProvider 供首屏 SnackBar 提示
///
/// embedded 模式不做任何探测，直接渲染 child。
/// local 模式启动内嵌 Go 后端，连接 localhost 并自动登录。
class StartupGate extends ConsumerStatefulWidget {
  final Widget child;
  const StartupGate({super.key, required this.child});

  @override
  ConsumerState<StartupGate> createState() => _StartupGateState();
}

/// 启动 Splash 的提示阶段。文案在 [build] 中通过 [AppLocalizations] 解析，
/// 因为 Splash 的 MaterialApp 在 SongloftApp 之外，设置文案时尚无可用的
/// BuildContext / 全局 l10n。
enum _StartupHint {
  starting,
  startingLocalBackend,
  connectingLocalBackend,
  connectingTo,
}

class _StartupGateState extends ConsumerState<StartupGate>
    with WidgetsBindingObserver {
  bool _ready = false;
  _StartupHint _hint = _StartupHint.starting;
  String _connectingTarget = '';

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      WidgetsBinding.instance.addObserver(this);
    }
    if (AppConfig.isEmbedded) {
      _ready = true;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
    }
  }

  @override
  void dispose() {
    if (kIsWeb) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!kIsWeb || state != AppLifecycleState.resumed) return;
    // Web 回前台轻量补几帧，促使引擎重绘。web 仍走 CanvasKit + WebGL（web/index.html
    // 里 canvasKitVariant: "auto"，由引擎按浏览器选 chromium/full 变体，都走 WebGL；
    // CPU-only 强制绕法早已移除），切后台 / GPU 显存压力下 WebGL context 仍可能丢失：
    // 崩溃已由 beta 3.47 引擎修复（flutter/flutter#185116）兜住，离屏封面的死纹理则由
    // installWebGLContextRecovery（main.dart）在 context 丢失/恢复时清空 imageCache
    // 收尾（songloft-org/songloft#309），故这里只需补帧。
    for (var i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) WidgetsBinding.instance.scheduleFrame();
      });
    }
  }

  Future<void> _bootstrap() async {
    try {
      await ref.read(runModeProvider.notifier).ensureLoaded();
      await ref.read(localMusicDirProvider.notifier).ensureLoaded();
      final runMode = ref.read(runModeProvider);

      // 仅在打包了内嵌后端的构建里才走本地模式；非 bundled 客户端即便
      // 残留了 run_mode=local（如同容器装过 bundled 版）也一律回退远程，
      // 与 backend_lifecycle / servers_page 的 hasEmbeddedBackend 守卫保持一致。
      if (runMode == RunMode.local && !kIsWeb && AppConfig.hasEmbeddedBackend) {
        await _bootstrapLocal();
      } else {
        await _bootstrapRemote();
      }
    } catch (e) {
      debugPrint('[StartupGate] 启动初始化失败: $e');
      ref.read(probeOutcomeProvider.notifier).set(ProbeOutcome.fallbackUsed);
    } finally {
      if (mounted) {
        setState(() {
          _ready = true;
        });
      }
    }
  }

  Future<void> _bootstrapLocal() async {
    setState(() => _hint = _StartupHint.startingLocalBackend);

    final musicDir = await EmbeddedBackendService.resolveMusicDir(
      ref.read(localMusicDirProvider),
    );
    if (musicDir == null || musicDir.isEmpty) {
      debugPrint('[StartupGate] 本地模式未配置音乐目录，回退到远程模式');
      await ref.read(runModeProvider.notifier).set(RunMode.remote);
      await _bootstrapRemote();
      return;
    }
    await ref.read(localMusicDirProvider.notifier).set(musicDir);

    await EmbeddedBackendService.ensureStoragePermission();

    final dataDir = (await getApplicationSupportDirectory()).path;
    final port = await EmbeddedBackendService.start(
      dataDir: dataDir,
      musicDir: musicDir,
    );

    final baseUrl = 'http://127.0.0.1:$port';
    ref.read(baseUrlProvider.notifier).set(baseUrl);

    setState(() => _hint = _StartupHint.connectingLocalBackend);

    // 等待后端 health 端点就绪
    final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 2)));
    for (var i = 0; i < 10; i++) {
      try {
        final resp = await dio.get('$baseUrl/api/v1/health');
        if (resp.statusCode == 200) break;
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
    dio.close();

    // 后端已就绪：若本次是后端热更后的冷启，确认补丁健康（崩溃回滚状态机的 confirm
    // 时机）。非 Android / 非 bundle / 无待生效补丁时安全 no-op。
    try {
      final versionDio = Dio(BaseOptions(baseUrl: baseUrl));
      await BackendPatchService(appDio: versionDio).confirmIfHealthy();
      versionDio.close();
    } catch (_) {}

    // 尝试恢复本地 session，有效则跳过 auto-login
    final storage = SecureStorageService();
    final restored = await storage.restoreWallet(
      SecureStorageService.localWalletKey,
    );
    if (!restored || await storage.isAccessTokenExpired()) {
      await _autoLogin(baseUrl);
    }

    ref.read(probeOutcomeProvider.notifier).set(ProbeOutcome.success);
  }

  Future<void> _autoLogin(String baseUrl) async {
    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 5),
        ),
      );
      final resp = await dio.post(
        '${AppConfig.apiPrefix}/auth/login',
        data: {'username': 'admin', 'password': 'admin'},
      );
      if (resp.statusCode == 200 && resp.data != null) {
        final storage = SecureStorageService();
        await storage.saveTokens(
          accessToken: resp.data['access_token'] ?? '',
          refreshToken: resp.data['refresh_token'] ?? '',
          expiresIn: resp.data['expires_in'] ?? 3600,
          walletKey: SecureStorageService.localWalletKey,
        );
        debugPrint('[StartupGate] 本地模式自动登录成功');
      }
      dio.close();
    } catch (e) {
      debugPrint('[StartupGate] 本地模式自动登录失败: $e');
    }
  }

  Future<void> _bootstrapRemote() async {
    final servers = await ref.read(serversProvider.future);

    if (servers.isEmpty) {
      ref.read(probeOutcomeProvider.notifier).set(ProbeOutcome.noServers);
    } else if (servers.length == 1) {
      final url = servers.first.url;
      ref.read(baseUrlProvider.notifier).set(url);
      await _resolveRedirect(url);
      // 恢复该服务器的 wallet
      final storage = SecureStorageService();
      await storage.restoreWallet(SecureStorageService.walletKey(url));
      ref.read(probeOutcomeProvider.notifier).set(ProbeOutcome.success);
    } else {
      setState(() {
        _hint = _StartupHint.connectingTo;
        _connectingTarget = _describe(servers.first);
      });

      final picked = await ServerProbe.pickFirstReachable(servers);
      final chosen = picked ?? servers.first;
      ref.read(baseUrlProvider.notifier).set(chosen.url);
      await _resolveRedirect(chosen.url);
      // 恢复选中服务器的 wallet
      final storage = SecureStorageService();
      await storage.restoreWallet(SecureStorageService.walletKey(chosen.url));
      ref
          .read(probeOutcomeProvider.notifier)
          .set(
            picked == null ? ProbeOutcome.fallbackUsed : ProbeOutcome.success,
          );
    }
  }

  /// 解析入口域名的 302 重定向，把真实地址写入 resolvedBaseUrlProvider
  /// （songloft-org/songloft-player#22）。每次启动都重新 resolve，覆盖 STUN 端口的
  /// 跨会话变化。walletKey 仍用身份 URL（[identityUrl]），不受影响。
  /// 失败/Web 时降级用入口域名，后续首个请求失败会由拦截器再次重解析兜底。
  Future<void> _resolveRedirect(String identityUrl) async {
    final resolved = await ServerRedirectResolver.resolve(
      identityUrl,
      insecureTls: AppConfig.insecureTls,
    );
    if (!mounted) return;
    ref.read(resolvedBaseUrlProvider.notifier).set(resolved);
  }

  String _describe(ServerEntry e) {
    if (e.name.isNotEmpty) return e.name;
    return e.displayName;
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.child;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          final hintText = switch (_hint) {
            _StartupHint.starting => l10n.startupStarting,
            _StartupHint.startingLocalBackend => l10n.startupStartingLocalBackend,
            _StartupHint.connectingLocalBackend =>
              l10n.startupConnectingLocalBackend,
            _StartupHint.connectingTo =>
              l10n.startupConnectingTo(_connectingTarget),
          };
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/icons/app_icon.png',
                    width: 64,
                    height: 64,
                    semanticLabel: 'Songloft',
                  ),
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text(hintText),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
