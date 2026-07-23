import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'package:dio/dio.dart';

import '../../config/app_config.dart';
import '../network/base_url_provider.dart';
import '../updater/backend_patch_service.dart';
import 'embedded_backend_service.dart';
import 'run_mode_provider.dart';

/// 监听应用生命周期，在 local 模式下自动重启 Go 后端。
/// 在 SongloftApp 中混入 WidgetsBindingObserver 使用。
class BackendLifecycle with WidgetsBindingObserver {
  final WidgetRef ref;

  BackendLifecycle(this.ref);

  void register() {
    WidgetsBinding.instance.addObserver(this);
  }

  void unregister() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kIsWeb || !AppConfig.hasEmbeddedBackend) return;
    if (ref.read(runModeProvider) != RunMode.local) return;

    switch (state) {
      case AppLifecycleState.resumed:
        _ensureBackendRunning();
        break;
      case AppLifecycleState.detached:
        EmbeddedBackendService.stop();
        break;
      default:
        break;
    }
  }

  Future<void> _ensureBackendRunning() async {
    final running = await EmbeddedBackendService.isRunning();
    if (running) return;

    final musicDir = await EmbeddedBackendService.resolveMusicDir(
      ref.read(localMusicDirProvider),
    );
    if (musicDir == null || musicDir.isEmpty) return;

    try {
      await EmbeddedBackendService.ensureStoragePermission();
      final dataDir = (await getApplicationSupportDirectory()).path;
      final port = await EmbeddedBackendService.start(
        dataDir: dataDir,
        musicDir: musicDir,
      );
      final baseUrl = 'http://127.0.0.1:$port';
      ref.read(baseUrlProvider.notifier).set(baseUrl);

      // 若本次是后端热更冷启，确认补丁健康（崩溃回滚状态机的 confirm 时机）。
      try {
        final versionDio = Dio(BaseOptions(baseUrl: baseUrl));
        await BackendPatchService(appDio: versionDio).confirmIfHealthy();
        versionDio.close();
      } catch (_) {}
    } catch (e) {
      debugPrint('[BackendLifecycle] 后端重启失败: $e');
    }
  }
}
