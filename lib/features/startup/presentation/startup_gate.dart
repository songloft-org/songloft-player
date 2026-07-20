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
import '../../../core/network/servers_provider.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/utils/image_recovery.dart';
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

  /// 上次执行 Web 重绘恢复的时间，用于节流（避免频繁切后台抖动时连续重建整树）。
  DateTime _lastWebRepaint = DateTime.fromMillisecondsSinceEpoch(0);

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
    _forceWebRepaint();
  }

  /// Web 切后台回前台的封面纹理恢复。
  ///
  /// Android Chrome 后台会丢弃 WebGL context，beta 3.47 引擎(#185116)只修了
  /// LateInitializationError 崩溃、重建 GrContext/SkSurface，**不会重传已解码位图的
  /// GPU 纹理**；返回时封面(CachedNetworkImage)会绘制失效纹理 → 纯黑(errorWidget
  /// 捕获不到)。与应用内切页面变黑同族(flutter/flutter#86809/#91881)。
  ///
  /// [bumpImageRecovery] 让所有挂载的 CoverImage 驱逐自身缓存条目并换 key 重建、
  /// 重新解码重传纹理(见 image_recovery.dart)——比 reassembleApplication 精准、无
  /// 打断临时状态的副作用。另清一次全局 imageCache 兜底非 CoverImage 的图(占位/
  /// asset 等)。矢量内容每帧从 Picture 重录自动恢复，无需额外处理。
  void _forceWebRepaint() {
    if (!mounted) return;

    // 节流：切后台频繁抖动时避免连续重建可见封面。
    final now = DateTime.now();
    if (now.difference(_lastWebRepaint) < const Duration(seconds: 2)) return;
    _lastWebRepaint = now;

    // 兜底清理非 CoverImage 图（占位/asset 等）的死纹理条目。
    final imageCache = PaintingBinding.instance.imageCache;
    imageCache.clear();
    imageCache.clearLiveImages();

    // 精准恢复所有挂载的封面：evict 自身缓存 + 换 key 重建 → 重解码重传纹理。
    bumpImageRecovery();
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
