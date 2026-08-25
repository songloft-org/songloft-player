# WebF Android verification

This harness builds a plugin and starts a temporary Songloft server on the host.
Docker builds an x86_64 release APK, runs the Android Emulator, installs the
APK, opens the real WebF plugin page, and runs automated verification.

## Downloader plugin test

```bash
./scripts/webf-android-verify/run.sh
```

Builds the downloader plugin, opens its settings page, and verifies switch
alignment from a screenshot. This is the original / primary test.

## MIoT plugin test

```bash
./scripts/webf-android-verify/run-miot-test.sh
```

Builds and uploads the miot plugin (`jsplugins-src/songloft-plugin-miot`),
opens the miot WebF page, navigates to settings, and captures screenshots.
Requires a pre-built APK (run `run.sh` at least once first to build it).

Outputs are written to `scripts/webf-android-verify/out/miot-test/`:

| File | Description |
|------|-------------|
| `miot-main.png` | 主页面截图（歌单选择器、播放栏、控件） |
| `miot-settings.png` | 设置页面截图（分类菜单） |
| `miot-settings-scrolled.png` | 设置页面滚动后截图 |
| `miot-ui.xml` | 主页面 UI 树 dump |
| `miot-settings-ui.xml` | 设置页面 UI 树 dump |
| `miot-logcat.txt` | 完整 logcat 日志 |

验证覆盖点：
- WebF 页面加载成功（无 startupError）
- SlSelect / SlButton / SlIcon 组件渲染
- Player icon font codepoints 映射正确
- PlayerProgress 时间标签显示
- 设置页面高度（100dvh → 100vh fix）生效

## MIoT 设置页 UI 取证（二维码 / 下拉面板 / 两列表单 / toast）

```bash
./scripts/webf-android-verify/run-ui-issues.sh
```

产物落在 `out/ui-issues/`。需要先跑过 `run.sh`（拿 APK）并在
`jsplugins-src/songloft-plugin-miot` 里 `npm run build`。

覆盖四处，判定**一律看 uiautomator dump 里的 bounds**，不靠目视截图：

| 段 | 目标 | 判定 |
|----|------|------|
| A | 语音页「外部搜索源」 | 该区应有 **3 个** `EditText`（名称 / 接口 URL / Token）；只有 1 个说明两列表单行没渲染 |
| B | 定时页「歌单」下拉 | 面板首个选项的 `top` 必须 **大于** 触发器 `bottom`（面板在下方），且面板不越出视口 |
| C | 设备页登录二维码 | `ImageView 登录二维码` 应为 **550×550** 设备 px（= 200×200 逻辑 px）；只有几 px 就是塌了 |
| D | toast | 点「自动填充」后 toast 节点宽度应非 0 |
| E | 面板内滚动 | `22-playlist-panel-OPEN` 与 `25-panel-after-inner-scroll` 两份 dump 里，**面板盒子的位置必须一致**（内容滚了、盒子没动）。盒子跟着滚动往下跑 = fixed 元素自己当了滚动容器，见下 |

脚本会预置 12 个歌单（下拉要 ≥8 项才顶到 320px 上限、才走得到翻转/让位分支），
并把插件 `server_host` 设成宿主的非回环 IP —— 插件的 `/playlists` 在 `server_host`
为空或回环时**只返回空列表加一句提示、不报错**，那样 B 段会静默取不到证。

> 踩坑：WebF 页面的视口只到宿主底部导航栏为止（1080×2400 上约 `y<1612`）。
> 落在折叠线上的按钮在 dump 里是个高度十几 px 的薄片，**点它不触发任何事件**，
> 而 dump 里明明有那段文字，极易误判成「点了没反应」。`runner-miot/tapnode.py`
> 因此要求节点整体落在 `[180,1600]` 内才肯点，不满足就先滚动。
>
> 另一个 WebF 坑（E 段就是为它加的）：`position: fixed` 的元素**不能自己是滚动容器**。
> `getFixedScrollCompensation()` 走 `getTotalScrollOffset()`，而后者从 `this.scrollTop`
> 起算（`rendering/box_model.dart:1807`），所以在这个元素内部滚 N px，它整体就被往下
> 画 N px。滚动必须放到内层子元素上。参考 songloft-org/songloft#397。
>
> 调试布局时可往插件前端塞临时 `console.log` 探针：页面 console 会以
> `flutter : [plugin][console] ...` 进 logcat，runner 已抽到 `out/ui-issues/page-console.txt`。
> \#79 就是靠它推翻了「元素没渲染」的猜测 —— `getBoundingClientRect` 返回正常的
> 309×42，但屏幕上和 dump 里都不存在，从而定位到 WebF「算出布局但不绘制 grid 容器」。

## MIoT 定时任务的全局动作（开启/关闭对话监听）

```bash
./scripts/webf-android-verify/run-schedule-monitor.sh
```

产物落在 `out/schedule-monitor/`，判定由 `assert_schedule_monitor.py` 自动做（PASS/FAIL +
非零退出码），不需要人工看图。需要先跑过 `run.sh`（拿 APK）并在
`jsplugins-src/songloft-plugin-miot` 里 `npm run build`。
参考案例：songloft-org/songloft-plugin-miot#89。

`enable_monitor` / `disable_monitor` 是**不绑定设备**的全局动作，编辑器要隐藏整个目标设备区，
后端也不该再校验设备。四条判定按「越往后越难伪造」排列：

| # | 判定 | 依据 |
|---|------|------|
| 1 | 默认动作 `play_playlist` 下**有**「目标设备 / 所有受管理设备」 | 控制项。少了它，判定 2 通过只说明 runner 没滚到位 |
| 2 | 切到「开启对话监听」后这两项与「选择歌单」**全部消失** | `16` / `17` / `18` 三份 dump 都不得命中 |
| 3 | toast 是「定时任务已保存」，列表副标题渲染中文 label | dump 里不得出现原始值 `enable_monitor` |
| 4 | 任务真的落库且 `devices` 为空 | `GET /schedules`。#89 就是 handler 拒收，UI 侧证据独木难支 |

> 踩坑一：`SlSelect` 在 WebF 下是**自绘面板**，不是原生 `<select>`——浏览器里能用
> `page.select` 一步切换的地方，这里必须「tap 触发器 → 面板展开 → tap 选项」，
> 触发器的 `content-desc` 就是当前 label（如「播放歌单」）。
>
> 踩坑二：任务名称框只在**切完动作、任何滚动之前**才是视口内第一个 `EditText`。
> 一旦滚到表单底部，视口里只剩「执行时间」那个框，按固定 index 点会把任务名打进
> 时间框，保存后只看到「请输入任务名称」的 toast —— 看着像按钮没反应，实际是填错了框。
> WebF 的 `EditText` 不带 `content-desc`（`aria-label` 未映射），只能靠 `text` 和位置认。
>
> 踩坑三：uiautomator 只 dump 视口内的节点。编辑器表单整段在折叠线以下，
> 刚打开时那份 dump 里没有「目标设备」**不代表它没渲染**，必须先滚到底再取证。

## MIoT 歌单下拉的搜索框

```bash
./scripts/webf-android-verify/run-playlist-search.sh
```

产物落在 `out/playlist-search/`，判定由 `assert_playlist_search.py` 自动做（PASS/FAIL +
非零退出码），不需要人工看图。需要先跑过 `run.sh`（拿 APK）并在
`jsplugins-src/songloft-plugin-miot` 里 `npm run build`。
参考案例：songloft-org/songloft#410。

旧版原生前端的歌单弹层顶部有「搜索歌单」输入框（`static/js/search.js`），
WebF 重写换成通用 `SlSelect` 后过滤功能整个丢了。修复给 `SlSelect` 加了可选
`searchable`，选项数 **大于 5**（`SEARCH_MIN_OPTIONS`）时在面板顶部挂一行搜索框。

**这个 harness 存在的唯一理由**：`SlInput` 在 `useNativeUI` 下渲染的是
`flutter-cupertino-input`，而它要被放进 `position: fixed` 的下拉面板里。浏览器里
`useNativeUI` 恒为 false、搜索框会退化成普通 `<input>`，**那条路径验不到原生元素**；
而本仓库有过原生元素「算出布局但不绘制」的先例（#79 的 grid 容器、#81 的 slider），
所以必须在真机上确认它渲染、能聚焦、能输入。

六条判定按「越往后越难伪造」排列：

| # | 判定 | 依据 |
|---|------|------|
| 1 | 面板内有**非零尺寸**的 `EditText`，且夹在触发器下沿与首个选项之间 | 缺失或塌成 0 = 原生输入框没渲染 |
| 2 | 输入小写 `jazz` 只剩「Jazz Night」 | 大小写不敏感的子串过滤真的在跑 |
| 3 | 输入 `0` 只剩「Mix 0」 | 见下 |
| 4 | 无匹配时渲染「无匹配项」空行，而不是空面板 | dump 命中该文案 |
| 5 | 过滤态下能选中 → 面板关闭 + 触发器 label 更新 | 过滤出来的是真选项，不是死文本 |
| 6 | 再打开时搜索框为空、列表回到全量 | 见下 |

> 判定 3 是 `SelectOption.searchText` 的锚点：种下的歌单都是 0 首歌，label 全长成
> 「xxx (0)」。**如果过滤匹配的是渲染出来的 label 而不是纯名称，输入 `0` 会命中全部
> 14 项**。歌单名里那个「Mix 0」就是专为这条判定准备的。
>
> 判定 6 针对的是「关键词残留」：`query` 挂在组件级 ref 上，而面板本身是 `v-if` 掉的，
> 漏了复位就会出现「列表还被上次的词过滤着，可搜索框已经空了」的错位。
>
> 踩坑一：**`tab-config` 必须配**（宿主脚本已做）。漏了客户端底部不会出现「智能音箱」
> tab，runner 会一路停在主程序首页 —— 而 `wait_for_text` 失败并不中断脚本，后面每步
> 都在给主程序的界面拍照，判定全线失败却看不出原因。
>
> 踩坑二：**`adb shell input text` 打不进中文**。所有用来搜索的歌单名必须是 ASCII
> （`Jazz Night` / `KPop Hits` / `Mix 0`），中文名只能用来凑够阈值项数。
>
> 踩坑三：WebF 不把 `aria-label` 映射到 `content-desc`，`EditText` 上没有任何可匹配的
> 文本，只能按**类名 + 位置**认。`assert_playlist_search.py` 因此假设面板**向下**展开
> （主页下拉在视口顶部，恒有下方空间）；将来若把这套判定用到会向上翻的下拉，
> `panel_edits()` 要跟着改。

## MIoT 播放器控件 / 图标字体竞态

```bash
SHOT_TAG=before SLOW_FONT=3 ./scripts/webf-android-verify/run-player-icons.sh
```

专门盯 miot 的**底部播放条 / 全屏播放器 / 音量弹出层**，产物落在
`out/player-icons/`（`icons-<TAG>-boot1..4` 是进入插件后的首屏连拍，
`-bar` / `-full` / `-volume` / `-back-main` / `-full2` 是各交互步骤）。

`SLOW_FONT=<秒>` 会在设备与后端之间插一个只拖慢 `.otf` 响应的透传代理
（`runner-miot/slow-font-proxy.py`），用来复现 WebF 的 **@font-face 迟到竞态**：

- WebF 的 `@font-face` 是布局期懒加载，字体到货后**只重排「第一个请求者」**
  （`webf/lib/src/css/font_face.dart`）。同一批并发请求者永远拿不到脏标记，
  段落缓存永久停在 fallback 字形。
- 本地 localhost 上字体几乎瞬时到达，**这个 bug 在本地环境是复现不出来的** ——
  必须用这个代理人为拉开延迟，否则会误判为「没问题」。
- 代理**逐条请求**识别（不是只看首行）：Dio 的连接是 keep-alive 复用的，
  字体常常是同一条 TCP 连接上的第 N 个请求，只看首行会全程零命中。

`SHOT_TAG` 区分修复前后两轮截图，方便并排比对。
参考案例：songloft-org/songloft-plugin-miot#81。

> 注意：播放条与全屏播放器需要「已选中设备」才渲染，而测试环境没有真实小米账号。
> 复现这两块时需要临时在插件前端注入假设备/假播放状态（用完删掉，不要提交）。

## Flutter 原生界面取证（播放器图标 / 布局）

```bash
BUILD_APK=1 SHOT_TAG=before ./scripts/webf-android-verify/run-flutter-player.sh
```

上面几节都在驱动 miot 插件的 WebF 页面，这一节走的是 **Flutter 自己的界面**
（登录 → 曲库 → 起播 → 展开全屏播放器 → 底部工具行），用来核对图标、间距、视重这类
只能眼见为实的东西。宿主脚本 `run-flutter-player.sh` 会用 ffmpeg 造 3 首正弦波测试曲、
起临时后端（`58396`）、扫描入库，再把 `runner-flutter/run-player-speed.sh` 送进容器跑。

产物落在 `out/flutter-player/`：

| 文件 | 说明 |
|------|------|
| `<TAG>-library.png` | 曲库列表 |
| `<TAG>-mini.png` | 起播后的 mini player |
| `<TAG>-full.png` / `-toolbar.png` | 全屏播放器整屏 / 底部两行放大 1.6× |
| `<TAG>-speed-panel.png` | 播放速度弹出面板 |
| `<TAG>-full-1p5.png` / `-toolbar-1p5.png` | 选 1.5 倍速后的状态 |
| `<TAG>-*-nodes.txt` | 各步骤的语义节点清单（`runner-flutter/tapx.py --list`） |

三个坑，按踩到的顺序：

- **改了 Dart 就必须 `BUILD_APK=1`**。`out/` 里的 APK 不会自动跟着代码走，装上旧 APK 截出来
  的是旧界面，而且**看起来完全正常**——只是与你刚改的代码无关。脚本会在 APK 比 `lib/` 下
  最新 `.dart` 旧时打 warn，别忽略。
- **重装前必须先 `adb uninstall`**。`apk-builder` 是 `--rm` 且 `/root/.android` 未持久化，
  每次重建都生成新的 debug keystore，于是 `install -r` 报 `INSTALL_FAILED_UPDATE_INCOMPATIBLE`。
  它把失败写进 **stdout 而非 stderr**、退出码也不一定非零，所以 runner 里额外 `grep Success`。
- **全屏播放器和 `OverlayEntry` 面板不进 uiautomator 无障碍树**。此时 dump 回来的仍是底下那层
  曲库页 + mini player 的节点（截图却是对的），于是「dump 里找不到 `播放速度`」根本不代表它
  没渲染。对全屏播放器的一切操作与断言只能靠**坐标 + 截图**，坐标写死在 `wm size 1080x2400`
  上。这跟上面 WebF 那条「dump 里明明有那段文字但点它不触发任何事件」正好是反向的同类坑。

`tapx.py` 是比 `runner/ui.py` 宽松的点击工具：按**子串**匹配 `text` + `content-desc`，
`--pick first|last|widest` 选歧义项，`--list` 打印全部可见节点。Flutter 常把邻近文字合并进
同一个语义节点（`Library\nTab 2 of 3`、`Expand player\n演示艺术家`），`ui.py` 的全匹配正则
`^Library$` 因此匹配不到。另外模拟器默认 locale 是 **en-US**，节点文字是英文，中文串只在改过
设备语言时才命中——runner 里一律「英文优先、中文兜底」。

参考案例：全屏播放器的播放速度控件曾是纯文字 `1×`（`887afa1` 起），夹在投屏/音量/队列三个
20px 图标中间视重不匹配，靠这套 runner 的 before/after 对比确认并改回图标。

## Host requirements

Linux with Go, npm, Docker, and `/dev/kvm`. The temporary server listens on
port `58192` (downloader), `58394` (miot), or `58396` (Flutter native UI) by default. The Android device
reaches it through `adb reverse`; override with `SERVER_PORT` when needed.

The default emulator is the official Google API 30 x86_64 container image.
Override it when a locally-built newer image is available:

```bash
EMULATOR_IMAGE=us-docker.pkg.dev/android-emulator-268719/images/30-google-x64:30.1.2 \
  ./scripts/webf-android-verify/run.sh
```

Set `KEEP_RUNNING=1` to keep the server and emulator up after a run. Results are
written to `scripts/webf-android-verify/out/`.

The default emulator image is headless and uses ADB. Screenshots are captured
with `adb exec-out screencap -p` by the runner.
