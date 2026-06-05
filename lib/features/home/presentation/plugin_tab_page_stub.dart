import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../../config/app_config.dart';
import '../../../core/storage/secure_storage.dart';

/// 插件 Tab 页面（Web 平台实现）
/// 使用 iframe 嵌入插件页面，体验与原生 WebView 一致
class PluginTabPage extends StatefulWidget {
  final String entryPath;

  const PluginTabPage({super.key, required this.entryPath});

  @override
  State<PluginTabPage> createState() => _PluginTabPageState();
}

class _PluginTabPageState extends State<PluginTabPage> {
  late final String _viewType;

  String get _pluginUrl {
    final baseUrl =
        '${AppConfig.baseUrl}${AppConfig.basePath}/api/v1/jsplugin/${widget.entryPath}';
    final token = SecureStorageService.cachedAccessToken ?? '';
    if (token.isEmpty) return '$baseUrl?embed';
    return '$baseUrl?embed&access_token=$token';
  }

  @override
  void initState() {
    super.initState();
    _viewType = 'plugin-tab-${widget.entryPath}-$hashCode';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = web.HTMLIFrameElement()
        ..src = _pluginUrl
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
