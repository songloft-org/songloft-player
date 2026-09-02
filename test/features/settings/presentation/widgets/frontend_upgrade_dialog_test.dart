import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/config/app_config.dart';
import 'package:songloft_flutter/features/settings/data/frontend_version_api.dart';
import 'package:songloft_flutter/features/settings/presentation/providers/settings_provider.dart';
import 'package:songloft_flutter/core/theme/app_theme.dart';
import 'package:songloft_flutter/features/settings/presentation/widgets/frontend_upgrade_dialog.dart';
import 'package:songloft_flutter/l10n/app_localizations.dart';

/// 测试环境下 FRONTEND_VERSION 未注入，恒为 'dev'，故检查结果必然是「已是最新」
/// （见 FrontendVersionApi._isNewerVersion：本地 build_time 为 unknown → false）。
/// 本文件覆盖「已是最新 / 检查失败时仍能拿到完整安装包下载入口」这条退路。
void main() {
  const launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');
  String? launchedUrl;

  setUp(() {
    launchedUrl = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcherChannel, (call) async {
          switch (call.method) {
            case 'canLaunch':
              return true;
            case 'launch':
              launchedUrl = (call.arguments as Map)['url'] as String?;
              return true;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcherChannel, null);
  });

  Future<void> pumpDialog(
    WidgetTester tester,
    FrontendVersionApi api, {
    String proxy = '',
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          frontendVersionApiProvider.overrideWithValue(api),
          // 对话框静默读取「设置 → 网络设置」的全局 GitHub 代理，测试中避免真实网络请求
          githubProxyProvider.overrideWith(
            () => _FakeGithubProxyNotifier(proxy),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(
            extensions: const [SongloftThemeExtension()],
          ),
          home: const Scaffold(body: FrontendUpgradeDialog()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('已是最新时展示重装提示与「下载完整安装包」按钮', (tester) async {
    await pumpDialog(tester, _apiReturning(_releaseJson()));

    expect(find.text('已是最新版本'), findsOneWidget);
    expect(find.text('客户端热更后如出现异常，可下载完整安装包覆盖安装'), findsOneWidget);
    expect(find.text('下载完整安装包'), findsOneWidget);
  });

  testWidgets('已是最新时点击按钮跳转 release 的 html_url', (tester) async {
    await pumpDialog(tester, _apiReturning(_releaseJson()));

    await tester.tap(find.text('下载完整安装包'));
    await tester.pumpAndSettle();

    expect(
      launchedUrl,
      'https://github.com/songloft-org/songloft-player/releases/tag/dev',
    );
  });

  testWidgets('全局配置 GitHub 代理后跳转地址带代理前缀', (tester) async {
    await pumpDialog(
      tester,
      _apiReturning(_releaseJson()),
      proxy: 'https://ghfast.top/',
    );

    await tester.tap(find.text('下载完整安装包'));
    await tester.pumpAndSettle();

    expect(
      launchedUrl,
      'https://ghfast.top/https://github.com/songloft-org/songloft-player/releases/tag/dev',
    );
  });

  testWidgets('检查失败时仍有下载按钮，跳当前渠道（dev）发布页兜底', (tester) async {
    await pumpDialog(tester, _apiReturning(null));

    expect(find.text('下载完整安装包'), findsOneWidget);

    await tester.tap(find.text('下载完整安装包'));
    await tester.pumpAndSettle();

    // dev 渠道兜底必须是 releases/tag/dev，而非 releases/latest（正式版页面）
    expect(
      AppConfig.frontendUpdateChannelReleaseUrl,
      endsWith('/releases/tag/dev'),
    );
    expect(launchedUrl, AppConfig.frontendUpdateChannelReleaseUrl);
  });
}

/// dev tag 的 GitHub release 响应（tag_name=dev → 与本地 'dev' 同渠道且判定为最新）
Map<String, dynamic> _releaseJson() => {
  'tag_name': 'dev',
  'html_url':
      'https://github.com/songloft-org/songloft-player/releases/tag/dev',
  'body': '- :bug: fix something',
  'published_at': '2026-07-01T00:00:00Z',
  'assets': <dynamic>[],
};

/// 内存版 GitHub 代理 Notifier：不发网络请求，模拟「设置 → 网络设置」中的全局配置。
class _FakeGithubProxyNotifier extends GithubProxyNotifier {
  _FakeGithubProxyNotifier(this._initial);

  final String _initial;

  @override
  Future<String> build() async => _initial;

  @override
  Future<void> setValue(String value) async {
    state = AsyncValue.data(value);
  }
}

/// [payload] 为 null 时模拟网络失败，触发对话框的 error 分支。
FrontendVersionApi _apiReturning(Map<String, dynamic>? payload) {
  final dio = Dio();
  dio.httpClientAdapter = _StubAdapter(payload);
  return FrontendVersionApi(dio: dio);
}

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.payload);

  final Map<String, dynamic>? payload;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (payload == null) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'stubbed offline',
      );
    }
    // version.json（dev 渠道精确比较用）不提供 → API 内部静默回退
    if (options.uri.path.endsWith('version.json')) {
      return ResponseBody.fromString('{}', 404);
    }
    return ResponseBody.fromString(
      jsonEncode(payload),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
