import 'dart:io' show Platform, Directory;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';

/// Windows WebView2 环境管理（songloft-org/songloft#271）。
///
/// 背景：`flutter_inappwebview_windows` 底层是 WebView2。若不显式指定用户数据目录
/// (User Data Folder)，WebView2 默认在**宿主 exe 同目录**创建 `<exe>.WebView2\`。
/// 免安装(portable)版常被放在 `Program Files`、只读挂载点或无写权限目录，导致
/// WebView2 环境创建失败，抛出 `Cannot create the InAppWebView instance!`——插件页
/// 永久转圈、重试无效（controller 恒为 null，`reload()` 是 no-op）。
///
/// 本单例在启动时把 UDF 指向应用支持目录（`getApplicationSupportDirectory()`，
/// 与后端 data 目录、多服务器配置同源，一定可写），使 portable 版即便放在只读目录
/// 也能创建 WebView。非 Windows 平台不需要（各自平台包自带默认环境），返回 null。
class SongloftWebViewEnvironment {
  SongloftWebViewEnvironment._();

  static WebViewEnvironment? _environment;
  static bool _initialized = false;

  /// 已就绪的 WebView2 环境（仅 Windows 非 null）；其它平台或未初始化时为 null，
  /// InAppWebView 传入 null 时按平台默认行为处理。
  static WebViewEnvironment? get instance => _environment;

  /// 在 `runApp` 之前调用（仅 Windows 生效）。失败不抛出，仅记录——
  /// 环境为 null 时 InAppWebView 会回退默认行为，不阻塞启动。
  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    if (kIsWeb || !Platform.isWindows) return;
    try {
      final supportDir = await getApplicationSupportDirectory();
      final udf = '${supportDir.path}${Platform.pathSeparator}webview2';
      await Directory(udf).create(recursive: true);
      _environment = await WebViewEnvironment.create(
        settings: WebViewEnvironmentSettings(userDataFolder: udf),
      );
    } catch (e) {
      // 创建失败（如 WebView2 Runtime 缺失）时保持 null，页面层会走加载超时/错误 UI。
      _environment = null;
    }
  }
}
