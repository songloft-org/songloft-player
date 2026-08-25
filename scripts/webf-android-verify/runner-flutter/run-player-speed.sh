#!/usr/bin/env bash
# Flutter 原生播放器界面取证 runner（在 test-runner 容器内执行）。
# 与 runner-miot/ 下那批的区别：那些驱动 miot 插件的 WebF 页面，这个走 Flutter 自己的
# 界面（登录 → 曲库 → 起播 → 展开全屏播放器 → 底部工具行），用来核对图标/布局这类
# 只能眼见为实的东西。
set -euo pipefail

OUT=/out/flutter-player
SERIAL="${ANDROID_SERIAL:-emulator:5555}"
PACKAGE="${APP_PACKAGE:-com.songloft.songloft_flutter}"
SERVER_HOST="${SERVER_HOST:-host.docker.internal}"
SERVER_PORT="${SERVER_PORT:-58396}"
TAG="${SHOT_TAG:-current}"
mkdir -p "$OUT"

if [ -n "${ADBKEY:-}" ]; then
  mkdir -p /root/.android
  printf '%s\n' "$ADBKEY" >/root/.android/adbkey
  chmod 600 /root/.android/adbkey
fi

echo "[player] waiting for emulator $SERIAL"
adb connect "$SERIAL" >/dev/null || true
for _ in $(seq 1 90); do
  adb -s "$SERIAL" get-state 2>/dev/null | grep -q '^device$' && break
  adb connect "$SERIAL" >/dev/null 2>&1 || true
  sleep 2
done
adb -s "$SERIAL" wait-for-device
for _ in $(seq 1 180); do
  [ "$(adb -s "$SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ] && break
  sleep 2
done
# 这条断言不能省：等待循环超时后会直接落下来，紧接着的 `settings put` 在半启动的系统上
# 失败，`set -e` 让整个脚本在一片空输出里退出，极难归因。
if [ "$(adb -s "$SERIAL" shell getprop sys.boot_completed | tr -d '\r')" != 1 ]; then
  echo "[player] emulator did not finish booting" >&2
  exit 1
fi

adb -s "$SERIAL" shell settings put global window_animation_scale 0
adb -s "$SERIAL" shell settings put global transition_animation_scale 0
adb -s "$SERIAL" shell settings put global animator_duration_scale 0
adb -s "$SERIAL" shell settings put system screen_off_timeout 1800000
adb -s "$SERIAL" shell wm size 1080x2400

socat "TCP-LISTEN:${SERVER_PORT},bind=127.0.0.1,reuseaddr,fork" "TCP:${SERVER_HOST}:${SERVER_PORT}" &
forward_pid=$!
trap 'kill "$forward_pid" 2>/dev/null || true' EXIT
adb -s "$SERIAL" reverse "tcp:${SERVER_PORT}" "tcp:${SERVER_PORT}"

echo "[player] installing APK"
# 先卸载再装：apk-builder 是 `--rm` 且 /root/.android 未持久化，每次重建都生成新的 debug
# keystore，于是重装同包名会 INSTALL_FAILED_UPDATE_INCOMPATIBLE（signatures do not match）。
# 只看 `adb install` 的退出码很容易漏掉——它把失败写进 stdout 而非 stderr。
adb -s "$SERIAL" uninstall "$PACKAGE" >/dev/null 2>&1 || true
adb -s "$SERIAL" install -r -g /out/songloft-x86_64-release.apk >"$OUT/install-$TAG.log" 2>&1
grep -q Success "$OUT/install-$TAG.log" || {
  echo "[player] APK install failed:" >&2; cat "$OUT/install-$TAG.log" >&2; exit 1; }
adb -s "$SERIAL" shell pm clear "$PACKAGE" >/dev/null
adb -s "$SERIAL" shell monkey -p "$PACKAGE" 1 >"$OUT/launch-$TAG.log" 2>&1

UI=/opt/webf-android-runner/ui.py
TAPX=/opt/runner-flutter/tapx.py
shot() { adb -s "$SERIAL" exec-out screencap -p >"$OUT/$TAG-$1.png"; echo "[player] shot $1"; }
listnodes() { python3 "$TAPX" "$SERIAL" --list >"$OUT/$TAG-$1-nodes.txt" 2>&1 || true; }
tapx() { python3 "$TAPX" "$SERIAL" "$1" ${2:+--pick "$2"}; }
# 裁出底部两行（控制行 + 工具行）并放大，图标这类差异在整屏缩略图上看不出来
crop_toolbar() {
  python3 - "$OUT/$TAG-$1.png" "$OUT/$TAG-$2.png" <<'PYIMG'
import sys
from PIL import Image
src, dst = sys.argv[1], sys.argv[2]
im = Image.open(src).convert('RGB')
w, h = im.size
box = (0, max(0, h - 620), w, h)
crop = im.crop(box)
crop.resize((int(crop.width * 1.6), int(crop.height * 1.6)), Image.LANCZOS).save(dst)
print('cropped', box)
PYIMG
}
edit_field() {
  python3 "$UI" "$SERIAL" click-nth android.widget.EditText --index "$1"
  sleep 1
  adb -s "$SERIAL" shell input text "$2"
}

echo "[player] logging in"
# standalone APK 的登录页有 3 个输入框：用户名 / 密码 / 服务器地址
python3 "$UI" "$SERIAL" wait-count android.widget.EditText --count 3 --timeout 90
edit_field 0 admin
edit_field 1 admin
edit_field 2 "http://localhost:${SERVER_PORT}"
adb -s "$SERIAL" shell input keyevent 111
sleep 1
# 勾选「我已阅读并同意」：语义树里它是唯一的 checkable 节点，按 content-desc 认不出来时
# 退化为取最窄的那个（复选框比整行文字窄）
python3 - "$SERIAL" <<'PY'
import sys, subprocess, re, xml.etree.ElementTree as ET
serial = sys.argv[1]
subprocess.run(["adb","-s",serial,"shell","uiautomator","dump","/sdcard/lg.xml"],
               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
raw = subprocess.check_output(["adb","-s",serial,"exec-out","cat","/sdcard/lg.xml"])
try: root = ET.fromstring(raw)
except ET.ParseError: sys.exit(0)
def bounds(n):
    m = re.fullmatch(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", n.attrib.get("bounds",""))
    return tuple(map(int, m.groups())) if m else None
boxes = [(bounds(n), n.attrib.get("content-desc","")) for n in root.iter("node")
         if n.attrib.get("checkable") == "true"]
boxes = [b for b in boxes if b[0]]
target = next((b for b, d in boxes
               if any(k in d.lower() for k in ("agree","terms","privacy","同意"))), None)
if target is None and boxes:
    boxes.sort(key=lambda x: x[0][2] - x[0][0])
    target = boxes[0][0]
if target:
    l, t, r, bb = target
    subprocess.run(["adb","-s",serial,"shell","input","tap",str((l+r)//2),str((t+bb)//2)])
PY
sleep 1
# 模拟器默认 locale 是 en-US，界面文字是英文；中文串只作兜底（改过设备语言时才命中）
tapx 'Log in' widest || tapx '登录' widest || true
sleep 8
shot login-done
listnodes login-done

# FRONTEND_VERSION=webf-android-test 恒低于线上版本，首屏必弹「New version required」，
# 不关掉它后面全部点击都会落在遮罩上
tapx 'Later' || tapx '稍后' || true
sleep 3

echo "[player] opening library tab"
tapx 'Library' last || tapx '曲库' last || true
sleep 5
shot library
listnodes library

echo "[player] playing first song"
tapx "${SONG_TITLE:-测试歌曲}" first || true
sleep 7
shot mini
listnodes mini

echo "[player] expanding fullscreen player"
tapx 'Expand player' || tapx "${SONG_TITLE:-测试歌曲}" last || true
sleep 7
shot full
listnodes full
crop_toolbar full toolbar

# 以下坐标写死在 1080x2400（脚本开头已 `wm size` 固定）。
# 为什么不用语义树：全屏播放器与 OverlayEntry 弹出面板都**不进** uiautomator 无障碍树,
# dump 回来的仍是底下那层曲库页 + mini player 的节点（截图却是对的，见
# out/flutter-player/*-full-nodes.txt）。所以对全屏播放器的一切操作与断言都只能靠
# 坐标 + 截图，不能靠 dump——这跟 README 里 WebF 那条「dump 里有但点不到」正好相反。
echo "[player] opening speed panel"
adb -s "$SERIAL" shell input tap 642 2160   # 工具行 spaceEvenly 四项：投屏/音量/速度/队列
sleep 3
shot speed-panel

echo "[player] selecting 1.5x"
adb -s "$SERIAL" shell input tap 564 1882   # 面板锚在按钮上方，自上而下 0.5/0.75/正常/1.25/1.5/2.0
sleep 4
shot full-1p5
crop_toolbar full-1p5 toolbar-1p5

adb -s "$SERIAL" logcat -d >"$OUT/$TAG-logcat.txt" 2>/dev/null || true
echo "[player] done"
ls -la "$OUT"/"$TAG"-*.png
