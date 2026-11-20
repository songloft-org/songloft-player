# Bundle 版 Android 热更新(前端 libapp.so + 后端 libgojni.so)

本文描述 Bundle 本地模式下 songloft-player 的 **Android 自托管热更新**:**无基线**——任何非最新 dev 更新到最新 dev、任何非最新 stable 更新到最新 stable。Flutter 标准版由客户端 Release 发布，Bundle 包由后端 Release 发布；Bundle 使用独立 manifest 与补丁文件名前缀。**每次发版自动**把最新补丁挂到 Release,客户端启动检查、一次下载、只重启一次:一次真进程冷启同时让前端 `libapp.so`(flutter_patcher)与后端 `libgojni.so`(gomobile)生效。

> 中英双语并存,改一版需同步 `docs/en/backend_hotupdate.md`。

## 核心模型:无基线 + 自动发布 + 工具链兼容键

- **无基线**:客户端查**后端 Release 的本渠道最新**——dev→滚动 tag `dev`;stable→GitHub `/releases/latest`(dev 是 prerelease,latest 天然返回最新正式版)。由 `lib/core/updater/channel_release_resolver.dart` 解析,复用 `FrontendVersionApi` 思路。
- **自动发布**:后端仓库 `release.yml` 的 Flutter Bundle job 每次发版自动产出并上传 Bundle 前端 `bundle-patch-<abi>-<commit>.zip`+`bundle-flutter-version.json`、后端 `bundle-libgojni-<abi>-<backend-sha>.so`+`bundle-flutter-backend-manifest-<abi>.json`(arm64-v8a / armeabi-v7a / x86_64,gomobile bind 含 android/amd64 目标)。补丁协议不绑定 versionCode。若后端构建只上传测试包，检查 [Bundle 发布签名与触发条件](https://songloft.hanxi.cc/bundle-mode#发布触发与签名)。
- **兼容键取代 versionCode**(自动、非手改):
  - **前端 libapp.so** — Gradle 将通用 APK 的 `versionCode` 下限设为 4002，以便覆盖安装旧分架构包（最高 4001）。CI 用 aapt 从 APK 读取实际版本码，并写入各 ABI 的前端补丁和 manifest。客户端检查 `versionCode`、Flutter 引擎键（`flutterBinding`）和原生契约，版本码或引擎不匹配时引导下载整包。
  - **后端 libgojni.so**:兼容边界是 gomobile 导出面(`mobile/export_surface.txt` + `release.yml` 导出面守卫,自动)。**去掉 versionCode**,靠「导出面冻结 + 崩溃回滚黑名单」保证任意老包热更到最新。
- **比较规则**:dev 比 **git commit hash**;stable 比**版本号**(semver,`lib/core/updater/version_compare.dart`)。已应用同补丁(`flutter_patcher.currentVersion == patchLabel` / 后端 confirmed)跳过。

## 原生契约哈希闸(Dart↔原生 / Go 导出面运行时校验)

热更只换 native .so,**Kotlin/Java 永不热更**(只随整包 APK 走)。versionCode 与 `flutterBinding` 两闸抓不到 **Dart↔原生 MethodChannel 契约漂移**:若某次发版给某 `com.songloft/*` channel 加了方法(Kotlin 加 + Dart 调),既不动引擎也不动 versionCode → 现有闸全放行 → 老包热更到新 `libapp.so`,但设备旧 Kotlin 没这方法 → 运行时 `MissingPluginException`。dev 渠道尤甚:只有一个滚动 release,git commit 每次都不同,无法据此区分「正常新版本」与「契约不兼容版本」。标准版无后端桥但同样热更 `libapp.so`,风险面更大(自定义 channel + 大量原生插件)。

**唯一能忠实反映「本地 APK 原生层支持什么」的信号只能运行时从不被热更的 Kotlin 读取**(Dart/Go 侧常量都会被补丁覆盖)。为此引入原生契约哈希闸:

- **两个哈希**,由原生 channel `com.songloft/contract` 的 `getHash` 一次返回 `{"dart","go"}`:
  - `dart` = Dart↔原生契约 = {所有 `com.songloft/*` channel 名 + 方法名集合 + `GeneratedPluginRegistrant` 插件集 + `.flutter-plugins-dependencies` 里 android 原生插件 name+version + release ProGuard 规则}。门控**前端 libapp.so**(标准版 + bundle 都用)。ProGuard 规则改变 JNI 描述符时也需要整包 APK；只修改规则的注释和空行不改变哈希。
  - `go` = `sha256(mobile/export_surface.txt)`。门控**后端 libgojni.so**(仅 bundle),补上「老 APK Kotlin vs 新 libgojni 运行时错配」——这是 CI 导出面冻结守卫看不到的维度。
- **值的来源**:CI 用 `scripts/compute_native_contract.sh`(确定性)在 `flutter build apk` 前算出,同时写进 APK asset `android/app/src/main/assets/native_contract.json`(Kotlin 读它返回)与热更 manifest(`patch.contractHash` / `backend.contractHash`),**同源同值**。
- **比对**:`checkPatch` 里 `contractHashBlocks(manifestHash, deviceHash)`——两端非空且不同 → 返回 null(落整包)。**任一为空**(老宿主无此 channel / 本地开发无 asset / 老式 manifest 无字段)→ 视为未知、**不拦截**(降级),同 `flutterBinding` 闸。
- **iOS 不参与**:热更 Android-only,`NativeContractService` 的 `_isAndroid` 守卫使 iOS 永不触发。
- **残余风险(诚实)**:Kotlin 方法集为启发式解析(`call.method == "x"` / `when` 分支 `"x" ->`),动态拼接的方法名可能漏掉;插件「同版本号但内部原生实现变化」也不捕获。宁滥勿缺(误触发只是多走整包=安全侧),换来零手维护清单。

## 能力边界(诚实)

| 场景 | 前端 libapp.so | 后端 libgojni.so |
|------|----------------|------------------|
| dev → 最新 dev | ✓(dev 共用 versionCode/引擎) | ✓ |
| stable → 最新 stable(引擎未变) | ✓(引擎键相同,跨 versionCode) | ✓(无 versionCode) |
| stable 且 Flutter 引擎升级 | ✗ → 走整包 APK(本就是新引擎新包) | ✓(与 gomobile 导出面无关) |
| 改了 `com.songloft/*` channel 方法集 / 增删原生插件 | ✗ 整包(dart 契约哈希不匹配) | —— |
| 改了 mobile.go 导出面 | ✗ 整包(前端不受影响则仍可热更) | ✗ 整包(导出面守卫 + go 契约哈希双拦) |

- 仅 Android;仅 Bundle 版(`hasEmbeddedBackend`)+ local 模式后端在运行时才检查后端补丁。iOS 静态 xcframework + Apple 政策 → 不支持。

### Kotlin 层冻结策略

`classes.dex`（Kotlin/Java 代码）不可热更，但可通过**冻结 Kotlin 方法接口**让契约哈希保持不变，使日常迭代不阻断 `libapp.so` 热更。策略：

1. **参数扩展优先**：新样式/行为走现有方法（`show`/`updateConfig`）的参数 Map 加 key，Kotlin 侧 `call.argument` 缺失时取默认值。方法名集合不变 → 哈希不变。
2. **`exec` 逃逸方法**：`FloatingLyricPlugin` 预埋 `exec` 方法，新原生能力通过 `exec` + `cmd` 参数实现。**关键**：子命令分发用 `if/else`（不用 `when`），因为 `compute_native_contract.sh` 的 grep 会捕获 `"x" ->` 模式但不捕获 `cmd == "x"` 比较。Dart 侧 `exec` 返回 null 表示当前 APK 不支持（优雅降级，不崩溃）。
3. **纯 Dart 插件优先**：增删带原生代码的 Flutter 插件会改变 `GeneratedPluginRegistrant` → 哈希变。能用 Dart 实现则不引入原生插件。

冻结后的能力边界变化：

| 场景 | 是否可热更 |
|------|-----------|
| FloatingLyric 新样式参数（字号/颜色/对齐） | ✓ 走 `updateConfig` 参数 Map |
| FloatingLyric 新原生能力（exec 子命令） | ✓ APK 含该子命令时生效，不含时降级 |
| 新增 Kotlin→Dart 反向回调 | ✓ `channel.invokeMethod` 不被哈希脚本捕获 |
| Widget 新数据字段 | ✓ SharedPreferences key 不影响哈希 |
| 增删带原生代码的 Flutter 插件 | ✗ 仍需整包 |

详见 `songloft-player/AGENTS.md`「Kotlin 层冻结规则」。

## 可行性根基(原生机制)

- `libgojni.so` 由 gomobile 的 `go.Seq` 静态块 `System.loadLibrary("gojni")` 在首次触碰任意 `mobile.*` 类时懒加载。
- `SongloftApplication.onCreate()`(早于任何 `mobile.*`)`System.load("<filesDir>/backend_patch/active/libgojni.so")` 预加载补丁版;bionic 按 soname 去重,后续 `loadLibrary("gojni")` 复用补丁版。**gomobile 产物无 DT_SONAME**(正常),bionic(minSdk 24 ≥ API 23)回退用**文件 basename** 作 soname;客户端落地文件名固定为 `libgojni.so`,故去重仍生效。release.yml 只校验「soname 为空或恰为 libgojni.so」(非空且不同才失败)。
- W^X:targetSdk 29+ 从私有目录 `System.load()` 下载的 .so **允许**(限制的是 execve 与含 text-reloc 的 .so)。
- 必须冷重启进程生效(Go runtime 单进程只初始化一次);`SystemNavigator.pop()` 只关 Activity,不够 → 用 `ProcessRestarter`(AlarmManager + killProcess)真重启。

## 客户端流程(统一入口)

`ShellLayout.initState` 每会话调一次 `PatchUpdateDialog.maybeShow`(`lib/core/updater/`)。**放在 Shell 而不是首页**:Shell 全会话常驻(延迟期间不会被 dispose),且 `HomePage` 与 `TvHomePage` 都在它下面,TV 模式一并覆盖。

**启动路径的三道闸**(按序,任一拦住即静默早退、一个网络请求都不发):
1. **开关**:「设置 → 关于与更新 → 启动时自动检查更新」(`autoUpdateCheckProvider`,prefs `auto_update_check_enabled`,缺省开)。
2. **节流**:距上次检查不足 `kPatchCheckThrottle`(6h,prefs `last_patch_check_at`)则跳过。时间戳刻意在发起检查**之前**就写 —— `checkPatch` 把网络异常都吞成 null,调用方分不清「没补丁」与「查失败」;宁可一次失败等一个窗口,也不要弱网环境每次冷启都白跑一轮,逃生门是手动入口。
3. **延迟 + 超时**:首帧后延 `kPatchCheckStartupDelay`(4s)才发起,让首页歌单/电台请求先落地;检查阶段套 20s 整体超时。

> **闸门顺序是「先等认证就绪、再等延迟」,不要退回只判 `mounted`。** 未登录时 `/login` 不在 ShellRoute 下,但 Shell 会在认证状态定型前先挂载一次再被重定向销毁。只判 `mounted` 是竞态而非因果:认证解析慢于延迟时(Web 的 secure_storage 走 IndexedDB、冷 Keychain、慢设备),那次短命挂载会吃掉本会话唯一的检查名额、写掉节流窗口,还带着无 token 的 dio 去查后端 `/settings/github-proxy`。因此改为 `ref.listenManual(authStateProvider)` 等到 `AuthStatus.authenticated` 才排延迟(与同类 `_scheduleAutoEnterLyrics` 等播放状态恢复同形),延迟用**可取消的 `Timer`** 而不是 `Future.delayed` —— 有句柄才能在 `dispose` 里取消,否则短命挂载会把已销毁的 State 子树多钉住一个延迟时长,且未来任何 pump 出 Shell 的 widget test 都会撞上「A Timer is still pending」。

**手动入口**:「设置 → 关于与更新 → 检查客户端更新」(与整包更新合并为一个 tile)走 `maybeShow(manual: true)` —— 跳过开关与节流、**绕过「忽略此版本」名单**(只是本次不过滤,并不清除 `ignored_*` 记录)、不写节流时间戳;无补丁时不做整包检查,由调用方落回 `FrontendUpgradeDialog`(它自带「正在检查 / 已是最新 / 失败」三态,故无需额外 snackbar)。闸门语义由 `test/core/updater/patch_update_dialog_gates_test.dart` 覆盖。

**查到补丁但弹不出来时要回滚节流时间戳**:`context.mounted` 为 false(用户在检查途中登出 / 离开设置页)时,这次发现只能丢,但必须把时间戳回滚回旧值 —— 否则一次「恰好卸载」会把一个真实可用的补丁压满一个节流窗口。该分支单独打日志,不要复用「无可热更补丁」那条,否则排查时误导人。

**已知缺口(改动前即如此,不是本次引入)**:手动入口所在的 tile 在 `AppConfig.isEmbedded` 守卫**之内**,而开关在守卫**之外**。所以 embedded 构建里用户能关掉自动检查、却没有手动入口 —— 开关文案因此刻意不承诺「关闭后改为手动检查」。另外某版本被忽略后,手动入口会一直先弹该补丁对话框,因而够不到整包版本信息。

放行后的流程:
1. 并行检查前端(`PatchUpdateService.checkPatch`)+ 后端(`BackendPatchService.checkPatch`,仅 `hasEmbeddedBackend && Android && local && 后端运行`)本渠道最新补丁,各自过滤「忽略此版本」(`manual` 时不过滤)。
2. 任一有更新 → 弹**一个**对话框列出待更新组件 + GitHub 代理选择器(复用 `GithubProxySelectionMixin`),按钮 **[忽略此版本] [稍后] [下载并更新]**。
3. 「下载并更新」一起下载(前端 `flutter_patcher.applyPatch` stage libapp.so、后端 `downloadAndStage` 下 .so + md5 + 交原生 `stageBackendPatch`)。
4. 完成 → 「立即重启」**一次** `EmbeddedBackendService.restartProcess()`(真进程冷启),提示「应用将重启,可能中断当前播放」。「稍后」保留 staged,下次冷启一并生效。
5. 前端补丁引擎不兼容(新 stable 换了 Flutter)→ checkPatch 返回 null → 落入「整包不兼容」分支跳设置页下 APK。

## 崩溃回滚 + 黑名单(原生 `BackendPatchManager`)

状态存纯文件 `filesDir/backend_patch/state.json`(需在 Dart 引擎前可读)。`preloadIfStaged`:无 active / 在黑名单 → 不预加载(回滚随包版);`confirmed` → 直接 `System.load`;`staged/pending` → `bootAttempts++`,超阈值(>1)判定启动即崩 → 拉黑(gitCommit+md5)+ 清 active + 回滚;`System.load` 抛异常 → 立即拉黑回滚,绝不让进程崩。confirm 时机:新进程后端健康后(`startup_gate` 冷启 / `backend_lifecycle` resume)`BackendPatchService.confirmIfHealthy()` 校验 `/api/v1/version` git_commit 一致 → `confirmBackendPatch()`。

## Manifest 约定(按 Release 资产与 ABI)

- 标准版前端使用 Flutter Release 的 `manifest-<abi>.json`;Bundle 前端使用后端 Release 的 `bundle-flutter-version.json`，Bundle 结构为 `{hasUpdate, patches:{<abi>: patch}}`。
- Bundle 后端使用 `bundle-flutter-backend-manifest-<abi>.json`:`{hasUpdate, backend:{abi, version, gitCommit, buildTime, soUrl, md5, contractHash, size}}`(无 targetVersionCode)。
- Bundle 资产由后端仓库 `release.yml` 构建；Release 准备阶段固定主仓库、Flutter/Lynx 子模块和 `pkg/tag` 的完整 SHA。
- Bundle 资产随后端 Release（tag=dev / v<x.y.z>）自动上传，客户端按渠道解析最新。

## 发布纪律

- 每次发版自动带补丁,无需额外操作;**导出面守卫**(`go doc ./mobile` 比对 `mobile/export_surface.txt`)在客户端构建 workflow 里,导出面漂移即 fail(须整包)。
- 改 Flutter 版本 → 前端老包自动走整包(引擎键不匹配);改 mobile.go 导出面 / 加原生插件 → 整包。
- **原生契约哈希全自动**:`scripts/compute_native_contract.sh` 每次构建重算 asset + manifest,无需手维护版本号或清单。改 `com.songloft/*` channel 方法集 / 增删原生插件 → dart 哈希自动变,老包读到不匹配自动走整包;导出面变 → go 哈希自动变。**无需 bump 任何常量**。

## 验证

1. **dev 任意→最新**:老 dev 包 → 弹一个对话框列前端+后端 → 一次下载 → 单次重启 → `/api/v1/version` git_commit 变最新 + 前端改动生效 → confirm。
2. **stable 任意→最新(引擎未变)**:老 stable 包 → 后端按版本号更新到最新 stable;前端引擎键相同 → 也更新。
3. **stable 引擎已变**:前端引擎键不匹配 → 前端走整包;后端仍可热更。
4. **崩溃回滚**:坏 .so → System.load/Init 崩 → bootAttempts 超阈值拉黑回滚,不再下发。
5. **无 versionCode 依赖**:后端全程不比 versionCode;CI `readelf` + 导出面守卫为唯一后端门禁。

## 注意

- Google Play 等渠道可能限制动态下发 `.so`,本项目走自控/侧载分发。
- **标准版(非 bundle)也是无基线**:player 仓库 `build-and-release.yml` 的 `build-android` 每次发版自动产出前端 `patch-<abi>-<commit>.zip`+`manifest`(无后端);手动 `patch-release.yml` 已删除。客户端逻辑对老式 manifest 仍向后兼容(无新字段时退回 hasUpdate + versionCode 绑定旧行为)。
