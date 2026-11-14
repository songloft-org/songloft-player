# 大歌单续播队列修复（2026-11-14）

对象：songloft-player 基线 4708c64 + 本批工作树。实现与提交推送沿用当前歌单续播任务授权。

原先 playPlaylistTarget 只放入一首，全部分页成功后才替换队列；同曲续播又会直接返回。现改为先拉目标附近最多 100 首，逐批向后加载并向前补齐。每个可见队列都是原排序的连续区间，映射当前索引、随机导航和预选状态，保持当前 Song 与音频实例。残缺队列续播会补齐，保留当前位置。

验证：analyze 无问题，flutter test --no-pub test/features/player 共 298 项通过，嵌入 Web 构建通过。新纯 Dart 加载器测试验证千首歌单在第二批等待时已提供目标与下一集、每批区间连续、失败保留和切换取消。Docker Chrome 中给后续每页增加 1 秒延迟，初始队列为 100，点击下一首实际播放第 129 集，最终队列显示 1000；截图 /tmp/songloft-resume-1000/flutter-first-window.png、flutter-full.png，结果 flutter-result.json，日志 /tmp/songloft-resume-1000-flutter-*。

原生真机、后台、投屏 Not run。上一提交 4708c64 的独立 Android CI 因 JNI 发布校验失败，本次未修改 Android/ProGuard；不把 Web 验收当作原生包验收。最终工作树/提交身份保存在 /tmp/songloft-resume-1000/。公共业务/API 说明见父仓库 docs/playlist-resume.md。
