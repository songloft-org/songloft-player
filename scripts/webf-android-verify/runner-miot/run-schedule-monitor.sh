#!/usr/bin/env bash
# 在模拟器里驱动 miot 定时任务编辑器，取「开启/关闭对话监听」这类**全局动作**的证据
# （songloft-org/songloft-plugin-miot#89）。
#
# 这两个动作不绑定设备：executor 走 executeGlobalAction 分支，编辑器应隐藏整个
# 目标设备区，后端也不该再校验设备。#89 的根因是 handler 的 validateTaskParams
# 漏了这两个 case，任务根本存不进去（前端只看到「未知的动作类型: enable_monitor」）。
#
# 取证点（判定在宿主侧 assert_schedule_monitor.py 里做，这里只负责驱动与留证）：
#   1) 默认 action=play_playlist 时，表单底部应有「目标设备 / 所有受管理设备」
#   2) 切到「开启对话监听」后，上面两项与「选择歌单」应全部消失
#   3) 保存应出现「定时任务已保存」toast，列表副标题显示中文 label 而非 enable_monitor
#   4) 任务真的落库（宿主侧 curl /schedules 断言，这是最硬的一条）
set -uo pipefail

SERIAL="${ANDROID_SERIAL:-emulator:5555}"
PACKAGE="${APP_PACKAGE:-com.songloft.songloft_flutter}"
SERVER_PORT="${SERVER_PORT:-58398}"
SERVER_HOST="${SERVER_HOST:-host.docker.internal}"
OUT=/out

if [ -n "${ADBKEY:-}" ]; then
  mkdir -p /root/.android
  printf '%s\n' "$ADBKEY" >/root/.android/adbkey
  chmod 600 /root/.android/adbkey
fi

# 单发 `adb connect` 会和模拟器 adbd 起来的时机赛跑，必须重试到 get-state 变 device，
# 否则 wait-for-device 永久挂住（同 runner/run-android-test.sh）。
echo "[runner] waiting for emulator $SERIAL"
adb connect "$SERIAL" >/dev/null || true
for _ in $(seq 1 90); do
  adb -s "$SERIAL" get-state 2>/dev/null | grep -q '^device$' && break
  adb connect "$SERIAL" >/dev/null 2>&1 || true
  sleep 2
done
adb -s "$SERIAL" wait-for-device
for _ in $(seq 1 90); do
  [ "$(adb -s "$SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ] && break
  sleep 2
done
[ "$(adb -s "$SERIAL" shell getprop sys.boot_completed | tr -d '\r')" = 1 ]

echo "[runner] deterministic display"
adb -s "$SERIAL" shell settings put global window_animation_scale 0
adb -s "$SERIAL" shell settings put global transition_animation_scale 0
adb -s "$SERIAL" shell settings put global animator_duration_scale 0
adb -s "$SERIAL" shell settings put system screen_off_timeout 1800000
adb -s "$SERIAL" shell settings put system system_locales zh-CN || true

socat "TCP-LISTEN:${SERVER_PORT},bind=127.0.0.1,reuseaddr,fork" "TCP:${SERVER_HOST}:${SERVER_PORT}" &
forward_pid=$!
trap 'kill "$forward_pid" 2>/dev/null || true' EXIT
adb -s "$SERIAL" reverse "tcp:${SERVER_PORT}" "tcp:${SERVER_PORT}"

shot() {
  adb -s "$SERIAL" exec-out screencap -p >"$OUT/$1.png" 2>/dev/null || true
  adb -s "$SERIAL" shell uiautomator dump "/sdcard/$1.xml" >/dev/null 2>&1 || true
  adb -s "$SERIAL" exec-out cat "/sdcard/$1.xml" >"$OUT/$1.xml" 2>/dev/null || true
  echo "[runner] captured $1"
}
scroll_down() { for _ in $(seq 1 "$1"); do adb -s "$SERIAL" shell input swipe 540 1400 540 900 250; sleep 1; done; }
scroll_up() { for _ in $(seq 1 "$1"); do adb -s "$SERIAL" shell input swipe 540 700 540 1500 250; sleep 1; done; }
wait_for_text() { python3 /opt/webf-android-runner/ui.py "$SERIAL" wait "$1" --timeout "${2:-30}"; }
click_text() { python3 /opt/webf-android-runner/ui.py "$SERIAL" click "$1"; }
# 滚动到目标真正完整可见再点（折叠线上的薄片点了不生效，见 tapnode.py 注释）
tap_node() { python3 /opt/runner-miot/tapnode.py "$SERIAL" "$1" "${2:-60}" "${3:-10}"; }
edit_field() {
  python3 /opt/webf-android-runner/ui.py "$SERIAL" click-nth android.widget.EditText --index "$1"
  sleep 1
  adb -s "$SERIAL" shell input text "$2"
}

echo "[runner] installing APK"
adb -s "$SERIAL" install -r -g "$OUT/songloft-x86_64-release.apk" >"$OUT/install.log" 2>&1
adb -s "$SERIAL" shell pm clear "$PACKAGE" >/dev/null
adb -s "$SERIAL" shell monkey -p "$PACKAGE" 1 >"$OUT/launch.log" 2>&1

echo "[runner] logging in"
python3 /opt/webf-android-runner/ui.py "$SERIAL" wait-count android.widget.EditText --count 3 --timeout 60
edit_field 0 admin
edit_field 1 admin
edit_field 2 "http://localhost:${SERVER_PORT}"
adb -s "$SERIAL" shell input keyevent 111
sleep 1
python3 - "$SERIAL" <<'PY'
import sys, subprocess, re, xml.etree.ElementTree as ET
serial = sys.argv[1]
subprocess.run(["adb","-s",serial,"shell","uiautomator","dump","/sdcard/lg.xml"],stdout=subprocess.DEVNULL)
raw = subprocess.check_output(["adb","-s",serial,"exec-out","cat","/sdcard/lg.xml"])
try: root = ET.fromstring(raw)
except ET.ParseError: sys.exit(0)
def bounds(n):
    m=re.fullmatch(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", n.attrib.get("bounds",""))
    return tuple(map(int,m.groups())) if m else None
boxes=[(bounds(n), n.attrib.get("content-desc","")) for n in root.iter("node")
       if n.attrib.get("checkable")=="true" and bounds(n)]
target=None
for b,d in boxes:
    if any(k in d.lower() for k in ("agree","terms","privacy")): target=b; break
if target is None and boxes:
    boxes.sort(key=lambda x: x[0][2]-x[0][0]); target=boxes[0][0]
if target:
    l,t,r,bb=target
    subprocess.run(["adb","-s",serial,"shell","input","tap",str((l+r)//2),str((t+bb)//2)])
PY
sleep 1
click_text '^(登录|Log in)$'
if wait_for_text '^(稍后|Later)$' 25; then click_text '^(稍后|Later)$'; sleep 2; fi

echo "[runner] opening miot tab"
wait_for_text '智能音箱' 45
click_text '智能音箱'
sleep 10
shot 00-main

echo "[runner] opening plugin settings"
adb -s "$SERIAL" shell input tap 1010 100
sleep 4
shot 01-settings-root

echo "[runner] === 定时页 ==="
wait_for_text '^定时$' 25 || true
tap_node '^定时$' 40 3 || { echo "[runner] FATAL: 定时 not found"; shot 99-no-timing; exit 1; }
sleep 5
shot 10-schedule-top

click_text '^新建任务$' || { echo "[runner] FATAL: 新建任务 not clickable"; exit 1; }
sleep 3
shot 11-editor-open

# ---------- 1) 默认 action=play_playlist：目标设备区应在 ----------
# uiautomator 只 dump 视口内的节点，编辑器表单整段在折叠线以下，所以必须先滚到底
# 才能取到「目标设备」的证；只看刚打开时那一份 dump 会误判成「没渲染」。
echo "[runner] === 1) 默认动作：目标设备区 ==="
scroll_down 6
shot 12-default-bottom
scroll_down 2
shot 13-default-bottom-2

# ---------- 2) 切到全局动作：目标设备区应整块消失 ----------
echo "[runner] === 2) 切换动作到「开启对话监听」 ==="
scroll_up 8
shot 14-back-to-top
# SlSelect 在 WebF 下是自绘面板（不是原生 <select>）：触发器的 content-desc 就是
# 当前 label「播放歌单」，点开后选项才作为独立节点出现。
if ! tap_node '^播放歌单$' 40 8; then
  echo "[runner] FATAL: 动作下拉触发器不可点"; shot 97-no-trigger; exit 1
fi
sleep 2
shot 15-action-panel-OPEN
if ! tap_node '^开启对话监听$' 40 6; then
  echo "[runner] FATAL: 「开启对话监听」选项不可点"; shot 98-no-option; exit 1
fi
sleep 3
# 同一滚动位置下，动作下方的字段应从「选择歌单」变成执行时间
shot 16-global-action

# 名称框此刻是视口内**第一个** EditText（text 为空）。必须在任何滚动之前填：
# 一旦滚到表单底部，视口里只剩「执行时间」那个 EditText，按固定 index 点就会
# 把任务名打进时间框，保存后只会看到「请输入任务名称」的 toast。
echo "[runner] === 填名称 ==="
python3 /opt/webf-android-runner/ui.py "$SERIAL" click-nth android.widget.EditText --index 0 || true
sleep 1
adb -s "$SERIAL" shell input text "WebF-issue89"
adb -s "$SERIAL" shell input keyevent 111
sleep 1
shot 17-name-filled

scroll_down 6
shot 18-global-bottom

# ---------- 3) 保存：toast + 列表中文 label ----------
echo "[runner] === 3) 保存 ==="
if tap_node '^保存$' 40 8; then
  # notify 只显示 3.2s，dump 要紧跟着做
  adb -s "$SERIAL" shell uiautomator dump /sdcard/19-toast.xml >/dev/null 2>&1 || true
  adb -s "$SERIAL" exec-out cat /sdcard/19-toast.xml >"$OUT/19-toast.xml" 2>/dev/null || true
  adb -s "$SERIAL" exec-out screencap -p >"$OUT/19-toast.png" 2>/dev/null || true
  echo "[runner] captured 19-toast"
  sleep 4
  shot 20-list-after-save
else
  echo "[runner] FATAL: 保存 不可点"; shot 96-no-save
fi

# 插件页的 console.log 会以 `flutter : [plugin][console] ...` 进 logcat
adb -s "$SERIAL" logcat -d 2>/dev/null | grep -a "\[plugin\]\[console\]" >"$OUT/page-console.txt" || true
echo "[runner] collecting logcat"
adb -s "$SERIAL" logcat -d >"$OUT/logcat.txt" 2>/dev/null || true
echo "[runner] ===== DONE ====="
