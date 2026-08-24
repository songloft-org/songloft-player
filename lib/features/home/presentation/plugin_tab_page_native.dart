import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_config.dart';
import '../../../core/storage/secure_storage.dart';
import '../../settings/presentation/providers/settings_provider.dart';
import 'plugin_tab_back_registry.dart';
import 'plugin_theme_utils.dart';
import 'render/plugin_render_controller.dart';
import 'render/plugin_render_engine_provider.dart';
import 'render/plugin_render_view.dart';

/// 插件 Tab 页面（原生平台实现）
/// 在 Shell 内嵌入插件页展示，底部导航栏保持可见。
///
/// 渲染、加载态、超时与错误处理全部委托 [PluginRenderView]；本页只负责 Tab
/// 特有的壳：URL 拼装、返回键接管、切走时释放焦点。
class PluginTabPage extends ConsumerStatefulWidget {
  final String entryPath;
  final bool isActive;

  const PluginTabPage({
    super.key,
    required this.entryPath,
    this.isActive = true,
  });

  @override
  ConsumerState<PluginTabPage> createState() => _PluginTabPageState();
}

class _PluginTabPageState extends ConsumerState<PluginTabPage> {
  PluginRenderController? _renderController;

  @override
  void didUpdateWidget(covariant PluginTabPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive == widget.isActive) return;
    if (!widget.isActive) {
      // 原生 WebView 即使被 Offstage 隐藏仍可在系统层面持有键盘焦点，
      // 释放焦点以防止抢夺 Flutter 输入法上下文。
      _renderController?.clearFocus();
    }
    // Tab 保活走 Offstage（controller 不销毁、页面 JS 状态完整保留），页面自己
    // 发现不了「被藏起来又被显示出来」，必须由宿主推——见 setPageVisible 的注释。
    _renderController?.setPageVisible(widget.isActive);
  }

  @override
  void dispose() {
    // 注销返回处理，避免路由层 PopScope 回调打到已销毁的渲染面上。
    PluginTabBackRegistry.unregister(widget.entryPath);
    super.dispose();
  }

  String _buildPluginUrl(String theme) {
    final token = SecureStorageService.cachedAccessToken ?? '';
    final uri = Uri.parse(
      '${AppConfig.resolvedBaseUrl}${AppConfig.basePath}/api/v1/jsplugin/${widget.entryPath}',
    );
    final query =
        Map<String, String>.from(uri.queryParameters)
          ..['embed'] = ''
          ..['theme'] = theme;
    if (token.isNotEmpty) {
      query['access_token'] = token;
    }
    return ensurePluginPathTrailingSlash(
      uri.replace(queryParameters: query).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final brightness = MediaQuery.platformBrightnessOf(context);
    final theme = resolveEffectiveTheme(themeMode, brightness);

    // 渲染引擎由插件自己的 plugin.json 声明（songloft-org/songloft#341），需要先
    // 拿到插件列表才知道用哪个。null = 还不知道 → 只显示 loading，**不挂渲染面**：
    // 先按默认 WebView 渲染再切 WebF 会让整页加载两次。理由见 provider 注释。
    final engine = ref.watch(pluginRenderEngineForProvider(widget.entryPath));

    // 返回键接管在路由层 `/plugin-tab` 页的 PopScope 里（经
    // [PluginTabBackRegistry] 调到本页的 `_renderController.goBackIfPossible`）：
    // 本页真实内容由 ShellLayout 用 Offstage 保活、不在路由页树内，本页挂的
    // PopScope 不会被 go_router 咨询，故改由路由页统一处理。
    return SafeArea(
      bottom: false,
      child:
          engine == null
              ? const Center(child: CircularProgressIndicator())
              : PluginRenderView(
                url: _buildPluginUrl(theme),
                theme: theme,
                engine: engine,
                // Tab 靠 shell 层 Offstage 保活，Hybrid Composition 下反复切换
                // 会让 overlay 重建异常、把底部 NavigationBar 抹成黑块，故用
                // Virtual Display（songloft-org/songloft#273）。
                useHybridComposition: false,
                onControllerReady: (controller) {
                  _renderController = controller;
                  PluginTabBackRegistry.register(widget.entryPath, () {
                    return _renderController?.goBackIfPossible() ??
                        Future.value(false);
                  });
                },
              ),
    );
  }
}
