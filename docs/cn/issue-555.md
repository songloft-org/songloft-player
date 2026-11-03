# 重开页面后恢复已保存歌词（songloft-org/songloft#555）

日期：2026-11-03。Flutter 配套修复；Lynx 在其仓库另有验证记录。报告人的具体客户端与 NAS 队列快照未取得，不把本次复现视为其环境唯一已证实根因。

## 原因与行为

本地队列快照可能早于歌词刮削，因此没有 `lyric_url`。Flutter 手动重新抓取会临时补齐端点，但不修改队列中的 Song；再次恢复时，普通歌词加载在读取缓存前就返回空状态。若两首歌曲都无地址且更新时间相同，旧 Provider 的监听键也无法区分切歌。

统一正常加载、失效重载和手动抓取的端点解析：优先保留服务端地址；本地正数 ID 的歌曲缺少地址时补 `/api/v1/songs/{id}/lyric`。监听解析后的地址和更新时间，保留歌词缓存版本检查。正常加载不加 `refresh`，优先读取缓存或数据库已有歌词；手动抓取仍强制刷新。404 表示无歌词，502 等错误仍显示加载失败。无歌曲、无效 ID、无地址的电台和远程歌曲不补端点。

Flutter Web 的歌词缓存只有内存级别，整页刷新后重新请求数据库；原生端继续复用文件缓存。本次没有改变缓存持久化方式或音频宿主。

## 验证对象与结果

- Flutter 仓库 songloft-org/songloft-player，基线 `32339c748af046a30a28744e2af10e533400d95a` + 本批未提交工作树。后端为主仓库 `88c0b4138aea53a0caf65c3c29c1713c72586177`，未修改。完整 diff 与文件 SHA-256 见 `/tmp/songloft-555-runtime/flutter-verification.json`。
- Linux amd64 / Flutter 3.44.8 / Dart 3.12.2。安装目录名为 3.41.5，版本按工具实际输出记录。Web 使用 release embedded 构建、Docker 无头 Chrome、真实临时后端/SQLite 与 10 秒合成 MP3，未访问用户曲库。
- 新增 5 项 Provider 回归使用真实队列编码器、HTTP 和歌词缓存，隔离音频宿主：旧实现 4 项因歌词为空或未发请求失败、1 项保护用例通过（`/tmp/songloft-555-flutter-before.log`）；修复后 5 项及全部 818 项测试通过（`/tmp/songloft-555-flutter-{focused,all}.log`）。覆盖旧 Web 队列、手动抓取后重建 Provider 读取缓存、相同时间戳切歌、404/502 和不应补端点的对象。
- `dart format lib/ test/`（最终零格式变化）、`flutter analyze --no-pub` 无问题、`flutter build web --release --no-pub --no-web-resources-cdn --dart-define=DEPLOY_MODE=embedded --output=/tmp/songloft-555-flutter-web` 通过，WASM dry run 成功。保留既有 CupertinoIcons 字体提示；日志 `/tmp/songloft-555-flutter-{format,analyze,build}.log`。
- Docker Chrome 1280×900：localStorage 保存不带歌词地址的旧队列，数据库保存 `lyric_source=scraped`。连续两次整页加载显示全部两行歌词，恰好两次普通歌词请求，没有强制重新刮削。通过实际播放按钮验证媒体进度与歌词显示；结果和截图见 `/tmp/songloft-555-runtime/flutter-browser-summary.json`、`flutter-reload.png`。
- `git diff --check`、UTF-8 和中英文配对检查通过。

Not run：报告人 NAS/Docker 实例、Android/iOS/Windows/macOS/Linux 原生应用、Bundle 本地后端与原生后台音频；没有修改后端或宿主，未重跑后端全量测试。浏览器和 Provider 验证不替代这些设备验收。

本批未提交、推送、更新父仓库指针、发布或评论。建议提交：`fix(lyrics): 恢复旧播放队列中的已保存歌词`，引用 `Ref songloft-org/songloft#555`。
