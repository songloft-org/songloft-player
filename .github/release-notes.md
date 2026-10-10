## 安装说明（中文）

这是需要连接 [Songloft 服务器](https://github.com/songloft-org/songloft)的标准 Flutter 客户端。安装后填写服务器地址并登录；需要内嵌后端的本地模式，请下载[主工程 Release](https://github.com/songloft-org/songloft/releases)中的 `songloft-bundled-*` 文件。

在本页 **Assets** 中选择适合设备的文件；部分安装格式可能未提供，以实际附件为准。

| 平台 | 下载文件 | 安装 / 部署方式 |
| --- | --- | --- |
| Android | `songloft-arm64-v8a.apk` / `songloft-armeabi-v7a.apk` / `songloft-x86_64.apk` | 根据设备架构选择，下载并打开 APK，按提示允许安装。ARM64 对应 arm64-v8a，32 位 ARM 对应 armeabi-v7a，Intel 设备或模拟器选择 x86_64。 |
| iOS | `songloft-ios-nosign.ipa` | 未签名设备包，需使用自己的开发者证书和适用于目标设备的 provisioning profile 重签后安装。 |
| Windows | `songloft-windows-x64.zip` / `songloft-windows-x64.msix` | ZIP 解压后运行应用，保留同目录全部文件；MSIX 按系统提示安装。 |
| macOS | `songloft-macos.dmg` / `songloft-macos.zip` | DMG 打开后将应用拖入「应用程序」，或解压 ZIP 后移动应用；Universal 包支持 Intel 和 Apple Silicon。 |
| Linux | `songloft-linux-x64.tar.gz` / `.deb` / `.rpm` / `.AppImage` | tar.gz 解压后运行应用并保留完整目录；DEB/RPM 使用系统包管理器安装；AppImage 添加执行权限后运行。 |
| Web（独立部署） | `songloft-web-standalone.tar.gz` | 解压到静态服务器，打开站点后配置后端 API 地址；跨源部署需要后端允许该站点访问。 |
| Web（同源部署） | `songloft-web-embedded.tar.gz` | 用于配置同源静态服务或后端嵌入构建，隐藏 API 地址输入；下载解压不会自动替换已运行的服务器前端。 |

`patch-*.zip`、`manifest-*.json` 和 `version.json` 供客户端检查更新使用，无需手动安装。更多配置见[中文 README](https://github.com/songloft-org/songloft-player/blob/main/README.md)。

## Installation (English)

This is the standard Flutter client, which connects to a [Songloft server](https://github.com/songloft-org/songloft). Enter the server address and sign in after installation. For local mode with a bundled backend, download `songloft-bundled-*` from the [main project releases](https://github.com/songloft-org/songloft/releases).

Choose a file for your device under **Assets** on this page. Some packaging formats may be unavailable; check the attached files.

| Platform | Download | Installation / deployment |
| --- | --- | --- |
| Android | `songloft-arm64-v8a.apk` / `songloft-armeabi-v7a.apk` / `songloft-x86_64.apk` | Choose your device architecture, download and open the APK, and allow installation when prompted. Use arm64-v8a for ARM64, armeabi-v7a for 32-bit ARM, or x86_64 for Intel devices/emulators. |
| iOS | `songloft-ios-nosign.ipa` | Unsigned device build. Re-sign with your developer certificate and a provisioning profile for your device before installing. |
| Windows | `songloft-windows-x64.zip` / `songloft-windows-x64.msix` | Extract the ZIP and launch the application, keeping all files together, or install the MSIX through the system installer. |
| macOS | `songloft-macos.dmg` / `songloft-macos.zip` | Open the DMG and drag the app into Applications, or extract the ZIP and move the app there. The Universal package supports Intel and Apple Silicon. |
| Linux | `songloft-linux-x64.tar.gz` / `.deb` / `.rpm` / `.AppImage` | Extract tar.gz and launch the app with its complete directory, install DEB/RPM using your package manager, or make the AppImage executable and run it. |
| Web (standalone) | `songloft-web-standalone.tar.gz` | Extract to a static server, open the site, and configure the backend API address. Cross-origin hosting requires the backend to allow access from the site. |
| Web (embedded) | `songloft-web-embedded.tar.gz` | For same-origin static hosting or a backend embedding build; hides the API address field. Extracting this archive does not automatically replace a running server's frontend. |

`patch-*.zip`, `manifest-*.json`, and `version.json` are used by the client's update checker and do not need manual installation. See the [English README](https://github.com/songloft-org/songloft-player/blob/main/README.en.md) for more configuration details.
