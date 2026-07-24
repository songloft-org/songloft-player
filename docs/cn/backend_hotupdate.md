# Bundle 版 Android 热更新(前端 libapp.so + 后端 libgojni.so)

本文描述 Bundle 本地模式下 songloft-player 的 **Android 自托管热更新**:**无基线**——任何非最新 dev 更新到最新 dev、任何非最新 stable 更新到最新 stable。**每次发版自动**把最新补丁挂到 Release,客户端启动检查、一次下载、只重启一次:一次真进程冷启同时让前端 `libapp.so`(flutter_patcher)与后端 `libgojni.so`(gomobile)生效。

> 中英双语并存,改一版需同步 `docs/en/backend_hotupdate.md`。

## 核心模型:无基线 + 自动发布 + 工具链兼容键

- **无基线**:客户端查**本渠道最新**——dev→滚动 tag `dev`;stable→GitHub `/releases/latest`(dev 是 prerelease,latest 天然返回最新正式版)。由 `lib/core/updater/channel_release_resolver.dart` 解析,复用 `FrontendVersionApi` 思路。
- **自动发布**:`release.yml` 的 `build-bundled-android` job 每次发版自动产出并上传:前端 `patch-<abi>.zip`+`manifest-<abi>.json`、后端 `libgojni-<abi>.so`+`backend-manifest-<abi>.json`(仅 arm64-v8a / armeabi-v7a;x86_64 无 gomobile 产物)。**无手动 workflow、无 versionCode 绑定**。
- **兼容键取代 versionCode**(自动、非手改):
  - **前端 libapp.so**:真正兼容边界是 **Flutter 引擎版本**(Dart AOT 快照 ↔ 引擎)。编译期 `AppConfig.flutterBinding`(= CI `FLUTTER_VERSION`,`--dart-define=FLUTTER_BINDING`)与 manifest 的 `flutterBinding` 比对:相同即兼容 → 应用时 `targetVersionCode=null` 让 flutter_patcher 绑定到当前设备(**不再跨 versionCode 被丢弃**);不同 → 不热更,交「整包不兼容」分支引导下 APK。
  - **后端 libgojni.so**:兼容边界是 gomobile 导出面(`mobile/export_surface.txt` + `release.yml` 导出面守卫,自动)。**去掉 versionCode**,靠「导出面冻结 + 崩溃回滚黑名单」保证任意老包热更到最新。
- **比较规则**:dev 比 **git commit hash**;stable 比**版本号**(semver,`lib/core/updater/version_compare.dart`)。已应用同补丁(`flutter_patcher.currentVersion == patchLabel` / 后端 confirmed)跳过。

## 能力边界(诚实)

| 场景 | 前端 libapp.so | 后端 libgojni.so |
|------|----------------|------------------|
| dev → 最新 dev | ✓(dev 共用 versionCode/引擎) | ✓ |
| stable → 最新 stable(引擎未变) | ✓(引擎键相同,跨 versionCode) | ✓(无 versionCode) |
| stable 且 Flutter 引擎升级 | ✗ → 走整包 APK(本就是新引擎新包) | ✓(与 gomobile 导出面无关) |
| 改了 mobile.go 导出面 / 加原生插件 | ✗ 整包 | ✗ 整包(导出面守卫拦截) |

- 仅 Android;仅 Bundle 版(`hasEmbeddedBackend`)+ local 模式后端在运行时才检查后端补丁。iOS 静态 xcframework + Apple 政策 → 不支持。

## 可行性根基(原生机制)

- `libgojni.so` 由 gomobile 的 `go.Seq` 静态块 `System.loadLibrary("gojni")` 在首次触碰任意 `mobile.*` 类时懒加载。
- `SongloftApplication.onCreate()`(早于任何 `mobile.*`)`System.load("<filesDir>/backend_patch/active/libgojni.so")` 预加载补丁版;bionic 按 ELF `DT_SONAME` 去重,后续 `loadLibrary("gojni")` 复用补丁版。前置:`DT_SONAME == libgojni.so`(release.yml `readelf -d` 断言)。
- W^X:targetSdk 29+ 从私有目录 `System.load()` 下载的 .so **允许**(限制的是 execve 与含 text-reloc 的 .so)。
- 必须冷重启进程生效(Go runtime 单进程只初始化一次);`SystemNavigator.pop()` 只关 Activity,不够 → 用 `ProcessRestarter`(AlarmManager + killProcess)真重启。

## 客户端流程(统一入口)

首页 `initState` 每会话调一次 `PatchUpdateDialog.maybeShow`(`lib/core/updater/`):
1. 并行检查前端(`PatchUpdateService.checkPatch`)+ 后端(`BackendPatchService.checkPatch`,仅 `hasEmbeddedBackend && Android && local && 后端运行`)本渠道最新补丁,各自过滤「忽略此版本」。
2. 任一有更新 → 弹**一个**对话框列出待更新组件 + GitHub 代理选择器(复用 `GithubProxySelectionMixin`),按钮 **[忽略此版本] [稍后] [下载并更新]**。
3. 「下载并更新」一起下载(前端 `flutter_patcher.applyPatch` stage libapp.so、后端 `downloadAndStage` 下 .so + md5 + 交原生 `stageBackendPatch`)。
4. 完成 → 「立即重启」**一次** `EmbeddedBackendService.restartProcess()`(真进程冷启),提示「应用将重启,可能中断当前播放」。「稍后」保留 staged,下次冷启一并生效。
5. 前端补丁引擎不兼容(新 stable 换了 Flutter)→ checkPatch 返回 null → 落入「整包不兼容」分支跳设置页下 APK。

## 崩溃回滚 + 黑名单(原生 `BackendPatchManager`)

状态存纯文件 `filesDir/backend_patch/state.json`(需在 Dart 引擎前可读)。`preloadIfStaged`:无 active / 在黑名单 → 不预加载(回滚随包版);`confirmed` → 直接 `System.load`;`staged/pending` → `bootAttempts++`,超阈值(>1)判定启动即崩 → 拉黑(gitCommit+md5)+ 清 active + 回滚;`System.load` 抛异常 → 立即拉黑回滚,绝不让进程崩。confirm 时机:新进程后端健康后(`startup_gate` 冷启 / `backend_lifecycle` resume)`BackendPatchService.confirmIfHealthy()` 校验 `/api/v1/version` git_commit 一致 → `confirmBackendPatch()`。

## Manifest 约定(父仓库 Release 资产,按 ABI)

- 前端 `manifest-<abi>.json`:`{hasUpdate, patch:{version(patchLabel), semanticVersion, gitCommit, flutterBinding, patchUrl, md5}}`
- 后端 `backend-manifest-<abi>.json`:`{hasUpdate, backend:{abi, version, gitCommit, buildTime, soUrl, md5, size}}`(无 targetVersionCode)
- 都随 `release.yml` 的 release(tag=dev / v<x.y.z>)自动上传;客户端按渠道解析最新。

## 发布纪律

- 每次发版自动带补丁,无需额外操作;**导出面守卫**(`go doc ./mobile` 比对 `mobile/export_surface.txt`)在 `release.yml` 里,导出面漂移即 fail(须整包)。
- 改 Flutter 版本 → 前端老包自动走整包(引擎键不匹配);改 mobile.go 导出面 / 加原生插件 → 整包。

## 验证

1. **dev 任意→最新**:老 dev 包 → 弹一个对话框列前端+后端 → 一次下载 → 单次重启 → `/api/v1/version` git_commit 变最新 + 前端改动生效 → confirm。
2. **stable 任意→最新(引擎未变)**:老 stable 包 → 后端按版本号更新到最新 stable;前端引擎键相同 → 也更新。
3. **stable 引擎已变**:前端引擎键不匹配 → 前端走整包;后端仍可热更。
4. **崩溃回滚**:坏 .so → System.load/Init 崩 → bootAttempts 超阈值拉黑回滚,不再下发。
5. **无 versionCode 依赖**:后端全程不比 versionCode;CI `readelf` + 导出面守卫为唯一后端门禁。

## 注意

- Google Play 等渠道可能限制动态下发 `.so`,本项目走自控/侧载分发。
- 标准版(非 bundle)前端热更仍走 player 仓库的 `patch-release.yml`(手动),客户端逻辑对老式 manifest 向后兼容(无 `flutterBinding` 时退回 versionCode 绑定的旧行为)。
