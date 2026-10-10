# 更新日志

此文件记录 Songloft Flutter 客户端的版本变更，仅提供中文版本。版本 tag 的 Release 发布成功后，由 CI 根据 Conventional Commits 分类追加记录并提交到 `main`；滚动 dev 记录见 [GitHub Releases](https://github.com/songloft-org/songloft-player/releases/tag/dev)。

## 开发记录（截至 2026-10-10）

以下列出近期变化，完整开发历史见 [Git 提交记录](https://github.com/songloft-org/songloft-player/commits/main/)。

### 新增功能

- [`67ea2be`](https://github.com/songloft-org/songloft-player/commit/67ea2be87b5c94d90aa12269fbdc10e3b9afbe1c) — 添加下一首播放并支持随机播放历史回退。
- [`c07ded3`](https://github.com/songloft-org/songloft-player/commit/c07ded3d10ff5244b2cb92281d1d2070c252d4af) — 支持 Android 自定义歌曲缓存目录。
- [`708107b`](https://github.com/songloft-org/songloft-player/commit/708107b93820757b89a1fc05fd7127f48e25de40) — 优化胶囊播放器与底部导航的液态玻璃效果。
- [`d54f746`](https://github.com/songloft-org/songloft-player/commit/d54f7463e98000853972f7f4c8e2c2a2014d3299) — 添加减少透明度与增强对比度设置。

### 重构

- [`5b4c304`](https://github.com/songloft-org/songloft-player/commit/5b4c30417aef3d12e9bd1ad37376c854b1ca4f71) — 合并导航与插件设置。
- [`17f15f1`](https://github.com/songloft-org/songloft-player/commit/17f15f18c23d098ec15a5b975eb946a892642749) — 将插件导航设置集中到插件管理页。
