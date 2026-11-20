# Flutter 前端脚本指南

本目录包含 Songloft Flutter 前端的构建与发布脚本。

## 📋 脚本列表

| 脚本 | 说明 |
|------|------|
| `build-frontend.sh` | 多平台构建脚本，支持 web/linux/windows/macos/android/ios/all |
| `bump-version.sh` | 版本发布脚本（语义化版本控制 + Git 标签） |
| `docker-build-frontend.sh` | Docker 构建便捷脚本 |
| `download-fonts.sh` | 字体下载脚本（下载项目所需的自定义字体） |
| `compute_native_contract.sh` | 计算插件、MethodChannel 和 release ProGuard 规则的热更新兼容哈希 |
| `check-android-preferences-jni.py` | 检查 release APK 中设置插件的 JNI 方法描述符，依赖 Android SDK 的 `apkanalyzer` |

Android release 构建后执行 `python3 scripts/check-android-preferences-jni.py <apk>`，检查 JNI 方法描述符，以及协程、结果和 Unit 等 JNI 运行时引用的 Kotlin 类/成员。标准版和 Bundle 发布工作流分别检查各自通用 APK 的 DEX，并在生成按 ABI 发布的补丁前确认包内含三个架构的 Flutter 原生库。纯 Dart 测试和 debug APK 不能替代此检查；修改 ProGuard 规则需要整包 APK，原生契约哈希会阻止旧 APK 仅接收 Dart 补丁。脚本回归使用 `python3 -m unittest discover -s scripts/tests -p '*_test.py'`。

## 🔧 `bump-version.sh` — 版本发布

用于自动化 Flutter 前端的版本发布流程。**统一发布契约**：与 `clients/player-lynx/scripts/bump-version.sh`、父仓库 `scripts/bump-version.sh` 的参数与行为完全一致，可被父仓库 `scripts/release-all.sh` 一键编排直接调用。

**用法**:

```bash
# 补丁版本升级（修复 bug，1.0.0 -> 1.0.1，默认）
./scripts/bump-version.sh patch

# 次版本号升级（新增功能，1.0.0 -> 1.1.0）
./scripts/bump-version.sh minor

# 主版本号升级（重大变更，1.0.0 -> 2.0.0）
./scripts/bump-version.sh major

# 正式发布（去掉预发布后缀：2.0.0-alpha.2 -> 2.0.0）
./scripts/bump-version.sh release

# 直接指定新版本（必须高于当前版本）
./scripts/bump-version.sh 2.1.0

# 仅预览计划，不修改文件、不打 tag、不联网
./scripts/bump-version.sh minor --dry-run

# 跳过交互确认 / 只创建本地 commit+tag 不推送
./scripts/bump-version.sh patch --yes
./scripts/bump-version.sh patch --no-push

# 查看帮助
./scripts/bump-version.sh --help
```

**脚本流程**：

1. 从 `pubspec.yaml` 读取当前版本号
2. 根据升级类型（release/major/minor/patch）或显式版本计算新版本，新版本必须高于当前版本
3. 预检：`main` 分支、工作树干净、`v<新>` tag 本地与远程均不存在、本地包含 `origin/main`
4. 更新 `pubspec.yaml` 中的版本号（保留 `+build number`）
5. Git commit + 创建 annotated tag（格式 `v{version}`）+ `git push --atomic` 一次推送 main 与该 tag

本仓库的 `.github/workflows/build-and-release.yml` 发布标准版。构建相关改动推送到 `main` 会更新本仓库的 `dev`，推送 `v*` tag 发布对应版本。纯 Markdown 修改不会触发构建。手动刷新 `dev` 时选择 **Actions → Build and Release → Run workflow**，使用 `main` 和全部平台选项。只选择部分平台也会替换滚动 `dev`，附件只包含本次产出的文件。

Flutter Bundle 与 Android Bundle 热更新资产由后端仓库的 `Release` 工作流生成和发布。需要更新 Bundle 时，在后端仓库运行工作流。查看[后端发布与签名说明](https://songloft.hanxi.cc/bundle-mode#发布触发与签名)和[完整包名清单](https://songloft.hanxi.cc/release-packages)。

Release 正文展示自动生成的分类变更记录，`.github/release-notes.md` 仅保留安装说明链接；各平台安装说明统一维护在根目录的 [README.md](../README.md#下载安装) 与 [README.en.md](../README.en.md#download)。版本 tag 发布成功后，独立 job 基于最新 `main` 更新根目录的中文 `CHANGELOG.md` 并提交回仓库；滚动 dev 不写入该文件。不同版本的日志更新串行执行，不触发新一轮构建。

**安全机制**：

- 任一预检失败即退出，先于任何写操作；`--dry-run` 零写入零联网
- 已发布的 tag **永不覆盖**；失败后保留现场（不自动删 tag / reset），按本文档人工处理
- 非交互环境用 `--yes`；`--no-push` 可先本地验证再手动 `git push --atomic origin HEAD:refs/heads/main refs/tags/v<版本>`
- stdout 末行输出 `v<版本>`，日志走 stderr，方便链式调用（`release-all.sh` 依赖此约定）

## 🔧 `build-frontend.sh` — 多平台构建

```bash
# 构建单个平台
./scripts/build-frontend.sh web              # Web standalone
./scripts/build-frontend.sh web-embedded     # Web 嵌入模式
./scripts/build-frontend.sh linux
./scripts/build-frontend.sh windows
./scripts/build-frontend.sh macos
./scripts/build-frontend.sh android
./scripts/build-frontend.sh ios

# 构建所有平台
./scripts/build-frontend.sh all
```

构建产物输出到 `songloft-player-build/` 目录。

## 📝 语义化版本控制

遵循 [Semantic Versioning](https://semver.org/) 规范：

- **MAJOR** (主版本号): 不兼容的 API 或重大功能变更
- **MINOR** (次版本号): 向下兼容的功能性新增
- **PATCH** (补丁版本): 向下兼容的问题修正
- 版本号格式：`X.Y.Z+W`（X=主版本，Y=次版本，Z=补丁，W=build number）
- 脚本只修改 `X.Y.Z` 部分，保留 build number
