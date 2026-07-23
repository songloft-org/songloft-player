#!/bin/bash

# Songloft Flutter 前端构建脚本
# 用法：./scripts/build-frontend.sh <platform> [output_dir]
# 平台：web | web-embedded | linux | windows | macos | android | ios | all
#
# 环境变量：
#   DEBUG=1   构建 Web 时输出 source map（main.dart.js.map），方便
#             在 Chrome DevTools 反混淆压缩堆栈，仅本地调试用，会显著增大产物体积
#
# 示例：
#   ./scripts/build-frontend.sh web
#   DEBUG=1 ./scripts/build-frontend.sh web-embedded   # 调试用：带 source map
#   ./scripts/build-frontend.sh linux /tmp/songloft-build
#   ./scripts/build-frontend.sh all ./frontend-build

set -e
set -o pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 获取脚本所在目录（脚本位于 frontend/scripts/ 下）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONTEND_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$FRONTEND_DIR")"

# 参数解析
PLATFORM="${1:-}"
OUTPUT_DIR="${2:-$(dirname "$FRONTEND_DIR")/songloft-player-build}"
case "$OUTPUT_DIR" in
    /*) ;;
    *) OUTPUT_DIR="$(pwd)/$OUTPUT_DIR" ;;
esac

FRONTEND_VERSION_VALUE="${FRONTEND_VERSION:-dev}"
FRONTEND_BUILD_TIME_VALUE="${FRONTEND_BUILD_TIME:-$(date -u '+%Y-%m-%d_%H:%M:%S')}"
FRONTEND_GIT_COMMIT_VALUE="${FRONTEND_GIT_COMMIT:-$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")}"
FLUTTER_VERSION_ARGS=(
    "--dart-define=FRONTEND_VERSION=${FRONTEND_VERSION_VALUE}"
    "--dart-define=FRONTEND_BUILD_TIME=${FRONTEND_BUILD_TIME_VALUE}"
    "--dart-define=FRONTEND_GIT_COMMIT=${FRONTEND_GIT_COMMIT_VALUE}"
)

# 帮助信息
show_help() {
    echo -e "${BLUE}Songloft Flutter 前端构建工具${NC}"
    echo ""
    echo "用法：$0 <platform> [output_dir]"
    echo ""
    echo "平台参数："
    echo "  web            构建 Web 独立部署版（standalone）"
    echo "  web-embedded   构建 Web 嵌入版（embedded，用于 Go 后端嵌入）"
    echo "  linux          构建 Linux 版（bundle + deb/rpm/appimage，需要 fastforge）"
    echo "  windows        构建 Windows 版（bundle + exe/msix/zip，需要 fastforge）"
    echo "  macos          构建 macOS 版（.app + dmg，需要 fastforge，仅 macOS 可用）"
    echo "  android        构建 Android 版（APK + AAB）"
    echo "  ios            构建 iOS 版（.app + ipa，仅 macOS 可用）"
    echo "  all            构建当前系统支持的所有平台"
    echo ""
    echo "可选参数："
    echo "  output_dir     输出目录（默认：\$(pwd)/frontend-build）"
    echo ""
    echo "环境变量："
    echo "  DEBUG=1        Web 构建附带 source map（用于调试反混淆，体积大幅增加）"
    echo ""
    echo "示例："
    echo "  $0 web"
    echo "  DEBUG=1 $0 web-embedded"
    echo "  $0 linux /tmp/songloft-build"
    echo "  $0 all ./frontend-build"
}

# 校验参数
if [ -z "$PLATFORM" ]; then
    show_help
    exit 1
fi

# 日志目录
LOG_DIR="$OUTPUT_DIR/.build_logs"

# 检查 Flutter 是否安装
check_flutter() {
    if ! command -v flutter &>/dev/null; then
        echo -e "${RED}错误：未检测到 Flutter，请先安装 Flutter SDK${NC}"
        exit 1
    fi
}

# 检查 fastforge 是否安装（仅用于提示）
check_fastforge() {
    if ! command -v fastforge &>/dev/null; then
        echo -e "${RED}错误：未检测到 fastforge，请先安装：${NC}"
        echo -e "  dart pub global activate fastforge"
        exit 1
    fi
}

# 准备构建环境
prepare() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Songloft Flutter 前端构建工具${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo -e "${BLUE}构建平台:${NC} $PLATFORM"
    echo -e "${BLUE}输出目录:${NC} $OUTPUT_DIR"
    echo -e "${BLUE}前端目录:${NC} $FRONTEND_DIR"
    echo -e "${BLUE}前端版本:${NC} $FRONTEND_VERSION_VALUE"
    echo -e "${BLUE}前端构建时间:${NC} $FRONTEND_BUILD_TIME_VALUE"
    echo ""

    check_flutter

    echo -e "${BLUE}Flutter 版本:${NC}"
    flutter --version
    echo ""

    mkdir -p "$OUTPUT_DIR"
    mkdir -p "$LOG_DIR"

    echo -e "${BLUE}[准备阶段]${NC} 安装 Flutter 依赖..."
    cd "$FRONTEND_DIR"
    flutter pub get
    echo -e "${GREEN}✓${NC} 依赖安装完成"
    echo ""
}

# 构建函数
build_web() {
    local mode="${1:-standalone}"
    local output_name="web-${mode}"
    local output="$OUTPUT_DIR/$output_name"
    local log_file="$LOG_DIR/${output_name}.log"

    echo -e "${BLUE}[Web]${NC} 开始构建 Web ${mode} 版..."
    cd "$FRONTEND_DIR"

    # 仅在 embedded 模式下检查并下载本地字体文件（standalone 模式使用 CDN 字体，无需本地文件）
    if [ "$mode" = "embedded" ]; then
        local need_download=false
        if [ ! -d "$FRONTEND_DIR/web/fonts/roboto/v32" ] || [ -z "$(ls -A "$FRONTEND_DIR/web/fonts/roboto/v32" 2>/dev/null)" ]; then
            need_download=true
        fi
        # 检查 Noto Sans SC 分片 woff2 是否已下载（CanvasKit fallback 中文字体）
        if [ ! -d "$FRONTEND_DIR/web/fonts/notosanssc/v37" ] || [ -z "$(ls -A "$FRONTEND_DIR/web/fonts/notosanssc/v37" 2>/dev/null)" ]; then
            need_download=true
        fi

        # 验证字体数量与当前 Flutter SDK 一致（防止升级 Flutter 后分片不全）
        if [ "$need_download" = false ]; then
            local font_data_file
            font_data_file="$(flutter --no-version-check sdk-path 2>/dev/null || true)/bin/cache/flutter_web_sdk/lib/_engine/engine/font_fallback_data.dart"
            if [ -f "$font_data_file" ]; then
                local expected_sc actual_sc
                expected_sc=$(grep -c "notosanssc" "$font_data_file" 2>/dev/null || echo "0")
                actual_sc=$(find "$FRONTEND_DIR/web/fonts/notosanssc" -name "*.woff2" 2>/dev/null | wc -l)
                if [ "$expected_sc" -gt 0 ] && [ "$actual_sc" -lt "$expected_sc" ]; then
                    need_download=true
                    echo -e "${YELLOW}⚠ [Web]${NC} 字体分片不完整（有 ${actual_sc}/${expected_sc}），需要补全"
                fi
            fi
        fi

        if [ "$need_download" = true ]; then
            echo -e "${BLUE}[Web]${NC} 下载本地字体文件..."
            if [ -f "$SCRIPT_DIR/download-fonts.sh" ]; then
                bash "$SCRIPT_DIR/download-fonts.sh"
            else
                echo -e "${YELLOW}⚠ [Web]${NC} 字体下载脚本不存在，跳过字体下载"
            fi
        else
            echo -e "${GREEN}✓ [Web]${NC} 本地字体文件已存在且完整"
        fi
    fi

    # DEBUG=1 时启用 source map，便于在 Chrome DevTools 反混淆压缩堆栈（仅本地调试用，会显著增大产物体积）
    local debug_args=""
    if [ "${DEBUG:-}" = "1" ] || [ "${DEBUG:-}" = "true" ]; then
        debug_args="--source-maps"
        echo -e "${YELLOW}⚠ [Web]${NC} DEBUG 模式：启用 source map（产物体积会显著增大，请勿用于发布）"
    fi

    # 构建命令按模式区分是否使用 --no-web-resources-cdn：
    # embedded 模式：使用本地引擎资源（--no-web-resources-cdn），canvaskit 路径由构建标志写入 flutter_build_config
    # standalone 模式：不传此标志，flutter_build_config 会配置从 CDN 加载引擎资源
    if [ "$mode" = "embedded" ]; then
        flutter build web --release ${debug_args} --no-web-resources-cdn --no-wasm-dry-run --dart-define=DEPLOY_MODE=${mode} "${FLUTTER_VERSION_ARGS[@]}" --output="$output" 2>&1 | tee -a "$log_file"
    else
        flutter build web --release ${debug_args} --no-wasm-dry-run --dart-define=DEPLOY_MODE=${mode} "${FLUTTER_VERSION_ARGS[@]}" --output="$output" 2>&1 | tee -a "$log_file"
    fi

    # 生成部署模式配置文件，供 index.html 读取
    echo "var _deployMode = '${mode}';" > "$output/deploy-mode.js"
    echo -e "${GREEN}✓ [Web]${NC} 已生成部署模式配置 (${mode})"

    # 生成前端版本标记，供运行时检测浏览器缓存是否过期（同源自比，绕过缓存拉取）。
    # 在 flutter build 之后写入，故不进入 Service Worker 的 RESOURCES map，SW 会网络透传取到最新值。
    printf '{"version":"%s","buildTime":"%s"}\n' \
        "$FRONTEND_VERSION_VALUE" "$FRONTEND_BUILD_TIME_VALUE" > "$output/version.json"
    echo -e "${GREEN}✓ [Web]${NC} 已生成版本标记 version.json (${FRONTEND_VERSION_VALUE} / ${FRONTEND_BUILD_TIME_VALUE})"

    # canvaskit 清理：仅在 embedded 模式下清理运行时用不到的产物（skwasm、wimp 两个未用
    # 渲染器 + 各处 .symbols 调试符号）。**保留 canvaskit/chromium 变体**：index.html 用
    # canvasKitVariant: "auto"，由引擎按浏览器选变体——Chromium 内核加载 chromium 变体，
    # Firefox/Safari 加载 full；自托管离线部署下 chromium 目录必须在本地，否则 Chrome 会
    # 404 白屏。symbols 只用于崩溃栈反混淆，运行时不加载，chromium 子目录内的也一并清掉。
    # standalone 模式不生成本地 canvaskit，无需清理
    if [ "$mode" = "embedded" ] && [ -d "$output/canvaskit" ]; then
        rm -f "$output/canvaskit"/skwasm* "$output/canvaskit"/wimp* "$output/canvaskit"/*.symbols
        rm -f "$output/canvaskit/chromium"/*.symbols
        echo -e "${GREEN}✓ [Web]${NC} 已清理未使用的渲染器变体与调试符号（保留 chromium 变体供 auto 选择）"
    fi

    # 字体瘦身：移除 pubspec.yaml 声明的 NotoSansSC OTF（8 MB eager loading），
    # CanvasKit 通过 fonts/notosanssc/ 下的 woff2 分片按需加载中文字符，渲染效果一致
    local noto_otf="$output/assets/fonts/NotoSansSC-Regular.otf"
    if [ -f "$noto_otf" ]; then
        rm -f "$noto_otf"
        # 从 FontManifest.json 移除 NotoSansSC 条目，避免 Flutter 尝试加载已删除的文件
        local manifest="$output/assets/FontManifest.json"
        if [ -f "$manifest" ]; then
            python3 -c "
import json, sys
with open('$manifest') as f:
    data = json.load(f)
data = [e for e in data if e.get('family') != 'NotoSansSC']
with open('$manifest', 'w') as f:
    json.dump(data, f)
" 2>/dev/null || echo -e "${YELLOW}⚠ [Web]${NC} FontManifest.json 更新失败，字体文件已删除但清单未同步"
        fi
        echo -e "${GREEN}✓ [Web]${NC} 已移除冗余 NotoSansSC OTF 字体（-8 MB），使用 CanvasKit woff2 按需加载"
    fi

    # 同步清理 Service Worker 的 RESOURCES map，移除已删除文件的条目
    # 避免按需缓存时对不存在的文件发出无效 404 请求
    local sw_file="$output/flutter_service_worker.js"
    if [ -f "$sw_file" ]; then
        python3 -c "
import json, os, re, sys

sw_path = '$sw_file'
output_dir = '$output'

with open(sw_path) as f:
    content = f.read()

match = re.search(r'const RESOURCES = (\{.*?\});', content, re.DOTALL)
if not match:
    sys.exit(0)

resources = json.loads(match.group(1))
cleaned = {k: v for k, v in resources.items()
           if k == '/' or os.path.exists(os.path.join(output_dir, k))}
removed = set(resources.keys()) - set(cleaned.keys())
if removed:
    new_resources = json.dumps(cleaned)
    content = content[:match.start(1)] + new_resources + content[match.end(1):]
    with open(sw_path, 'w') as f:
        f.write(content)
    print(f'Cleaned {len(removed)} stale entries from service worker RESOURCES')
" 2>/dev/null && echo -e "${GREEN}✓ [Web]${NC} 已清理 Service Worker 中的过期资源条目" \
               || echo -e "${YELLOW}⚠ [Web]${NC} Service Worker 清理失败，跳过"
    fi

    # 预压缩可压缩静态资源（brotli + gzip），嵌入 Go 二进制后启动时零开销直出
    if command -v brotli &>/dev/null; then
        local compress_count=0
        local compress_exts="js mjs css html json svg wasm xml txt otf map"
        for ext in $compress_exts; do
            while IFS= read -r -d '' file; do
                brotli -q 11 -f -o "${file}.br" "$file" 2>/dev/null || true
                gzip -9 -c "$file" > "${file}.gz" 2>/dev/null || true
                compress_count=$((compress_count + 1))
            done < <(find "$output" -name "*.${ext}" -size +127c -print0 2>/dev/null) || true
        done
        if [ "$compress_count" -gt 0 ]; then
            echo -e "${GREEN}✓ [Web]${NC} 已预压缩 ${compress_count} 个静态资源（brotli-11 + gzip-9）"
        fi
    else
        echo -e "${YELLOW}⚠ [Web]${NC} 未安装 brotli CLI，跳过预压缩（安装：apt install brotli / brew install brotli）"
    fi

    echo -e "${GREEN}✓ [Web]${NC} Web ${mode} 构建完成 → $output"
}

build_linux() {
    local output="$OUTPUT_DIR/linux"
    local log_file="$LOG_DIR/linux.log"

    echo -e "${BLUE}[Linux]${NC} 开始构建 Linux 版本..."
    cd "$FRONTEND_DIR"
    mkdir -p "$output"

    # 1. 构建 Flutter Linux bundle
    flutter build linux --release "${FLUTTER_VERSION_ARGS[@]}" 2>&1 | tee -a "$log_file"
    cp -r build/linux/x64/release/bundle "$output/"
    echo -e "${GREEN}✓ [Linux]${NC} Linux bundle 构建完成"

    # 2. 使用 fastforge 生成发行版包（deb/rpm/appimage）
    if command -v fastforge &>/dev/null; then
        echo -e "${BLUE}[Linux]${NC} 使用 fastforge 生成发行版包..."

        # DEB 包
        echo -e "${BLUE}[Linux]${NC} 构建 DEB 包..."
        if fastforge package --platform linux --targets deb 2>&1 | tee -a "$log_file"; then
            local deb_file
            deb_file=$(find dist -maxdepth 2 -name "*.deb" -print -quit 2>/dev/null)
            if [ -n "$deb_file" ]; then
                cp "$deb_file" "$output/"
                echo -e "${GREEN}✓ [Linux]${NC} DEB 包构建完成"
            else
                echo -e "${YELLOW}⚠ [Linux]${NC} 未找到 DEB 产物"
            fi
        else
            echo -e "${YELLOW}⚠ [Linux]${NC} DEB 包构建失败，跳过"
        fi

        # RPM 包
        if command -v rpmbuild &>/dev/null; then
            echo -e "${BLUE}[Linux]${NC} 构建 RPM 包..."
            if fastforge package --platform linux --targets rpm 2>&1 | tee -a "$log_file"; then
                local rpm_file
                rpm_file=$(find dist -maxdepth 2 -name "*.rpm" -print -quit 2>/dev/null)
                if [ -n "$rpm_file" ]; then
                    cp "$rpm_file" "$output/"
                    echo -e "${GREEN}✓ [Linux]${NC} RPM 包构建完成"
                else
                    echo -e "${YELLOW}⚠ [Linux]${NC} 未找到 RPM 产物"
                fi
            else
                echo -e "${YELLOW}⚠ [Linux]${NC} RPM 包构建失败，跳过"
            fi
        else
            echo -e "${YELLOW}⚠ [Linux]${NC} 未安装 rpmbuild，跳过 RPM 构建。安装命令：sudo apt install rpm (Debian/Ubuntu) 或 sudo dnf install rpm-build (Fedora)"
        fi

        # AppImage
        if command -v appimagetool &>/dev/null; then
            echo -e "${BLUE}[Linux]${NC} 构建 AppImage..."
            if fastforge package --platform linux --targets appimage 2>&1 | tee -a "$log_file"; then
                local appimage_file
                appimage_file=$(find dist -maxdepth 2 -name "*.AppImage" -print -quit 2>/dev/null)
                if [ -n "$appimage_file" ]; then
                    cp "$appimage_file" "$output/"
                    echo -e "${GREEN}✓ [Linux]${NC} AppImage 构建完成"
                else
                    echo -e "${YELLOW}⚠ [Linux]${NC} 未找到 AppImage 产物"
                fi
            else
                echo -e "${YELLOW}⚠ [Linux]${NC} AppImage 构建失败，跳过"
            fi
        else
            echo -e "${YELLOW}⚠ [Linux]${NC} 未安装 appimagetool，跳过 AppImage 构建。安装方法：从 https://github.com/AppImage/AppImageKit/releases 下载 appimagetool 并添加到 PATH"
        fi
    else
        echo -e "${YELLOW}⚠ [Linux]${NC} 未安装 fastforge，跳过发行版包构建。安装命令：dart pub global activate fastforge"
    fi

    echo -e "${GREEN}✓ [Linux]${NC} Linux 构建完成 → $output"
}

build_windows() {
    local output="$OUTPUT_DIR/windows"
    local log_file="$LOG_DIR/windows.log"

    echo -e "${BLUE}[Windows]${NC} 开始构建 Windows 版本..."
    cd "$FRONTEND_DIR"
    mkdir -p "$output"

    # 1. 构建 Flutter Windows bundle
    flutter build windows --release "${FLUTTER_VERSION_ARGS[@]}" 2>&1 | tee -a "$log_file"
    cp -r build/windows/x64/runner/Release "$output/bundle"
    echo -e "${GREEN}✓ [Windows]${NC} Windows bundle 构建完成"

    # 2. 打包绿色便携 ZIP
    echo -e "${BLUE}[Windows]${NC} 构建绿色便携 ZIP 包..."
    if [ -d "build/windows/x64/runner/Release" ]; then
        cd build/windows/x64/runner/Release
        if zip -r "$output/songloft-windows-portable.zip" . 2>&1 | tee -a "$log_file"; then
            echo -e "${GREEN}✓ [Windows]${NC} 绿色便携 ZIP 包构建完成"
        else
            echo -e "${YELLOW}⚠ [Windows]${NC} ZIP 包构建失败，跳过"
        fi
        cd "$FRONTEND_DIR"
    fi

    # 3. 使用 fastforge 生成安装包（exe/msix）
    if command -v fastforge &>/dev/null; then
        echo -e "${BLUE}[Windows]${NC} 使用 fastforge 生成安装包..."

        # EXE 安装程序
        if command -v iscc &>/dev/null; then
            echo -e "${BLUE}[Windows]${NC} 构建 EXE 安装程序..."
            if fastforge package --platform windows --targets exe 2>&1 | tee -a "$log_file"; then
                local exe_file
                exe_file=$(find dist -maxdepth 2 -name "*.exe" -print -quit 2>/dev/null)
                if [ -n "$exe_file" ]; then
                    cp "$exe_file" "$output/"
                    echo -e "${GREEN}✓ [Windows]${NC} EXE 安装程序构建完成"
                else
                    echo -e "${YELLOW}⚠ [Windows]${NC} 未找到 EXE 产物"
                fi
            else
                echo -e "${YELLOW}⚠ [Windows]${NC} EXE 安装程序构建失败，跳过"
            fi
        else
            echo -e "${YELLOW}⚠ [Windows]${NC} 未安装 Inno Setup，跳过 EXE 构建。安装方法：从 https://jrsoftware.org/isinfo.php 下载 Inno Setup 并将 iscc 添加到 PATH"
        fi

        # MSIX 包
        echo -e "${BLUE}[Windows]${NC} 构建 MSIX 包..."
        if fastforge package --platform windows --targets msix 2>&1 | tee -a "$log_file"; then
            local msix_file
            msix_file=$(find dist -maxdepth 2 -name "*.msix" -print -quit 2>/dev/null)
            if [ -n "$msix_file" ]; then
                cp "$msix_file" "$output/"
                echo -e "${GREEN}✓ [Windows]${NC} MSIX 包构建完成"
            else
                echo -e "${YELLOW}⚠ [Windows]${NC} 未找到 MSIX 产物"
            fi
        else
            echo -e "${YELLOW}⚠ [Windows]${NC} MSIX 包构建失败，跳过"
        fi
    else
        echo -e "${YELLOW}⚠ [Windows]${NC} 未安装 fastforge，跳过安装包构建。安装命令：dart pub global activate fastforge"
    fi

    echo -e "${GREEN}✓ [Windows]${NC} Windows 构建完成 → $output"
}

build_macos() {
    local output="$OUTPUT_DIR/macos"
    local log_file="$LOG_DIR/macos.log"

    if [[ "$(uname)" != "Darwin" ]]; then
        echo -e "${RED}✗ [macOS]${NC} macOS 构建仅在 macOS 系统上支持"
        return 1
    fi

    echo -e "${BLUE}[macOS]${NC} 开始构建 macOS 版本..."
    cd "$FRONTEND_DIR"
    mkdir -p "$output"

    # 1. 构建 Flutter macOS .app
    flutter build macos --release "${FLUTTER_VERSION_ARGS[@]}" 2>&1 | tee -a "$log_file"

    # Xcode 构建阶段会在签名前嵌入 Go 后端二进制。
    local go_server="macos/Runner/songloft-server"
    if [ -f "$go_server" ]; then
        for app_dir in build/macos/Build/Products/Release/*.app; do
            if [ ! -x "$app_dir/Contents/MacOS/songloft-server" ]; then
                echo -e "${RED}✗ [macOS]${NC} Go 后端未打包进 .app"
                return 1
            fi
            codesign --verify --deep --strict --verbose=2 "$app_dir" 2>&1 | tee -a "$log_file"
            echo -e "${GREEN}✓ [macOS]${NC} Go 后端已打包进 .app 并通过签名校验"
        done
    fi

    cp -r build/macos/Build/Products/Release/*.app "$output/"
    echo -e "${GREEN}✓ [macOS]${NC} macOS .app 构建完成"

    # 2. 使用 fastforge 生成 DMG
    if command -v fastforge &>/dev/null; then
        if command -v appdmg &>/dev/null; then
            echo -e "${BLUE}[macOS]${NC} 使用 fastforge 生成 DMG..."

            if fastforge package --platform macos --targets dmg 2>&1 | tee -a "$log_file"; then
                local dmg_file
                dmg_file=$(find dist -maxdepth 2 -name "*.dmg" -print -quit 2>/dev/null)
                if [ -n "$dmg_file" ]; then
                    cp "$dmg_file" "$output/"
                    echo -e "${GREEN}✓ [macOS]${NC} DMG 磁盘映像构建完成"
                else
                    echo -e "${YELLOW}⚠ [macOS]${NC} 未找到 DMG 产物"
                fi
            else
                echo -e "${YELLOW}⚠ [macOS]${NC} DMG 构建失败，跳过"
            fi
        else
            echo -e "${YELLOW}⚠ [macOS]${NC} 未安装 appdmg，跳过 DMG 构建。安装命令：npm install -g appdmg"
        fi
    else
        echo -e "${YELLOW}⚠ [macOS]${NC} 未安装 fastforge，跳过 DMG 构建。安装命令：dart pub global activate fastforge"
    fi

    echo -e "${GREEN}✓ [macOS]${NC} macOS 构建完成 → $output"
}

build_android() {
    local output="$OUTPUT_DIR/android"
    local log_file="$LOG_DIR/android.log"

    echo -e "${BLUE}[Android]${NC} 开始构建 Android 版本..."
    cd "$FRONTEND_DIR"
    mkdir -p "$output"

    # 构建 APK（split-per-abi 生成多架构包）
    flutter build apk --release --split-per-abi "${FLUTTER_VERSION_ARGS[@]}" 2>&1 | tee -a "$log_file"
    # 复制 APK 产物到输出目录
    if [ -d "build/app/outputs/flutter-apk" ]; then
        cp -r build/app/outputs/flutter-apk "$output/apk"
        echo -e "${GREEN}✓ [Android]${NC} APK 构建完成"
    fi

    # 构建 AAB（App Bundle）
    flutter build appbundle --release "${FLUTTER_VERSION_ARGS[@]}" 2>&1 | tee -a "$log_file"
    # 复制 AAB 产物到输出目录
    if [ -d "build/app/outputs/bundle/release" ]; then
        mkdir -p "$output/bundle"
        cp build/app/outputs/bundle/release/*.aab "$output/bundle/"
        echo -e "${GREEN}✓ [Android]${NC} AAB 构建完成"
    fi

    echo -e "${GREEN}✓ [Android]${NC} Android 构建完成 → $output"
}

build_ios() {
    local output="$OUTPUT_DIR/ios"
    local log_file="$LOG_DIR/ios.log"

    if [[ "$(uname)" != "Darwin" ]]; then
        echo -e "${RED}✗ [iOS]${NC} iOS 构建仅在 macOS 系统上支持"
        return 1
    fi

    echo -e "${BLUE}[iOS]${NC} 开始构建 iOS 版本..."
    cd "$FRONTEND_DIR"
    mkdir -p "$output"

    # 1. 构建 Flutter iOS .app
    flutter build ios --release --no-codesign "${FLUTTER_VERSION_ARGS[@]}" 2>&1 | tee -a "$log_file"
    cp -r build/ios/iphoneos/*.app "$output/" 2>/dev/null || true
    echo -e "${GREEN}✓ [iOS]${NC} iOS .app 构建完成"

    # 2. 手动 Payload/zip 方式打包 IPA（无需代码签名）
    if [ -d "build/ios/iphoneos/Runner.app" ]; then
        echo -e "${BLUE}[iOS]${NC} 打包 IPA（无签名）..."
        local ipa_temp="$output/.ipa_temp"
        mkdir -p "$ipa_temp/Payload"
        cp -r build/ios/iphoneos/Runner.app "$ipa_temp/Payload/"
        cd "$ipa_temp"
        zip -r -y "$output/songloft-ios-nosign.ipa" Payload 2>&1 | tee -a "$log_file"
        cd "$FRONTEND_DIR"
        rm -rf "$ipa_temp"
        echo -e "${GREEN}✓ [iOS]${NC} IPA 打包完成 → $output/songloft-ios-nosign.ipa"
    else
        echo -e "${YELLOW}⚠ [iOS]${NC} 未找到 Runner.app，跳过 IPA 打包"
    fi

    echo -e "${GREEN}✓ [iOS]${NC} iOS 构建完成 → $output"
}

build_all() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}[并行构建] 启动所有平台构建...${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    PIDS=()
    PLATFORMS_LAUNCHED=()

    # Web
    echo -e "${YELLOW}→ 启动 Web 构建${NC}"
    (build_web standalone) &
    PIDS+=($!)
    PLATFORMS_LAUNCHED+=("web")

    # Linux
    echo -e "${YELLOW}→ 启动 Linux 构建${NC}"
    (build_linux) &
    PIDS+=($!)
    PLATFORMS_LAUNCHED+=("linux")

    # Windows（仅 Windows 系统）
    if [[ "$(uname -s)" == MINGW* ]] || [[ "$(uname -s)" == CYGWIN* ]] || [[ "$(uname -s)" == MSYS* ]]; then
        echo -e "${YELLOW}→ 启动 Windows 构建${NC}"
        (build_windows) &
        PIDS+=($!)
        PLATFORMS_LAUNCHED+=("windows")
    else
        echo -e "${YELLOW}⚠ 跳过 Windows 构建（需要 Windows 系统）${NC}"
    fi

    # macOS（仅 macOS 系统）
    if [[ "$(uname)" == "Darwin" ]]; then
        echo -e "${YELLOW}→ 启动 macOS 构建${NC}"
        (build_macos) &
        PIDS+=($!)
        PLATFORMS_LAUNCHED+=("macos")

        echo -e "${YELLOW}→ 启动 iOS 构建${NC}"
        (build_ios) &
        PIDS+=($!)
        PLATFORMS_LAUNCHED+=("ios")
    else
        echo -e "${YELLOW}⚠ 跳过 macOS/iOS 构建（需要 macOS 系统）${NC}"
    fi

    # Android（需要 Android SDK）
    if command -v sdkmanager &>/dev/null || [ -n "$ANDROID_HOME" ] || [ -n "$ANDROID_SDK_ROOT" ]; then
        echo -e "${YELLOW}→ 启动 Android 构建${NC}"
        (build_android) &
        PIDS+=($!)
        PLATFORMS_LAUNCHED+=("android")
    else
        echo -e "${YELLOW}⚠ 跳过 Android 构建（未检测到 Android SDK）${NC}"
    fi

    echo ""
    echo -e "${BLUE}等待所有构建进程完成...${NC}"
    echo ""

    FAILED=0
    for pid in "${PIDS[@]}"; do
        if ! wait "$pid"; then
            FAILED=1
        fi
    done

    if [ $FAILED -eq 1 ]; then
        echo -e "${RED}========================================${NC}"
        echo -e "${RED}✗ 部分平台构建失败${NC}"
        echo -e "${RED}========================================${NC}"
        echo ""
        echo -e "${YELLOW}查看各平台构建日志:${NC}"
        for log_file in "$LOG_DIR"/*.log; do
            if [ -s "$log_file" ]; then
                echo "  - $(basename "$log_file" .log): $log_file"
            fi
        done
        exit 1
    fi
}

# 显示构建结果
show_result() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✓ 构建完成！${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${BLUE}输出目录:${NC} $OUTPUT_DIR"
    echo ""

    # 列出产物
    for dir in "$OUTPUT_DIR"/*/; do
        if [ -d "$dir" ] && [ "$(basename "$dir")" != ".build_logs" ]; then
            local platform_name
            platform_name=$(basename "$dir")
            local size
            size=$(du -sh "$dir" 2>/dev/null | cut -f1)
            echo "  ${platform_name}: ${size}"
        fi
    done
    echo ""
}

# 主流程
prepare

case "$PLATFORM" in
    web)
        build_web standalone
        ;;
    web-embedded)
        build_web embedded
        ;;
    linux)
        build_linux
        ;;
    windows)
        build_windows
        ;;
    macos)
        build_macos
        ;;
    android)
        build_android
        ;;
    ios)
        build_ios
        ;;
    all)
        build_all
        ;;
    *)
        echo -e "${RED}错误：未知平台 '$PLATFORM'${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac

show_result
