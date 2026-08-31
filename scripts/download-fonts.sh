#!/bin/bash

# 下载 CanvasKit 字体 fallback 所需的全部字体文件
#
# 字体列表从当前 Flutter SDK 的 font_fallback_data.dart 动态解析，
# 确保与编译产物使用的引擎版本一致。
#
# 包括：
# - NotoSansSC-Regular.otf：通过 pubspec.yaml 绑定的完整中文字体
# - NotoSansKR-Hangul.otf：谚文子集，解决 CanvasKit 按需加载偶发漏加载问题（#425）
# - font_fallback_data.dart 中注册的所有 Noto Sans 变体 woff2 分片
# - Roboto：英文字体（CanvasKit fallback 机制使用）
#
# CanvasKit 渲染引擎在遇到绑定字体未覆盖的字符时，会从 fontFallbackBaseUrl 按需加载
# Google Fonts 的分片 woff2 文件。embedded 模式下需要预下载这些分片到本地。

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONTEND_DIR="$(dirname "$SCRIPT_DIR")"
FONTS_DIR="$FRONTEND_DIR/web/fonts"
PUBSPEC_FONTS_DIR="$FRONTEND_DIR/fonts"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}下载 CanvasKit 字体文件${NC}"
echo -e "${BLUE}========================================${NC}"

# ========================================
# 从 Flutter SDK 定位字体数据文件
# ========================================

FLUTTER_ROOT="$(flutter --no-version-check sdk-path 2>/dev/null || dirname "$(dirname "$(which flutter)")")"
FONT_DATA_FILE="$FLUTTER_ROOT/bin/cache/flutter_web_sdk/lib/_engine/engine/font_fallback_data.dart"
CANVASKIT_FONTS_FILE="$FLUTTER_ROOT/bin/cache/flutter_web_sdk/lib/_engine/engine/canvaskit/fonts.dart"

if [ ! -f "$FONT_DATA_FILE" ]; then
    echo -e "${RED}错误：找不到 Flutter SDK 的 font_fallback_data.dart${NC}"
    echo -e "${RED}路径：$FONT_DATA_FILE${NC}"
    echo -e "${YELLOW}请确保已运行 'flutter precache' 或 'flutter doctor'${NC}"
    exit 1
fi

echo -e "${BLUE}Flutter SDK:${NC} $FLUTTER_ROOT"
echo -e "${BLUE}字体数据:${NC} $FONT_DATA_FILE"
echo ""

# 从 font_fallback_data.dart 提取所有字体 URL
extract_all_font_urls() {
    grep -oP "'[^']+\.woff2'" "$FONT_DATA_FILE" | tr -d "'"
}

# 从 canvaskit/fonts.dart 提取 Roboto URL
extract_roboto_url() {
    grep "fontFallbackBaseUrl" "$CANVASKIT_FONTS_FILE" 2>/dev/null | grep -oP "(?<=fontFallbackBaseUrl})[^']+" | head -1
}

# ========================================
# [1/5] 下载 NotoSansSC-Regular.otf（pubspec.yaml 绑定字体）
# ========================================

mkdir -p "$PUBSPEC_FONTS_DIR"

echo -e "${BLUE}[1/5] 下载 NotoSansSC-Regular.otf...${NC}"

NOTO_OTF_FILE="$PUBSPEC_FONTS_DIR/NotoSansSC-Regular.otf"
if [ -f "$NOTO_OTF_FILE" ]; then
    echo -e "  [跳过] NotoSansSC-Regular.otf (已存在)"
else
    NOTO_OTF_URL="https://github.com/notofonts/noto-cjk/raw/main/Sans/SubsetOTF/SC/NotoSansSC-Regular.otf"
    echo -e "  [下载] NotoSansSC-Regular.otf"
    if curl -s -f -L -o "$NOTO_OTF_FILE" "$NOTO_OTF_URL" 2>/dev/null; then
        echo -e "    ${GREEN}✓${NC} 成功"
    else
        rm -f "$NOTO_OTF_FILE"
        echo -e "    ${RED}✗${NC} 下载失败"
    fi
fi

# ========================================
# [2/5] 生成 NotoSansKR-Hangul.otf（韩文谚文子集）
# ========================================
#
# CanvasKit 的字体 fallback 机制按需分批加载 woff2 分片，但存在调度缺陷：
# 部分谚文分片在首次渲染时可能被跳过，导致个别韩文字符显示为方框（tofu）。
# 解决方案：从 NotoSansKR SubsetOTF 生成一个仅含谚文的子集（~1.8 MB），
# 通过 pubspec.yaml 绑定为 eager loading 字体，绕过不可靠的按需加载。

echo -e "${BLUE}[2/5] 生成 NotoSansKR-Hangul.otf（韩文谚文子集）...${NC}"

NOTO_KR_HANGUL="$PUBSPEC_FONTS_DIR/NotoSansKR-Hangul.otf"
if [ -f "$NOTO_KR_HANGUL" ]; then
    echo -e "  [跳过] NotoSansKR-Hangul.otf (已存在)"
else
    NOTO_KR_URL="https://github.com/notofonts/noto-cjk/raw/main/Sans/SubsetOTF/KR/NotoSansKR-Regular.otf"
    NOTO_KR_FULL="$PUBSPEC_FONTS_DIR/.NotoSansKR-Regular.otf.tmp"
    echo -e "  [下载] NotoSansKR-Regular.otf (SubsetOTF)"
    if curl -s -f -L -o "$NOTO_KR_FULL" "$NOTO_KR_URL" 2>/dev/null; then
        echo -e "    ${GREEN}✓${NC} 下载成功"
        # 子集范围：谚文音节 + 谚文字母 + 兼容字母 + 扩展 A/B
        if command -v pyftsubset &>/dev/null; then
            echo -e "  [子集] 提取谚文字符 (U+AC00-D7FF, U+1100-11FF, U+3130-318F, U+A960-A97F)..."
            if pyftsubset "$NOTO_KR_FULL" \
                --unicodes="U+AC00-D7FF U+1100-11FF U+3130-318F U+A960-A97F" \
                --output-file="$NOTO_KR_HANGUL" \
                --layout-features='*' \
                --no-subset-tables+=DSIG 2>/dev/null; then
                local_size=$(du -h "$NOTO_KR_HANGUL" | cut -f1)
                echo -e "    ${GREEN}✓${NC} 子集生成成功 (${local_size})"
            else
                echo -e "    ${RED}✗${NC} pyftsubset 子集生成失败"
            fi
        else
            echo -e "    ${RED}✗${NC} 未安装 pyftsubset (fonttools)，无法生成子集"
            echo -e "    安装：pip install fonttools brotli"
        fi
        rm -f "$NOTO_KR_FULL"
    else
        rm -f "$NOTO_KR_FULL"
        echo -e "    ${RED}✗${NC} 下载失败"
    fi
fi

# ========================================
# [3/5] 下载所有 CanvasKit fallback 字体分片
# ========================================

echo -e "${BLUE}[3/5] 下载 CanvasKit fallback 字体分片...${NC}"

ALL_URLS=$(extract_all_font_urls)
if [ -z "$ALL_URLS" ]; then
    echo -e "  ${RED}错误：未在 font_fallback_data.dart 中找到字体 URL${NC}"
    exit 1
fi

TOTAL=$(echo "$ALL_URLS" | wc -l)
echo -e "  共 ${TOTAL} 个分片"

DOWNLOADED=0
SKIPPED=0
FAILED=0
CURRENT_FAMILY=""

while IFS= read -r rel_path; do
    [ -z "$rel_path" ] && continue

    family=$(echo "$rel_path" | cut -d'/' -f1)
    dir_part=$(dirname "$rel_path")

    if [ "$family" != "$CURRENT_FAMILY" ]; then
        if [ -n "$CURRENT_FAMILY" ]; then
            echo ""
        fi
        CURRENT_FAMILY="$family"
        echo -ne "  ${family} "
    fi

    mkdir -p "$FONTS_DIR/$dir_part"
    output_file="$FONTS_DIR/$rel_path"

    if [ -f "$output_file" ]; then
        SKIPPED=$((SKIPPED + 1))
        echo -n "."
    else
        url="https://fonts.gstatic.com/s/${rel_path}"
        if curl -s -f -o "$output_file" "$url" 2>/dev/null; then
            DOWNLOADED=$((DOWNLOADED + 1))
            echo -n "+"
        else
            rm -f "$output_file"
            FAILED=$((FAILED + 1))
            echo -n "x"
        fi
    fi
done <<< "$ALL_URLS"

echo ""
echo -e "  ${GREEN}✓${NC} 完成: 新下载 ${DOWNLOADED}, 已存在 ${SKIPPED}, 失败 ${FAILED}"

if [ "$FAILED" -gt 0 ]; then
    echo -e "  ${YELLOW}⚠${NC} 部分分片下载失败，相关字符可能显示为方框"
fi

# ========================================
# [4/5] 下载 Roboto 字体
# ========================================

echo -e "${BLUE}[4/5] 下载 Roboto 字体...${NC}"

ROBOTO_URL=$(extract_roboto_url)
if [ -n "$ROBOTO_URL" ]; then
    dir_part=$(dirname "$ROBOTO_URL")
    filename=$(basename "$ROBOTO_URL")
    mkdir -p "$FONTS_DIR/$dir_part"
    OUTPUT_FILE="$FONTS_DIR/$ROBOTO_URL"

    if [ -f "$OUTPUT_FILE" ]; then
        echo -e "  [跳过] $filename (已存在)"
    else
        URL="https://fonts.gstatic.com/s/$ROBOTO_URL"
        echo -e "  [下载] $filename"
        if curl -s -f -o "$OUTPUT_FILE" "$URL" 2>/dev/null; then
            echo -e "    ${GREEN}✓${NC} 成功"
        else
            rm -f "$OUTPUT_FILE"
            echo -e "    ${RED}✗${NC} 下载失败"
        fi
    fi
else
    echo -e "  ${YELLOW}⚠${NC} 未找到 Roboto URL，跳过"
fi

# ========================================
# [5/5] 清理不再需要的旧字体文件
# ========================================

echo ""
echo -e "${BLUE}[5/5] 移除 Flutter SDK 不再需要的旧字体文件...${NC}"

EXPECTED_URLS=$(extract_all_font_urls)
EXPECTED_DIRS=$(echo "$EXPECTED_URLS" | xargs -I{} dirname {} | sort -u)
REMOVED_TOTAL=0

while IFS= read -r font_dir; do
    [ -z "$font_dir" ] && continue
    full_dir="$FONTS_DIR/$font_dir"
    [ ! -d "$full_dir" ] && continue

    while IFS= read -r -d '' file; do
        rel_path="${file#$FONTS_DIR/}"
        if ! echo "$EXPECTED_URLS" | grep -qF "$rel_path"; then
            rm -f "$file"
            REMOVED_TOTAL=$((REMOVED_TOTAL + 1))
        fi
    done < <(find "$full_dir" -name "*.woff2" -print0 2>/dev/null)
done <<< "$EXPECTED_DIRS"

if [ "$REMOVED_TOTAL" -gt 0 ]; then
    echo -e "  ${GREEN}✓${NC} 移除 ${REMOVED_TOTAL} 个过期分片"
else
    echo -e "  ${GREEN}✓${NC} 无过期分片"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ 字体下载完成！${NC}"
echo -e "${GREEN}========================================${NC}"
