# Shorebird 热更新接入文档

本文档描述在 **songloft-player** 中接入 [Shorebird](https://shorebird.dev) Dart code push（免安装热更新）的完整实现方案，覆盖**自动版本发布**、**仅正式版接入、dev 版本不接入**两条硬约束。

> 相关背景与选型对比见团队讨论；本文只讲「决定接入 Shorebird 后怎么落地」。

> **本仓库落地现状（2026-07）**：Android 主路径已落地——CI（`build-and-release.yml`）
> tag 触发走 `shorebird release android --artifact apk`，新增手动补丁 workflow
> `shorebird-patch.yml`；客户端采用**主动式更新流程**（`shorebird.yaml` 设
> `auto_update: false`，首页每会话检查一次：发现新版本→弹「是否下载」对话框→下载进度→
> 「重启生效」提示，见 `lib/core/updater/`），而非静默后台更新。
> **app_id 不硬编码在 `shorebird.yaml`**：仓库内只放占位值，真实 app_id 存在 GitHub
> 仓库变量 `SHOREBIRD_APP_ID`，CI 在 release / patch 前覆写（见 §3.2、§4.3）。
> iOS 仍按 §4.2 建议**作为独立后续任务**，暂未接入。

---

## 1. 范围与边界

| 维度 | 结论 |
|------|------|
| 平台 | **Android + iOS**（Shorebird 仅支持这两端）。Web / Windows / macOS / Linux **不接入**，继续走整包更新。 |
| 渠道 | **仅正式版**（`v*` tag 构建）接入 Shorebird release / patch。**dev 版（push main 的滚动 prerelease）完全不接入**，保持现有 `flutter build`。 |
| 能热更 | `lib/` 下任意 Dart 代码、纯 Dart 依赖、Flutter assets（随 release 打包的）。 |
| 不能热更 | 原生 Kotlin/Swift、`AndroidManifest.xml`/`Info.plist`、含原生代码的插件（media_kit / just_audio 等）的原生侧、Flutter 引擎/SDK 升级 —— 这些必须发新正式版整包。 |
| 生效时机 | 补丁后台静默下载，**下次冷启动生效**，不在当前进程内替换。 |

### 为什么天然只发正式版

现有 CI（`.github/workflows/build-and-release.yml`）的版本口径已经是：

```bash
if [[ "$GITHUB_REF" == refs/tags/v* ]]; then
  VERSION="$PUBSPEC_VERSION"   # 正式版
else
  VERSION="dev"                # push main / workflow_dispatch
fi
```

因此**只要把 Shorebird 步骤用 `startsWith(github.ref, 'refs/tags/v')` 门控**，dev 构建路径就一行都不碰 Shorebird，天然满足"dev 不接入"。

---

## 2. 核心概念

- **release（基线）**：一次 `shorebird release android/ios` 会同时（a）编译产物（AAB/APK/IPA）、（b）把该版本的 Dart 快照指纹登记到 Shorebird 云。每个 release 由 `versionName+versionCode`（即 pubspec 的 `2.11.0+1`）唯一标识。
- **patch（补丁）**：`shorebird patch android/ios --release-version=2.11.0+1` 针对**某个已存在的 release** 生成 Dart 层二进制 diff，下发给装了该 release 的设备。
- **强绑定**：补丁只对同 `release-version` + 同引擎 + 同 flavor 的设备生效；正式版升级后旧补丁自然失效。
- **自动更新**：客户端内置 updater，App 启动时后台拉取适配补丁，下次冷启动应用，无需任何 UI 代码。

---

## 3. 一次性准备（只做一次）

### 3.1 安装 CLI 并登录

```bash
curl --proto '=https' --tlsv1.2 https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh -sSf | bash
shorebird login          # 本地开发者账号（浏览器授权）
```

### 3.2 初始化项目

在 `songloft-player/` 根目录：

```bash
shorebird init
```

它会：
- 生成 `shorebird.yaml`（含唯一 `app_id`），并自动把它加入 `pubspec.yaml` 的 `assets:`（打包进 App，运行时 updater 读取）。
- Android + iOS **共用同一个 `app_id`**（Shorebird 控制台里按平台分别管理 release）。

`shorebird.yaml` 关键字段：

```yaml
app_id: <生成的-uuid>
auto_update: true   # 默认 true：启动时自动检查+下载补丁（推荐保留）
```

> `shorebird.yaml` **必须入库**。`app_id` 是公开标识（非密钥），本可直接提交；但**本仓库**
> 约定把真实 `app_id` 放进 GitHub 仓库变量 `SHOREBIRD_APP_ID`，入库的 `shorebird.yaml`
> 只保留占位值（`00000000-...`），CI 在 `shorebird release` / `shorebird patch` 前用
> `sed` 覆写占位值（见 §4.1、§5）。占位值只为满足 pubspec `assets:` 对文件存在的要求——
> dev/web/desktop 等非 Shorebird 构建打包它但不启用 updater，占位值无副作用。`shorebird init`
> 首次生成真实 `app_id` 后填入 GitHub 变量即可。

### 3.3 确认 Flutter 版本兼容

Shorebird 自带**定制版 Flutter**（要求 Flutter ≥ 3.24）。项目当前用 `FLUTTER_VERSION: '3.44.6'`（stable，见 workflow env）。

> ✅ **3.44.6 已被 Shorebird 支持** —— Shorebird 官方 GitHub Actions 示例用的就是 `FLUTTER_VERSION: 3.44.6`。CI 里 `shorebird release` 传 `--flutter-version=3.44.6`，与整包构建完全一致。

- 只在 `shorebird release` 上传 `--flutter-version`；**`shorebird patch` 不传**（见 §5，它会自动探测目标 release 的构建版本）。
- 若将来升级 `FLUTTER_VERSION`：先 `shorebird flutter versions list` 确认新版本受支持，升级后**旧补丁作废**，需发新正式版；此后针对新 release 的补丁会自动用新版本构建。

### 3.4 创建 CI 授权 token

从 **[Shorebird Console](https://console.shorebird.dev) → Account → API Keys** 创建 API Key（key 值只显示一次），存为 GitHub secret：**`SHOREBIRD_TOKEN`**。

> `shorebird login:ci` 已废弃（旧 token 用到 2026-09），新 token 一律走 Console 创建；环境变量名仍是 `SHOREBIRD_TOKEN`，不变。

### 3.5 Android 产物形态的重要变化 ⚠️

**本仓库已统一为单个 universal APK**：无论 dev 还是正式版，Android 都只产出一个含全部 ABI 的 APK，不再 split-per-abi 拆 arm64-v8a / armeabi-v7a / x86_64 三包。

- dev：`flutter build apk --release`（普通 flutter，无 Shorebird）产出单个 universal APK。
- 正式版：`shorebird release android --artifact apk` 产出单个 universal APK（同时登记 Shorebird 基线）。

- 取舍：universal APK 体积增大（打包多份 ABI 的原生库），但分发链路更简单，且**补丁分发不受影响** —— updater 会自动为设备架构下发对应的 patch。

---

## 4. 自动版本发布（CI 改造）

目标：**push `v*` tag 时，Android/iOS 自动执行 `shorebird release`**（既产出可下载安装包，又登记 Shorebird 基线）；push main 的 dev 构建保持原样。

只改 `build-android`、`build-ios` 两个 job；`build-web`/`build-linux`/`build-windows`/`build-macos` 与 `release` 汇总 job **完全不动**。

### 4.1 `build-android` job 改造

在 `Extract version` 之后、`Build APK` 之前插入 Shorebird 安装步骤（**仅 tag 触发**）：

```yaml
      # 仅正式版（tag）安装 Shorebird CLI；dev 构建跳过，不引入任何依赖
      - name: Setup Shorebird
        if: startsWith(github.ref, 'refs/tags/v')
        uses: shorebirdtech/setup-shorebird@v1
```

把原 `Build APK` 步骤改为按渠道分支：

```yaml
      - name: Build APK
        env:
          ANDROID_KEYSTORE_PASSWORD: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
          ANDROID_KEY_ALIAS: ${{ secrets.ANDROID_KEY_ALIAS }}
          ANDROID_KEY_PASSWORD: ${{ secrets.ANDROID_KEY_PASSWORD }}
          SHOREBIRD_TOKEN: ${{ secrets.SHOREBIRD_TOKEN }}
        run: |
          COMMON_DEFINES="--dart-define=FRONTEND_VERSION=${{ steps.version.outputs.version }} \
            --dart-define=FRONTEND_BUILD_TIME=${{ steps.version.outputs.build_time }} \
            --dart-define=TRACELY_APP_ID=${{ secrets.TRACELY_APP_ID }} \
            --dart-define=TRACELY_APP_SECRET=${{ secrets.TRACELY_APP_SECRET }} \
            --dart-define=TRACELY_HOST=${{ secrets.TRACELY_HOST }}"

          if [[ "$GITHUB_REF" == refs/tags/v* ]]; then
            # 正式版：Shorebird release（登记基线 + 产出单个 universal APK）
            shorebird release android \
              --flutter-version=3.44.6 \
              --artifact apk \
              -- $COMMON_DEFINES
          else
            # dev：不接入 Shorebird，同样产出单个 universal APK
            flutter build apk --release $COMMON_DEFINES
          fi
```

> `--` 之后的参数由 Shorebird 透传给底层 `flutter build`，所以 `--dart-define` 全部照旧生效。

`Collect APK` 步骤统一产出单个 `songloft-android.apk`，仅因两条路径输出目录不同而分支（Shorebird 在 `apk/release/`，普通 flutter 在 `flutter-apk/`）：

```yaml
      - name: Collect APK
        run: |
          mkdir -p apk-output
          if [[ "$GITHUB_REF" == refs/tags/v* ]]; then
            # Shorebird universal APK 路径
            cp build/app/outputs/apk/release/app-release.apk apk-output/songloft-android.apk
          else
            cp build/app/outputs/flutter-apk/app-release.apk apk-output/songloft-android.apk
          fi
```

> Shorebird APK 实际输出路径以 `shorebird release android --artifact apk` 结束时打印的路径为准，首次接入时核对一次。

### 4.2 `build-ios` job 改造

同理，仅 tag 触发接入：

```yaml
      - name: Setup Shorebird
        if: startsWith(github.ref, 'refs/tags/v')
        uses: shorebirdtech/setup-shorebird@v1

      - name: Build iOS
        env:
          SHOREBIRD_TOKEN: ${{ secrets.SHOREBIRD_TOKEN }}
        run: |
          COMMON_DEFINES="--dart-define=FRONTEND_VERSION=${{ steps.version.outputs.version }} ...（同上）"
          if [[ "$GITHUB_REF" == refs/tags/v* ]]; then
            shorebird release ios --flutter-version=3.44.6 --no-codesign -- $COMMON_DEFINES
          else
            flutter build ios --release --no-codesign $COMMON_DEFINES
          fi
```

> ⚠️ **iOS 关键差异（务必读）**：Shorebird 官方文档明确 —— `shorebird release ios --no-codesign` 产出的是 **`.xcarchive`**，**不能** `shorebird preview`、也不能直接装到设备，必须**手动在 Xcode / 签名流水线里对该 xcarchive 签名**后才能分发。这和当前 CI「从 `build/ios/iphoneos/Runner.app` 直接打未签名 IPA」的做法不同，接入后 iOS 产物路径与打包步骤都要重做。
>
> 因此 iOS 走 Shorebird 实际要求一套**签名发布链路**（Apple 开发者账号 + 证书/描述文件，通常配 App Store/TestFlight）。**Android 是本方案主收益且开箱可用；iOS 建议作为独立的后续任务，先补齐签名链路再接入。**

### 4.3 需要新增的 GitHub Secrets / Variables

| 名称 | 类型 | 用途 |
|------|------|------|
| `SHOREBIRD_TOKEN` | Secret | CI 调 `shorebird release`/`patch` 的授权（Console → Account → API Keys 创建，见 §3.4） |
| `SHOREBIRD_APP_ID` | Variable（仓库变量） | 真实 app_id（公开标识，非密钥）；CI 用它覆写 `shorebird.yaml` 占位值。缺失时 release/patch 步骤直接失败 |

Android 签名相关 secret（`ANDROID_KEYSTORE_*`）已存在，**必须保持不变** —— 补丁强依赖"用户装的 release 与 Shorebird 登记的基线是同一签名+同一构建"。

---

## 5. 补丁发布流程（真正的"热更新"动作）

正式版整包发布后，两次正式版之间的**纯 Dart 修复**通过补丁下发。**补丁不自动跟 commit 走**（避免误发、且 5000 次/月免费额度需要克制），用**手动触发的独立 workflow** 控制。

新增 `.github/workflows/shorebird-patch.yml`：

```yaml
name: Shorebird Patch

on:
  workflow_dispatch:
    inputs:
      release_version:
        description: '目标基线版本（pubspec 形式，如 2.11.0+1）'
        required: true
      platform:
        description: '平台'
        type: choice
        options: [android, ios, both]
        default: android

jobs:
  patch:
    runs-on: ${{ github.event.inputs.platform == 'ios' && 'macos-latest' || 'ubuntu-latest' }}
    steps:
      - uses: actions/checkout@v4
      - uses: shorebirdtech/setup-shorebird@v1
      - name: Patch Android
        if: ${{ inputs.platform == 'android' || inputs.platform == 'both' }}
        env:
          SHOREBIRD_TOKEN: ${{ secrets.SHOREBIRD_TOKEN }}
        run: |
          # 注意：patch 不传 --flutter-version，Shorebird 自动探测该 release 的构建版本
          shorebird patch android \
            --release-version=${{ inputs.release_version }} \
            -- --dart-define=FRONTEND_VERSION=$(echo ${{ inputs.release_version }} | cut -d'+' -f1) ...（同 release 的 defines）
      # iOS patch 步骤同理（同样不传 --flutter-version）
```

> **`shorebird patch` 不接受 `--flutter-version`**：它按 `--release-version` 查出该基线当初用的 Flutter 版本，自动用同版本编译补丁。`--` 之后的 `--dart-define` 应与对应 release 保持一致。

发补丁的标准操作：

1. 从要修复的正式版 tag（如 `v2.11.0`）**checkout 出对应 commit**，在其上 cherry-pick / 提交纯 Dart 修复。
2. （推荐）先发到 **staging track** 内测：`shorebird patch android --release-version=2.11.0+1 --track=staging`，用 `shorebird preview --track=staging` 或内测设备验证。
3. 验证 OK 后再发到默认 **stable track**（不带 `--track`），触发 `Shorebird Patch` workflow，`release_version` 填 `2.11.0+1`（与该正式版 pubspec 完全一致）。
4. Shorebird 云生成 diff → 已装 `2.11.0+1` 的设备下次启动拉取 → 再次冷启动生效。

> **补丁与基线的 Dart 快照必须来自同一构建配置**（同 Flutter 版本、同 defines）。所以补丁一定要在**对应正式版 tag 的代码基础上**改，不能拿 main 最新代码打补丁。

---

## 6. 客户端集成

### 6.1 零改动即可用

`shorebird.yaml` 的 `auto_update: true` 下，updater 在 App 启动时自动后台检查并下载补丁，下次冷启动应用。**不写任何 Dart 代码，热更新就已生效。**

### 6.2 （可选）提示用户重启以尽快生效

若希望"补丁下好后提示用户重启"，加依赖（需 `shorebird_code_push` v2）：

```yaml
dependencies:
  shorebird_code_push: ^2.0.0
```

在合适时机（如回到首页）检查更新状态并轻提示：

```dart
final updater = ShorebirdUpdater();

// 查询是否有可用更新
final status = await updater.checkForUpdate();
if (status == UpdateStatus.restartRequired) {
  // 补丁已下好，重启后生效 —— 用现有 responsive_snackbar 轻提示
}

// 读取当前已生效的补丁号（用于日志/上报，patch 不改版本号，见 §9）
final patch = await updater.readCurrentPatch();
```

- 建议**只做轻提示**，不做强制重启；`auto_update: true` 下补丁本就会在下次自然冷启动生效。
- 该 UI 与现有 `FrontendUpgradeDialog`（整包更新）**互不冲突**：前者管 Dart 热补丁，后者管正式版整包升级。
- API 名称以 `shorebird_code_push` v2 实际为准，接入时对照 pub.dev 文档。

### 6.3 与现有版本检查的分工

| 通道 | 负责 | 入口 |
|------|------|------|
| Shorebird patch | 纯 Dart 热修（免安装） | 启动自动 / 可选轻提示 |
| `FrontendVersionApi` + `FrontendUpgradeDialog` | 正式版整包升级（含原生/引擎变更） | 设置页「检查客户端更新」 |

两者并存：日常小 bug 走 Shorebird 秒级下发；涉及原生/插件/引擎的大版本走整包。

---

## 7. 灰度、回滚与额度

- **灰度机制 = tracks（不是控制台百分比滑块）**：Shorebird 用 `staging` / `beta` / `stable` 三条 track 分发。`shorebird patch` 不带 `--track` 即发到 `stable`（全体用户）。
  - **推荐流程**：先 `--track=staging`（开发/内测机验证）→ 再发 `stable`。
  - **真正的按百分比放量**需要客户端配合：`shorebird.yaml` 设 `auto_update: false` + 引入 `shorebird_code_push` + 自己做用户分桶（如随机 group + 云端 KV 存放各版本放量比例），决定该用户走 `beta` 还是 `stable`。这是可选的进阶方案，初期用 staging→stable 两段即可。
- **回滚**：发一个修正补丁到对应 track 覆盖，或停止下发问题补丁；已生效设备下次启动回落到基线或新补丁。
- **免费额度**：Free 档 **5,000 次补丁安装/月，硬封顶、无超量计费**。注意消耗 ≈（当月补丁数）×（每补丁的设备安装数）——**频繁发补丁会加速消耗**。超出需升级 Pro（$20/月，50,000 次）。发布补丁前评估活跃装机量是否会撞顶。

---

## 8. 落地验证清单

**准备阶段**
- [ ] `shorebird flutter versions list` 确认 3.44.6 受支持（否则对齐版本）
- [ ] `shorebird init` 生成并提交 `shorebird.yaml`
- [ ] `SHOREBIRD_TOKEN` 已加入 GitHub secrets

**Android 端到端（主路径）**
- [ ] push 一个 `vX.Y.Z` tag，CI 的 `build-android` 走 `shorebird release android --artifact apk` 成功，Release 页出现 universal APK
- [ ] 真机装该 APK（尤其小米/HyperOS）
- [ ] 在对应 tag 代码上改一处 Dart UI，先发 `--track=staging` 补丁，`shorebird preview --track=staging` 验证
- [ ] 再发 stable 补丁（触发 `Shorebird Patch` workflow，`release_version` 填 `X.Y.Z+build`）
- [ ] App 冷启动两次后确认补丁生效
- [ ] 发一个修正补丁 / 停止下发，确认可回退
- [ ] push main（dev 构建）确认**完全没走** Shorebird，仍出单个 universal APK（`songloft-android.apk`）

**iOS（独立后续任务）**
- [ ] 补齐签名链路（Apple 账号 + 证书/描述文件）
- [ ] `shorebird release ios` 产出 `.xcarchive` → 手动/流水线签名 → 分发（App Store/TestFlight）
- [ ] 针对该 release 发补丁并在真机验证

---

## 9. 关键约束与踩坑

1. **dev 不接入**：所有 Shorebird 步骤必须用 `if: startsWith(github.ref, 'refs/tags/v')` 门控；`Build` 步骤内再用 `if [[ "$GITHUB_REF" == refs/tags/v* ]]` 分支。双重保险，别让 dev 路径引入 Shorebird。
2. **Flutter 版本锁死**：升级 `FLUTTER_VERSION` 必须同步确认 Shorebird 支持该版本，且升级后**旧补丁作废**，需发新正式版。
3. **签名一致性**：补丁基线依赖用户装的 APK 与 CI 登记的 release 同签名。`ANDROID_KEYSTORE_*` secrets 不能变、不能回退到 debug 签名。
4. **补丁基于正式版 tag 改**：不要用 main 最新代码打补丁，Dart 快照配置必须与目标 release 一致。
5. **只能热更 Dart**：任何原生/插件原生侧/引擎变更混进补丁都不会生效（且可能行为不一致），这类改动必须发正式版整包。
6. **Android 分发形态**：全渠道统一为单个 universal APK（`songloft-android.apk`），不再 split-per-abi 拆多架构包，Release 说明与下载页文案已相应调整。
7. **补丁不改版本号**：Shorebird 补丁**不会**改 App 的 `versionName+versionCode`（`2.11.0+1` 打了补丁后仍是 `2.11.0+1`）。这意味着 `FrontendVersionApi` 那套"整包版本比较"看不到补丁，两者互不干扰；但做分析/上报时要用 `readCurrentPatch()` 取当前补丁号区分"打没打补丁"。
8. **额度监控**：接入自建监控（tracely）上报补丁生效/失败与 `readCurrentPatch()` 补丁号，配合 Shorebird 控制台盯 5,000/月 免费额度。

---

> **英文版同步**：本仓库 `docs/cn/` 与 `docs/en/` 双语同名结构，落地实现后需补 `docs/en/shorebird_hot_update.md`。
