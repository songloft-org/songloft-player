# Bundle 版 Android 后端热更新（换 libgojni.so）

本文描述 Bundle 本地模式下 songloft-player 对**内嵌 Go 后端**的**自托管 Android 热更新**：冷启动整包替换 gomobile 生成的 `libgojni.so`，补丁托管在**父仓库** GitHub Release，**启动检查 + 手动更新**，与前端 [flutter_patcher 热更](./flutter_patcher_hotupdate.md)合并为一次体验（两个 so 一起下载、只重启一次）。

> 中英双语并存，改一版需同步 `docs/en/backend_hotupdate.md`。

## 范围与边界

| 维度 | 结论 |
|------|------|
| 平台 | **仅 Android**。iOS 后端是静态 `.xcframework` 编译期链接、且 Apple 禁止下载执行原生码 → 不支持，只能整包；桌面本次不做 |
| 适用构建 | 仅 Bundle 版（`--dart-define=HAS_BACKEND=true`，`AppConfig.hasEmbeddedBackend`）且 `local` 模式后端在运行；远程模式后端在远端服务器，不由客户端热更 |
| 能热更 | `mobile.go` 导出面（`Start/Stop/IsRunning/GetPort`）**不变**前提下的任意内部 Go 逻辑（handlers/services/scanner/cache 等 bugfix） |
| 不能热更 | 改 `mobile.go` 导出签名（需连 classes.jar/DEX 一起换）、原生依赖变更、gomobile/引擎升级 → 必须发新 APK。x86_64 无 aar 产物，不覆盖 |
| 生效时机 | 补丁下载后**下次冷启动**生效（Go runtime 单进程只初始化一次，不能进程内热替换）；自带 pending→confirmed 崩溃回滚 + 黑名单 |
| 渠道 | **dev 更 dev、stable 更 stable，不跨渠道**（由编译期 `FRONTEND_VERSION` 决定 tag） |
| 版本比较 | **dev 比 git commit hash；stable 比版本号**（semver 三段）。见 `lib/core/updater/version_compare.dart` |
| 校验 | md5（客户端下载后 + 原生 `System.load` 失败 catch） |

## 可行性根基（原生机制）

- `libgojni.so` 由 gomobile 生成的 `go.Seq` 静态块 `System.loadLibrary("gojni")` 在**首次触碰任意 `mobile.*` 类时懒加载**。
- 自定义 `SongloftApplication.onCreate()`（早于任何 `mobile.*` 调用）用 `System.load("<filesDir>/backend_patch/active/libgojni.so")` **预加载补丁版**；bionic 动态链接器按 ELF `DT_SONAME` 去重，后续 `loadLibrary("gojni")` 复用补丁版，不再加载 APK 随包旧版。
- 前置铁律：补丁 .so 的 `DT_SONAME` 必须 == `libgojni.so`（Go c-shared 默认满足，发布 workflow `readelf -d` 断言）。
- W^X：targetSdk 29+ 从应用私有目录 `System.load()` 下载来的 .so **允许**（限制的是 execve 可执行文件与含 text-relocation 的 .so）。

## 客户端流程（统一入口，与前端补丁合并）

入口：首页 `initState` 每会话调一次 `PatchUpdateDialog.maybeShow`（`lib/core/updater/`）。

1. **并行检查**前端 flutter_patcher 补丁（libapp.so）+ 后端补丁（libgojni.so，`BackendPatchService.checkPatch`）。
2. 任一有更新且未忽略 → 弹**一个**对话框，列出待更新组件 + GitHub 代理选择（复用 `GithubProxySelectionMixin`），按钮 **[忽略此版本] [稍后] [下载并更新]**。
3. 「下载并更新」把可用补丁一起下载（前端 `flutter_patcher.applyPatch` stage libapp.so、后端 `downloadAndStage` 下载 .so + md5 + 交原生 `stageBackendPatch` 落地）。
4. 完成 → 「立即重启」**一次** `ProcessRestarter`（真进程冷启：libapp.so 生效 + Application 预加载 libgojni.so）；提示「应用将重启，可能中断当前播放」。「稍后」保留 staged，下次自然冷启一并生效。

- 忽略：分别记 `AppPreferences.ignoredPatchVersion`（前端）/ `ignoredBackendPatchVersion`（后端）。
- 后端「当前版本」运行期取自 `GET /api/v1/version`（含 `version` / `git_commit`），非编译期常量。

## 崩溃回滚 + 黑名单（原生 `BackendPatchManager`）

状态存纯文件 `filesDir/backend_patch/state.json`（需在 Dart 引擎起来前可读，不用 shared_preferences）。

- `preloadIfStaged`：无 active / 在黑名单 → 不预加载（回滚随包版）；`state=confirmed` → 直接 `System.load`；`staged/pending` → `bootAttempts++`，超阈值（>1）判定启动即崩 → 拉黑（gitCommit+md5）+ 清 active + 回滚；否则置 pending 后 `System.load`。`System.load` 抛异常 → 立即拉黑 + 回滚，绝不让进程崩。
- confirm 时机：新进程后端启动健康后（`startup_gate` 冷启路径 / `backend_lifecycle` resume）调 `BackendPatchService.confirmIfHealthy()`，`/api/v1/version` 的 git_commit 与 staged 一致 → `confirmBackendPatch()`（state→confirmed、bootAttempts=0）。

## 托管与 URL 约定（父仓库 Release，按 ABI）

补丁传到父仓库 `songloft-org/songloft`（`AppConfig.frontendUpdateRepo`）的 Release，与 bundle 客户端同 tag（dev / v<x.y.z>）。

- 后端 manifest：`backend-manifest-<abi>.json`
  - 字段：`{hasUpdate, backend:{abi, version, patchLabel, gitCommit, buildTime, targetVersionCode, soUrl, md5, size}}`
  - `targetVersionCode` 绑定安装包 versionCode（锁死导出面/classes.jar 与安装包一致），不匹配不下发。
- 后端补丁包：同 Release 的 `libgojni-<abi>.so`
- 配套前端补丁：同 tag 的 `manifest-<abi>.json` + `patch-<abi>.zip`（保证两个 so 同 tag 可一起下载）。

## 发布补丁（`.github/workflows/backend-patch-release.yml`，手动）

1. 从基线（dev 分支 / 正式版对应 commit）cherry-pick **纯内部逻辑**修复，**保持 `mobile.go` 导出面不变**；
2. dispatch，填 `target_version`（dev 或基线版本号如 `2.11.0`）、`patch_version`（**stable 专用**，须 > 基线如 `2.11.1`，供版本号比较；dev 忽略）、`patch_label`（如 `2.11.1-b1`）；
3. workflow：**导出面守卫**（`go doc ./mobile` 比对 `mobile/export_surface.txt`，变更即 fail）→ `make build-go-mobile-android`（`VERSION=<so 版本>`）→ `flutter build apk --split-per-abi`（`FRONTEND_VERSION=<基线渠道>`）→ 每 ABI：`flutter_patcher:pack` 出前端 `patch-<abi>.zip`、从 APK 抽 `libgojni-<abi>.so`（**`readelf -d` 断言 SONAME=libgojni.so**）→ 写两份 manifest → `gh release upload <tag> ... --clobber`。

## 发布纪律

- **内部逻辑修复（导出面不变）** → 发补丁，冷启生效；
- **改导出面 / 原生依赖 / 引擎** → 打新 tag 发新 APK（不给旧基线发补丁）；导出面守卫会拦截误发。
- stable 补丁务必把 `patch_version` 提到高于基线，否则客户端按版本号比较检测不到。

## 验证

1. **两 so 一起换、单次重启**：同 tag 同发前端补丁 + 后端补丁 → 弹一个对话框列两者 → 一次下载 → 立即重启一次 → 新进程 libapp.so 生效 + 预加载 libgojni.so → `/api/v1/version` git_commit/版本号变新值 → confirm。
2. **崩溃回滚**：发一个 Init panic 的补丁 → 应用+重启 → 早期崩 → 再启 bootAttempts 超阈值 → 拉黑 + 回滚随包版 → 不再下发。
3. **静默**：remote 模式 / 标准版 / iOS / x86_64 → 后端分支跳过，前端热更流程照旧。
4. **渠道 + 比较**：dev 只拉 dev 且比 git hash；stable 只拉 v<x.y.z> 且比版本号；不跨渠道。
5. **忽略**：点忽略后同 patchLabel 不再弹；更新 patchLabel 恢复弹。

## 注意

- Google Play 等渠道可能限制动态下发可执行 `.so`，本项目走自控/侧载分发。
- 与前端 flutter_patcher（换 libapp.so）**正交**，互不影响。
