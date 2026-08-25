#!/usr/bin/env bash
# 驱动 runner-flutter/run-player-speed.sh：起临时后端 + 造测试曲库 + 跑模拟器，
# 截 Flutter 原生播放器界面。SHOT_TAG=before|after 区分改动前后的截图。
#
# BUILD_APK=1 时先重建 APK。**改过 lib/ 下的 Dart 代码就必须重建**，否则装的是旧 APK、
# 截出来的是旧界面——脚本会在 APK 比 lib/ 最新改动旧时打 warn，别忽略它。
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
OUT="$HERE/out/flutter-player"
PLAYER_ROOT=$(cd "$HERE/../.." && pwd)
REPO_ROOT=$(cd "$PLAYER_ROOT/.." && pwd)
SERVER_PORT="${SERVER_PORT:-58396}"
SHOT_TAG="${SHOT_TAG:-current}"
COMPOSE=(docker compose -f "$HERE/compose.yaml")
server_pid=''

[ -e /dev/kvm ] || { echo "[player] /dev/kvm required" >&2; exit 1; }
command -v ffmpeg >/dev/null || {
  echo "[player] ffmpeg required (用来造测试音频)" >&2; exit 1; }

if [ "${BUILD_APK:-}" = 1 ]; then
  echo "[player] building APK"
  "${COMPOSE[@]}" run --rm apk-builder
fi
[ -f "$HERE/out/songloft-x86_64-release.apk" ] || {
  echo "[player] APK not found. Run with BUILD_APK=1 (or run.sh) first." >&2; exit 1; }

# APK 早于代码改动是本脚本最容易踩的坑：界面照旧、结论全错。
newest_dart=$(find "$PLAYER_ROOT/lib" -name '*.dart' -newer "$HERE/out/songloft-x86_64-release.apk" -print -quit 2>/dev/null || true)
if [ -n "$newest_dart" ]; then
  echo "[player] WARNING: APK 比 lib/ 下的 Dart 改动旧（如 ${newest_dart#"$PLAYER_ROOT/"}）。" >&2
  echo "[player]          截出来的是改动前的界面，请用 BUILD_APK=1 重跑。" >&2
fi

mkdir -p "$OUT"

export ADBKEY=$(<"$HOME/.android/adbkey")
export SERVER_PORT

cleanup() {
  if [ "${KEEP_RUNNING:-}" != 1 ]; then
    [ -n "$server_pid" ] && kill "$server_pid" 2>/dev/null && wait "$server_pid" 2>/dev/null || true
    "${COMPOSE[@]}" down --remove-orphans >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

RUNTIME_DIR="$OUT/runtime"
rm -rf "$RUNTIME_DIR/data"
mkdir -p "$RUNTIME_DIR/data" "$RUNTIME_DIR/music"

# 造 3 首正弦波测试曲。注意音乐目录不能落在 /tmp 下：music_path 的默认 exclude_dirs 含
# `tmp`，而 ShouldExcludeDir 是按路径任一层级的目录名匹配的，整个 /tmp/... 会被静默排除
# （扫描"成功完成"但 discovered_files=0，不报错、不打 warn）。
if [ -z "$(ls -A "$RUNTIME_DIR/music" 2>/dev/null)" ]; then
  echo "[player] generating test audio"
  for i in 1 2 3; do
    ffmpeg -y -f lavfi -i "sine=frequency=$((300 * i)):duration=200" \
      -metadata title="测试歌曲 $i" -metadata artist="演示艺术家" -metadata album="演示专辑" \
      -b:a 128k "$RUNTIME_DIR/music/song$i.mp3" >/dev/null 2>&1
  done
fi

echo "[player] building temp server"
(cd "$REPO_ROOT" && go build -tags 'dev lite' -o "$RUNTIME_DIR/songloft-server" .)
"$RUNTIME_DIR/songloft-server" \
  -port "$SERVER_PORT" \
  -db "$RUNTIME_DIR/data/songloft.db" \
  -music "$RUNTIME_DIR/music" \
  >"$OUT/server.log" 2>&1 &
server_pid=$!
for _ in $(seq 1 60); do
  curl -fsS "http://127.0.0.1:${SERVER_PORT}/api/v1/health" >/dev/null 2>&1 && break
  sleep 1
done
curl -fsS "http://127.0.0.1:${SERVER_PORT}/api/v1/health" >/dev/null

echo "[player] scanning library"
token=$(curl -fsS "http://127.0.0.1:${SERVER_PORT}/api/v1/auth/login" \
  -H 'Content-Type: application/json' \
  --data '{"username":"admin","password":"admin"}' | jq -r '.access_token')
# 扫描要重试：健康检查刚通过时 Scanner 还没拿到 -music 写进配置的 music_path，紧跟着发的
# 第一次 /scan 会「成功完成」但一个文件都没导（imported_files=0，不报错、不打 warn）。
count=0
for attempt in 1 2 3; do
  curl -fsS -X POST "http://127.0.0.1:${SERVER_PORT}/api/v1/scan" \
    -H "Authorization: Bearer ${token}" -H 'Content-Type: application/json' \
    --data '{}' >/dev/null
  for _ in $(seq 1 15); do
    count=$(curl -fsS "http://127.0.0.1:${SERVER_PORT}/api/v1/songs?limit=1" \
      -H "Authorization: Bearer ${token}" | jq -r '.total // 0')
    [ "${count:-0}" -gt 0 ] && break
    sleep 1
  done
  [ "${count:-0}" -gt 0 ] && break
  echo "[player] scan attempt $attempt imported nothing, retrying"
  sleep 3
done
[ "${count:-0}" -gt 0 ] || { echo "[player] library is empty after scan" >&2; exit 1; }
echo "[player] library has $count songs"

echo "[player] starting emulator"
"${COMPOSE[@]}" up -d emulator

echo "[player] running verification (tag=$SHOT_TAG)"
"${COMPOSE[@]}" run --rm --no-deps --entrypoint bash \
  -e SERVER_PORT="$SERVER_PORT" -e ADBKEY="$ADBKEY" -e SHOT_TAG="$SHOT_TAG" \
  -v "$HERE/out:/out" -v "$HERE/runner-flutter:/opt/runner-flutter:ro" \
  test-runner /opt/runner-flutter/run-player-speed.sh

echo "[player] done. Screenshots in $OUT/"
