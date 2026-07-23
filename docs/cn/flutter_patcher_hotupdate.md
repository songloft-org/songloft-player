# flutter_patcher 自托管 Android 热更新

本文描述 songloft-player 用 [`flutter_patcher`](https://github.com/xuelinger2333/flutter_patcher) 实现的**自托管 Android 热更新**:冷启动**整包替换 `libapp.so`**,补丁托管在自己的 GitHub Release,**启动检查 + 手动更新**;无法热更的版本引导去设置页下载 APK。

> 中英双语并存,改一版需同步 `docs/en/flutter_patcher_hotupdate.md`。

## 范围与边界

| 维度 | 结论 |
|------|------|
| 平台 | **仅 Android**。iOS/桌面/Web 上插件与本项目封装全部安全 no-op |
| 能热更 | `lib/` 下任意 Dart、纯 Dart 依赖、随包注册的 Flutter assets |
| 不能热更 | 原生 Kotlin/Java/C++、`AndroidManifest`、`res/`、原生插件增改、Flutter 引擎升级 —— 必须发新 APK |
| 生效时机 | 补丁下载后**下次冷启动**生效,不在当前进程内替换;插件自带崩溃回滚 + 坏补丁黑名单 |
| 渠道 | **dev 更 dev、stable 更 stable,不跨渠道**(由编译期 `FRONTEND_VERSION` 决定) |
| 校验 | 目前仅 **MD5**(`FlutterPatcher.init(strictSignature: false)`);后续可加 Ed25519 |

## 关键绑定

- **versionCode 绑定**:补丁按宿主 APK 的 `versionCode`(= pubspec `version` 的 `+N`)绑定。一个正式版 tag = 一个 versionCode;补丁必须用**相同 versionCode** 打包,装了该 APK 的设备才会应用。
- **ABI 分片**:APK 走 split-per-abi,补丁按 `arm64-v8a / armeabi-v7a / x86_64` 各出一份;客户端按 `FlutterPatcher.deviceAbi` 取对应 `manifest-<abi>.json`。

## 客户端流程(启动检查 + 手动)

入口:首页 `initState` 每会话调一次 `PatchUpdateDialog.maybeShow`(`lib/core/updater/`)。

1. **有匹配补丁**(且未被「忽略此版本」)→ 弹**可关闭**对话框:内含 **GitHub 代理选择**(复用 `GithubProxySelectionMixin`)+ 按钮 **[忽略此版本] [稍后] [下载并更新]**;下载显示进度 → 完成弹「重启生效」([立即重启]=`SystemNavigator.pop()`)。
2. **无补丁但同渠道有更高整包版本**(`FrontendVersionApi`,且未被忽略)→ 弹「需要下载新版本」→ **[忽略此版本] [稍后] [前往下载]**;前往下载 = 跳 `/settings`(那里有「检查客户端更新」下 APK)。
3. 都没有 → 静默。

- 代理:抓 manifest 与下载 patch 都套用户所选代理(`PatchUpdateService.applyProxy`,前缀拼接);选择持久化到 `githubProxyProvider`,与插件商店/整包升级共用。
- 忽略:分别记忆到 `AppPreferences.ignoredPatchVersion / ignoredClientVersion`。

## 托管与 URL 约定

补丁作为资产传到**对应版本的 GitHub Release**(本期只做标准版,仓库 `songloft-org/songloft-player`;Bundle 版延后,届时传到父仓库 Release 即可,客户端用 `AppConfig.frontendUpdateRepo` 自动切换、无需改代码)。

- manifest:`https://github.com/<repo>/releases/download/<tag>/manifest-<abi>.json`
  - stable:`<tag>` = `v<version>`;dev:`<tag>` = `dev`
  - 内容为 `PatchCheckResult` 形状:`{"hasUpdate":true,"patch":{"version","patchUrl","md5","targetVersionCode"}}`
- patch 包:同 Release 的 `patch-<abi>.zip`

## 发布补丁(`.github/workflows/patch-release.yml`,手动)

1. 从要修复的版本代码上 cherry-pick **纯 Dart** 修复,**保持 pubspec versionCode 不变**;
2. dispatch `Patch Release`,填 `target_version`(stable 填版本号如 `2.11.0`;dev 填 `dev`)、`patch_label`(如 `2.11.0-h1`);
3. workflow:`flutter build apk --release --split-per-abi`(FRONTEND_VERSION 保持基线渠道值)→ 对每 ABI `dart run flutter_patcher:pack --apk <abi apk> --version <label> --target-version-code <vc> --abi <abi>` → 生成 `patch-<abi>.zip` + `manifest-<abi>.json`(md5 取 zip 的)→ `gh release upload <tag> ... --clobber`。

## 发布纪律

- **纯 Dart 修复** → 发补丁(不打新 tag),用户热更、重启生效;
- **动了原生/插件原生侧/引擎** → 打新 tag 发新 APK(不给旧基线发补丁),用户被引导下 APK。

## 验证

1. `flutter analyze` 通过;`flutter build apk --release --split-per-abi` 成功。
2. 装某 ABI 的 APK 到真机,记录 versionCode。
3. 改一处可见 Dart,用 `patch-release.yml`(或本地 `dart run flutter_patcher:pack` + `flutter_patcher:mock_server`)对该 versionCode 发补丁。
4. 打开 App → 弹「发现新版本」→ 选代理 → 下载 → 重启 → 看到改动 = 成功。
5. 不兼容路径:发更高正式版 tag 且不发补丁 → 打开应弹「需要下载新版本」→ 跳 `/settings`。
6. 忽略此版本后同版本不再提示;换更高版本恢复提示。

## 注意

- **Google Play 等渠道**可能限制动态下发可执行 `.so`,本项目走自控/侧载分发。
- flutter_patcher 标注 beta,先内测再放量。
- 要求(已满足):AGP 8.11.1+ / Kotlin 2.2.20+ / Java 17 / minSdk 24 / compileSdk 36 / NDK 27+。
