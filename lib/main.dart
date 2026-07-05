import 'dart:io' show Platform;
import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:audio_service_mpris/audio_service_mpris.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:window_manager/window_manager.dart';
import 'package:windows_single_instance/windows_single_instance.dart';

import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'config/app_config.dart';
import 'core/audio/audio_service.dart';
import 'core/audio/smtc_service.dart';
import 'core/audio/songloft_just_audio_platform.dart';
import 'core/backend/embedded_backend_service.dart';
import 'core/env/tv_detector.dart';
import 'core/storage/app_preferences.dart';
import 'core/storage/secure_storage.dart';
import 'core/tracely/tracely_client.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/responsive.dart';
import 'core/router/app_router.dart';
import 'core/utils/file_logger.dart';
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

const _desktopPluginStartupTimeout = Duration(seconds: 3);
const _audioStartupTimeout = Duration(seconds: 5);
const _windowsMpvTeardownGracePeriod = Duration(seconds: 6);

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化文件日志并拦截 debugPrint，使所有日志同时写入控制台和文件。
  // 必须在所有 debugPrint 调用之前完成，确保捕获完整的启动日志。
  await FileLogger.init();
  final originalDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    originalDebugPrint(message, wrapWidth: wrapWidth);
    if (message != null) {
      FileLogger.writeln(message);
    }
  };

  // Install global handlers before any plugin initialization. Several desktop
  // plugins run before runApp; catching their failures keeps startup visible.
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

  // Web 端默认启用语义树，无需用户手动点击 "Enable accessibility"
  if (kIsWeb) {
    SemanticsBinding.instance.ensureSemantics();
  }

  // Web 上 dart:io 的 Platform 不可用，调用任意 getter 会抛 UnsupportedError，
  // 必须用 kIsWeb 守卫后再访问 Platform.isWindows
  if (!kIsWeb && Platform.isWindows) {
    try {
      await WindowsSingleInstance.ensureSingleInstance(
        args,
        'songloft_player_instance',
        onSecondWindow: (List<String> args) {
          windowManager.show();
          windowManager.focus();
        },
      ).timeout(_desktopPluginStartupTimeout);
    } catch (e, stackTrace) {
      debugPrint('[Main] Windows 单实例初始化失败，继续启动: $e');
      debugPrint('[Main] Stack trace: $stackTrace');
    }
  }

  // Windows 和 Linux 平台需要 media_kit 作为 just_audio 的后端
  // 必须在 AudioService.init() 之前调用
  // 使用自定义 SongloftJustAudioPlatform 替代 JustAudioMediaKit，
  // 以暴露 media_kit Player 实例供 EQ 均衡器设置 mpv 音频滤镜。
  if (!kIsWeb) {
    try {
      if (Platform.isWindows || Platform.isLinux) {
        SongloftJustAudioPlatform.register();
      } else {
        JustAudioMediaKit.ensureInitialized();
      }
    } catch (e, stackTrace) {
      debugPrint('[Main] MediaKit 初始化失败，音频功能将不可用: $e');
      debugPrint('[Main] Stack trace: $stackTrace');
    }
  }

  // 初始化 Windows 系统托盘与拦截关闭事件。托盘是非关键功能，失败不能阻塞首帧。
  try {
    await WindowTrayManager.setup().timeout(_desktopPluginStartupTimeout);
  } catch (e, stackTrace) {
    debugPrint('[Main] Windows 托盘初始化失败，继续启动: $e');
    debugPrint('[Main] Stack trace: $stackTrace');
  }

  AppConfig.isTvMode = await TvDetector.isTv();

  if (AppConfig.isEmbedded) {
    // 嵌入模式：Flutter Web 嵌入 Go 后端，直接使用当前页面的 origin 作为后端 API 地址
    // 两者同域，无需手动配置
    AppConfig.baseUrl = Uri.base.origin;
    // 检测 <base href> 中的 sub-path（由 Go 服务端运行时注入）
    final uriBasePath = Uri.base.path;
    if (uriBasePath.length > 1) {
      final trimmed =
          uriBasePath.endsWith('/')
              ? uriBasePath.substring(0, uriBasePath.length - 1)
              : uriBasePath;
      AppConfig.basePath = trimmed;
      AppConfig.apiPrefix = '$trimmed/api/v1';
    }
  } else {
    // 独立部署模式：迁移旧的单地址到新的服务器列表。
    // 实际探测在 StartupGate 内异步执行，避免阻塞 main 让 Splash 立即可见。
    // 偏好存储初始化失败时不阻塞启动流程，后续使用默认配置。
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
        _tracelyClient!.reportUpgrade(
          lastVersion,
          currentVersion,
          platform,
          userId,
        );
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

  // Linux: 注册 MPRIS 平台实现，使 audio_service 自动集成 D-Bus 媒体键
  if (!kIsWeb && Platform.isLinux) {
    try {
      AudioServiceMpris.registerWith();
    } catch (e, stackTrace) {
      debugPrint('[Main] MPRIS 注册失败，继续启动: $e');
      debugPrint('[Main] Stack trace: $stackTrace');
    }
  }

  // Windows: 初始化 SMTC (System Media Transport Controls)
  var smtcAvailable = false;
  if (!kIsWeb && Platform.isWindows) {
    try {
      await initializeSmtc().timeout(_desktopPluginStartupTimeout);
      smtcAvailable = true;
    } catch (e, stackTrace) {
      debugPrint('[Main] SMTC 初始化失败，继续启动: $e');
      debugPrint('[Main] Stack trace: $stackTrace');
    }
  }

  // 初始化 audio_service（带降级保护）
  //
  // 注意：Web 端此前跳过 AudioService.init，导致 audio_service_web 从未初始化，
  // 浏览器 MediaSession 的 nexttrack / previoustrack 处理器从未注册——系统媒体
  // 控制 / 蓝牙耳机 / 语音助手的「上一首 / 下一首」全部失效（play / pause 只是
  // 靠浏览器对底层 <audio> 元素的原生兜底才可用）。改为所有平台统一走
  // AudioService.init，让 Web 也接入 MediaSession，next / prev 才有处理器。
  // init 失败时回退到裸 handler（等价于此前的 Web 行为），首帧延迟由 timeout 兜底。
  SongloftAudioHandler audioHandler;
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
        androidBrowsableRootExtras: {
          AndroidContentStyle.supportedKey: true,
          AndroidContentStyle.playableHintKey:
              AndroidContentStyle.listItemHintValue,
          AndroidContentStyle.browsableHintKey:
              AndroidContentStyle.gridItemHintValue,
        },
      ),
    ).timeout(_audioStartupTimeout);
    await audioHandler.ensureInitialized().timeout(_audioStartupTimeout);
    debugPrint(
      '[Main] ✅ AudioService 初始化成功, handler type: ${audioHandler.runtimeType}',
    );
  } catch (e, stackTrace) {
    debugPrint('[Main] ❌ AudioService.init 失败: $e');
    debugPrint('[Main] Stack trace: $stackTrace');
    debugPrint('[Main] ⚠️ 使用降级 handler (通知栏功能将不可用)');
    audioHandler = SongloftAudioHandler();
    try {
      await audioHandler.ensureInitialized().timeout(_audioStartupTimeout);
    } catch (fallbackError, fallbackStackTrace) {
      debugPrint('[Main] 降级 handler 初始化失败，继续启动: $fallbackError');
      debugPrint('[Main] Stack trace: $fallbackStackTrace');
    }
  }

  // Windows: 创建 SMTC 桥接服务，连接系统媒体传输控件与音频处理器
  SmtcService? smtcService;
  if (!kIsWeb && Platform.isWindows && smtcAvailable) {
    try {
      smtcService = SmtcService(audioHandler);
    } catch (e, stackTrace) {
      debugPrint('[Main] SMTC 服务创建失败，继续启动: $e');
      debugPrint('[Main] Stack trace: $stackTrace');
    }
  }

  // 注入退出前清理回调：先释放音频资源，避免窗口销毁时 libmpv C++ 线程仍在运行导致 Fail Fast Exception
  if (!kIsWeb && Platform.isWindows) {
    WindowTrayManager().onBeforeExit = () async {
      Future<void> runCleanup(
        String label,
        Future<void> Function() cleanup,
      ) async {
        try {
          debugPrint('[Main] $label 清理开始');
          await cleanup();
          debugPrint('[Main] $label 清理完成');
        } catch (e, stackTrace) {
          debugPrint('[Main] $label 清理失败，继续退出: $e');
          debugPrint('[Main] Stack trace: $stackTrace');
        }
      }

      await runCleanup('SMTC', () async {
        await smtcService?.dispose();
      });
      await runCleanup('音频停止', audioHandler.stop);
      await runCleanup('音频释放', audioHandler.dispose);
      await runCleanup('libmpv 延迟销毁等待', () async {
        // media_kit 在 Windows 上会在 Player.dispose() 返回后延迟销毁 libmpv。
        // 窗口/Flutter engine 立即退出时，libmpv 后台线程仍可能触发 Fail Fast。
        await Future<void>.delayed(_windowsMpvTeardownGracePeriod);
      });
      await runCleanup('内嵌后端停止', EmbeddedBackendService.stop);
    };
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

  // Windows 高 DPI 下启动首帧可能出现「窗口一半白屏」，首帧后触发一次尺寸重排修复。
  WindowTrayManager.fixInitialSurfaceSize();
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
