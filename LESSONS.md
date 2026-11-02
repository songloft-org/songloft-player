# Flutter 客户端开发经验

## 范围与来源

记录songloft-org/songloft-player 的 Flutter、Provider、音频、Bundle 与原生宿主行为。流程见 [本地 AI 开发流程](docs/cn/ai-development.md)，公共宿主约束见父仓库。已有 AGENTS 和业务文档仍是权威规则，LESSONS 链接证据而不复制历史全文。

## 记录与升级

每条含规则、适用范围、完整 owner/repo#编号、失败/修复 commit SHA、实际验证和 Done right 示例；没有正确示例时写待补。Seen 只统计不同日期的独立事件，同一事故重复复盘不增加。三个日期后提出升级并标记规范位置，已有铁律/严重问题立即处理。与 [英文版](LESSONS.en.md) 同步，不虚构历史次数、修复结论或设备验收，敏感信息脱敏。

## 条目

### SORT-001：手动排序入口不能依赖当前视图排序字段

- 范围：Flutter 歌单详情，songloft-org/songloft#551；基线 `5be710cd57227fd60d16396b198be10f700ae91e`。
- 证据：报告截图选中「文件时间」升序；旧菜单仅在 `currentSort == 'position'` 时显示手动排序，与 `auto_created` 标签或扫描方式无关。新增实际页面回归在旧实现下 14 项失败、2 项通过，其中 12 项直接断言其他排序字段下入口缺失。
- 规则与修复：视图排序偏好不应隐藏永久调整顺序的入口。Flutter 以当前显示顺序进入拖动，保存完整成员顺序后切回自定义升序；取消不写入，搜索结果仍不提供永久排序。
- Done right：覆盖七种字段的升/降序、拖动保存和取消/搜索约束；完整 809 项测试与静态分析通过。两客户端的浏览器验证、源码身份及平台边界见 [#551 记录](docs/cn/issue-551.md)。Lynx 原有入口不依赖当前字段，29 项相关测试及实际拖动保存验证通过。
- Seen 1× (2026-11-02)。状态：实现与本地验证通过；提交、推送及 CI 按本批交付核对，Windows 原生安装包未验收。

### AUDIO-005：双重中断监听不能单独证明无法恢复的根因

- 范围：Flutter `audio_session` / `just_audio` 中断、用户取消及直播恢复，songloft-org/songloft-player#52；基线 `538c228677350fa7c87f74bb5fe12e6e71b7ef56`。
- 证据：2026-10-26，初查把 Handler 与 just_audio 双监听直接解释为报告的恢复失败。逐行核对发现 just_audio 另有恢复标记，普通单次恢复在旧 Handler 注入测试中也通过，不能据此认定原机根因。旧 Handler 在重复 begin、unknown 结束、主动暂停、异步暂停等待、直播恢复入口和迟到订阅等边界上确有缺口，隔离旧逻辑的 17 项回归中 14 项失败、3 项通过。
- 规则：先核对依赖监听顺序、暂停的同步部分、恢复状态及系统 `shouldResume` 映射，再解释用户症状；中断应有统一所有者，显式取消和耳机拔出也要清除恢复意图。注入会话的边界回归只能证明该层行为，不等于发布包或原机复现。
- Done right：候选统一 Handler 中断处理并等待暂停完成，恢复经过直播入口，用户取消后不再续播。Linux x86_64 / Flutter 3.44.8 / Dart 3.12.2 全量 791 项通过、静态分析无问题；代码对象、隔离方法及证据见 [#52 记录](docs/cn/issue-52.md)。Not run：iOS 编译、iPhone 视频中断及后台切歌、其他原生焦点路径；后台不切歌仍待版本和设备日志定位。
- Seen 1× (2026-10-26)。状态：经验；用户已授权提交、推送和回复 Issue，设备测试等待新包，未认定报告现象已解决。

### LYRIC-004：切歌动画的对比度下限套用静态 7:1 会中和强调色

- 范围：Flutter 手机/桌面全屏播放器 `PlayerBackdrop`，songloft-org/songloft#537；基线 `8fa1d6e`（v2.13.6）。
- 证据：2026-10-24，报告截图中的当前行与图标为 `#415F91`（浅色主题 primary）、非当前行接近 50% onSurface、顶部有黑色遮罩，对应 #523 之前的实现。当前 `_readable` 又把只在切歌动画中出现的黑/白封面混合色按 7:1 约束，六种内置配色的当前行都退化为近中性灰（浅色蓝/青/森林/玫瑰/琥珀/紫为 `#1F2631`/`#122C2C`/`#1F281A`/`#37232A`/`#352515`/`#2D2536`，深色为 `#E8E8ED`/`#E4E9E9`/`#E7E9E1`/`#F2E5E7`/`#F1E6DD`/`#ECE6ED`），强调色色相被中和。新增色相回归在旧实现下浅色（饱和度差 0.15595 > 0.02）和深色（色相差 20.47° > 1.5°）均失败。
- 规则与修复：静态背景按 7:1，切歌动画期间才可能显示的旧背景只按 4.5:1；调整前景时优先只改 HSL 明度、保留色相，不要先混向中性 onSurface。默认蓝色主题浅色强调色由 `#1F2631` 变为 `#2D4266`，深色直接保留 `#AAC7FF`。
- Done right：对比度/过渡回归及全部相关测试通过；新增色相测试在旧实现失败、新实现通过。完整验证与 Not run 见 [#537 记录](docs/cn/issue-537.md)。报告截图为旧客户端，不能据此宣称当前版本仍有同样的深灰背景。
- Seen 1× (2026-10-24)。状态：经验；提交与发布以 Git/CI 为准。

### ANDROID-001：JNI 参数类型属于原生契约，debug 启动通过不能替代 release 验收

- 范围：Android 标准版 / Bundle 的 R8 混淆、SharedPreferences 初始化与热更新兼容哈希；基线 `203e79b5fd7ac02b8edb93af291bb6981e62974f`，正式包源码 `d89934eea468c22f635d28e5bfd0b5fe81c98147`。
- 失败证据：2026-10-20，反馈 2.13.4 卡在「正在启动」，卸载重装无效。正式 x86_64 APK（SHA-256 `01812553e6cfc32e80b095f956c2f291dfc5f54500195b9a9a05e258a46769bf`）在隔离 API 34 模拟器初始化设置时复现 `SharedPreferencesApiRegistrar.getAll` 的 `NoSuchMethodError`。DEX 中实参为 `LE3/d;`，JNI 仍查找 `Lkotlin/coroutines/Continuation;`。2026-10-21 补查用户指定的正式 ARM64 包（SHA-256 `54e9bd33a8aaa305b1a210160e539f2faf4c4782d17a09aa6e63a0f5af8b576c`），同样未通过 JNI 检查，且两个 DEX 均与 x86_64 正式包逐字节一致；红米 K40 为用户报告，未作为真机验收。发布 CI 证实 2.13.3 解析 `shared_preferences_android 2.4.28`，2.13.4 解析 `2.5.1`；后者通过 JNI 调用 Kotlin suspend 方法。此前无服务器的 widget 测试、debug 包和网络超时回归不能发现 release 混淆错误；网络加固已另存证据目录，不作为本事故修复。
- 规则与修复：在 release 中加载 ProGuard 规则，用 `-keep,includedescriptorclasses` 同时保留设置插件桥及其参数类型，并核对 `package:jni` 的 `lib/src/kotlin.dart`，保留其按名字查找的协程、Result/Failure 与 Unit 类及成员。只保留方法描述符的首个候选包虽通过初版静态检查，原生启动仍报 `CoroutineSingletons` 类缺失；已保留 `candidate-descriptors-only.apk`、`native-partial.log` 与 `partial-startup.png` 作为反例，扩展后的 APK 检查会拒绝它。标准版 / Bundle CI 逐一检查 ARM64、ARMv7 与 x86_64 release APK 的 `getAll` 描述符和这些运行时符号。ProGuard 规则纳入原生契约哈希，规则改变需整包更新，避免向旧 APK 仅下发 Dart 补丁；注释和空行不改变哈希。
- 验证记录：`/tmp/songloft-startup-20261020/` 的 `release-sharedprefs-dex.txt`、`jni-before.log`、`release-ci.log`、`release-2.13.3-android.log` 与 `native-contract-{before,test}.log`。旧正式包被新 APK 检查按预期拒绝；旧哈希脚本在新增兼容性回归下失败，新脚本通过。修复包构建、DEX 与原生启动验收以 `validation-native.json` 为准，不将首次因引擎下载失败的构建写成通过。
- Done right（2026-10-21）：Linux amd64 / Flutter 3.44.8 / Dart 3.12.2 / shared_preferences_android 2.5.1 / jni 1.1.0；完整混淆 release APK 构建和桥接/协程运行时符号检查通过，6 项启动/契约 Dart 测试及 1 项脚本回归通过，静态分析无问题。API 34/x86_64 全新安装与第二次冷启动均进入登录页，日志无原生查找异常；截图 `final-{startup,restart}.png`，日志 `native-final.log`。首次下载失败及两次构建机 OOM 均保留失败日志；最终使用镜像、单 worker、受限堆和串行 GC 完成构建，不修改发布配置的并发/内存默认值。补验 ARM64 分架构 release 构建、完整 JNI 检查、原生契约 asset 一致性与仅包含 ARM64 原生库均通过；产物 `songloft-startup-fixed-arm64-v8a.apk`，SHA-256 `1be79259583a4f0ee6d0962c682d868a99f936ef56009d25d5f724728d835504`，记录 `release-build-arm64.log` 与 `jni-fixed-arm64.log`。APK 使用本地调试证书签署，仅供验证；Not run：报告人 ARM 真机、正式签名发布包、Bundle 本地后端和远端 CI。
- Seen 1× (2026-10-20)。状态：已确认的 release 原生故障，已完成本地修复；设备、最终提交与构建覆盖见验证记录，正式版发布单独追踪。

### AUDIO-004：直播断流不是歌曲完成，重连必须保留播放意图与取消边界

- 范围：Flutter 直播电台、播放重试及 audio_service 媒体会话，songloft-org/songloft#531；基线 `d89934eea468c22f635d28e5bfd0b5fe81c98147`。
- 证据：隔离旧 Provider 后，直播完成按播放模式/下一首预约推进，加载失败耗尽网络重试后切到 B 台；旧退避对极大重试次数算出零延迟。API 34 原生首轮确认断流后继续请求 A 台，同时发现加载失败使 MediaSession 进入 idle 并失活；该轮因宿主内存压力中断，不算完整设备验收。
- 规则与修复：`isLive` 的完成/错误走当前台重连，在有限歌曲重试预算外持续退避，计算前截断指数；断流不消费歌曲完成事件、下一首预约或睡眠歌曲数。暂停/停止/换台/销毁使旧代次失效，暂停废弃尚未完成的源加载；重连期间发布 buffering 与播放意图以保留通知控制，取消时清除。
- Done right：修复后音频、播放器 domain 与真实 Provider 共 291 项测试通过，覆盖三分钟离线后原台恢复、取消、媒体播放键及睡眠定时器。最终全量 767 项通过，API 34 模拟器完成 110 秒断网原台恢复及媒体暂停/继续/停止验证。完整验证对象见 [#531 记录](docs/cn/issue-531.md) 与 `/tmp/songloft-531-20261020/`；模拟器和合成源不替代报告人真机与长后台。
- Seen 1× (2026-10-20)。状态：经验；本地验证在提交前完成，最终提交及发布状态以 Git/CI 为准。

### AUDIO-003：libmpv 的 error 日志不等于致命错误，判定曲目结束前要看播放是否真的停住

- 范围：原生端（Win/Linux/macOS/Android/iOS）media_kit/libmpv 播放，songloft-org/songloft#529，基线 `1dcc52612f6242a0598b3c06c946200a5d2f1ec5`。
- 证据：2026-10-20，报告样本 MP3 在文件偏移 728728 处有一段**整 32768 字节的全零**（无 Xing 头，对应音频 25.73s）。后端无锅：扫描时长 282.996083333s 正确，`/api/v1/songs/1/play` 返回 `Content-Length: 6903290` 与文件逐字节一致；`curl -r` 重取原站同段数据亦完全相同，损坏在源文件。解码器其实能恢复：ffmpeg 报一次 `[mp3float] Header missing` 后仍解出 281.52s（比 283.0s 少的 1.4s 正好 = 32768 ÷ 24000 B/s）；Chrome `<audio>` 播到 283s 才 `ended`。但 libmpv 把这条**可恢复**的解码错误按 `level=error` 从 `ad` 模块打出，vendored media_kit `real.dart` 的 `prefix == 'ad'` 分支将其转成 `player.stream.error`，`songloft_mediakit_player.dart` 的播放中错误分支（为 songloft-org/songloft#357 的 FLAC 尾部错误/网络流中断而加）无条件置 `completed` → 上层当曲目放完自动切歌 → 整首歌在 00:25 被跳过。
- 规则：**错误事件本身区分不出可恢复与致命**，不要靠它单独判定曲目结束。要看错误之后播放位置还推不推进：记下位置、等一个观察窗口，窗口结束仍几乎原地不动才判定致命。暂停中不判定（既无从比较，自动切歌本身也错）；连续错误刷屏不重置窗口，否则窗口永不到期；seek/换曲/load/release 要让基线失效。
- Done right：新增 `lib/core/audio/playback_error_watchdog.dart`（3s 窗口 / 500ms 推进阈值），播放中错误改为 `arm()`，加载失败分支行为不变（#357 的不可恢复场景仍会判定结束，只是晚 3s）。7 项新单测覆盖「推进中不判定」「停住判定」「低于阈值判定」「暂停不切歌」「cancel」「连续错误只判一次」「判定后可重新 arm」；隔离破坏检查删掉推进判断后 #529 回归项如期失败。`flutter analyze`（core/audio + test/core/audio）无问题，完整 749 项测试通过，`dart format` 无差异。
- 其他端结论：Flutter Web（`songloft_web_audio_player.dart`）error → `idle` 不切歌，真实 headless Chrome 驱动的 Flutter Web 从 25.1s 直播到 33.1s 无 error、无 `ended`；Lynx Web（`player-store.ts` 的 `audio.on('error')`）走 `scheduleRetry` 原位重试，`stateChanged: 'error'` 分支为空，均不受影响。报告人所说「web 端」与此不符，待其确认客户端类型。
- Not run：报告人 Windows/Android 原生包与其私人曲库的实际验收；本地无 Windows/Android 设备，ffmpeg 与 Chrome 不替代原生 libmpv 真机回归。
- Seen 1× (2026-10-20)。状态：经验；修复提交以 Git 为准。

### AUDIO-002：just_audio 的 headers 会无条件启用回环代理，HLS 子资源 key 与之不匹配

- 范围：桌面（Win/Linux/macOS）HLS 电台播放，libmpv 后端与 just_audio 0.10.6，songloft-org/songloft-player，基线 `a9e5dda70b61e313ee9902b9bfc26691c16230c6`。
- 证据：`UriAudioSource._onLoad` 只在 `headers`（或 player 级 userAgent）非空时启用 `_ProxyHttpServer`；该代理对 m3u8 的相对子资源用**入口 URL** 的 query 注册 key（`uri.replace(path: ...)` 不换 query），而 libmpv 以代理入口为 base 解析切片，实际请求 query 是切片自带的 `u=...`。注册 key 与请求 key 不同 → `_handlerMap[uriPath]!` 空指针 → 所有切片 `Failed to open segment` → 18s 超时重试。用户日志中 `_ProxyHttpServer.start.<anonymous closure>` 的空指针即此。
- 规则：**不要把发往源站的请求头塞进 `AudioSource.uri(headers:)`**，除非确认该源不需要子资源（非 HLS）。也不要全局 `useProxyForRequestHeaders: false`：`insecureTls` 路径依赖该代理把上游 HTTPS 交给 Dart trust-all HttpClient（#272）。
- Done right：桌面直播把 UA/Referer/`Icy-MetaData` 包成 `LiveStreamHeaders` 挂到 just_audio 的 `tag`，`SongloftMediaKitPlayer` 转成 `Media(httpHeaders:)`（media_kit → mpv `http-header-fields`）直达 libmpv；`headers` 保持 null 不启用代理。新增 10 项单测覆盖「桌面 live headers 为空且头在 tag」「tag 到达 Media.httpHeaders」「非桌面行为不变」；`flutter analyze` 仅余 2 个既存 warning，新增测试全通过。
- Not run：真实 Windows 客户端 + 用户内网电台的实际播放验收；也未向上游 just_audio 提 issue（`uri.replace` 丢 query + `_handlerMap[...]!` 无兜底）。
- Seen 1× (2026-10-19)。状态：经验；修复提交以 Git 为准。

### LYRIC-003：文字对比度与封面色差必须分别验收

- 范围：Flutter 封面取色、手机/桌面全屏背景，songloft-org/songloft#523 的 2026-10-17 反馈。
- 证据：基线 `18b50cbca02a7470279ddcd04907f71365140a57` 的文字对比度测试通过，但浅色背景只保留 12%→4% 封面色；下端没有 mutedColor 时退回主题色。真实 HTTP/PNG 回归还确认默认过滤器丢弃暖棕/黑白，缓存相对路径没有服务器身份。旧实现两项取色与两项色差测试失败。
- Done right：分别约束渐变两端的封面色差、真实图片解码和文字对比度；提高色深后，把切歌动画中的旧背景也纳入前景计算。初版加强背景被原有对比度/动画回归拦截，补齐极值边界后相关 12 项通过；完整验收及原机边界见 [记录](docs/cn/issue-523.md#2026-10-17--封面颜色仍不明显)。不能用本地缺陷证明报告人原机根因。
- Seen 1× (2026-10-17)。状态：经验；当前为未提交工作树。

### LYRIC-002：排查取色背景前先核对有效无障碍设置

- 范围：Flutter 全屏播放器，songloft-org/songloft#523 的 2026-10-16 反馈。
- 证据：基线 `bb03a5c49eb6701d90a73b924ed12ec388c6560c` 的实际配色函数在增强对比度时主动返回纯色；旧开关说明未提封面背景。不能从有封面却无渐变直接推断取色失败，也不能只查应用开关而忽略系统高对比度。
- Done right：保留无障碍策略，补齐三语开关说明；实际函数对照与验证范围见 [#523 后续记录](docs/cn/issue-523.md)。报告人设备状态尚未确认，未宣称根因已证实。
- Seen 1× (2026-10-16)。状态：经验；验证时文案尚未提交，最终验证对象见任务记录。

### QUEUE-001：大队列定位必须让布局知道行高，追加查重不能逐项扫描整队列

- 范围：手机播放队列、桌面侧栏和分批追加，songloft-org/songloft#525。
- 证据：2026-10-15，基线 `00cbe94841acca3eaf561a339f61072914c9de31` 的两处 `ReorderableListView.builder` 未指定行高；隔离旧源码定位 3 万首队列中部时，两项回归均触发超过 200 行构建的保护。旧 `PlayQueue.add` 向 3 万首追加 100 首的回归读取歌曲 ID 6,000,000 次。
- 规则与修复：列表的 `itemExtent` 和自动定位使用同一行高，按文字缩放容纳标题与歌手；身份集合按 `(id, type)` 查重，保留既有重复条目、批内去重和顺序。
- Done right：新实现打开、跨队列切歌的条目读取均少于 100 次；同一追加回归 ID 读取不超过 30,100 次。完整 728 项 Flutter 测试、静态分析、嵌入 Web 构建通过；中英文、两倍字号、拖拽和删除验证及浏览器证据见 [#525 记录](docs/cn/issue-525.md)。
- Not run：报告人的 Windows、Android 原生包与私人曲库验收；浏览器不替代真机，未把修复候选当成已发布。
- Seen 1× (2026-10-15)。状态：经验；验证对象为上述基线 + 本次修复，测试时工作树标识见任务记录，提交 SHA 以 Git 为准。

### AUDIO-001：通知停止动作要核对 SDK 的分平台转换

- 范围：Flutter audio_service 通知和 Android 系统媒体面板，songloft-org/songloft#520。
- 规则：核对锁定版本的 `createCustomAction`、通知动作列表和分平台转换，不把 Dart 的 customAction 字段当成所有 Android 版本的渲染证明。
- 证据：2026-10-14，基线 `3860205b0d8cf8449d8cf31746c254ef597c55e3` 的停止为显式 customAction，audio_service 0.18.19 的普通通知列表会排除它。本批初版额外加入标准 STOP，API 34 实际 MediaSession 出现两个 Stop；库在 Android 13+ 已会自动把标准 STOP 转为自定义 STOP，双注册多余。
- Done right：只保留标准 STOP，旧通知有停止动作、新面板只有一个停止动作。隔离副本缺少标准动作时 4 项回归失败，修复后通过；最终 API 34/x86_64 原生播放时 Stop 数量为 1，播放中点账户退出后 PID、服务和通知归零。证据 `/tmp/songloft-520-flutter-{single-stop,final-playing,playing-exit}.json`；工作树对象见 [#520 记录](docs/cn/issue-520.md)。
- 停止生命周期补充：真实 API 34 验收发现底层迟到 ready/completed 事件会重新发布播放态，且界面绑定使上游 `stopSelf()` 不触发销毁，前台通知/唤醒锁未释放。Dart 停止状态拒绝旧加载和完成回调；本地 audio_service 0.18.19 在 stop 中先结束前台并释放唤醒锁。停止后通知为 0、媒体失活且 startRequested=false；重新点歌可恢复。本批经验仍计一次。
- 图标补充（2026-10-15，同一 Issue）：覆盖库图标需核对密度配置；新 APK 使用 `drawable-anydpi` 同名矢量资源，保留旧包可解析的 `audio_service_*` 名字。`aapt2 dump resources` 与 API 34 实际通知分别确认打包配置及 X 停止效果，见 [后续记录](docs/cn/issue-520.md)。契约检查覆盖默认标准控件及应用/库两处资源，不能再按 `audio_service_*` 前缀直接跳过。
- Not run：鸿蒙 4.2 实机通知布局；API 34 不能替代该设备验收。
- Seen 1× (2026-10-14)。状态：经验；修复提交以 Git 为准，不把模拟器结果写成真机验收。

### WIN-001：辅助窗口坐标测试不等于 WebView2 桌面输入验收

- 范围：Windows 插件 WebView2、跨屏移动与残留区域鼠标输入。
- 规则：分别核对修复提交、发布版本和实际输入；模拟 Win32 坐标测试及 Windows 编译不能证明旧区域恢复桌面右键。覆盖全屏插件、跨屏往返、不同 DPI、最小化和托盘恢复，记录真实窗口及输入证据。
- 失败：songloft-org/songloft#499 的位置同步补丁 [f1ef7f2](https://github.com/songloft-org/songloft-player/commit/f1ef7f2d8aabf4ba9e9da12cac029f52e211e189) 于 2026-10-06 合入，仅验证模拟窗口及编译，明确未做双屏实测。2026-10-14，报告人[反馈客户端 2.13.1 仍屏蔽右键](https://github.com/songloft-org/songloft/issues/499#issuecomment-6160069251)。标准版 v2.13.1 与父仓库同版 gitlink 都指向 f684da386c75bb8825713b1b14fdd2a3c24d7adb，包含该补丁；不能归为发布遗漏。
- 调查：基线 1cb9b4947cdc1c641507e9486b0a0024fc274e97 下，Linux/GCC 12.2 的原有 7 个模拟场景通过。测试没有 WebView2 控制器或真实鼠标命中。基线 runner 及锁定的 flutter_inappwebview_windows 0.6.0 未调用 `NotifyParentWindowPositionChanged`，属于已确认的接口缺口，但不能据此认定复发根因。
- 候选修复：本次候选补丁将 Windows 平台包 vendoring 到 `third_party/flutter_inappwebview_windows`，辅助 HWND 的 `WM_WINDOWPOSCHANGED` 默认处理后通知控制器；退出与窗口销毁均解绑，防重入与 HWND 复用。Windows 打包 CI 增加真实 HWND/comctl32 检查，ZIP 包含只读 `webview_hit_test.exe`，若仍复发可取证实际命中窗口。范围与验收见[补丁说明](third_party/flutter_inappwebview_windows/README.md)及[平台说明](docs/cn/platform-notes.md#windows-插件与桌面右键验收)。
- Done right：Linux/GCC 12.2 `cmake` 与 `ctest` 通过（7 个原有坐标场景 + 8 个 observer 场景，目录 `/tmp/songloft-499-native-20261014-02`）；隔离副本删掉关键通知或显式解绑后均编译成功且目标测试失败，日志分别在 `/tmp/songloft-499-no-notify-final-20261014/validation.log`、`/tmp/songloft-499-no-detach-final-20261014/validation.log`。这属于破坏检查，不是旧包的 Windows 复现。Flutter 3.41.5 下 13 个插件相关测试、`flutter analyze`、格式和 diff 检查通过。Not run：Windows 完整编译、真实 HWND 检查、诊断工具运行及双屏/WebView2 输入验收；开发机为 Linux，用户也无 Windows 环境，待 CI 构建与报告人测试。
- Seen 1× (2026-10-14)。状态：经验，#499 未完成实机验收。

### LYRIC-001：歌词前景要按实际背景计算对比度

- 范围：Flutter 手机与桌面全屏歌词，songloft-org/songloft#523。
- 证据：2026-10-15，基线 `b80e03b47eefb1aaedf07d611b1d9d3c3d48257b` 的背景叠加封面深色与顶部黑罩，歌词直接使用主题 primary，译文/罗马音再降低透明度。隔离副本使用旧 `lyrics_view.dart` 配合新的柔和背景时，亮色当前行 5.17:1、暗色译文 5.82:1，均未达到本次 7:1 目标；两项渲染回归按预期失败，日志 `/tmp/songloft-523/before-lyrics.log`。
- 规则：背景取色与前景一起设计；半透明文本要先合成到实际背景再测对比度，不能把 Material 在默认 surface 上的保障直接套到任意封面遮罩。缺失/失败封面要核对统一兜底，增强对比度要覆盖动态图层。
- Done right：统一 `PlayerBackdrop` 将取色混合到当前 surface，按背景加强强调色；当前行/翻译/罗马音/逐字共用完整对比度。六种内置配色与极端封面的亮暗渐变采样通过，完整 716 项测试、静态分析、嵌入构建通过；实际浏览器切歌及缺失/失败封面比对见 [#523 记录](docs/cn/issue-523.md)。Not run：原生真机户外验收。
- Seen 1× (2026-10-15)。状态：经验，未提交工作树对象见任务记录；发布状态另按 Git/CI 核对。
