# 内置收藏歌单手动排序（songloft-org/songloft#550）

日期：2026-11-02。基线 `ae85c9570943c5f06ac77397dd384ef5907e2811`；Flutter 实现未改动，本次仅补充验证记录。Linux amd64 / Flutter 3.44.8 / Dart 3.12.2 / Docker Chrome 121；父仓库基线 `71635ae30ec76a6a0a8bf4efa94304fe2276a057` 加未提交后端修复。

[原 Issue](https://github.com/songloft-org/songloft/issues/550) 的界面为 Flutter。`_enterSortMode` 加载全部成员，拖动后由 `_exitSortMode` 提交完整 `song_ids`，成功后 `resetFilter` 保存自定义升序。失败来自服务端错误地禁止内置歌单成员排序；因此无需修改 Flutter 的请求形态或另设本机排序。

验证通过：

- `flutter analyze` 无问题；`flutter test test/features/playlist` 27 项通过。
- `flutter build web --release --dart-define=DEPLOY_MODE=embedded --no-web-resources-cdn` 成功。构建记录含 WASM dry-run 失败警告，最终 JavaScript 构建成功；此处验收的不是 WASM 模式。
- 1440×1000 真实浏览器界面分别打开收藏和电台收藏，选择手动排序，将第一项拖到末尾并点击完成。两者的持久顺序都与拖动后的完整四项顺序一致；真实 PUT、后端读取、截图及刷新后重新打开的界面顺序一致，页面异常为零。

证据：`/tmp/songloft-550-flutter-{analyze,tests,build}.log`；`/tmp/songloft-550-ui/flutter.js`、`flutter-final.json`、`flutter-{drag,saved}-{1,2}.png`。验证源码指纹见 `/tmp/songloft-550-verification.json`。浏览器驱动分别等待菜单动画和无障碍 `aria-label`，不从截图推出保存成功。

Not run：Windows 原生客户端及其他原生平台；Web 验证不能替代报告人的 Windows 安装包验收。本次未提交、推送、发布或回复 Issue。部署修复需要升级后端；仅重装同版本 Flutter 不能解除旧后端的 403 限制。
