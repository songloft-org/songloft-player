import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// 插件 WebView 页面（Web 平台桩实现）
/// Web 平台通过 launchUrl 在新标签页打开插件，正常情况下不会路由到此页面。
/// 此文件不引入 flutter_inappwebview，确保 Web 构建不包含该包。
class PluginWebViewPage extends StatelessWidget {
  final String pluginUrl;
  final String pluginName;

  const PluginWebViewPage({
    super.key,
    required this.pluginUrl,
    required this.pluginName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(pluginName)),
      body: Center(
        child: Text(AppLocalizations.of(context).homePluginWebOpenInNewTab),
      ),
    );
  }
}
