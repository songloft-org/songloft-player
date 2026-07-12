import '../l10n/l10n_holder.dart';

/// 部署模式，通过 --dart-define=DEPLOY_MODE=embedded 在构建时注入
/// - 'embedded' : Flutter Web 嵌入 Go 后端，同域访问，无需用户配置 API 地址
/// - 'standalone': 独立静态部署，后端地址与前端不同域，需用户手动配置
/// 默认值为 'standalone'，即未指定时保持完整功能
const String _kDeployMode = String.fromEnvironment(
  'DEPLOY_MODE',
  defaultValue: 'standalone',
);

class AppConfig {
  static String baseUrl = 'http://localhost:58091';
  static String apiPrefix = '/api/v1';
  static String basePath = '';

  /// 是否忽略 HTTPS 证书校验（不安全，仅用于自签/内网证书场景）。
  ///
  /// 运行期 single source of truth 由 [insecureTlsProvider] 持有并 mirror 到此处，
  /// 供非 Riverpod 上下文（如 [ServerProbe.probeOne]）同步读取。
  /// 仅影响 Dart 层 HTTP（Dio）；原生音频播放器的 TLS 不受此开关影响。
  static bool insecureTls = false;
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  static String get apiBaseUrl => '$baseUrl$apiPrefix';

  /// 是否为嵌入模式（Flutter Web 打包进 Go 二进制）
  /// 编译时常量，tree-shaking 会移除未使用的分支代码
  static const bool isEmbedded = _kDeployMode == 'embedded';

  /// 是否为移动端嵌入后端构建（通过 --dart-define=HAS_BACKEND=true 注入）
  /// 为 true 时显示"本地模式"选项，允许在设备上直接运行 Go 后端
  static const bool hasEmbeddedBackend = bool.fromEnvironment(
    'HAS_BACKEND',
    defaultValue: false,
  );

  /// 是否运行在电视系统上
  static late final bool isTvMode;

  /// 前端版本号，通过 --dart-define=FRONTEND_VERSION=x.y.z 在构建时注入
  /// 本地开发时默认为 'dev'
  static const String frontendVersion = String.fromEnvironment(
    'FRONTEND_VERSION',
    defaultValue: 'dev',
  );

  /// 前端构建时间，通过 --dart-define=FRONTEND_BUILD_TIME=YYYY-MM-DD_HH:MM:SS 注入
  static const String frontendBuildTime = String.fromEnvironment(
    'FRONTEND_BUILD_TIME',
    defaultValue: 'unknown',
  );

  /// Tracely 监控配置（编译时通过 --dart-define 注入，未配置则不启用）
  static const String tracelyAppId = String.fromEnvironment(
    'TRACELY_APP_ID',
    defaultValue: '',
  );
  static const String tracelyAppSecret = String.fromEnvironment(
    'TRACELY_APP_SECRET',
    defaultValue: '',
  );
  static const String tracelyHost = String.fromEnvironment(
    'TRACELY_HOST',
    defaultValue: '',
  );
  static bool get tracelyEnabled =>
      tracelyAppId.isNotEmpty &&
      tracelyAppSecret.isNotEmpty &&
      tracelyHost.isNotEmpty;

  /// 前端 GitHub 仓库
  static const String frontendRepo = 'songloft-org/songloft-player';

  /// 前端最新发布地址
  static const String frontendReleasesUrl =
      'https://github.com/songloft-org/songloft-player/releases/latest';

  /// 格式化前端版本号用于显示
  /// 'dev' -> '开发版本', '1.0.14' -> 'v1.0.14'
  static String get frontendVersionDisplay =>
      frontendVersion == 'dev'
          ? (l10nOrNull?.coreVersionDev ?? '开发版本')
          : 'v$frontendVersion';
}
