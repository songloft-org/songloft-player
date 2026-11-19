# Songloft Flutter

[English](README.en.md) | 中文

[![Build and Release](https://github.com/songloft-org/songloft-player/actions/workflows/build-and-release.yml/badge.svg)](https://github.com/songloft-org/songloft-player/actions/workflows/build-and-release.yml)
[![GitHub License](https://img.shields.io/github/license/songloft-org/songloft-player)](https://github.com/songloft-org/songloft-player)
[![GitHub Release](https://img.shields.io/github/v/release/songloft-org/songloft-player)](https://github.com/songloft-org/songloft-player/releases)
[![Stars](https://img.shields.io/github/stars/songloft-org/songloft-player)](https://github.com/songloft-org/songloft-player/stargazers)

<p align="center">
  <strong>🎵 Songloft 跨平台音乐播放器 — 基于 Flutter 构建</strong>
</p>

Songloft 跨平台音乐播放器，基于 Flutter 构建，支持 iOS、Android、macOS、Windows、Linux、Web 六端。支持 **Bundle 本地模式**：内嵌 Go 后端，无需部署服务器即可播放本地音乐。

「设置 → 播放设置 → 歌词页屏幕常亮」可在查看歌词时保持亮屏，默认关闭、仅保存到本机。手机返回封面、离开播放器或切到后台后恢复系统自动熄屏；宽屏播放器在歌词可见时生效，暂停播放仍可查看歌词。Web 端受浏览器亮屏能力和权限限制，不支持或拒绝时不影响播放。

<p align="center">
  <a href="https://github.com/songloft-org/songloft-player">🏠 GitHub</a> •
  <a href="https://github.com/songloft-org/songloft-player/releases">📥 下载</a> •
  <a href="https://github.com/songloft-org/songloft-player/issues">💬 问题反馈</a>
</p>

## 截图

https://github.com/songloft-org/songloft/issues/6

## 下载安装

从 [GitHub Releases](https://github.com/songloft-org/songloft-player/releases/latest) 下载最新版本：

Release 正文展示版本变更，并保留本节的安装说明链接；历史记录保存在中文 [CHANGELOG.md](CHANGELOG.md)，在版本发布成功后自动更新。各平台安装说明见下表。

本仓库发布标准 Flutter 客户端和 Bundle 本地模式客户端。标准版连接独立的 [Songloft 服务器](https://github.com/songloft-org/songloft)；Bundle 版在本机启动随包内嵌的 Go 后端，可在登录页或设置页切换本地/远程模式。Bundle 流水线以启动时主仓库 `main` 的最新提交构建 Go 后端，并用同一 SHA 为各平台打包。

在 Release 页的 **Assets** 中选择适合设备的文件；部分安装格式可能未提供，以实际附件为准。

| 平台 | 下载链接 | 说明 |
|------|----------|------|
| 🌐 **Web (standalone)** | [songloft-web-standalone.tar.gz](https://github.com/songloft-org/songloft-player/releases/latest/download/songloft-web-standalone.tar.gz) | 解压到静态服务器，打开站点后配置后端 API 地址；跨源部署需要后端允许该站点访问 |
| 🌐 **Web (embedded)** | [songloft-web-embedded.tar.gz](https://github.com/songloft-org/songloft-player/releases/latest/download/songloft-web-embedded.tar.gz) | 用于同源静态服务或后端嵌入构建，隐藏 API 地址输入；解压不会自动替换已运行的服务器前端 |
| 🐧 **Linux** | [songloft-linux-x64.tar.gz](https://github.com/songloft-org/songloft-player/releases/latest/download/songloft-linux-x64.tar.gz) | 解压后运行应用，保留完整目录 |
| | [songloft-linux-x64.deb](https://github.com/songloft-org/songloft-player/releases/latest/download/songloft-linux-x64.deb) | Debian/Ubuntu x64，使用系统包管理器安装 |
| | [songloft-linux-x64.rpm](https://github.com/songloft-org/songloft-player/releases/latest/download/songloft-linux-x64.rpm) | Fedora/RHEL/CentOS x64，使用系统包管理器安装 |
| | [songloft-linux-x64.AppImage](https://github.com/songloft-org/songloft-player/releases/latest/download/songloft-linux-x64.AppImage) | 添加执行权限后运行 |
| 🪟 **Windows** | [songloft-windows-x64.zip](https://github.com/songloft-org/songloft-player/releases/latest/download/songloft-windows-x64.zip) | x64 便携版，解压后运行应用，保留同目录全部文件 |
| | [songloft-windows-x64.msix](https://github.com/songloft-org/songloft-player/releases/latest/download/songloft-windows-x64.msix) | x64 安装版，按系统提示安装 |
| 🍎 **macOS** | [songloft-macos.dmg](https://github.com/songloft-org/songloft-player/releases/latest/download/songloft-macos.dmg) | Universal (Intel/Apple Silicon)，打开 DMG 后将应用拖入「应用程序」 |
| | [songloft-macos.zip](https://github.com/songloft-org/songloft-player/releases/latest/download/songloft-macos.zip) | Universal (Intel/Apple Silicon)，解压 ZIP 后将应用移入「应用程序」 |
| 🤖 **Android** | [songloft-arm64-v8a.apk](https://github.com/songloft-org/songloft-player/releases/latest/download/songloft-arm64-v8a.apk) | ARM64 设备（推荐），下载并打开 APK，按提示允许安装 |
| | [songloft-armeabi-v7a.apk](https://github.com/songloft-org/songloft-player/releases/latest/download/songloft-armeabi-v7a.apk) | 32 位 ARM 设备，下载并打开 APK，按提示允许安装 |
| | [songloft-x86_64.apk](https://github.com/songloft-org/songloft-player/releases/latest/download/songloft-x86_64.apk) | Intel 设备或模拟器，下载并打开 APK，按提示允许安装 |
| 📱 **iOS** | [songloft-ios-nosign.ipa](https://github.com/songloft-org/songloft-player/releases/latest/download/songloft-ios-nosign.ipa) | 未签名设备包，需使用自己的开发者证书和适用于目标设备的 provisioning profile 重签后安装 |

> 开发版可在 [dev 分支 Release](https://github.com/songloft-org/songloft-player/releases/tag/dev) 获取。
> 下载内嵌后端的客户端时，请按 [Bundle 选包说明](#bundle-本地模式)中的文件名选择。

`patch-*.zip`、`manifest-*.json` 和 `version.json` 供客户端检查更新使用，无需手动安装。

## 功能特性

- **跨平台支持**: iOS、Android（手机/平板）、macOS、Windows、Linux、Web
- **车机版本**: 车载信息娱乐系统请使用 [songloft-tv](https://github.com/boluofan/songloft-tv)
- **Bundle 本地模式**: 内嵌 Go 后端，无需服务器，支持本地/远程双模式切换
- **响应式布局**: 3 级断点自适应（Mobile < 600px, Tablet 600-900px, Desktop 900px+），超宽屏（宽高比 > 2.2:1）自动切换 Dock 导航
- **自适应导航**: 手机底栏、平板侧栏、桌面侧边菜单
- **音乐播放**: 基于 just_audio，支持本地和网络歌曲，后台播放
- **歌单管理**: 创建、编辑、删除歌单，添加/移除歌曲
- **歌曲库**: 分页加载、搜索过滤、歌曲编辑
- **主题切换**: 亮色/暗色/跟随系统
- **JWT 认证**: 双 Token 机制，安全存储（自动降级）

## 环境要求

- Flutter >= 3.41.0
- Dart SDK >= 3.7.0

## 快速开始

```bash
# 安装依赖
flutter pub get

# 运行（自动选择已连接设备）
flutter run

# 指定平台运行
flutter run -d chrome --no-web-resources-cdn  # Web（standalone 模式）
flutter run -d macos                          # macOS
flutter run -d "iPhone 16 Pro"                # iOS 模拟器
flutter run -d <device-id>                    # Android 设备
```

## 构建

```bash
# 各平台构建
flutter build web --no-web-resources-cdn                                       # Web (standalone)
flutter build web --no-web-resources-cdn --dart-define=DEPLOY_MODE=embedded    # Web (嵌入模式)
flutter build apk --split-per-abi                                              # Android APK
flutter build ios --no-codesign                                                # iOS
flutter build macos                                                            # macOS
flutter build linux                                                            # Linux
flutter build windows                                                          # Windows

# 使用构建脚本（支持并行构建所有平台）
./scripts/build-frontend.sh web           # 构建单个平台
./scripts/build-frontend.sh all           # 构建所有平台
```

详细构建说明参见 [构建指南](docs/cn/build_guide.md)。

## CI/CD

本仓库通过 GitHub Actions 自动构建和发布：

- **推送 `v*` tag** → 自动构建所有平台并创建正式 Release
- **手动触发** → 构建并发布到分支名对应的 Release（如 `main`）

工作流文件：[`.github/workflows/build-and-release.yml`](.github/workflows/build-and-release.yml)

## 项目结构

```
lib/
├── config/          # 应用配置（API 地址、常量）
├── core/            # 核心层
│   ├── a11y/        # 无障碍辅助
│   ├── audio/       # 音频播放服务
│   ├── backend/     # Bundle 本地模式（嵌入后端抽象层）
│   ├── env/         # 环境信息
│   ├── network/     # HTTP 客户端、认证拦截器
│   ├── platform/    # 平台检测
│   ├── router/      # GoRouter 路由配置
│   ├── storage/     # 本地存储、安全存储
│   ├── theme/       # 主题、响应式断点
│   ├── tracely/     # 前端监控
│   └── utils/       # 工具函数
├── features/        # 功能模块
│   ├── auth/        # 认证（登录/登出/Token 管理/本地模式入口）
│   ├── dlna/        # DLNA 投屏
│   ├── home/        # 首页
│   ├── jsplugin/    # JS 插件管理
│   ├── startup/     # 启动流程（本地/远程模式自动引导）
│   ├── library/     # 歌曲库
│   ├── player/      # 播放器（桌面/移动/迷你）
│   ├── playlist/    # 歌单管理
│   └── settings/    # 设置（主题/扫描/插件/升级）
├── shared/          # 共享层
│   ├── constants/   # 常量定义
│   ├── layouts/     # 自适应布局（AdaptiveScaffold、ShellLayout）
│   ├── mixins/      # 通用 Mixin
│   ├── models/      # 数据模型（Song、ApiResponse、Pagination）
│   ├── utils/       # 共享工具函数
│   └── widgets/     # 通用组件
├── main.dart        # 应用入口
scripts/
├── build-frontend.sh         # 多平台构建脚本
├── bump-version.sh           # 版本发布脚本（语义化版本控制）
├── docker-build-frontend.sh  # Docker 构建便捷脚本
└── download-fonts.sh         # 字体下载脚本
```

## 文档

| 文档 | 说明 |
|------|------|
| [docs/cn/build_guide.md](docs/cn/build_guide.md) | 多平台构建指南 |
| [docs/cn/development.md](docs/cn/development.md) | 开发指南 |
| [docs/cn/architecture.md](docs/cn/architecture.md) | 架构补充说明 |
| [docs/cn/platform-notes.md](docs/cn/platform-notes.md) | 平台特定注意事项 |
| [scripts/README.md](scripts/README.md) | 构建与发布脚本指南 |

## 技术栈

| 类别 | 技术 |
|------|------|
| 状态管理 | Riverpod |
| 路由 | GoRouter |
| HTTP | Dio + JWT 拦截器 |
| 音频 | just_audio + audio_service |
| 本地存储 | SharedPreferences |
| 图片缓存 | CachedNetworkImage |

## 部署模式

| 模式 | 编译参数 | 说明 |
|------|---------|------|
| **standalone** | 默认（不传 `--dart-define`） | 前后端分离部署，显示 API 地址配置 UI，用户手动填写后端地址 |
| **embedded** | `--dart-define=DEPLOY_MODE=embedded` | 嵌入 Go 后端同域部署，自动使用当前域名，隐藏 API 地址 UI |
| **bundle** | `--dart-define=HAS_BACKEND=true` | 客户端内嵌 Go 后端，无需服务器，支持本地/远程双模式切换 |

默认构建（不传 `--dart-define`）等同于 standalone 模式。

### Bundle 本地模式

Bundle 版将 Go 后端嵌入到客户端中，用户无需单独部署服务器：

- **移动端（Android/iOS）**：Go 后端通过 gomobile 编译为原生库（`.aar` / `.xcframework`），Flutter 通过 MethodChannel 调用
- **桌面端（macOS/Windows/Linux）**：Go 后端编译为 `songloft-server` 可执行文件，启动时作为子进程运行
- **Web**：不支持 Bundle 模式

本地构建以 Android 为例。先准备主仓库源码并初始化 `pkg/tag`，脚本使用该 checkout 的 HEAD：

```bash
SONGLOFT_BACKEND_SOURCE=/absolute/songloft bash scripts/build-bundle-backend.sh android
flutter build apk --dart-define=HAS_BACKEND=true
```

Android、iOS、Linux、Windows、macOS 的 Bundle 包由本仓库 `.github/workflows/build-and-release.yml` 与标准客户端一起发布。流水线记录本次选用的后端 SHA 和版本。

Android 和桌面端首次启用本地模式时选择音乐目录，iOS 使用应用 Documents 目录；无需在首次启动时通过独立弹窗选择运行模式。Bundle 资产在[本仓库 Releases](https://github.com/songloft-org/songloft-player/releases/latest)中，文件名以 `songloft-bundled-` 开头：

| 平台 | Bundle 下载 |
|---|---|
| Android ARM64 / ARMv7 / x86_64 | [Release Assets](https://github.com/songloft-org/songloft-player/releases/latest) 中的 `songloft-bundled-android-*.apk` |
| iOS | `songloft-bundled-ios-nosign.ipa`（未签名，需自行重签） |
| Linux x86_64 | `songloft-bundled-linux-x64.tar.gz` |
| macOS Universal | `songloft-bundled-macos.zip` |
| Windows x86_64 | `songloft-bundled-windows-x64.zip` |

## 版本发布

使用 `bump-version.sh` 脚本进行版本发布（遵循语义化版本控制）：

```bash
# 补丁版本升级（1.0.0 -> 1.0.1）
./scripts/bump-version.sh patch

# 次版本号升级（1.0.0 -> 1.1.0）
./scripts/bump-version.sh minor

# 主版本号升级（1.0.0 -> 2.0.0）
./scripts/bump-version.sh major
```

脚本会自动：
- 读取并升级 `pubspec.yaml` 中的版本号
- 创建 Git 标签（格式：`v{version}`）
- 推送 Git 标签到远程仓库
- 提供交互式确认和进度反馈

## 后端

**标准版**需要配合 [Songloft 后端](https://github.com/songloft-org/songloft) 服务运行。默认连接 `http://localhost:58091`，可在登录页中修改 API 地址。

**Bundle 版**内嵌 Go 后端，无需单独部署服务器；客户端使用本地后端生成并保存在应用数据目录中的管理员凭据自动登录。

默认账号：admin / admin

🔗 **服务端 GitHub**: [https://github.com/songloft-org/songloft](https://github.com/songloft-org/songloft)

## 许可证 / 第三方组件

本项目**源代码**基于 [Apache-2.0 license](LICENSE) 开源。

> **LGPL 合规提示**：本客户端在 Windows / Linux 上通过 `just_audio_media_kit` 调用 libmpv（LGPL-2.1+）作为音频后端。Windows 端打包的是 **audio-only LGPL 构建**（不含 GPL 编码器如 libx264 / libx265），Linux 端动态链接系统的 libmpv。完整的第三方组件清单、许可证类型与源码获取途径见 [NOTICE](NOTICE)。
