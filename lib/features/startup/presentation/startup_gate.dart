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

class _StartupGateState extends ConsumerState<StartupGate>
    with WidgetsBindingObserver {
  bool _ready = false;
  String _hint = '正在启动…';

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
    setState(() => _hint = '正在启动本地后端…');

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

    setState(() => _hint = '正在连接本地后端…');

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
        _hint = '正在连接 ${_describe(servers.first)}…';
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
      home: Scaffold(
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
              Text(_hint),
            ],
          ),
        ),
      ),
    );
  }
}
