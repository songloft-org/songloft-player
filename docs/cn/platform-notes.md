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
- 打包的是 **audio-only LGPL 构建**（不含 GPL 编码器如 libx264/libx265）
- 依赖 `media_kit_libs_windows_audio`

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
