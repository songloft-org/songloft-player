# 其他视图排序下的手动排序入口（songloft-org/songloft#551）

## 2026-11-02 后续：跨屏拖动自动滚动

评论 `6576318751` 反馈手动排序只能在当前视口内移动。排序模式原先将禁止滚动、shrink-wrap 的 `ReorderableListView` 嵌在页面 `CustomScrollView` 中，拖动自动滚动绑定到内层而不是页面。改用同一页面中的 `SliverReorderableList`，保留拖动浮层的 Material、原有完成/取消和完整顺序保存语义。不新增置顶功能。

本批 Flutter 基线 `feb97bb0c46f5d9e4de3ff5049ebdd07c3a9f605` + 未提交工作树；主仓库 `e204855590bdf4c38483ff87ee19769ba91df1fc`。Linux amd64，Flutter 安装路径标作 3.41.5，但当前工具实际报告 Flutter 3.44.8 / Dart 3.12.2，不能用路径名当版本。

- 80 首实际页面手势回归：500/1440px 宽、向上/向下，拖到边缘停住仍自动滚动超过 200px，保存顺序且成员不丢失，四项通过。隔离旧页面四项均因滚动为 0 失败，最终日志 `/tmp/songloft-551-scroll-negative-clean.log`；前期隔离副本缺资源/依赖及资源竞争造成的失败不作为反向证据。
- `flutter analyze` 无问题；定向 20 项和全量 813 项通过；嵌入 Web release 构建通过，WASM dry run 通过，保留 CupertinoIcons 字体提示。
- Docker Chrome 1440×1000，通过真实扫描生成的 140 首合成音乐歌单，从首曲拖到下边缘并停留，一次拖到第 25 位；点击完成后真实 API 返回 140 首且位置符合操作，页面异常为 0。证据 `/tmp/songloft-551-scroll/flutter-ui.json`、`flutter-drag.png`、`flutter-saved.png`。
- `dart format lib/ test/` 及 diff 检查通过。日志 `/tmp/songloft-551-scroll-{focused,analyze,all,build}.log`。

Lynx 也发现未配置滚动边界，配套修复记录在其 `docs/project/issue-551-scroll.md`。本批未提交、推送、更新父指针、发布或评论。Not run：Windows 和其他原生设备；浏览器/Widget 测试不替代报告人 Windows 验收。后端源码未变，未重跑后端测试。

日期：2026-11-02。Issue：[songloft-org/songloft#551](https://github.com/songloft-org/songloft/issues/551)。

## 原因与行为

报告截图中的「Mp3」是自动创建的歌单，选中「文件时间」升序。Flutter 原菜单仅在 `currentSort == 'position'` 时提供「手动排序」；该条件不检查扫描范围或 `auto_created` 标签。因此复制目录或定向扫描不是入口缺失的判断依据，切换视图排序即可复现。

移除该字段限制。非搜索状态下，七种视图排序的升序和降序均可直接进入手动排序，以当前显示顺序开始拖动；完成时通过原有 API 提交完整成员顺序并保存自定义升序。取消不改变持久顺序或视图偏好，搜索结果仍不提供永久排序操作。

Lynx 已有入口不依赖当前排序字段，进入时先保存 `position asc` 再显示拖动控件。本次代码检查、原有页面回归与真实 Web 操作均未发现相同缺陷，无需改动 Lynx 源码。两客户端进入拖动时的初始顺序策略不同，均按各自既有流程验证。

## 验证对象

- Flutter：songloft-org/songloft-player，基线 `5be710cd57227fd60d16396b198be10f700ae91e` 加本次未提交修改。
- Lynx：songloft-org/songloft-player-lynx，`8ed3c6484d6107a5f5fd0dc417b6d984578524fd`，无源码修改；只读核对远端 main 为同一 SHA。
- 后端：songloft-org/songloft，`ee5d16ab38552ea0416f86a1cf9679e57a3f7a40`，未改动；`CGO_ENABLED=0 go build -tags dev,lite` 构建临时服务。
- 环境：Linux amd64、Flutter 3.44.8、Dart 3.12.2、Node 22.17.1、pnpm 11.15.1、Docker HeadlessChrome 121.0.6167.85。源码/工作树身份保存在 `/tmp/songloft-551-verification.json`。
- 使用独立数据库及四首合成 MP3，音乐目录 `/home/hanxi/.cache/songloft-551-music/Mp3`；通过真实 `/scan` 指定此目录，生成 `auto_created` 歌单，四首均入库，无失败。

## 命令与结果

| 检查 | 结果 |
| --- | --- |
| 修复前 `flutter test test/features/playlist/presentation/playlist_manual_sort_test.dart` | 14 项失败、2 项通过；其他字段下手动入口缺失，符合预期 |
| `flutter analyze` | 无问题 |
| `flutter test` | 全部 809 项通过，含新增 16 项实际页面回归 |
| `flutter test --no-pub test/features/playlist/presentation/playlist_manual_sort_test.dart` | 最终 16 项通过，见 `focused-final.log` |
| `flutter build web --release --dart-define=DEPLOY_MODE=embedded --no-web-resources-cdn` | 成功；WASM dry run 成功，保留 CupertinoIcons 字体提示，实际验收为 JavaScript 构建 |
| Lynx `pnpm exec vitest run src/features/playlist/__tests__/playlist-detail.test.tsx` | 29 项通过，包含其他排序方式进入手动排序的既有回归 |
| Lynx `pnpm run build:web-embedded` | 成功，浏览器使用本批构建产物 |
| `dart format lib/ test/`、格式复查及 `git diff --check` | 通过 |

真实浏览器操作与后端验证：

- Flutter 中文 1440×1000：从首页打开扫描生成的 Mp3 歌单，文件时间升序下打开菜单并进入手动排序，将首行跨三行拖到末尾，点击完成。后端完整顺序为 `[1,2,4,3]`，符合拖动目标，保存偏好为 `position asc`；刷新后从首页重新打开，界面标题顺序与后端一致，页面异常为零。
- Lynx 英文 1200×900：同一扫描歌单的文件时间升序下，更多菜单提供 Reorder；点击后保存 `position asc`。首行跨三行拖动后，实际 `songs/move` 请求和后端完整顺序 `[2,1,3,4]` 一致，刷新后界面顺序仍一致，页面异常为零。

证据位于 `/tmp/songloft-551/`：`before.log`、`analyze.log`、`tests.log`、`focused-final.log`、`build.log`、`lynx-tests.log`、`lynx-build.log`、`fixture.json`、`flutter-ui-verified.json`、`lynx-ui.json`、`flutter-*.png`、`lynx-*.png` 及浏览器驱动脚本。JSON 包含请求记录，认证请求体未记录。首轮定向测试曾因测试自身直接等待 fake-async 中的搜索而挂起，已修正为先 pump 再等待；两次 Flutter 浏览器驱动的刷新检查曾因未重新打开歌单/未等待语义节点而失败，诊断结果保留为 `flutter-ui-attempt{1,2}.json`，最终驱动通过，未因此修改产品代码。

Not run：Windows 原生安装包、其他原生平台及报告人的私人曲库；Web 界面验证不替代 Windows 验收。后端完整测试、Lynx 全量测试和原生编译未运行，本次未修改相应源码。以上为提交前验证记录；提交、父仓库 gitlink、推送、CI 与开发包状态以对应 GitHub 提交和本批交付为准，未执行正式版发布。

提交信息：`fix(playlist): 保留其他视图排序下的手动排序入口`，引用 `Ref songloft-org/songloft#551`；Issue 保留供报告人验收。
