# AGENTS.md

本文件为 AI 编程助手提供 Songloft Flutter 前端的**入口信息**。代码本身是真实来源，本文件仅提供导航和约定。

> **详细文档**：
> - 开发指南：[docs/development.md](docs/development.md)
> - 架构补充：[docs/architecture.md](docs/architecture.md)
> - Domain 层架构：[docs/cn/domain_layer.md](docs/cn/domain_layer.md)
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
│   ├── library/           # 歌曲库（分页、搜索、编辑、收藏）；domain/use_cases/ 含 FavoriteService
│   ├── player/            # 播放器；domain/use_cases/ 含 PlayQueue、PlayModeResolver、RetryPolicy、QueueLoader 等
│   ├── playlist/          # 歌单管理；domain/use_cases/ 含 PlaylistSort（支持拼音比较器）
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

## 代码格式化（铁律）

每次修改代码后**必须**格式化，提交前确认无格式差异：

```bash
dart format lib/ test/
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
| `libraryStatsProvider` | 同上 | 曲库汇总统计（首页底部面板，`GET /songs/stats`） |
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

详见 [docs/backend_hotupdate.md](docs/backend_hotupdate.md)（Bundle 统一模型,权威）。要点:

- **无基线 + 自动发布**:客户端查**本渠道最新**（dev→`dev` tag;stable→`/releases/latest`,`channel_release_resolver.dart`）；`release.yml` 的 `build-bundled-android` 每次发版**自动**产出并上传前端 `patch-<abi>-<commit>.zip`+`manifest`、后端 `libgojni-<abi>-<commit>.so`+`backend-manifest`（无手动 workflow）。
- **合并为一次体验**:`PatchUpdateDialog.maybeShow`（`lib/core/updater/`）每会话并行检查两类补丁,一个对话框列出、一起下载、**只重启一次**（`EmbeddedBackendService.restartProcess` 真进程冷启 —— libapp.so 生效 + `SongloftApplication` 预加载 libgojni.so）。
- **启动检查的三道闸 + 手动入口**（不要退回「首帧就打网络」）:触发点在 `ShellLayout`（**不是** HomePage —— Shell 全会话常驻,且 TvHomePage 也在它下面,TV 因此一并覆盖）,顺序是**先 `ref.listenManual(authStateProvider)` 等 `authenticated`、再排 `kPatchCheckStartupDelay`(4s) 的可取消 `Timer`**（只判 `mounted` 是竞态:认证慢于延迟时,登录前那次短命挂载会吃掉本会话唯一的检查名额、写掉节流窗口,还带无 token 的 dio 去查;`Timer` 而非 `Future.delayed` 是为了能在 `dispose` 取消）。受「启动时自动检查更新」开关（`autoUpdateCheckProvider`,prefs `auto_update_check_enabled`,缺省开）与 `kPatchCheckThrottle`(6h,prefs `last_patch_check_at`) 节流约束;检查阶段套 45s 整体超时（代理失败会降级直连，单请求最坏翻倍）;节流判定必须带 `elapsed >= 0`（时钟被往回调过时未来时间戳会把检查挡死到真实时间追上）。**查到补丁但 `context` 已卸载时要回滚节流时间戳**,且单独打日志别复用「无可热更补丁」那条。手动入口合并在「设置 → 关于与更新 → 检查客户端更新」,走 `maybeShow(manual: true)`:跳过两道闸、**绕过（非清除）「忽略此版本」名单**、不写节流时间戳,无补丁时落回 `FrontendUpgradeDialog`（它自带三态,故不额外 snackbar）。闸门语义由 `test/core/updater/patch_update_dialog_gates_test.dart` 覆盖。
- **兼容键取代 versionCode**（自动、非手改）:前端用 **Flutter 引擎版本**（`AppConfig.flutterBinding` = CI `FLUTTER_VERSION`,manifest 带 `flutterBinding`;相同即兼容并 `targetVersionCode=null` 跨 versionCode 放行,不同→整包）;后端用**导出面冻结**（`mobile/export_surface.txt` + `release.yml` 守卫）,无 versionCode。
- **原生契约哈希闸**（Dart↔原生 MethodChannel / Go 导出面运行时校验,拦「热更 Dart 调旧 APK 不存在的原生方法」）:原生 channel `com.songloft/contract` 的 `getHash` 返回 `{dart,go}`（值由 CI `scripts/compute_native_contract.sh` 构建期算出、同时烧进 APK asset 与 manifest `contractHash`）。`checkPatch` 用 `contractHashBlocks` 比对,不等落整包,任一空则降级不拦。全自动无需 bump 常量。标准版 + bundle 通用（iOS 不参与）。见 `docs/cn/backend_hotupdate.md`。
- 比较分渠道:**dev 比 git commit hash、stable 比版本号**（`version_compare.dart`）;崩溃回滚由原生 `BackendPatchManager`（pending→confirmed + 黑名单）负责。
- 标准版（非 bundle）也无基线:本仓库 `build-and-release.yml` 的 `build-android` 每次发版自动产出前端 `patch-<abi>-<commit>.zip`+`manifest`（无后端）；手动 `patch-release.yml` 已删。前端跨版本靠**恒定 versionCode**（pubspec `+N` 不 bump）+ 引擎键(`flutterBinding`)兜底,非手挑基线。客户端对老式 manifest 向后兼容。

### Kotlin 层冻结规则（Android 热更安全边界）

目的：让 `compute_native_contract.sh` 产出的 dart 契约哈希在日常迭代中**保持不变**，避免 `libapp.so` 热更被阻断、用户被迫跳设置页下整包 APK。非 Bundle 版没有 Go 后端可下沉，此规则尤为关键。

**硬规则：**

1. **禁止新增 MethodChannel 方法名** —— 不得在 Kotlin `when(call.method)` 中加新分支。契约哈希脚本用 `grep` 提取 `call.method == "x"` 和 `"x" ->` 模式，新增即变哈希。
2. **扩展已有方法的参数 Map** —— 需要新的配置/样式/行为参数时，往现有方法（`show` / `updateConfig`）的参数 Map 里加 key。Kotlin 侧用 `call.argument<T>("newKey")` 读取，缺失时取默认值（向后兼容）。这不改变方法名集合 → 哈希不变。
3. **用 `exec` 逃逸方法扩展不可参数化的新能力** —— `FloatingLyricPlugin` 已预埋 `exec` 方法。新原生能力（如查询窗口边界、新交互模式）通过 `exec` + `cmd` 参数实现。**子命令分发必须用 `if/else`，禁止用 `when`**（`"x" ->` 会被哈希脚本捕获）。Dart 侧调 `exec` 返回 null 表示当前 APK 不支持（优雅降级）。
4. **优先选纯 Dart 实现的 Flutter 插件** —— 增删带原生代码的 Flutter 插件会改变 `GeneratedPluginRegistrant` → 哈希变。能用 Dart 实现就不引入原生插件。
5. **必须改 Kotlin 时视为「整包发版」事件** —— 在 commit message 中明确标注：`feat(android)!: add new native channel (breaks hot-update contract hash)`。

**不影响哈希（无需担心）：**

- Kotlin→Dart 反向回调（`channel.invokeMethod`）不被哈希脚本捕获，可自由新增。
- `updateConfig` / `show` 的参数 Map 新增 key 不影响哈希。
- SharedPreferences 的 key（Widget 数据通道）不影响哈希。
- `exec` 内部用 `if/else` 新增的子命令不影响哈希。

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
