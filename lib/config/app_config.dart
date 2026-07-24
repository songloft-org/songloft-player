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

  /// 实际发起网络请求（Dio baseUrl / 播放·封面·歌词 URL 拼接）使用的真实服务地址。
  ///
  /// 与 [baseUrl] 的区别：[baseUrl] 是**身份 URL**（用户填的入口域名，稳定，用于
  /// walletKey 派生 / 多服务器定位 / 持久化）；[resolvedBaseUrl] 是入口域名经 302
  /// 重定向解析出的**真实地址**，可能随 STUN 端口变化而动态刷新（见
  /// [ServerRedirectResolver]）。运行期 single source of truth 是 [resolvedBaseUrlProvider]
  /// 并 mirror 到此处，供非 Riverpod 上下文（[UrlHelper]）同步读取。
  ///
  /// **未 resolve 时回退到 [baseUrl]**：覆盖 embedded（同域，Uri.base.origin）、本地
  /// 模式（127.0.0.1）等无需重定向解析的路径，无需在这些初始化点额外赋值。
  static String? _resolvedBaseUrlOverride;
  static String get resolvedBaseUrl => _resolvedBaseUrlOverride ?? baseUrl;
  static set resolvedBaseUrl(String value) => _resolvedBaseUrlOverride = value;

  static String apiPrefix = '/api/v1';
  static String basePath = '';

  /// 是否忽略 HTTPS 证书校验（不安全，仅用于自签/内网证书场景）。
  ///
  /// 运行期 single source of truth 由 [insecureTlsProvider] 持有并 mirror 到此处，
  /// 供非 Riverpod 上下文（如 [ServerProbe.probeOne]）同步读取。
  /// 同时影响 Dart 层 HTTP（Dio / HttpClient）和原生音频播放器（libmpv）的 TLS 证书校验。
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

  /// 前端 Git Commit，通过 --dart-define=FRONTEND_GIT_COMMIT=xxxxxxx 注入
  static const String frontendGitCommit = String.fromEnvironment(
    'FRONTEND_GIT_COMMIT',
    defaultValue: 'unknown',
  );

  /// 前端热更（flutter_patcher 换 libapp.so）的**引擎兼容键**，通过
  /// `--dart-define=FLUTTER_BINDING=<Flutter 版本>` 注入（CI = FLUTTER_VERSION）。
  ///
  /// libapp.so（Dart AOT 快照）必须匹配 APK 里的 Flutter 引擎;此键是「引擎版本」的
  /// 自动代理（取代按 versionCode 手工绑定）。客户端与补丁 manifest 的该键相同 → 视为
  /// 引擎兼容,可跨 versionCode 热更;不同 → 不热更,引导整包。空表示未知（本地开发）。
  static const String flutterBinding = String.fromEnvironment(
    'FLUTTER_BINDING',
    defaultValue: '',
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

  /// 标准版前端 GitHub 仓库（连接独立部署的服务器，产物名 songloft-*）
  static const String frontendRepo = 'songloft-org/songloft-player';

  /// 标准版前端最新发布地址
  static const String frontendReleasesUrl =
      'https://github.com/songloft-org/songloft-player/releases/latest';

  /// Bundle 版（内嵌后端）发布在父仓库 songloft-org/songloft，产物名 songloft-bundled-*，
  /// 与标准版仓库/版本号相互独立。
  static const String frontendBundleRepo = 'songloft-org/songloft';

  /// 「客户端更新」流程实际使用的检查仓库：bundle 版查父仓库，标准版查 player 仓库。
  /// hasEmbeddedBackend 为编译时常量，tree-shaking 会固定此值。
  static const String frontendUpdateRepo =
      hasEmbeddedBackend ? frontendBundleRepo : frontendRepo;

  /// 「客户端更新」流程使用的最新发布页地址（跟随 frontendUpdateRepo）
  static const String frontendUpdateReleasesUrl =
      'https://github.com/$frontendUpdateRepo/releases/latest';

  /// 格式化前端版本号用于显示
  /// 'dev' -> '开发版本 (abc1234)', '1.0.14' -> 'v1.0.14'
  static String get frontendVersionDisplay {
    if (frontendVersion == 'dev') {
      final label = l10nOrNull?.coreVersionDev ?? '开发版本';
      return frontendGitCommit != 'unknown' && frontendGitCommit.isNotEmpty
          ? '$label ($frontendGitCommit)'
          : label;
    }
    return 'v$frontendVersion';
  }
}
