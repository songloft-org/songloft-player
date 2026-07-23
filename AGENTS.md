# AGENTS.md

本文件为 AI 编程助手提供 Songloft Flutter 前端的**入口信息**。代码本身是真实来源，本文件仅提供导航和约定。

> **详细文档**：
> - 开发指南：[docs/development.md](docs/development.md)
> - 架构补充：[docs/architecture.md](docs/architecture.md)
> - 平台注意事项：[docs/platform-notes.md](docs/platform-notes.md)
> - 构建指南：[docs/build_guide.md](docs/build_guide.md)
> - 版本发布：[scripts/README.md](scripts/README.md)
> - 架构概览：父仓库 `docs/architecture_frontend.md`
> - 颜色系统：父仓库 `docs/color_system.md`

---

## 项目概述

Songloft 跨平台音乐播放器，基于 Flutter 3.29+ / Dart 3.7+ 构建，支持 iOS、Android、macOS、Windows、Linux、Web 六端。

独立仓库 [songloft-org/songloft-player](https://github.com/songloft-org/songloft-player)，作为父仓库 [songloft](https://github.com/songloft-org/songloft) 的子模块。后端 API 默认 `http://localhost:58091`（账号 admin/admin）。

---

## 目录结构速查

```
lib/
├── main.dart              # 应用入口，audioHandlerProvider 定义在此
├── config/                # app_config（部署模式、baseUrl）、constants（分页、播放模式、歌曲类型）
├── core/                  # 核心基础设施
│   ├── audio/             # SongloftAudioHandler、system_volume_provider
│   ├── env/               # tv_detector（TV 模式检测）
│   ├── network/           # api_client（Dio）、auth_interceptor（JWT 双 Token）、base_url_provider、servers_provider
│   ├── platform/          # live_activity_service（iOS Live Activity）
│   ├── router/            # app_router（GoRouter + 认证守卫）
│   ├── storage/           # secure_storage、app_preferences、playback_state、lyric_cache
│   ├── theme/             # app_theme（Material 3）、responsive（4 级断点）、tv_theme、app_dimensions
│   ├── tracely/           # tracely_client（可选监控）
│   └── utils/             # formatters、platform_utils、url_helper、window_tray_manager、color_extraction
├── features/              # 功能模块，每个含 data/domain/presentation 三层
│   ├── auth/              # 认证（登录/登出/Token 管理）
│   ├── home/              # 首页 + 插件 Tab/WebView
│   ├── jsplugin/          # JS 插件管理（安装/更新/注册表）
│   ├── library/           # 歌曲库（分页、搜索、编辑、收藏）
│   ├── player/            # 播放器（桌面/移动/TV/迷你 多布局 + 歌词）
│   ├── playlist/          # 歌单管理（CRUD、排序、批量操作）
│   ├── settings/          # 设置（扫描/缓存/升级/Tab 配置/重复检查/多服务器/HLS 代理/HTTP 代理）
│   └── startup/           # 启动门控（加载完成前的等待页）
└── shared/                # 共享层
    ├── layouts/           # adaptive_scaffold、shell_layout、active_destinations
    ├── models/            # Song、Playlist、Pagination、ApiResponse
    ├── utils/             # responsive_snackbar
    └── widgets/           # cover_image、confirm_dialog、song_picker、tv_focusable 等
```

---

## 常用命令

```bash
flutter pub get                                       # 安装依赖
flutter run -d chrome --no-web-resources-cdn           # Web standalone 开发
flutter run -d chrome --dart-define=DEPLOY_MODE=embedded  # Web embedded 开发
flutter run -d macos                                   # macOS 开发
flutter run -d linux                                   # Linux 开发
flutter analyze                                        # 静态分析
flutter test                                           # 运行测试

# 构建脚本
./scripts/build-frontend.sh <platform|all>             # 多平台构建
./scripts/release-frontend.sh <patch|minor|major>      # 版本发布
```

---

## 编码约定

- **状态管理**：flutter_riverpod 手写 Provider（**不使用** code generation / build_runner），三种类型：`Provider`、`NotifierProvider`、`FutureProvider`（含 `AsyncNotifierProvider`）
- **路由**：go_router 声明式路由，路径常量定义在 `AppRoutes`，认证守卫在 `redirect` 中
- **HTTP**：Dio 封装在 `core/network/api_client.dart`，`AuthInterceptor` 自动处理 JWT 双 Token 刷新
- **主题**：Material 3，seedColor `indigo-500`，**禁止**硬编码颜色值，一律 `Theme.of(context).colorScheme`
- **响应式**：4 级断点 — Mobile < 600px / Tablet 600-900px / Desktop 900-1920px / TV >= 1920px
- **条件导入**：Web 平台不支持的功能用 stub + native 文件对（如 `plugin_webview_page.dart` / `_native.dart` / `_stub.dart`）
- **import 路径**：相对路径（`../../`）
- **Lint 规则**（`analysis_options.yaml`）：`prefer_const_constructors`、`prefer_single_quotes`、`avoid_print`、`prefer_const_declarations`
- **Feature 模块结构**：`features/<name>/data/`（API 类 + Repository）、`domain/`（状态模型 + 业务逻辑）、`presentation/`（页面 + `providers/` + `widgets/`）

---

## 核心 Provider 速查

| Provider | 文件 | 职责 |
|----------|------|------|
| `authStateProvider` | `features/auth/.../auth_provider.dart` | 认证状态（登录/登出/Token） |
| `appPreferencesProvider` | 同上 | 本地偏好设置 |
| `playerStateProvider` | `features/player/.../player_provider.dart` | 播放器完整状态（当前歌曲、队列、播放模式、进度） |
| `audioHandlerProvider` | `main.dart` | SongloftAudioHandler 单例 |
| `lyricStateProvider` | `features/player/.../lyric_provider.dart` | 歌词解析与当前行定位 |
| `songsListProvider` | `features/library/.../songs_provider.dart` | 歌曲列表分页加载 |
| `songDetailProvider` | 同上 | 单曲详情 |
| `favoriteProvider` | `features/library/.../favorite_provider.dart` | 收藏状态管理 |
| `playlistListProvider` | `features/playlist/.../playlist_provider.dart` | 歌单列表 |
| `playlistNotifierProvider` | 同上 | 歌单 CRUD 操作 |
| `dioProvider` | `core/network/api_client.dart` | Dio HTTP 客户端 |
| `baseUrlProvider` | `core/network/base_url_provider.dart` | 动态 baseUrl 切换 |
| `serversProvider` | `core/network/servers_provider.dart` | 多服务器管理 |
| `routerProvider` | `core/router/app_router.dart` | GoRouter 实例 |
| `themeModeProvider` | `features/settings/.../settings_provider.dart` | 亮色/暗色/跟随系统 |
| `tabConfigProvider` | 同上 | 底栏/侧栏 Tab 配置 |
| `activeDestinationsProvider` | `shared/layouts/active_destinations.dart` | 当前激活的导航目标 |

---

## API 类

每个 feature 的 `data/` 层有对应的 API 类，封装后端 HTTP 调用：

| API 类 | 文件 | 对应后端模块 |
|--------|------|-------------|
| `AuthApi` | `features/auth/data/auth_api.dart` | 认证 |
| `SongsApi` | `features/library/data/songs_api.dart` | 歌曲 |
| `PlaylistApi` | `features/playlist/data/playlist_api.dart` | 歌单 |
| `ScanApi` | `features/settings/data/scan_api.dart` | 扫描 |
| `ConfigApi` | `features/settings/data/config_api.dart` | 通用配置 KV |
| `SettingsApi` | `features/settings/data/settings_api.dart` | 业务设置端点 |
| `CacheApi` | `features/settings/data/cache_api.dart` | 缓存管理 |
| `UpgradeApi` | `features/settings/data/upgrade_api.dart` | 升级 |
| `JSPluginApi` | `features/jsplugin/data/jsplugin_api.dart` | JS 插件 |
| `DirectoryApi` | `features/settings/data/directory_api.dart` | 目录浏览 |
| `FrontendVersionApi` | `features/settings/data/frontend_version_api.dart` | 前端版本检查 |

---

## 路由表

路径常量定义在 `core/router/app_router.dart` 的 `AppRoutes` 类：

| 路径 | 页面 |
|------|------|
| `/login` | 登录页 |
| `/` | 首页 |
| `/library` | 歌曲库 |
| `/playlists` | 歌单列表 |
| `/playlists/:id` | 歌单详情 |
| `/settings` | 设置页 |
| `/settings/servers` | 多服务器管理 |
| `/settings/tab-config` | Tab 配置 |
| `/settings/duplicate-check` | 重复检查 |
| `/settings/plugin-registry` | 插件注册表 |
| `/plugin` | 插件主页 |
| `/plugin-tab/:entryPath` | 插件 Tab 页 |

---

## 部署模式

| 模式 | 编译参数 | 说明 |
|------|---------|------|
| standalone | 默认（不传 `--dart-define`） | 前后端分离，显示 API 地址配置 UI |
| embedded | `--dart-define=DEPLOY_MODE=embedded` | 嵌入 Go 后端同域部署，隐藏 API 地址 UI |

`AppConfig.isEmbedded` 是编译时常量，tree-shaking 会移除未使用分支。嵌入模式下 `Uri.base.path` 自动检测子路径部署。

### Bundle 本地模式（HAS_BACKEND）与更新仓库口径（踩坑）

Bundle 版通过 `--dart-define=HAS_BACKEND=true` 注入（`AppConfig.hasEmbeddedBackend`），在设备上内嵌 Go 后端运行，**与 embedded（`DEPLOY_MODE`）正交**：bundle 版并不设 `DEPLOY_MODE=embedded`，故 `isEmbedded=false`，设置页的「检查客户端更新」tile 照常显示。

**关键：两类客户端发布在不同仓库，更新检查必须区分。**

| 版本 | 发布仓库 | 产物名 | 由谁构建 |
|------|---------|--------|---------|
| 标准版 | `songloft-org/songloft-player` | `songloft-*.apk` 等 | 本仓库 `build-and-release.yml` |
| Bundle 版 | 父仓库 `songloft-org/songloft` | `songloft-bundled-*` | 父仓库 `release.yml` |

- `FrontendVersionApi` 的更新检查仓库由 `AppConfig.frontendUpdateRepo`（`hasEmbeddedBackend ? frontendBundleRepo : frontendRepo`，编译期固定）决定；`frontendUpdateReleasesUrl` 同理。
- **不要**在更新流程里硬编码 `songloft-org/songloft-player`：bundle 版注入的 `FRONTEND_VERSION` 是父仓库 tag，若仍查 player 仓库，版本比较口径错配、且用户会下载到丢失内嵌后端的标准版覆盖安装。
- `frontendRepo` / `frontendReleasesUrl` 保留原义，仅供 Web 端 `client_download_page.dart` 的「标准版下载」区使用（该页 web-only）。

### 热更新（前端 libapp.so + Bundle 版 Android 后端 libgojni.so）

- **前端热更**（flutter_patcher 换 `libapp.so`，仅 Android）：见 [docs/flutter_patcher_hotupdate.md](docs/flutter_patcher_hotupdate.md)。
- **后端热更**（Bundle 版换 gomobile 的 `libgojni.so`，仅 Android + `hasEmbeddedBackend` + local 模式）：见 [docs/backend_hotupdate.md](docs/backend_hotupdate.md)。
- 两者**合并为一次体验**：`PatchUpdateDialog.maybeShow`（`lib/core/updater/`）每会话并行检查两类补丁，一个对话框列出、一起下载、**只重启一次**（`EmbeddedBackendService.restartProcess` 真进程冷启 —— libapp.so 冷启生效 + `SongloftApplication` 预加载 libgojni.so）。
- 版本比较分渠道：**dev 比 git commit hash、stable 比版本号**（`lib/core/updater/version_compare.dart`）；不跨渠道。补丁均托管在 `frontendUpdateRepo`（bundle=父仓库）同一 tag。
- 后端补丁铁律：`mobile.go` 导出面（Start/Stop/IsRunning/GetPort）冻结，`mobile/export_surface.txt` + CI 守卫 + `targetVersionCode` 绑定三道门禁；崩溃回滚由原生 `BackendPatchManager` 的 pending→confirmed 状态机 + 黑名单负责。

---

## Git 提交约定

- **禁止** `Co-Authored-By` 尾部标记
- Conventional Commits 格式：`type(scope): description`
- 引用父仓库 issue **必须**带完整路径：`songloft-org/songloft#NNN`（不能只写 `#NNN`，否则 GitHub 解析为本仓库 issue）

---

## 测试

```bash
flutter test
```

测试文件放在 `test/` 下对应 `lib/` 的路径结构。当前测试文件：

- `test/core/env/tv_detector_test.dart`
- `test/features/player/domain/lyric_parser_test.dart`
- `test/features/home/presentation/tv_home_page_test.dart`
- `test/shared/widgets/tv_focusable_test.dart`
- `test/widget_test.dart`
