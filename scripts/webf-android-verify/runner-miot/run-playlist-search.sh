#!/usr/bin/env bash
# 在模拟器里驱动 miot 主页的歌单下拉，取搜索框的几何与过滤结果证据
# （songloft-org/songloft#410）。判定一律看 uiautomator dump 的 bounds 与文本，
# 由宿主侧 assert_playlist_search.py 离线做，不靠目视截图。
set -uo pipefail

SERIAL="${ANDROID_SERIAL:-emulator:5555}"
PACKAGE="${APP_PACKAGE:-com.songloft.songloft_flutter}"
SERVER_PORT="${SERVER_PORT:-58399}"
SERVER_HOST="${SERVER_HOST:-host.docker.internal}"
OUT=/out

if [ -n "${ADBKEY:-}" ]; then
  mkdir -p /root/.android
  printf '%s\n' "$ADBKEY" >/root/.android/adbkey
  chmod 600 /root/.android/adbkey
fi

# 单发 `adb connect` 会和模拟器 adbd 起来的时机赛跑，必须重试到 get-state 真的变成
# device，否则 wait-for-device 会永久挂住（同 runner/run-android-test.sh）。
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
[ "$(adb -s "$SERIAL" shell getprop sys.boot_completed | tr -d '\r')" = 1 ] || {
  echo "[runner] emulator never booted" >&2; exit 1; }

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
wait_for_text() { python3 /opt/webf-android-runner/ui.py "$SERIAL" wait "$1" --timeout "${2:-30}"; }
click_text() { python3 /opt/webf-android-runner/ui.py "$SERIAL" click "$1"; }
tap_node() { python3 /opt/runner-miot/tapnode.py "$SERIAL" "$1" "${2:-60}" "${3:-10}"; }
edit_field() {
  python3 /opt/webf-android-runner/ui.py "$SERIAL" click-nth android.widget.EditText --index "$1"
  sleep 1
  adb -s "$SERIAL" shell input text "$2"
}
# 退格 N 次。清空搜索框只能这么做：WebF 的 EditText 不认 `input keyevent 123`（End）
# 之类的组合，而 `input text` 是追加而不是替换。
backspace() { for _ in $(seq 1 "$1"); do adb -s "$SERIAL" shell input keyevent 67; done; }

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
sleep 12
shot 50-main

# ---- 主页歌单下拉：14 项 > SEARCH_MIN_OPTIONS(5)，搜索行必须出现 ----
# 触发器认 U+E5CF（SlSelect trigger 的 Material `expand_more` 图标）——它的 content-desc
# 是「当前 label + 图标」，而选项行只有 label。**不要**改回按「(歌曲数)」结尾去匹配：
# 触发器与选项行的面积只差 0.5%（1014x110 vs 1009x110），而 tapnode.py 是按面积最大挑的，
# 换个分辨率就可能挑中选项行而不是触发器。
# 写成 Python 正则的 \uXXXX 转义，而不是把 U+E5CF 直接嵌进脚本：那是私用区字符，
# 编辑器里不可见、容易被工具悄悄替换成 U+FFFD。tapnode.py 走 re.compile，认这个转义。
TRIGGER_PAT='\ue5cf$'
echo "[runner] === opening playlist dropdown ==="
tap_node "$TRIGGER_PAT" 40 3 || echo "[runner] WARN: dropdown trigger not found"
sleep 3
shot 51-panel-open

# 面板内的搜索框：WebF 不把 aria-label 映射到 content-desc，EditText 上没有任何可
# 匹配的文本，只能按类名 + 位置认。取最靠上的那个 —— 歌曲搜索框在页面更下方。
# 一个 EditText 都没有就说明 cupertino input 在 fixed 面板里没渲染，这正是本脚本
# 要证的核心事项，所以这里只打印、不 exit，让判定脚本给出 FAIL。
echo "[runner] === focus search box (topmost EditText) ==="
python3 - "$SERIAL" <<'PY'
import sys, subprocess, re, xml.etree.ElementTree as ET
serial = sys.argv[1]
subprocess.run(["adb","-s",serial,"shell","uiautomator","dump","/sdcard/sb.xml"],stdout=subprocess.DEVNULL)
raw = subprocess.check_output(["adb","-s",serial,"exec-out","cat","/sdcard/sb.xml"])
try: root = ET.fromstring(raw)
except ET.ParseError: sys.exit(0)
def bounds(n):
    m=re.fullmatch(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", n.attrib.get("bounds",""))
    return tuple(map(int,m.groups())) if m else None
edits=[(bounds(n), n.attrib.get("text","")) for n in root.iter("node")
       if n.attrib.get("class")=="android.widget.EditText" and bounds(n)]
print("EditText nodes:", edits)
if not edits:
    print("NO EDITTEXT — cupertino input did not render inside the fixed panel")
    sys.exit(0)
edits.sort(key=lambda e: e[0][1])
l,t,r,b = edits[0][0]
subprocess.run(["adb","-s",serial,"shell","input","tap",str((l+r)//2),str((t+b)//2)])
print(f"tapped search box at ({(l+r)//2},{(t+b)//2}) size={r-l}x{b-t}")
PY
sleep 2
shot 52-search-focused

# 大小写不敏感：歌单名是「Jazz Night」，这里搜全小写 jazz
echo "[runner] === typing 'jazz' ==="
adb -s "$SERIAL" shell input text "jazz"
sleep 3
shot 53-filtered-jazz

# searchText 判定：所有歌单都是 0 首，label 全带「(0)」。匹配 label 的话输入 0 会
# 命中全部 14 项；只剩「Mix 0」才说明匹配的是纯名称。
echo "[runner] === replacing query with '0' ==="
backspace 6
adb -s "$SERIAL" shell input text "0"
sleep 3
shot 54-filtered-zero

echo "[runner] === no-match state ==="
backspace 3
adb -s "$SERIAL" shell input text "zzzz"
sleep 3
shot 55-no-match

echo "[runner] === pick an option while filtered ==="
backspace 6
adb -s "$SERIAL" shell input text "kpop"
sleep 3
shot 56-filtered-kpop
tap_node '^KPop Hits' 30 2 || echo "[runner] WARN: filtered option not tappable"
sleep 4
shot 57-after-select

# 复位：再打开一次，搜索框必须是空的、列表不能还被上次的关键词过滤着
echo "[runner] === reopen (query must be reset) ==="
tap_node "$TRIGGER_PAT" 40 3 || echo "[runner] WARN: could not reopen dropdown"
sleep 3
shot 58-reopen

# 插件页的 console.log 会以 `flutter : [plugin][console] ...` 进 logcat，
# 临时往前端塞布局探针时直接读这个文件。
adb -s "$SERIAL" logcat -d 2>/dev/null | grep -a "\[plugin\]\[console\]" >"$OUT/page-console.txt" || true
echo "[runner] collecting logcat"
adb -s "$SERIAL" logcat -d >"$OUT/logcat.txt" 2>/dev/null || true
echo "[runner] ===== DONE ====="
