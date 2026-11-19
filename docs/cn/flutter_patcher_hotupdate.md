# flutter_patcher 自托管 Android 热更新（前端 libapp.so）

本文描述 songloft-player 用 [`flutter_patcher`](https://github.com/xuelinger2333/flutter_patcher) 实现的**前端自托管 Android 热更新**:冷启动整包替换 `libapp.so`,补丁作为资产随**每次 GitHub Release 自动发布**,客户端启动检查、手动确认下载、冷重启生效;无法热更的版本引导去设置页下载 APK。

> 中英双语并存,改一版需同步 `docs/en/flutter_patcher_hotupdate.md`。
> Bundle 版把本前端补丁与后端 `libgojni.so` 补丁合并为一次更新体验(同一对话框、一次冷重启),详见 [backend_hotupdate.md](backend_hotupdate.md);本文聚焦**前端机制与标准版发布**。

## 范围与边界

| 维度 | 结论 |
|------|------|
| 平台 | **仅 Android**。iOS/桌面/Web 上插件与本项目封装全部安全 no-op |
| 能热更 | `lib/` 下任意 Dart、纯 Dart 依赖、随包注册的 Flutter assets |
| 不能热更 | 原生 Kotlin/Java/C++、`AndroidManifest`、`res/`、原生插件增改、Flutter 引擎升级 —— 必须发新 APK |
| 生效时机 | 补丁下载后**下次冷启动**生效,不在当前进程内替换;插件自带崩溃回滚 + 坏补丁黑名单 |
| 渠道 | **dev 更 dev、stable 更 stable,不跨渠道**(由编译期 `AppConfig.frontendVersion` 决定) |
| 校验 | 目前仅 **MD5**(`FlutterPatcher.init(strictSignature: false)`);后续可加 Ed25519 |

## 核心模型:无基线 + 自动发布 + 兼容键

- **无基线**:客户端查**本渠道最新** Release——dev→滚动 tag `dev`;stable→GitHub `/releases/latest`(dev 是 prerelease,latest 天然返回最新正式版)。由 `lib/core/updater/channel_release_resolver.dart` 解析,任意非最新 → 最新。
- **自动发布**:`build-and-release.yml` 的 `build-android` job 每次发版自动 `dart run flutter_patcher:pack` 产出 `patch-<abi>-<commit>.zip` + `manifest-<abi>.json` 随 release 上传(`arm64-v8a` / `armeabi-v7a` / `x86_64`)。**已无手动 `patch-release.yml`。**
- **比较规则**:dev 比 **git commit hash**;stable 比**版本号**(semver,`lib/core/updater/version_compare.dart`)。已应用同补丁(`flutter_patcher.currentVersion == patchLabel`)跳过。
- **版本码与引擎兼容性** — Gradle 将通用 APK 的 `versionCode` 下限设为 4002，以便覆盖安装旧分架构包（最高 4001）。CI 用 aapt 从 APK 读取实际版本码，并写入各 ABI 的前端补丁和 manifest。客户端检查 `versionCode`、Flutter 引擎键（`flutterBinding`）和原生契约，版本码或引擎不匹配时引导下载整包。

## 客户端流程(启动检查 + 手动)

入口:`ShellLayout.initState` 每会话调一次 `PatchUpdateDialog.maybeShow`(`lib/core/updater/`)——前端补丁(本文)与后端补丁(Bundle 版)**合并为一个对话框**。启动路径受延迟/开关/节流三道闸约束,手动入口在「设置 → 关于与更新 → 检查客户端更新」,详见 [backend_hotupdate.md](backend_hotupdate.md#客户端流程统一入口)。

1. **有可热更补丁**(且未被「忽略此版本」)→ 弹**可关闭**对话框:列出待更新组件 + **GitHub 代理选择**(复用 `GithubProxySelectionMixin`)+ 按钮 **[忽略此版本] [稍后] [下载并更新]**;下载显示进度 → 完成弹「重启生效」([立即重启] = `EmbeddedBackendService.restartProcess()` **真进程冷启**,让 `libapp.so` 冷启生效)。
2. **无补丁但同渠道有更高整包版本**(`FrontendVersionApi`,且未被忽略)→ 弹「需要下载新版本」→ **[忽略此版本] [稍后] [前往下载]**;前往下载 = 跳 `/settings`(那里有「检查客户端更新」下 APK)。
3. 都没有 → 静默。

- 代理:抓 manifest 与下载 patch 都套用户所选代理(`PatchUpdateService.applyProxy`,前缀拼接);选择持久化到 `githubProxyProvider`,与插件商店/整包升级共用。
- 忽略:分别记忆到 `AppPreferences.ignoredPatchVersion / ignoredClientVersion`。

## 托管与 URL 约定

补丁作为资产随 songloft-player 对应渠道 Release 上传;标准版使用 `manifest-<abi>.json` / `patch-*`,Bundle 版使用 `bundle-manifest-<abi>.json` / `bundle-patch-*`,客户端根据 `HAS_BACKEND` 与渠道选择资产。

- 标准版 manifest:`https://github.com/songloft-org/songloft-player/releases/download/<tag>/manifest-<abi>.json`;Bundle 版使用 `bundle-manifest-<abi>.json`
  - stable:`<tag>` = `v<version>`(经 `/releases/latest` 解析);dev:`<tag>` = `dev`
  - 内容为 `PatchCheckResult` 形状:`{"hasUpdate":true,"patch":{"version","semanticVersion","gitCommit","flutterBinding","targetVersionCode","patchUrl","md5"}}`(其中 `version` 是 `<semver>-<gitCommit>` 形式的补丁标签)
- patch 包:标准版为 `patch-<abi>-<commit>.zip`,Bundle 版为 `bundle-patch-<abi>-<commit>.zip`(md5 取 zip 的)
- **向后兼容**:老式 manifest 无 `semanticVersion` / `gitCommit` / `flutterBinding` 时,客户端退回「`hasUpdate` + versionCode 绑定 + 已应用守卫」旧行为。

## 发布(`build-and-release.yml` 的 `build-android`,自动)

每次发版（`dev` 或 `v<x.y.z>`）用 `flutter build apk --release` 生成一个通用 APK。CI 从同一个 APK 为 `arm64-v8a`、`armeabi-v7a` 和 `x86_64` 分别运行 `dart run flutter_patcher:pack --apk <apk> --version <semver>-<commit> --target-version-code <vc> --abi <abi>`，随 Release 上传 APK、`patch-<abi>-<commit>.zip` 和 `manifest-<abi>.json`。

## 发布纪律

- **纯 Dart 改动** → 随下次发版自动带补丁,老包热更、冷重启生效(无需单独打补丁 tag);
- **动了原生 / 插件原生侧 / 引擎** → Flutter 引擎变则 `flutterBinding` 键不匹配,老包自动落整包 APK 分支;有意 bump versionCode 时同理走整包,用户被引导下 APK。
- **Dart 引用原生资源(`res/`)是隐藏的跨界**:Dart 里写 `androidIcon: 'drawable/xxx'` 这类**资源名字符串**,编译期无人检查、契约哈希闸也拦不到(它只覆盖 MethodChannel 面),但 `res/` 随旧 APK 冻结。热更后引用到旧 APK 没有的资源 → `getIdentifier()` 返回 0 → 原生构建通知直接抛异常。**只引用早已随历史 APK 落地、且内容无主题属性(`?attr/...`)依赖的资源;新增资源必须发整包。**(songloft-org/songloft#329;由 `test/core/audio/notification_icon_contract_test.dart` 静态兜底)

## 验证

1. `flutter analyze` 通过;`flutter build apk --release` 成功。
2. 装某 ABI 的老 dev / stable APK 到真机。
3. 发一版更新(改一处可见 Dart)→ 打开 App → 弹「发现新版本」列前端组件 → 选代理 → 下载 → 重启 → 看到改动 = 成功。
4. 不兼容路径:升级了 Flutter 引擎的新版 → `flutterBinding` 不匹配 → 打开应弹「需要下载新版本」→ 跳 `/settings`。
5. 忽略此版本后同版本不再提示;换更高版本恢复提示。

## 注意

- **Google Play 等渠道**可能限制动态下发可执行 `.so`,本项目走自控/侧载分发。
- flutter_patcher 标注 beta,先内测再放量。
- 要求(已满足):AGP 8.11.1+ / Kotlin 2.2.20+ / Java 17 / minSdk 24 / compileSdk 36 / NDK 27+。
