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

## Host requirements

Linux with Go, npm, Docker, and `/dev/kvm`. The temporary server listens on
port `58192` (downloader) or `58394` (miot) by default. The Android device
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
