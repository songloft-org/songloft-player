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

`PlayerNotifier` 的核心业务逻辑已提取到 `domain/use_cases/` 纯 Dart 层（详见 [Domain 层架构](domain_layer.md)）：

- **PlayQueue**：队列增删改查，正确维护 currentIndex
- **PlayModeResolver**：5 种播放模式的 next/prev 计算，随机去重
- **PlaybackRetryPolicy**：本地/网络歌曲重试策略（指数退避）、连续失败阈值
- **SongCompletionRouter**：歌曲播完后的动作路由
- **SleepTimerLogic**：睡眠定时器（按时长/按歌曲数）
- **QueueLoader**：后台分批加载 + generation 竞态取消 + 环形拼装
- **PrefetchStrategy**：预加载决策逻辑

Notifier 本身保留的职责：
- **播放代次 `_playGeneration`**：用户快速切歌时，旧协程在 await 后检测 generation 变化后退出
- **平台交互**：调用 `SongloftAudioHandler`（音频播放）、`VolumeController`（系统音量）
- **State 更新**：驱动 UI 重建
- **播放状态持久化**：`_saveDebounceTimer` 防抖保存队列，`_positionSaveTimer` 每 10s 保存播放进度

---

## 网络层

### 多服务器管理

`ServersNotifier`（`core/network/servers_provider.dart`）维护服务器列表的 CRUD + 持久化。

启动流程（`StartupGate`）：

1. 读取持久化的 `RunMode`（local / remote）
2. **本地模式（Bundle）**：申请所需存储权限 → 启动嵌入后端（`EmbeddedBackendService.start()`）取得动态端口 → 健康检查通过后设置 `baseUrlProvider` 为 `127.0.0.1:<port>` → 读取本地后端生成的管理员凭据自动登录，不使用服务器默认 `admin/admin`
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

### 分页列表点单曲的播放队列构建（铁律，songloft-org/songloft#299）

歌单 / 歌曲库 / 分类等长列表都是**滚动分页**加载的（首页 100 条，触底 `loadMore` 再取下一页）。**从这类列表点击某首歌播放时，绝不能把"当前已加载的分页片段"直接当成完整播放队列**，否则队列被截断到已加载页（如最长 100），只在页内循环；用户滚动触发 `loadMore` 后队列才被动增长到 200/300——这正是 #299 的现象。

**统一约定**：分页列表点单曲 = **立即用已加载片段 + startIndex 起播** ＋ **若 `total > 已加载数` 则按与该列表完全相同的筛选/排序条件，从已加载 offset 起后台补齐整个队列**。补齐走 `PlayerNotifier` 的后台加载器，并用 `_loadGeneration` 代次守卫：用户切歌单 / 换筛选 / 清空队列时旧的后台加载自动失效。

| 列表来源 | 起播 + 补齐入口 | 补齐条件 |
|----------|----------------|----------|
| 歌单详情（普通 / TV） | `playPlaylistFromLoaded(loadedSongs, startIndex, playlistId, total, sort, order, keyword)` | 同一 `sort/order/keyword`，按 `playlistId` 分页 |
| 歌曲库「所有歌曲」（普通 / TV） | `playPlaylist(...)` + `loadRemainingSongsForCurrentPlaylist(keyword, type, ...)` | 同一 `keyword/type` 过滤 |
| 分类页（专辑 / 歌手 / 流派 / 年代…，普通 / TV） | `playPlaylist(...)` + `loadRemainingSongsForCurrentPlaylist(..., genre/artist/album/language/style/year/decade)` | 同一分类维度过滤，映射见 `categorySongsFilter(key)` |

要点：

- **筛选/排序必须与列表一致**：补齐时若用默认条件而非列表当前的 `sort/order/keyword/分类维度`，补进来的歌会与用户看到的顺序/范围错位。分类维度的 `(field,value) → getSongs 参数` 映射统一走 `categorySongsFilter(key)`（`category_provider.dart`），是唯一来源，勿在 UI 层重复手写。
- **「播放全部」是另一条路**：走 `playPlaylistById`（歌单）或先 `loadAll()` 再 `playPlaylist`（分类/facet），本身即覆盖全量，不受此约定影响。
- **已是完整列表的场景无需补齐**：队列抽屉 / `queue_page` 用的是 `state.playlist`（播放队列本身）、插件 `setQueue` 传入的是插件解析好的全量歌曲，均非分页片段。
- **新增任何"分页列表点单曲播放"的页面**，必须一并接上"起播 + 后台补齐"，否则又会引入同类截断。

### 各平台音频后端

| 平台 | 后端（默认） | 说明 |
|------|------|------|
| Web | HTML5 Audio + hls.js | 自定义 `SongloftWebJustAudioPlugin`（just_audio_web + 自接 hls.js 播 HLS 电台） |
| Android | libmpv (media_kit) | `just_audio_media_kit`；统一 media_kit(libmpv)，支持应用内视频画面 |
| iOS | libmpv (media_kit) | 同上；统一 media_kit(libmpv)，支持应用内视频画面 |
| macOS | libmpv (media_kit) | 同上；统一 media_kit(libmpv)，支持应用内视频画面 |
| Windows / Linux | libmpv (media_kit) | `just_audio_media_kit`，LGPL-2.1+ |

> 所有原生平台（Win/Linux/macOS/Android/iOS）统一使用 media_kit(libmpv)，无回退、无 kill-switch。后端选择集中在 `core/audio/audio_backend.dart` 的 `AudioBackend.usesMediaKit`（简化为 `!kIsWeb`），统一后端并支持应用内视频画面（songloft-org/songloft#76）。

### 视频画面渲染与 Web 后端决策（songloft-org/songloft#76）

视频容器（mp4/mov/mkv/webm/avi/ts）扫描时由后端 ffprobe 探测 `is_video`。应用内画面渲染分两条路：

- **原生平台**（Win/Linux/macOS/Android/iOS）：复用音频用的**同一个** media_kit `Player` 派生 `VideoController`（`core/audio/video_controller_provider.dart`），画面与音频同源、天然同步，无第二引擎。`VideoStage` 组件在视频歌曲时渲染画面、否则回退封面。
- **Web**：用**静音的原生 `<video>`**（`features/player/.../web_video_view_web.dart`）只出画面，音频仍由 `SongloftWebJustAudioPlugin` 播放，二者按 `playerStateProvider` 的播放/暂停/进度同步。

**为什么 Web 不迁到 media_kit 统一？**（已调研，勿反复重提）

- media_kit 在 **Web 上不用 libmpv**，底层就是浏览器 `<video>` 元素，HLS 靠**动态注入 hls.js**（media_kit 源码 `media_kit/lib/src/player/web/utils/hls.dart`）。所以切到 media_kit **不能摆脱 hls.js**，只是把"自接 hls.js"换成"media_kit 帮你接"，HLS 能力无质变（官方称 web 格式支持 "extremely limited"）。
- 桥接包 `just_audio_media_kit` 面向 **Windows/Linux**，**无 web 实现**。Web 用 media_kit 只能整层弃用 just_audio 改用 media_kit `Player` API（波及 `audio_service`/`player_provider` 全套状态机），成本远大于"少维护一套 hls 接入"的收益。
- 结论：**Web 维持 just_audio_web + 自定义 hls.js（电台）+ 静音 `<video>`（画面）**。除非将来 Web 视频统一维护成为硬需求，再评估整层迁移。
