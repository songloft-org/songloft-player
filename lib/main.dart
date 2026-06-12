import 'dart:io' show Platform;
import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:window_manager/window_manager.dart';
import 'package:windows_single_instance/windows_single_instance.dart';

import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'config/app_config.dart';
import 'core/audio/audio_service.dart';
import 'core/env/tv_detector.dart';
import 'core/storage/app_preferences.dart';
import 'core/storage/secure_storage.dart';
import 'core/tracely/tracely_client.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/responsive.dart';
import 'core/router/app_router.dart';
import 'core/utils/platform_utils.dart';
import 'core/utils/window_tray_manager.dart';
import 'features/settings/presentation/providers/settings_provider.dart';
import 'features/startup/presentation/startup_gate.dart';

/// 全局 AudioHandler Provider
final audioHandlerProvider = Provider<SongloftAudioHandler>((ref) {
  throw UnimplementedError('audioHandlerProvider must be overridden');
});

/// 全局 Tracely 客户端（未启用时为 null）
TracelyClient? _tracelyClient;

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Web 上 dart:io 的 Platform 不可用，调用任意 getter 会抛 UnsupportedError，
  // 必须用 kIsWeb 守卫后再访问 Platform.isWindows
  if (!kIsWeb && Platform.isWindows) {
    await WindowsSingleInstance.ensureSingleInstance(
      args,
      'songloft_player_instance',
      onSecondWindow: (List<String> args) {
        windowManager.show();
        windowManager.focus();
      },
    );
  }

  // Windows 和 Linux 平台需要 media_kit 作为 just_audio 的后端
  // 必须在 AudioService.init() 之前调用
  if (!kIsWeb) {
    JustAudioMediaKit.ensureInitialized();
  }

  // 初始化 Windows 系统托盘与拦截关闭事件
  await WindowTrayManager.setup();

  // 全局异常处理，防止未捕获异常导致白屏
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('[FlutterError] ${details.exceptionAsString()}');
    FlutterError.presentError(details);
    _tracelyClient?.reportError(
      type: 'flutter',
      message: details.exceptionAsString(),
      stack: details.stack?.toString(),
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[PlatformError] $error\n$stack');
    _tracelyClient?.reportError(
      type: 'dart',
      message: error.toString(),
      stack: stack.toString(),
    );
    return true;
  };

  AppConfig.isTvMode = await TvDetector.isTv();

  if (AppConfig.isEmbedded) {
    // 嵌入模式：Flutter Web 嵌入 Go 后端，直接使用当前页面的 origin 作为后端 API 地址
    // 两者同域，无需手动配置
    AppConfig.baseUrl = Uri.base.origin;
    // 检测 <base href> 中的 sub-path（由 Go 服务端运行时注入）
    final uriBasePath = Uri.base.path;
    if (uriBasePath.length > 1) {
      final trimmed = uriBasePath.endsWith('/')
          ? uriBasePath.substring(0, uriBasePath.length - 1)
          : uriBasePath;
      AppConfig.basePath = trimmed;
      AppConfig.apiPrefix = '$trimmed/api/v1';
    }
  } else {
    // 独立部署模式：迁移旧的单地址到新的服务器列表。
    // 实际探测在 StartupGate 内异步执行，避免阻塞 main 让 Splash 立即可见。
    // shared_preferences_android 2.4.23 声明 minSdk=24，API 23 上可能失败
    try {
      final prefs = await AppPreferences.create();
      await prefs.migrateLegacyApiBaseUrl();
    } catch (e) {
      debugPrint('[Main] SharedPreferences 初始化失败，使用默认配置: $e');
    }
  }

  // 初始化 Tracely 监控（仅在编译时注入了配置参数时启用）
  if (AppConfig.tracelyEnabled) {
    _tracelyClient = TracelyClient(
      appId: AppConfig.tracelyAppId,
      appSecret: AppConfig.tracelyAppSecret,
      host: AppConfig.tracelyHost,
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastVersion = prefs.getString('_tracely_reported_version') ?? '';
      const currentVersion = AppConfig.frontendVersion;
      final platform = kIsWeb ? 'Web' : PlatformUtils.platformName;
      var userId = prefs.getString('_tracely_uid') ?? '';
      if (userId.isEmpty) {
        userId = _generateUserId();
        await prefs.setString('_tracely_uid', userId);
      }
      if (lastVersion.isEmpty) {
        _tracelyClient!.reportInstall(currentVersion, platform, userId);
      } else if (lastVersion != currentVersion) {
        _tracelyClient!
            .reportUpgrade(lastVersion, currentVersion, platform, userId);
      }
      if (lastVersion != currentVersion) {
        await prefs.setString('_tracely_reported_version', currentVersion);
      }
    } catch (e) {
      debugPrint('[Main] Tracely 初始化失败: $e');
    }
  }

  // Android 13+ 需要运行时请求通知权限
  // 通知权限为非关键功能，TV/低版本设备上可能失败，不应阻塞启动
  if (!kIsWeb && Platform.isAndroid) {
    try {
      final status = await Permission.notification.status;
      debugPrint('[Main] Android 平台检测');
      debugPrint('[Main] 通知权限状态: $status');
      if (status.isDenied) {
        debugPrint('[Main] 请求通知权限...');
        final result = await Permission.notification.request();
        debugPrint('[Main] 通知权限请求结果: $result');
      }
      if (status.isPermanentlyDenied) {
        debugPrint('[Main] 通知权限被永久拒绝，需要在系统设置中手动开启');
      }
    } catch (e) {
      debugPrint('[Main] 通知权限检查失败: $e');
    }
  }

  // 预加载 access token 到内存缓存，避免 UI 首帧渲染时 cachedAccessToken 为 null
  // 解决 Windows 等平台上封面图和音乐 URL 中 access_token= 为空导致 401 的竞态问题
  // （checkAuth() 使用 Future.microtask 异步执行，比 UI 首帧渲染更晚填充缓存）
  try {
    await SecureStorageService().getAccessToken();
    debugPrint(
      '[Main] 预加载 token 完成: cachedAccessToken is ${SecureStorageService.cachedAccessToken != null ? "set" : "null"}',
    );
  } catch (e) {
    debugPrint('[Main] Token 预加载失败: $e');
  }

  // 初始化 audio_service（带降级保护）
  SongloftAudioHandler audioHandler;
  if (kIsWeb) {
    // Web 平台无系统通知栏，跳过 AudioService.init 的 await，
    // 直接创建 handler 让首帧尽快渲染。_initAudioSession 在构造函数中
    // 已异步启动，播放时通过 await _initFuture 保证初始化完成。
    audioHandler = SongloftAudioHandler();
  } else {
    try {
      debugPrint('[Main] 🚀 开始初始化 AudioService...');
      audioHandler = await AudioService.init<SongloftAudioHandler>(
        builder: () => SongloftAudioHandler(),
        // androidStopForegroundOnPause 设为 false 保持前台服务持续运行：
        // HyperOS3 等系统在前台服务停止后会激进回收资源，
        // 导致歌曲播放完成后 playNext() 命令失效无法自动切歌
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.songloft.playback',
          androidNotificationChannelName: 'Songloft 播放控制',
          androidNotificationOngoing: false,
          androidStopForegroundOnPause: false,
        ),
      );
      await audioHandler.ensureInitialized();
      debugPrint(
        '[Main] ✅ AudioService 初始化成功, handler type: ${audioHandler.runtimeType}',
      );
    } catch (e, stackTrace) {
      debugPrint('[Main] ❌ AudioService.init 失败: $e');
      debugPrint('[Main] Stack trace: $stackTrace');
      debugPrint('[Main] ⚠️ 使用降级 handler (通知栏功能将不可用)');
      audioHandler = SongloftAudioHandler();
      await audioHandler.ensureInitialized();
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        // 将 audioHandler 注入到 Riverpod 中
        audioHandlerProvider.overrideWithValue(audioHandler),
      ],
      child: const StartupGate(child: SongloftApp()),
    ),
  );
}

String _generateUserId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  // 格式化为 UUID v4 风格
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// 支持鼠标拖拽滚动的 ScrollBehavior（macOS / desktop）
class _AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

class SongloftApp extends ConsumerWidget {
  const SongloftApp({super.key});

  /// 根据屏幕宽度获取 ScreenType
  ScreenType _getScreenType(double width) {
    if (width >= ResponsiveBreakpoints.tv) return ScreenType.tv;
    if (width >= ResponsiveBreakpoints.desktop) return ScreenType.desktop;
    if (width >= ResponsiveBreakpoints.tablet) return ScreenType.tablet;
    return ScreenType.mobile;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Songloft',
      debugShowCheckedModeBanner: false,
      scrollBehavior: _AppScrollBehavior(),
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        // 在 builder 中获取 MediaQuery 来应用响应式主题
        final width = MediaQuery.of(context).size.width;
        final screenType = _getScreenType(width);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data:
              isDark
                  ? AppTheme.darkTheme(screenType: screenType)
                  : AppTheme.lightTheme(screenType: screenType),
          child: child!,
        );
      },
    );
  }
}
