# #563 服务端收藏同步

为认证会话订阅 `/playlists/favorites/changes`，收到失效通知后重新读取完整收藏；不依赖设置页或插件 WebView。后台／退出／服务器或账号切换停止旧订阅，恢复时对账；旧宿主 404 停止订阅，网络失败退避重试。

基线 `87a7699d2580b8c4463fa43e159d7bff18f6df29` + 未提交工作树。`flutter analyze`、831 项 `flutter test` 通过；新回归覆盖挂起请求、失败后游标、取消后的迟到事件、两类收藏缓存和旧初始化。隔离旧服务复现 ID 2 被旧响应恢复成 1。

实际 Docker Chrome 曲库行中，真实 QuickJS 插件增删后红心 Favorite→Unfavorite→Favorite，未点击红心或刷新页面。Profile Web 构建通过。

证据：`/tmp/songloft-563-extra/` 的测试／构建日志、截图和 `worktree-final.json`。首次并行构建因内存压力终止，串行分目标重跑；首次 Lynx 全量测试因该失败构建缺少产物而失败，成功构建后全量通过。

Not run：Android/iOS 及桌面真机、发行包与远端 CI。当前仅代码和 Web／注入测试验收；本记录描述提交前验证。用户随后授权提交、推送、SDK 发版和回复 songloft-org/songloft#563，最终提交及 CI 以 GitHub 和父仓库交付记录为准。
