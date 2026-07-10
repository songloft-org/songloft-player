import 'web_os.dart';

/// 非 Web 平台占位实现：原生客户端无需检测浏览器 OS。
WebOS detectWebOS() => WebOS.unknown;
