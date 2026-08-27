import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/auth_state.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

import '../../features/home/presentation/home_page.dart';
import '../../features/home/presentation/plugin_webview_page.dart';
import '../../features/home/presentation/plugin_tab_back_registry.dart';
import '../../features/library/presentation/library_page.dart';
import '../../features/library/presentation/category_songs_page.dart';
import '../../features/library/presentation/tag_songs_page.dart';
import '../../features/playlist/presentation/playlist_detail_page.dart';
import '../../features/settings/presentation/servers_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/settings/presentation/tab_config_page.dart';
import '../../features/jsplugin/presentation/widgets/plugin_registry.dart';
import '../../features/settings/presentation/duplicate_check_page.dart';
import '../../features/settings/presentation/shortcut_settings_page.dart';
import '../../features/settings/presentation/client_download_page.dart';
import '../../features/settings/presentation/licenses_page.dart';
import '../../features/settings/presentation/widgets/settings_category_content.dart';
import '../../features/settings/presentation/providers/settings_provider.dart';
import '../../features/player/presentation/widgets/mobile_player.dart';
import '../../features/player/presentation/widgets/desktop_full_player.dart';
import '../../shared/layouts/shell_layout.dart';
import '../theme/responsive.dart';
import '../../l10n/app_localizations.dart';

/// 从插件页 URL 里取 `entryPath`：`.../api/v1/jsplugin/<entryPath>[/...]`。
///
/// 用正则而不是按路径段索引：调用方传进来的 url 形态不统一（有的带尾斜杠、有的带
/// query、子路径部署时前缀还会多一段），按段数取会错位。
String? _pluginEntryPathFromUrl(String url) {
  final match = RegExp(r'/jsplugin/([^/?#]+)').firstMatch(url);
  final entryPath = match?.group(1);
  return (entryPath == null || entryPath.isEmpty) ? null : entryPath;
}

/// 路由路径常量
class AppRoutes {
  static const String login = '/login';
  static const String home = '/';
  static const String library = '/library';
  static const String playlists = '/playlists';
  static const String playlistDetail = '/playlists/:id';
  static const String settings = '/settings';
  static const String servers = '/settings/servers';
  static const String tabConfig = '/settings/tab-config';
  static const String duplicateCheck = '/settings/duplicate-check';
  static const String shortcuts = '/settings/shortcuts';
  static const String clientDownload = '/settings/download';
  static const String pluginRegistry = '/settings/plugin-registry';
  static const String licenses = '/settings/licenses';
  static const String settingsCategory = '/settings/category/:index';
  static const String plugin = '/plugin';
  static const String pluginTab = '/plugin-tab/:entryPath';
  static const String player = '/player';
}

/// 将 Riverpod 认证状态变化桥接为 GoRouter 的 refreshListenable，
/// 避免每次 auth 状态变化都重建 GoRouter 实例。
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    ref.listen(authStateProvider, (_, _) {
      notifyListeners();
    });
  }
}

/// GoRouter Provider
/// 根 Navigator key，供路由体系外的全局逻辑（如 Web 更新提示弹窗）拿到
/// 位于 MaterialApp 之下的 BuildContext 弹出对话框。
final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authChangeNotifier = _AuthChangeNotifier(ref);

  ref.onDispose(() {
    authChangeNotifier.dispose();
  });

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: true,
    refreshListenable: authChangeNotifier,
    redirect: (context, state) {
      // 在 redirect 回调中直接读取最新状态（不使用 ref.watch）
      final authState = ref.read(authStateProvider);
      final isAuthenticated = authState.status == AuthStatus.authenticated;
      final isAuthResolved = authState.status != AuthStatus.unknown;

      // 认证状态尚未确定（正在从存储中读取 token），不做跳转
      if (!isAuthResolved) {
        return null;
      }

      final isLoggingIn = state.uri.path == AppRoutes.login;

      // 未认证且不在登录页面，跳转到登录页
      if (!isAuthenticated && !isLoggingIn) {
        return AppRoutes.login;
      }

      // 已认证且在登录页面，跳转到首页
      if (isAuthenticated && isLoggingIn) {
        return AppRoutes.home;
      }

      // 其他情况不做跳转
      return null;
    },
    routes: [
      // 登录页面（独立路由，不使用 ShellRoute）
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),

      // 插件 WebView 页面（独立路由，全屏显示，不显示底部导航）
      GoRoute(
        path: AppRoutes.plugin,
        // ⚠️ **已注册为 Tab 的插件转到 Tab 页，不再开这条独立路由。**
        // 两者给 PluginRenderView 传的 url 相同，而 WebF 的 controller 缓存键是
        // 「去掉 query 的 URL」（`plugin_render_surface_webf.dart` 的
        // `_controllerNameFor`），于是**两条入口指向同一个 WebFController**。
        // 让同一插件只有一个入口，既避免两个渲染面同时持有一个 controller，
        // 也避免「独立页 push/pop 一次 = Tab 页的渲染面被销毁再重建」这种
        // 白白丢掉页面状态的抖动（songloft-org/songloft#341）。
        //
        // 注意 Tab 页**并非所有平台都保活**：Web 与移动端用 Offstage 保活，
        // 桌面端（Windows/macOS/Linux）切走即销毁（见 `shell_layout.dart`，
        // 规避 #246 的 WebView2 残留灰块）。所以桌面端上这条 redirect 省掉的是
        // 一次真实的 dispose + 重新挂载，收益比 Web/移动端更大。
        redirect: (context, state) {
          final entryPath = _pluginEntryPathFromUrl(
            state.uri.queryParameters['url'] ?? '',
          );
          if (entryPath == null) return null;
          // 配置还没到就别拦：宁可放过（顶多白屏一次）也不要把导航卡住。
          final tabs = ref.read(tabConfigProvider).asData?.value.pluginTabs;
          if (tabs == null) return null;
          if (tabs.any((t) => t.entryPath == entryPath)) {
            return '/plugin-tab/$entryPath';
          }
          return null;
        },
        builder: (context, state) {
          final url = state.uri.queryParameters['url'] ?? '';
          final name = state.uri.queryParameters['name'] ?? '';
          return PluginWebViewPage(pluginUrl: url, pluginName: name);
        },
      ),

      // 全屏播放器（独立顶层路由，全屏无导航栏，与 /login、/plugin 同级）。
      // 做成真实路由而非命令式 Navigator.push，让浏览器/系统返回键在 Web 上
      // 也能关闭播放器。按屏幕类型分派 Mobile/Desktop 两种全屏播放器，
      // 分派规则与 shell_layout 的 _openFullPlayerForScreen 一致。
      GoRoute(
        path: AppRoutes.player,
        pageBuilder: (context, state) {
          final page =
              int.tryParse(state.uri.queryParameters['page'] ?? '') ?? 0;
          final screenType = context.screenType;
          final Widget child;
          if (screenType == ScreenType.mobile) {
            child = MobilePlayer(initialPage: page);
          } else {
            child = const DesktopFullPlayer();
          }
          return CustomTransitionPage(
            key: state.pageKey,
            opaque: true,
            transitionDuration: const Duration(milliseconds: 300),
            reverseTransitionDuration: const Duration(milliseconds: 300),
            transitionsBuilder: (context, animation, secondaryAnimation, c) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
                child: c,
              );
            },
            child: child,
          );
        },
      ),

      // 主应用路由（使用 ShellRoute 包含导航和播放器）
      ShellRoute(
        builder: (context, state, child) => ShellLayout(child: child),
        routes: [
          // 首页
          GoRoute(
            path: AppRoutes.home,
            pageBuilder:
                (context, state) => const NoTransitionPage(child: HomePage()),
          ),

          // 曲库
          GoRoute(
            path: AppRoutes.library,
            pageBuilder:
                (context, state) => NoTransitionPage(
                  child: LibraryPage(
                    initialViewKey: state.uri.queryParameters['view'],
                  ),
                ),
          ),

          // 某分类下的歌曲列表。value 走 query 参数：专辑/歌手名可能含
          // % / 等字符，放路径段会触发 go_router 的编解码歧义与双重解码。
          GoRoute(
            path: '/library/categories/:field',
            builder: (context, state) {
              final field = state.pathParameters['field'] ?? '';
              final value = state.uri.queryParameters['value'] ?? '';
              final cover = state.uri.queryParameters['cover'];
              return CategorySongsPage(
                field: field,
                value: value,
                coverUrl: cover,
              );
            },
          ),

          // 标签下的歌曲列表
          GoRoute(
            path: '/library/tags/:tagId',
            builder: (context, state) {
              final tagId =
                  int.tryParse(state.pathParameters['tagId'] ?? '') ?? 0;
              final name = state.uri.queryParameters['name'] ?? '';
              final cover = state.uri.queryParameters['cover'];
              return TagSongsPage(
                tagId: tagId,
                tagName: name,
                coverUrl: cover,
              );
            },
          ),

          // 歌单列表已并入曲库（曲库的「全部歌单/普通歌单/电台歌单」视图）。
          // 旧入口重定向到曲库，避免死链。
          GoRoute(
            path: AppRoutes.playlists,
            redirect: (context, state) => AppRoutes.library,
          ),

          // 歌单详情
          GoRoute(
            path: AppRoutes.playlistDetail,
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return PlaylistDetailPage(playlistId: id);
            },
          ),

          // 设置
          GoRoute(
            path: AppRoutes.settings,
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: SettingsPage()),
          ),

          // 服务器列表管理
          GoRoute(
            path: AppRoutes.servers,
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: ServersPage()),
          ),

          // 菜单设置
          GoRoute(
            path: AppRoutes.tabConfig,
            builder: (context, state) => const TabConfigPage(),
          ),

          // 重复歌曲检测
          GoRoute(
            path: AppRoutes.duplicateCheck,
            builder: (context, state) => const DuplicateCheckPage(),
          ),

          // 键盘快捷键（仅桌面从设置进入）
          GoRoute(
            path: AppRoutes.shortcuts,
            builder: (context, state) => const ShortcutSettingsPage(),
          ),

          // 客户端下载（仅 Web 访问时从设置进入）
          GoRoute(
            path: AppRoutes.clientDownload,
            builder: (context, state) => const ClientDownloadPage(),
          ),

          // 插件商店
          GoRoute(
            path: AppRoutes.pluginRegistry,
            builder: (context, state) => const PluginRegistryPage(),
          ),

          // 开源许可（GPL-3.0 分发声明 + 内嵌许可全文，songloft-org/songloft#341）
          GoRoute(
            path: AppRoutes.licenses,
            builder: (context, state) => const LicensesPage(),
          ),

          // 设置分类详情（移动端二级页）。做成真实路由让浏览器/系统返回键回到
          // 设置一级列表；宽屏 master-detail 仍在 SettingsPage 内同页切换。
          GoRoute(
            path: AppRoutes.settingsCategory,
            redirect: (context, state) {
              // 越界防御（不在 redirect 里依赖 l10n，用固定分类数常量）。
              final index = int.tryParse(state.pathParameters['index'] ?? '');
              if (index == null ||
                  index < 0 ||
                  index >= settingsCategoryCount) {
                return AppRoutes.settings;
              }
              return null;
            },
            builder: (context, state) {
              final index = int.parse(state.pathParameters['index']!);
              final categories = buildSettingsCategories(
                AppLocalizations.of(context),
              );
              return Scaffold(
                appBar: AppBar(title: Text(categories[index].title)),
                body: SettingsCategoryContent(index: index),
              );
            },
          ),

          // 插件 Tab 页面（实际渲染由 ShellLayout 管理，此处仅作路由占位）
          GoRoute(
            path: AppRoutes.pluginTab,
            pageBuilder: (context, state) {
              final entryPath = state.pathParameters['entryPath'] ?? '';
              // canPop:false 让嵌套 navigator 的 maybePop 返回 false，从而进入下面的
              // onExit 兜底——由它经 PluginTabBackRegistry 调插件 consumeBack：
              // 有浮层/编辑器就收起（onExit 返回 false=阻止退出，留页），没有就
              // context.go(home) 退回首页 tab（而非退出 App）。
              // 直接 canPop:true 的话 maybePop 会弹出这个占位路由→直接回 Library，
              // 绕过插件内部返回。
              return NoTransitionPage(
                key: ValueKey('plugin-tab-$entryPath'),
                child: PopScope(
                  canPop: false,
                  // 返回键由路由页的 PopScope 统一接管（canPop:false 阻止系统弹栈，
                  // onPopInvokedWithResult 在每次返回时触发）：有浮层/编辑器/非 main
                  // 页就调插件 consumeBack 收起并吞掉这次返回；否则退回首页 tab。
                  // 之前只挂 onExit 时，go_router 在 webf 覆盖层打开时不咨询 onExit，
                  // 导致「打开设备选择器后返回键直接吞掉、不收起」；PopScope 的
                  // onPopInvokedWithResult 是 Flutter 层回调，对每次系统返回都稳定触发。
                  onPopInvokedWithResult: (didPop, result) async {
                    if (didPop) return;
                    final consumed = await PluginTabBackRegistry.handleBack(
                      entryPath,
                    );
                    if (!consumed && context.mounted) {
                      context.go(AppRoutes.home);
                    }
                  },
                  child: const SizedBox.shrink(),
                ),
              );
            },
          ),
        ],
      ),
    ],
    errorBuilder:
        (context, state) => Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context).coreNotFoundPageTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  state.uri.path,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => context.go(AppRoutes.home),
                  icon: const Icon(Icons.home),
                  label: Text(AppLocalizations.of(context).coreBackToHome),
                ),
              ],
            ),
          ),
        ),
  );
});
