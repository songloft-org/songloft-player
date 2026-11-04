# 更新日志

此文件记录 Songloft Flutter 客户端的版本变更，仅提供中文版本。版本 tag 的 Release 发布成功后，由 CI 根据 Conventional Commits 分类追加记录并提交到 `main`；滚动 dev 记录见 [GitHub Releases](https://github.com/songloft-org/songloft-player/releases/tag/dev)。

## [v2.13.8] - 2026-11-04
### :bug: 问题修复
- [`feb97bb`](https://github.com/songloft-org/songloft-player/commit/feb97bb0c46f5d9e4de3ff5049ebdd07c3a9f605) - **playlist**: 保留其他视图排序下的手动排序入口 *(提交者 [@hanxi](https://github.com/hanxi))*
- [`32339c7`](https://github.com/songloft-org/songloft-player/commit/32339c748af046a30a28744e2af10e533400d95a) - **playlist**: 修复拖动排序跨屏自动滚动 *(提交者 [@hanxi](https://github.com/hanxi))*
- [`f5079b5`](https://github.com/songloft-org/songloft-player/commit/f5079b55ef3c6a04ee842cd12d323e7d150ab3ad) - **lyrics**: 恢复旧播放队列中的已保存歌词 *(提交者 [@hanxi](https://github.com/hanxi))*

### :memo: 文档更新
- [`5be710c`](https://github.com/songloft-org/songloft-player/commit/5be710cd57227fd60d16396b198be10f700ae91e) - **playlist**: 记录内置收藏排序双端验证 *(提交者 [@hanxi](https://github.com/hanxi))*

### :wrench: 维护工作
- [`59bc9c7`](https://github.com/songloft-org/songloft-player/commit/59bc9c7def13e73ced81df045cf77e3ce32f0426) - release version 2.13.8 *(提交者 [@hanxi](https://github.com/hanxi))*


## [v2.13.6] - 2026-10-23
### :sparkles: 新增功能
- [`d7c2f4a`](https://github.com/songloft-org/songloft-player/commit/d7c2f4a643336a7ad93e25bc781dbd6ce4db8edb) - **home**: 支持首页收藏歌单显示设置 *(提交者 [@hanxi](https://github.com/hanxi))*

### :bug: 问题修复
- [`9345a6b`](https://github.com/songloft-org/songloft-player/commit/9345a6b0e92ab4188282dade1af11027dbbee377) - **local-mode**: 本地模式改用每安装随机管理员密码，替换 admin/admin *(提交者 [@hanxi](https://github.com/hanxi))*

### :memo: 文档更新
- [`1e30e05`](https://github.com/songloft-org/songloft-player/commit/1e30e059e4b39ba8b43d5c6d3b7cfedc20f4c7dd) - **changelog**: 更新 v2.13.5 变更记录 *(提交者 [@github-actions[bot]](https://github.com/apps/github-actions))*

### :wrench: 维护工作
- [`8fa1d6e`](https://github.com/songloft-org/songloft-player/commit/8fa1d6e5fc27fccc62a94e389337a6ea91b55ee7) - release version 2.13.6 *(提交者 [@hanxi](https://github.com/hanxi))*


## [v2.13.5] - 2026-10-20
### :bug: 问题修复
- [`203e79b`](https://github.com/songloft-org/songloft-player/commit/203e79b5fd7ac02b8edb93af291bb6981e62974f) - **player**: 电台断流持续重连并保留当前台 *(提交者 [@hanxi](https://github.com/hanxi))*
- [`e22b755`](https://github.com/songloft-org/songloft-player/commit/e22b75561c0a0e93bd391dba324e66f09bcd395c) - **android**: 保留 JNI 协程运行时以修复启动卡住 *(提交者 [@hanxi](https://github.com/hanxi))*

### :memo: 文档更新
- [`2621aec`](https://github.com/songloft-org/songloft-player/commit/2621aecda59f70fec344954f000ba57532aa7abf) - **changelog**: 更新 v2.13.4 变更记录 *(提交者 [@github-actions[bot]](https://github.com/apps/github-actions))*

### :wrench: 维护工作
- [`98fe97d`](https://github.com/songloft-org/songloft-player/commit/98fe97d0ae23a16e5034a56337134c4b4aa142ce) - release version 2.13.5 *(提交者 [@hanxi](https://github.com/hanxi))*


## [v2.13.4] - 2026-10-20
### :bug: 问题修复
- [`bb03a5c`](https://github.com/songloft-org/songloft-player/commit/bb03a5c49eb6701d90a73b924ed12ec388c6560c) - **player**: 优化大播放队列定位与批量追加 songloft-org/songloft[#525](https://github.com/songloft-org/songloft-player/pull/525) *(提交者 [@hanxi](https://github.com/hanxi))*
- [`18b50cb`](https://github.com/songloft-org/songloft-player/commit/18b50cbca02a7470279ddcd04907f71365140a57) - **settings**: 明确增强对比度停用封面背景（Ref songloft-org/songloft[#523](https://github.com/songloft-org/songloft-player/pull/523)） *(提交者 [@hanxi](https://github.com/hanxi))*
- [`a9e5dda`](https://github.com/songloft-org/songloft-player/commit/a9e5dda70b61e313ee9902b9bfc26691c16230c6) - **player**: 加深封面背景并修复取色 *(提交者 [@hanxi](https://github.com/hanxi))*
- [`1dcc526`](https://github.com/songloft-org/songloft-player/commit/1dcc52612f6242a0598b3c06c946200a5d2f1ec5) - **player**: 桌面 HLS 电台请求头改走 tag，绕开 just_audio 回环代理 *(PR [#51](https://github.com/songloft-org/songloft-player/pull/51) by [@hurleychin](https://github.com/hurleychin))*
- [`e49f245`](https://github.com/songloft-org/songloft-player/commit/e49f245d69ae4fdf6ac6b7bd0bc51b55ae763f62) - **audio**: 可恢复的解码错误不再跳过整首歌 *(提交者 [@hanxi](https://github.com/hanxi))*

### :memo: 文档更新
- [`00cbe94`](https://github.com/songloft-org/songloft-player/commit/00cbe94841acca3eaf561a339f61072914c9de31) - **changelog**: 更新 v2.13.3 变更记录 *(提交者 [@github-actions[bot]](https://github.com/apps/github-actions))*

### :wrench: 维护工作
- [`d89934e`](https://github.com/songloft-org/songloft-player/commit/d89934eea468c22f635d28e5bfd0b5fe81c98147) - release version 2.13.4 *(提交者 [@hanxi](https://github.com/hanxi))*


## [v2.13.3] - 2026-10-15
### :sparkles: 新增功能
- [`8a21e26`](https://github.com/songloft-org/songloft-player/commit/8a21e2634f2d89efae1bfeb9627b9078f98078fc) - **player**: 优化歌词可读性并新增内置配色（Ref songloft-org/songloft[#523](https://github.com/songloft-org/songloft-player/pull/523)） *(提交者 [@hanxi](https://github.com/hanxi))*

### :bug: 问题修复
- [`1a2bc0e`](https://github.com/songloft-org/songloft-player/commit/1a2bc0eab4df7bc52e9a61bcb431f2c9185a1495) - **android**: 统一通知播放控件图标样式（Ref songloft-org/songloft[#520](https://github.com/songloft-org/songloft-player/pull/520)） *(提交者 [@hanxi](https://github.com/hanxi))*
- [`b80e03b`](https://github.com/songloft-org/songloft-player/commit/b80e03b47eefb1aaedf07d611b1d9d3c3d48257b) - **playlist**: 明确歌曲名称排序 songloft-org/songloft[#524](https://github.com/songloft-org/songloft-player/pull/524) *(提交者 [@hanxi](https://github.com/hanxi))*

### :recycle: 重构
- [`9f5fbd2`](https://github.com/songloft-org/songloft-player/commit/9f5fbd27766993da76843ee4e04ca03c73810082) - **scripts**: 发布脚本对齐统一发布契约 *(提交者 [@hanxi](https://github.com/hanxi))*

### :memo: 文档更新
- [`2bc03f7`](https://github.com/songloft-org/songloft-player/commit/2bc03f75157cc3c17aea6434af2576262137be5d) - **changelog**: 更新 v2.13.2 变更记录 *(提交者 [@github-actions[bot]](https://github.com/apps/github-actions))*

### :wrench: 维护工作
- [`4cae619`](https://github.com/songloft-org/songloft-player/commit/4cae61909da9591b1c56cfb7446b1bfea672b57a) - release version 2.13.3 *(提交者 [@hanxi](https://github.com/hanxi))*


## [v2.13.2] - 2026-10-14
### :sparkles: 新增功能
- [`d54f746`](https://github.com/songloft-org/songloft-player/commit/d54f7463e98000853972f7f4c8e2c2a2014d3299) - **appearance**: 添加减少透明度与增强对比度设置 *(提交者 [@hanxi](https://github.com/hanxi))*
- [`708107b`](https://github.com/songloft-org/songloft-player/commit/708107b93820757b89a1fc05fd7127f48e25de40) - **player**: 优化胶囊播放器与底部导航的液态玻璃效果 *(提交者 [@hanxi](https://github.com/hanxi))*
- [`c07ded3`](https://github.com/songloft-org/songloft-player/commit/c07ded3d10ff5244b2cb92281d1d2070c252d4af) - **cache**: 支持 Android 自定义歌曲缓存目录 *(提交者 [@hanxi](https://github.com/hanxi))*
- [`67ea2be`](https://github.com/songloft-org/songloft-player/commit/67ea2be87b5c94d90aa12269fbdc10e3b9afbe1c) - **player**: 添加下一首播放并支持随机播放历史回退 *(提交者 [@hanxi](https://github.com/hanxi))*
- [`15e3208`](https://github.com/songloft-org/songloft-player/commit/15e3208a36fe9876ce315a88d09e0f112d10ddcd) - **release**: 持久化中文变更日志并补充双语安装说明 *(提交者 [@hanxi](https://github.com/hanxi))*
- [`2fef73d`](https://github.com/songloft-org/songloft-player/commit/2fef73df1b9d3b31c83360c0acc862c538089d6d) - **jsplugin**: 支持 GitHub Token 与商店客户端渐进加载 *(提交者 [@hanxi](https://github.com/hanxi))*
- [`cacd69d`](https://github.com/songloft-org/songloft-player/commit/cacd69d22ee88ebed30b9d24c914a1d1fb66e9ac) - **player**: 支持全屏歌曲信息选择复制 *(提交者 [@hanxi](https://github.com/hanxi))*
- [`1cb9b49`](https://github.com/songloft-org/songloft-player/commit/1cb9b4947cdc1c641507e9486b0a0024fc274e97) - **playlists**: 优化歌单浏览并支持隐藏首页电台 *(提交者 [@hanxi](https://github.com/hanxi))*
- [`a0b2ae1`](https://github.com/songloft-org/songloft-player/commit/a0b2ae17194dd0a1acdaa7c0050ca4681e119c07) - **player**: 支持歌词页屏幕常亮配置 *(提交者 [@hanxi](https://github.com/hanxi))*

### :bug: 问题修复
- [`039d094`](https://github.com/songloft-org/songloft-player/commit/039d0942f94b4c0dc47ebcc22d1899abb12cf5b4) - **jsplugin**: 优先处理插件页面内返回操作 *(提交者 [@hanxi](https://github.com/hanxi))*
- [`57db976`](https://github.com/songloft-org/songloft-player/commit/57db9766ac36b58f136b4e7ae41a2d1c51a079ce) - **windows**: 补齐 WebView2 移动通知与右键残留回归验证 *(提交者 [@hanxi](https://github.com/hanxi))*
- [`3860205`](https://github.com/songloft-org/songloft-player/commit/3860205b0d8cf8449d8cf31746c254ef597c55e3) - **jsplugin**: 支持四段插件发布版本比较 *(提交者 [@hanxi](https://github.com/hanxi))*
- [`da15d75`](https://github.com/songloft-org/songloft-player/commit/da15d75dd8640e8a4e1773ab4f63fe8500a8dc19) - **android**: 完善退出应用与通知停止清理（Ref songloft-org/songloft[#520](https://github.com/songloft-org/songloft-player/pull/520)） *(提交者 [@hanxi](https://github.com/hanxi))*

### :recycle: 重构
- [`17f15f1`](https://github.com/songloft-org/songloft-player/commit/17f15f18c23d098ec15a5b975eb946a892642749) - **jsplugin**: 将插件导航设置集中到插件管理页 *(提交者 [@hanxi](https://github.com/hanxi))*
- [`5b4c304`](https://github.com/songloft-org/songloft-player/commit/5b4c30417aef3d12e9bd1ad37376c854b1ca4f71) - **settings**: 合并导航与插件设置 *(提交者 [@hanxi](https://github.com/hanxi))*

### :memo: 文档更新
- [`e24d7ea`](https://github.com/songloft-org/songloft-player/commit/e24d7eaf5f0d6a44fd2c178385f38135f35d3d56) - **ai**: 接入连续开发与经验复盘流程 *(提交者 [@hanxi](https://github.com/hanxi))*

### :wrench: 维护工作
- [`f7494d1`](https://github.com/songloft-org/songloft-player/commit/f7494d1b9dd6c1caacbf01437302b777310dc6fe) - release version 2.13.2 *(提交者 [@hanxi](https://github.com/hanxi))*


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
[v2.13.2]: https://github.com/songloft-org/songloft-player/compare/v2.13.1...v2.13.2
[v2.13.3]: https://github.com/songloft-org/songloft-player/compare/v2.13.2...v2.13.3
[v2.13.4]: https://github.com/songloft-org/songloft-player/compare/v2.13.3...v2.13.4
[v2.13.5]: https://github.com/songloft-org/songloft-player/compare/v2.13.4...v2.13.5
[v2.13.6]: https://github.com/songloft-org/songloft-player/compare/v2.13.5...v2.13.6
[v2.13.8]: https://github.com/songloft-org/songloft-player/compare/v2.13.7...v2.13.8
