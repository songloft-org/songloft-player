#!/usr/bin/env bash
# miot 定时任务「开启/关闭对话监听」（全局动作）的 WebF Android 取证跑法。
# 参考案例 songloft-org/songloft-plugin-miot#89：handler 的 validateTaskParams
# 漏了 enable_monitor / disable_monitor 两个 case，任务存不进去。
#
# 复用 run.sh 已构建的 APK 与 compose 里的模拟器；需要先在 miot 插件目录跑过
# `npm run build`。产物落在 out/schedule-monitor/，判定由 assert_schedule_monitor.py 做。
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
OUT="$HERE/out/schedule-monitor"
REPO_ROOT=$(cd "$HERE/../../.." && pwd)
MIOT_ROOT="$REPO_ROOT/jsplugins-src/songloft-plugin-miot"
SERVER_PORT="${SERVER_PORT:-58398}"
COMPOSE=(docker compose -f "$HERE/compose.yaml")
server_pid=''

[ -e /dev/kvm ] || { echo "[schedule-monitor] /dev/kvm required" >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "[schedule-monitor] Docker unavailable" >&2; exit 1; }
[ -f "$HERE/out/songloft-x86_64-release.apk" ] || {
  echo "[schedule-monitor] APK not found. Run run.sh first to build it." >&2; exit 1
}
[ -f "$MIOT_ROOT/dist/miot.jsplugin.zip" ] || {
  echo "[schedule-monitor] miot.jsplugin.zip not found. Run 'npm run build' in $MIOT_ROOT" >&2; exit 1
}

rm -rf "$OUT"; mkdir -p "$OUT"
cp "$MIOT_ROOT/dist/miot.jsplugin.zip" "$OUT/"
cp "$HERE/out/songloft-x86_64-release.apk" "$OUT/"

export ADBKEY=$(<"$HOME/.android/adbkey")
export SERVER_PORT

cleanup() {
  if [ "${KEEP_RUNNING:-}" != 1 ]; then
    [ -n "$server_pid" ] && kill "$server_pid" 2>/dev/null && wait "$server_pid" 2>/dev/null || true
    "${COMPOSE[@]}" down --remove-orphans >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

RUNTIME="$OUT/runtime"; mkdir -p "$RUNTIME/data" "$RUNTIME/music"
if (echo >/dev/tcp/127.0.0.1/"$SERVER_PORT") 2>/dev/null; then
  echo "[schedule-monitor] port $SERVER_PORT in use" >&2; exit 1
fi

echo "[schedule-monitor] building temp server"
(cd "$REPO_ROOT" && go build -tags 'dev lite' -o "$RUNTIME/songloft-server" .)
"$RUNTIME/songloft-server" -port "$SERVER_PORT" \
  -db "$RUNTIME/data/songloft.db" -music "$RUNTIME/music" \
  >"$OUT/server.log" 2>&1 &
server_pid=$!
for _ in $(seq 1 60); do
  curl -fsS "http://127.0.0.1:${SERVER_PORT}/api/v1/health" >/dev/null 2>&1 && break
  sleep 1
done
curl -fsS "http://127.0.0.1:${SERVER_PORT}/api/v1/health" >/dev/null

token=$(curl -fsS "http://127.0.0.1:${SERVER_PORT}/api/v1/auth/login" \
  -H 'Content-Type: application/json' \
  --data '{"username":"admin","password":"admin"}' | jq -r '.access_token')
AUTH=(-H "Authorization: Bearer ${token}")

# 默认动作 play_playlist 的「歌单」下拉需要有选项，否则第 1 段取不到对照证据。
echo "[schedule-monitor] seeding 3 playlists"
for i in 1 2 3; do
  curl -sS "http://127.0.0.1:${SERVER_PORT}/api/v1/playlists" "${AUTH[@]}" \
    -H 'Content-Type: application/json' \
    --data "$(jq -n --arg n "测试歌单 $i" '{name: $n, type: "normal"}')" -o /dev/null || true
done

echo "[schedule-monitor] starting emulator"
"${COMPOSE[@]}" up -d emulator

echo "[schedule-monitor] uploading miot plugin"
curl -fsS "http://127.0.0.1:${SERVER_PORT}/api/v1/jsplugins/upload" "${AUTH[@]}" \
  -F "file=@${OUT}/miot.jsplugin.zip" >"$OUT/plugin-upload.json"
curl -fsS "http://127.0.0.1:${SERVER_PORT}/api/v1/jsplugins/" "${AUTH[@]}" >"$OUT/plugins.json"
plugin_id=$(jq -r '.plugins[] | select(.entry_path == "miot") | .id' "$OUT/plugins.json")
[ -n "$plugin_id" ] && [ "$plugin_id" != null ] || {
  echo "[schedule-monitor] plugin not installed" >&2; cat "$OUT/plugin-upload.json" >&2; exit 1
}

curl -fsS -X PUT "http://127.0.0.1:${SERVER_PORT}/api/v1/settings/tab-config" "${AUTH[@]}" \
  -H 'Content-Type: application/json' \
  --data "$(jq -n --argjson id "$plugin_id" \
    '{show_library: true, show_playlists: true,
      plugin_tabs: [{plugin_id: $id, entry_path: "miot", name: "智能音箱"}]}')" >"$OUT/tab-config.json"

# 插件的 /playlists 在 server_host 为空或回环时只返回空列表加一句提示、不报错，
# 那样「歌单」下拉一个选项都没有。这里只要求非回环，不要求真的可达。
LAN_IP="${LAN_IP:-$(ip -4 addr show scope global 2>/dev/null | grep -oP 'inet \K[\d.]+' | head -1)}"
LAN_IP="${LAN_IP:-192.168.0.1}"
curl -fsS -X POST "http://127.0.0.1:${SERVER_PORT}/api/v1/jsplugin/miot/config" "${AUTH[@]}" \
  -H 'Content-Type: application/json' \
  --data "$(jq -n --arg h "http://${LAN_IP}:${SERVER_PORT}" '{server_host: $h}')" \
  >"$OUT/plugin-config.json" || true

curl -fsS "http://127.0.0.1:${SERVER_PORT}/api/v1/jsplugin/miot/schedules" "${AUTH[@]}" \
  >"$OUT/schedules-before.json"

echo "[schedule-monitor] running runner"
"${COMPOSE[@]}" run --rm --no-deps --entrypoint bash \
  -e SERVER_PORT="$SERVER_PORT" -e ADBKEY="$ADBKEY" \
  -v "$OUT:/out" -v "$HERE/runner-miot:/opt/runner-miot:ro" \
  test-runner /opt/runner-miot/run-schedule-monitor.sh 2>&1 | tee "$OUT/runner.log"

# 落库断言的数据源：修复前这里会是空列表（POST 被 validateTaskParams 拒掉）。
curl -fsS "http://127.0.0.1:${SERVER_PORT}/api/v1/jsplugin/miot/schedules" "${AUTH[@]}" \
  >"$OUT/schedules-after.json"

echo "[schedule-monitor] asserting"
python3 "$HERE/assert_schedule_monitor.py" --out "$OUT"
echo "[schedule-monitor] done → $OUT"
