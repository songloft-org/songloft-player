#!/usr/bin/env bash
# miot 歌单下拉搜索框的 WebF Android 取证跑法。
# 参考案例 songloft-org/songloft#410：旧版原生前端的歌单弹层顶部有「搜索歌单」输入框，
# 重构成 WebF/Vue 后换成了通用 SlSelect，过滤功能整个丢了。
#
# 真正只有真机 WebF 能回答的问题：`flutter-cupertino-input`（SlInput 在 useNativeUI
# 下渲染的原生元素）放进 `position: fixed` 的下拉面板里，到底渲不渲染、能不能聚焦
# 输入。浏览器里 useNativeUI 恒为 false、搜索框会退化成普通 <input>，验不到这一层。
#
# 复用 run.sh 已构建的 APK 与 compose 里的模拟器；需要先在 miot 插件目录跑过
# `npm run build`。产物落在 out/playlist-search/，判定由 assert_playlist_search.py 做
# （PASS/FAIL + 非零退出码，不需要人工看图）。
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
OUT="$HERE/out/playlist-search"
REPO_ROOT=$(cd "$HERE/../../.." && pwd)
MIOT_ROOT="$REPO_ROOT/jsplugins-src/songloft-plugin-miot"
SERVER_PORT="${SERVER_PORT:-58399}"
COMPOSE=(docker compose -f "$HERE/compose.yaml")
server_pid=''

[ -e /dev/kvm ] || { echo "[playlist-search] /dev/kvm required" >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "[playlist-search] Docker unavailable" >&2; exit 1; }
[ -f "$HERE/out/songloft-x86_64-release.apk" ] || {
  echo "[playlist-search] APK not found. Run run.sh first to build it." >&2; exit 1
}
[ -f "$MIOT_ROOT/dist/miot.jsplugin.zip" ] || {
  echo "[playlist-search] miot.jsplugin.zip not found. Run 'npm run build' in $MIOT_ROOT" >&2; exit 1
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
  echo "[playlist-search] port $SERVER_PORT in use" >&2; exit 1
fi

echo "[playlist-search] building temp server"
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

# 歌单名有三处刻意设计，改动前先读完：
#   * 必须凑够 >5 个（SEARCH_MIN_OPTIONS），否则搜索框按设计根本不显示；
#     迁移预置的「收藏」「电台收藏」也算在内，所以这里 12 个 → 一共 14 项。
#   * 关键词必须是 ASCII：`adb shell input text` 打不进中文，中文歌单名只能用来
#     凑数、不能用来搜。Jazz Night / KPop Hits 就是给搜索用的。
#   * 「Mix 0」是 searchText 判定的载体：这些歌单都是 0 首歌，label 全长成
#     「xxx (0)」。如果过滤匹配的是 label 而不是纯名称，输入 0 会命中全部 14 项；
#     只剩「Mix 0」才说明 SelectOption.searchText 真的生效了。
echo "[playlist-search] seeding 12 playlists"
for n in "Jazz Night" "KPop Hits" "Rock Classic" "Mix 0" \
         "周杰伦精选" "周杰伦经典" "华语流行" "欧美金曲" \
         "古典音乐" "粤语经典" "日语动漫" "睡前轻音乐"; do
  curl -sS "http://127.0.0.1:${SERVER_PORT}/api/v1/playlists" "${AUTH[@]}" \
    -H 'Content-Type: application/json' \
    --data "$(jq -n --arg n "$n" '{name: $n, type: "normal"}')" -o /dev/null || true
done

echo "[playlist-search] starting emulator"
"${COMPOSE[@]}" up -d emulator

echo "[playlist-search] uploading miot plugin"
curl -fsS "http://127.0.0.1:${SERVER_PORT}/api/v1/jsplugins/upload" "${AUTH[@]}" \
  -F "file=@${OUT}/miot.jsplugin.zip" >"$OUT/plugin-upload.json"
curl -fsS "http://127.0.0.1:${SERVER_PORT}/api/v1/jsplugins/" "${AUTH[@]}" >"$OUT/plugins.json"
plugin_id=$(jq -r '.plugins[] | select(.entry_path == "miot") | .id' "$OUT/plugins.json")
[ -n "$plugin_id" ] && [ "$plugin_id" != null ] || {
  echo "[playlist-search] plugin not installed" >&2; cat "$OUT/plugin-upload.json" >&2; exit 1
}

# 这一步漏了的话客户端底部不会出现「智能音箱」tab，runner 会一路停在主程序首页，
# 而 wait_for_text 失败并不中断脚本 —— 后面每一步都在给主程序的界面拍照，
# 判定全线失败却看不出原因。实测踩过，别删。
curl -fsS -X PUT "http://127.0.0.1:${SERVER_PORT}/api/v1/settings/tab-config" "${AUTH[@]}" \
  -H 'Content-Type: application/json' \
  --data "$(jq -n --argjson id "$plugin_id" \
    '{show_library: true, show_playlists: true,
      plugin_tabs: [{plugin_id: $id, entry_path: "miot", name: "智能音箱"}]}')" >"$OUT/tab-config.json"

# 插件的 /playlists 在 server_host 为空或回环时只返回空列表加一句提示、不报错，
# 那样下拉一个选项都没有、整套判定静默取不到证。只要求非回环，不要求真的可达。
LAN_IP="${LAN_IP:-$(ip -4 addr show scope global 2>/dev/null | grep -oP 'inet \K[\d.]+' | head -1)}"
LAN_IP="${LAN_IP:-192.168.0.1}"
curl -fsS -X POST "http://127.0.0.1:${SERVER_PORT}/api/v1/jsplugin/miot/config" "${AUTH[@]}" \
  -H 'Content-Type: application/json' \
  --data "$(jq -n --arg h "http://${LAN_IP}:${SERVER_PORT}" '{server_host: $h}')" \
  >"$OUT/plugin-config.json" || true
echo -n "[playlist-search] plugin sees playlists: "
curl -fsS "http://127.0.0.1:${SERVER_PORT}/api/v1/jsplugin/miot/playlists" "${AUTH[@]}" \
  | jq -r '.data | length'

echo "[playlist-search] running runner"
"${COMPOSE[@]}" run --rm --no-deps --entrypoint bash \
  -e SERVER_PORT="$SERVER_PORT" -e ADBKEY="$ADBKEY" \
  -v "$OUT:/out" -v "$HERE/runner-miot:/opt/runner-miot:ro" \
  test-runner /opt/runner-miot/run-playlist-search.sh 2>&1 | tee "$OUT/runner.log"

echo "[playlist-search] asserting"
python3 "$HERE/assert_playlist_search.py" --out "$OUT"
echo "[playlist-search] done → $OUT"
