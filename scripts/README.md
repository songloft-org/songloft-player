# Flutter 前端脚本指南

本目录包含 Songloft Flutter 前端的构建与发布脚本。

## 📋 脚本列表

| 脚本 | 说明 |
|------|------|
| `build-frontend.sh` | 多平台构建脚本，支持 web/linux/windows/macos/android/ios/all |
| `bump-version.sh` | 版本发布脚本（语义化版本控制 + Git 标签） |
| `docker-build-frontend.sh` | Docker 构建便捷脚本 |
| `download-fonts.sh` | 字体下载脚本（下载项目所需的自定义字体） |

## 🔧 `bump-version.sh` — 版本发布

用于自动化 Flutter 前端的版本发布流程。

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

# 仅预览，不实际修改
./scripts/bump-version.sh minor --dry-run

# 查看帮助
./scripts/bump-version.sh --help
```

**脚本流程**：

1. 从 `pubspec.yaml` 读取当前版本号
2. 根据升级类型（release/major/minor/patch）计算新版本
3. 更新 `pubspec.yaml` 中的版本号（保留 build number）
4. Git commit + 创建 annotated tag（格式 `v{version}`）+ push

推送 tag 后由 `.github/workflows/build-and-release.yml` 自动完成多平台构建和 GitHub Release。

**安全机制**：
- 检查 Git 仓库环境
- 未提交更改时提示确认
- 关键步骤需要交互式确认
- 标签冲突时提示是否覆盖

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
