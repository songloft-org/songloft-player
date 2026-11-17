# #572：歌单与收藏的下一首播放

关联 [songloft-org/songloft#572](https://github.com/songloft-org/songloft/issues/572)。歌单详情和内置收藏共用 `PlaylistSongTile`，此前没有传入或展示曲库已有的下一首播放操作。

正常模式的歌曲菜单现在提供「下一首播放」，直接调用 `PlayerNotifier.playSongNext`。当前歌曲、进度和队列来源保持不变；只安排选中的歌曲，不切换或加载整个歌单。空队列、重复歌曲及播放模式沿用现有队列规则。多选和手动排序仍隐藏歌曲菜单。复用现有中英西文案。

验证对象：2026-11-17，`songloft-org/songloft-player` 基线 `e8ccdcc4a765356c0bd6dc0c64fc04c0d94aa521` + 本批未提交工作树；父仓库基线 `d57b42ba45c565bc48cd2d8f3f70f5b68d32859a`。Linux amd64，Flutter 3.44.8、Dart 3.12.2，临时真实 Go 后端和 Docker Chrome。最终差异及文件哈希见 `/tmp/songloft-572/verification.json`。

验证结果：

- `dart format lib/ test/`、最终 `flutter analyze --no-pub`、`git diff --check` 通过。
- `flutter test --no-pub --concurrency=2`：849 项通过；歌单及队列导航定向检查：88 项通过。
- 新增页面回归覆盖普通歌单/收藏、500px/1280px、中英西语言，确认只调用单曲排队且不增加歌单 HTTP 请求。同样 12 项测试在 `git archive` 隔离的旧实现上均因菜单缺项失败。
- 排序测试夹具隔离无关的 `playlistProgressProvider`；此前全组 20 项因续播卡片的五秒轮询定时器残留失败，本批未修改生产续播逻辑。
- embedded Web release 构建通过。中英西文案来自既有本地化；构建仍有既有的 9 项西文未翻译提示和 Cupertino 字体警告。
- 实际浏览器交互、音频进度、保存队列及来源证据：`/tmp/songloft-572/flutter-{full,mobile}.json`，菜单截图为对应 `playlistScreenshot.png` / `favoriteScreenshot.png`。夹具使用四段生成的静音 WAV，不涉及私人曲库。

边界：西文 390px 页面头部原有播放/添加按钮布局溢出，本批不扩大为头部布局修复；三语页面回归采用 500px 窄屏，中文另验 390px。Not run：Android/iOS/桌面原生包及报告人设备验收；Web 不替代原生验证。后端业务测试不适用，未修改后端。

本批已获用户授权提交、推送、同步父仓库指针并回复 #572，按子仓库先、父仓库后的顺序交付；不创建正式版本。最终提交与同 SHA CI 状态记录在 `/tmp/songloft-572/delivery.json`。提交：`feat(playlist): 歌单和收藏支持下一首播放 songloft-org/songloft#572`。
