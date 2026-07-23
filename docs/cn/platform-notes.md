# 平台特定注意事项

跨平台开发中各平台的特殊处理和已知问题。

---

## Android

### 构建准备

```bash
sdkmanager --licenses   # 首次构建前接受许可证
```

需要 Android SDK、NDK、JDK 17+。

### 运行时注意

- **Android 13+（API 33）**：需运行时申请通知权限 `POST_NOTIFICATIONS`，否则无法显示播放控制通知
- **HyperOS3（小米）**：需设置 `androidStopForegroundOnPause: false`，否则暂停时前台服务被回收，后台播放中断
- **APK 分架构构建**：`flutter build apk --split-per-abi` 生成 arm64-v8a、armeabi-v7a、x86_64 三个 APK

### 故障排查

```bash
# Gradle 缓存损坏
flutter clean && rm -rf android/.gradle
flutter pub get
```

---

## iOS

### 构建与分发

- 使用 `flutter build ios --no-codesign` 构建未签名 IPA
- 通过 AltStore / Sideloadly 侧载安装（不需要开发者账号）
- 仅在 macOS 上可构建

### CocoaPods 问题

```bash
cd ios
pod deintegrate
pod install
cd ..
flutter clean && flutter pub get
```

---

## macOS

### 窗口管理

使用 `window_manager` + `tray_manager` 实现：
- 窗口大小和位置记忆
- 系统托盘图标 + 菜单
- 单实例运行

### 签名与存储

应用未签名时无法使用 Keychain（FlutterSecureStorage 依赖它），已统一改用 SharedPreferences 存储 Token，不再受签名影响。

---

## Windows

### 音频后端

Windows 端通过 `just_audio_media_kit` 使用 libmpv 作为音频后端：
- 打包的是 **LGPL 构建**（不含 GPL 编码器如 libx264/libx265）
- 依赖 `media_kit_libs_windows_video`（含视频输出，取代旧的 audio 变体，用于应用内视频画面 songloft-org/songloft#76）

### 构建要求

- Visual Studio 2022（带 C++ 桌面开发工作负载）
- Windows 10 SDK

### MSIX 打包

```bash
flutter pub run msix:create
```

### Token 存储

Windows 平台的 SharedPreferences 读取偶尔不稳定，`AuthInterceptor` 优先使用内存缓存的 `cachedAccessToken`，仅在缓存为空时才读存储。

---

## Linux

### 系统依赖

```bash
# Ubuntu/Debian
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev
```

### 音频后端

Linux 端同样通过 `just_audio_media_kit` 使用 libmpv，但采用**动态链接系统的 libmpv**（非静态打包），用户系统需安装 mpv/libmpv。

### 分发格式

构建脚本支持 tar.gz、deb、rpm、AppImage 四种格式。

---

## Web

### 构建参数

- **必须**加 `--no-web-resources-cdn`，否则 Flutter 会从 Google CDN 加载字体/canvaskit，国内环境访问缓慢或失败
- standalone 模式：`flutter build web --no-web-resources-cdn`
- embedded 模式：`flutter build web --no-web-resources-cdn --dart-define=DEPLOY_MODE=embedded`
- **CanvasKit 变体**：`web/index.html` 用 `canvasKitVariant: "auto"`，由引擎按浏览器选变体——Chromium 内核用体积更小的 `chromium` 变体，Firefox/Safari 用 `full`。二者**都走 WebGL**，与 CPU/GPU 渲染模式无关（`canvasKitForceCpuOnly` 是另一回事，早已移除）。因此 embedded 自托管构建**必须保留** `canvaskit/chromium` 子目录（`scripts/build-frontend.sh` 只删 skwasm/wimp/`.symbols`，不删 chromium），否则 Chrome 离线会 404 白屏

### 部署模式差异

| | standalone | embedded |
|---|-----------|----------|
| API 地址 | 用户在登录页手动配置 | 自动使用 `Uri.base`（同域） |
| API 地址 UI | 显示 | 隐藏（编译时 tree-shaking 移除） |
| 子路径部署 | 需手动配置 | `Uri.base.path` 自动检测 |

### 条件导入

Web 平台不支持 `dart:io`，涉及原生功能（WebView、文件系统）的代码使用 stub 文件模式：

```
plugin_webview_page.dart       → export 入口
plugin_webview_page_stub.dart  → Web 平台（占位 UI）
plugin_webview_page_native.dart → 原生平台（真实实现）
```

项目中的 stub 文件对：
- `plugin_webview_page` — JS 插件 WebView
- `plugin_tab_page` — 插件 Tab 页
- `web_cache_clearer` — Web 缓存清理

### 存储降级

- `PlaybackStateStorage`：Web 平台降级为 SharedPreferences（localStorage），原生平台用文件
- `LyricCacheService`：Web 平台降级为纯内存缓存，原生平台用文件系统

### 封面 / 网络图片必须缩略解码（CanvasKit 大纹理踩坑）

> **铁律：web 上所有网络封面图必须走 `CoverImage` 或 `NetworkCoverImage`，禁止直接裸用 `CachedNetworkImage` / `Image.network`。**

- **现象**：列表/网格封面在切 tab、切筛选、来回导航后偶发**变纯黑**，继续操作又变成**默认占位图标**；而常驻的播放器大图从不出问题。
- **根因**：CanvasKit 默认 web 渲染方式 `ImageRenderMethodForWeb.HtmlImage` 把封面按**原图全分辨率**上传为 GPU 纹理（实测 ~1.5MB/张），且此路径下 `memCacheWidth` **不生效**。列表大量大封面纹理累积挤爆移动端浏览器 GPU 显存 → CanvasKit 的 WebGL context 被丢弃 → 已上传纹理失效（**黑**）、新解码 `MakeLazyImageFromTextureSourceWithInfo` 返回 null 抛 `ImageCodecException: Failed to create image from Image.decode`（**占位图标**）。常驻 widget（播放器大图）因 listener 永不释放、被钉在 `imageCache` 的 live 集合永不淘汰，故不受影响——这正是"播放器不丢、列表丢"的原因。
- **修复**：封面组件强制 `imageRenderMethodForWeb: ImageRenderMethodForWeb.HttpGet` + `memCacheWidth`（按显示尺寸 × DPR）缩略解码，纹理从 ~1.5MB 降到数十~百 KB，大幅降低 GPU 显存压力；且 HttpGet 字节可在 context 恢复后重解码，比 `<img>` 惰性纹理更抗 context 丢失。已封装在：
  - `shared/widgets/cover_image.dart`（`CoverImage`，定尺寸方形封面）
  - `shared/widgets/network_cover_image.dart`（`NetworkCoverImage`，填充式 / 自定义布局封面）
- **最易踩的坑**：新增封面渲染点时**必须**用上述两个组件之一；图省事直接写 `CachedNetworkImage(imageUrl: ...)`，web 上就会重新引入变黑。历史上正因专辑 / 歌手 / 歌单卡片漏用封装、直接裸用 `CachedNetworkImage`，导致这些列表封面单独变黑（歌曲列表因用了 `CoverImage` 反而正常），排查绕了很多弯。
- **排查判据**：`ImageCodecException: Failed to create image from Image.decode` = GPU 纹理创建失败（context 丢失 / 显存耗尽），**不是**网络或字节问题；**纯黑** = 已解码 `ui.Image` 的纹理失效（`errorWidget` 捕获不到，因失败在 GPU 绘制层）；**占位图标** = 走到了 `errorWidget`（解码 / 加载真失败）。
- **超大歌单的后续（songloft-org/songloft#309）**：歌单/队列上千首时纹理压力更大，还叠加两个后续问题，当前缓解栈为：
  1. **崩溃**：context 丢失时 `CkSurface` 访问未初始化 late 字段崩溃（flutter/flutter#184683）→ web 构建切到含官方修复 #185116 的 **beta 3.47**（见 `.github/workflows/build-and-release.yml`）。
  2. **回滚封面变空白**：崩溃修好后，**离屏但仍驻留 `imageCache` 的封面**其 GPU 纹理随旧 context 一起失效，回滚时同步命中缓存拿到**死纹理**画成空白，且不再重新解码。因 `imageCache` 存的是**解码后的 `ui.Image`（GPU 纹理句柄）而非编码字节**，"命中缓存"反成陷阱。→ `core/utils/webgl_context_recovery.dart` 的 `installWebGLContextRecovery`（`main.dart` 内 web 挂载）在 `webglcontextlost`/`restored` 时清空 `imageCache`，逼回滚重新解码（字节仍在 `cached_network_image` 本地缓存，不重新联网）。
  3. **纹理压力**：`core/utils/web_image_tuning.dart` 在 web 端收紧大列表 `cacheExtent`（250→100）并按显示尺寸解码小封面（队列/侧栏 36–48px），降低同时驻留纹理数与体积。
- **不要走的弯路**（均已验证无效或更差）：调大 `imageCache`（根本没触发 LRU 淘汰）、`imageCache.evict` / 换 key 重建（治标且加剧重解码）、`canvasKitForceCpuOnly`（全局软件渲染极卡且不解决）、`canvasKitMaximumSurfaces=1`（Chrome 走单 OffscreenCanvas，无效）。
