# 架构补充说明

> 完整架构概览见父仓库 `docs/architecture_frontend.md`（目录结构、页面路由、响应式布局、主题系统、部署模式概述）。本文档聚焦实现层面的补充细节。

---

## 状态管理

### Provider 类型选择

项目使用 flutter_riverpod，手写 Provider（不使用 code generation）：

| 类型 | 适用场景 | 示例 |
|------|---------|------|
| `Provider` | 无状态的单例/计算值 | `dioProvider`、`routerProvider`、`isPlayingProvider` |
| `NotifierProvider` | 同步有状态的业务逻辑 | `playerStateProvider`、`authStateProvider`、`baseUrlProvider` |
| `AsyncNotifierProvider` | 异步有状态 + CRUD | `serversProvider`、`playlistListProvider`、`songsListProvider` |
| `FutureProvider` | 一次性异步加载 | `songDetailProvider`、`configsProvider`、`appPreferencesProvider` |
| `FutureProvider.family` | 带参数的异步加载 | `songDetailProvider(id)`、`playlistDetailProvider(id)` |
| `StreamProvider` | 持续数据流 | `systemVolumeProvider` |

### Provider 依赖链

```
appPreferencesProvider (SharedPreferences)
    ↓
secureStorageProvider → dioProvider → [各 feature 的 xxxApiProvider]
    ↓                       ↓
authStateProvider      baseUrlProvider ← serversProvider
    ↓
routerProvider (redirect 守卫)
```

核心原则：`dioProvider` 通过 `ref.watch(baseUrlProvider)` 监听 baseUrl 变化，baseUrl 改变时自动重建 Dio 实例，下游所有 API Provider 随之更新。

### PlayerNotifier 生命周期

`PlayerNotifier` 是项目中最复杂的 Notifier（~1600 行），关键内部机制：

- **播放代次 `_playGeneration`**：用户快速切歌时，旧的 `playByIndex()` 协程在 await 后检测 generation 变化后退出，避免竞态
- **预拉取 `_prefetchCancelToken`**：播放过程中提前请求下一首歌的元数据，剩余 30s 触发保险预拉取（`_lateStagePrefetchFired`）
- **随机去重 `_playedIndices`**：随机模式下记录已播索引，全部播完后重置
- **播放状态持久化**：`_saveDebounceTimer` 防抖保存队列，`_positionSaveTimer` 每 10s 保存播放进度
- **失败重试**：单曲最多重试 2 次，连续跳过 3 首后停止

---

## 网络层

### 多服务器管理

`ServersNotifier`（`core/network/servers_provider.dart`）维护服务器列表的 CRUD + 持久化。

启动流程（`StartupGate`）：

1. 读取持久化的 `RunMode`（local / remote）
2. **本地模式（Bundle）**：申请存储权限 → 启动嵌入后端（`EmbeddedBackendService.start()`）→ 健康检查轮询（最多 10 次 × 300ms）→ 设置 `baseUrlProvider` 为 `127.0.0.1:<port>` → 自动使用 `admin/admin` 登录
3. **远程模式**：读取持久化的服务器列表 → 单服务器直接使用；多服务器并行探测可达性（最长 2.5s）→ 选优先级最高的成功项写入 `baseUrlProvider`；全失败则 fallback 到列表首项
4. 设置 `probeOutcomeProvider` 供首屏 SnackBar 提示
5. embedded 模式跳过探测，直接使用 `Uri.base`
6. `BackendLifecycle`（WidgetsBindingObserver）监听 App 生命周期，前台恢复时自动重启后端，detached 时停止

### baseUrl 动态切换

`BaseUrlNotifier`（`core/network/base_url_provider.dart`）是 baseUrl 的 single source of truth。写入时同步镜像到 `AppConfig.baseUrl`，供非 Riverpod 上下文（如 `UrlHelper` 字符串拼接）读取。

### Token 刷新流程

`AuthInterceptor` 处理 JWT 双 Token：

1. 请求拦截：非公开路径自动注入 `Authorization: Bearer <accessToken>`（优先读内存缓存，fallback 读存储）
2. 响应拦截：401 时触发 refreshToken → 成功则重试原请求，失败则 `onTokenExpired` 回调触发登出
3. 并发保护：`_isRefreshing` + `Completer` 确保多个并发 401 只触发一次刷新

公开路径（`/auth/login`、`/auth/refresh`、`/version`、`/health`）不注入 Token。

---

## 存储层

| 服务 | 文件 | 存储后端 | 用途 |
|------|------|---------|------|
| `SecureStorageService` | `core/storage/secure_storage.dart` | SharedPreferences + 内存缓存 | Token 存储（access/refresh/过期时间） |
| `AppPreferences` | `core/storage/app_preferences.dart` | SharedPreferences | 用户偏好（主题、baseUrl、服务器列表、音量、播放模式、上次登录凭据） |
| `PlaybackStateStorage` | `core/storage/playback_state_storage.dart` | 原生平台：文件（`playback_queue.json`）；Web：SharedPreferences | 播放队列 + 进度持久化，应用重启后恢复 |
| `LyricCacheService` | `core/storage/lyric_cache_service.dart` | 原生平台：文件（`lyric_cache/` 目录）；Web：纯内存 | 歌词缓存，避免重复网络请求 |

### Token 存储策略

统一使用 SharedPreferences（非 FlutterSecureStorage）。对于自托管的本地音乐服务器，简化存储实现是可接受的。`cachedAccessToken` / `cachedRefreshToken` 静态变量提供同步读取，解决 Windows 平台存储读取不稳定的问题。

---

## 平台特化

### TV 模式检测

`TvDetector`（`core/env/tv_detector.dart`）在应用启动时检测是否运行在 TV 系统上，结果写入 `AppConfig.isTvMode`（`late final`，仅赋值一次）。

TV 模式下：
- 使用 `TvThemeConstants` 放大按钮/字体尺寸
- 路由切换为 `TvHomePage`（顶部 Tab 导航）
- 焦点组件 `TvFocusable` 支持 D-Pad 方向键导航

### Live Activity

`LiveActivityService`（`core/platform/live_activity_service.dart`）在 iOS 上提供锁屏 Live Activity 展示当前播放歌曲。

### 窗口与托盘

`WindowTrayManager`（`core/utils/window_tray_manager.dart`）在桌面平台（macOS/Windows/Linux）管理窗口大小、位置记忆、系统托盘图标和菜单。

---

## 音频播放

### SongloftAudioHandler

集成 `audio_service` 实现系统通知栏控制，核心设计：

- 使用官方 `pipe()` 模式将 `playbackEventStream` 直接管道连接到 `playbackState`，比手动 listen + add 更可靠
- 通知栏回调（`onSkipToNext`/`onSkipToPrevious`/`onSongCompleted`）由 `PlayerNotifier` 注入
- `notifySongActivated` 钩子：切歌前通知后端取消旧 song 的进行中工作（prefetch/transcode），解决 LockCachingAudioSource 不主动 abort 上游 HTTP 的问题

### 各平台音频后端

| 平台 | 后端（默认） | 说明 |
|------|------|------|
| Web | HTML5 Audio + hls.js | 自定义 `SongloftWebJustAudioPlugin`（just_audio_web + 自接 hls.js 播 HLS 电台） |
| Android | libmpv (media_kit) | `just_audio_media_kit`；可传 `--dart-define=SONGLOFT_MEDIAKIT_MOBILE=false` 回退 ExoPlayer |
| iOS | libmpv (media_kit) | 同上；回退 AVPlayer |
| macOS | libmpv (media_kit) | 可传 `--dart-define=SONGLOFT_MEDIAKIT_MACOS=false` 回退 AVPlayer |
| Windows / Linux | libmpv (media_kit) | `just_audio_media_kit`，LGPL-2.1+ |

> 后端选择集中在 `core/audio/audio_backend.dart` 的 `AudioBackend.usesMediaKit`。macOS/移动端默认用 media_kit 以统一后端并支持应用内视频画面（songloft-org/songloft#76），编译期开关作为 kill-switch 回退原生。

### 视频画面渲染与 Web 后端决策（songloft-org/songloft#76）

视频容器（mp4/mov/mkv/webm/avi/ts）扫描时由后端 ffprobe 探测 `is_video`。应用内画面渲染分两条路：

- **原生平台**（Win/Linux/macOS/Android/iOS）：复用音频用的**同一个** media_kit `Player` 派生 `VideoController`（`core/audio/video_controller_provider.dart`），画面与音频同源、天然同步，无第二引擎。`VideoStage` 组件在视频歌曲时渲染画面、否则回退封面。
- **Web**：用**静音的原生 `<video>`**（`features/player/.../web_video_view_web.dart`）只出画面，音频仍由 `SongloftWebJustAudioPlugin` 播放，二者按 `playerStateProvider` 的播放/暂停/进度同步。

**为什么 Web 不迁到 media_kit 统一？**（已调研，勿反复重提）

- media_kit 在 **Web 上不用 libmpv**，底层就是浏览器 `<video>` 元素，HLS 靠**动态注入 hls.js**（media_kit 源码 `media_kit/lib/src/player/web/utils/hls.dart`）。所以切到 media_kit **不能摆脱 hls.js**，只是把"自接 hls.js"换成"media_kit 帮你接"，HLS 能力无质变（官方称 web 格式支持 "extremely limited"）。
- 桥接包 `just_audio_media_kit` 面向 **Windows/Linux**，**无 web 实现**。Web 用 media_kit 只能整层弃用 just_audio 改用 media_kit `Player` API（波及 `audio_service`/`player_provider` 全套状态机），成本远大于"少维护一套 hls 接入"的收益。
- 结论：**Web 维持 just_audio_web + 自定义 hls.js（电台）+ 静音 `<video>`（画面）**。除非将来 Web 视频统一维护成为硬需求，再评估整层迁移。
