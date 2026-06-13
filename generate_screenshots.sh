#!/bin/bash
# App Store プロモーションスクリーンショット生成スクリプト
# 筋肉ごめん (SorryGains)

set -e

# --- Configuration ---
OUTPUT_DIR="/Users/koya1104/Desktop/01_active/Muscle360/SorryGains/AppStoreScreenshots"
SCREENSHOT_DIR="/Users/koya1104/Desktop/01_active/Muscle360/SorryGains/ref-images/screenshot"
FONT_BOLD="/System/Library/Fonts/ヒラギノ角ゴシック W8.ttc"
FONT_MEDIUM="/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"
FONT_LIGHT="/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc"

# App Store 6.7" display size
CANVAS_W=1290
CANVAS_H=2796

# Colors (from DESIGN.md)
BG_DARK="#0E1320"
BG_MID="#171A22"
AMBER="#D79A2B"
AMBER_LIGHT="#E0A33A"
RED_ACCENT="#C84B5A"
TEXT_WHITE="#FFFFFF"
TEXT_GRAY="#7F8CA3"

# Screenshot file mapping
SS_ANGRY="${SCREENSHOT_DIR}/Simulator Screenshot - iPhone 17 Pro - 2026-04-29 at 18.28.42.png"
SS_SAD="${SCREENSHOT_DIR}/Simulator Screenshot - iPhone 17 Pro - 2026-04-29 at 18.29.01.png"
SS_WARNING="${SCREENSHOT_DIR}/Simulator Screenshot - iPhone 17 Pro - 2026-04-29 at 18.29.16.png"
SS_HAPPY="${SCREENSHOT_DIR}/Simulator Screenshot - iPhone 17 Pro - 2026-04-29 at 18.29.33.png"
SS_SESSION="${SCREENSHOT_DIR}/Simulator Screenshot - iPhone 17 Pro - 2026-04-29 at 18.29.57.png"
SS_SAGE="${SCREENSHOT_DIR}/Simulator Screenshot - iPhone 17 Pro - 2026-04-29 at 18.30.02.png"
SS_ENTRY="${SCREENSHOT_DIR}/Simulator Screenshot - iPhone 17 Pro - 2026-04-29 at 18.30.21.png"

# --- Helper: Create dark gradient background ---
create_background() {
    local output="$1"
    magick -size ${CANVAS_W}x${CANVAS_H} \
        gradient:"#1A1F2E"-"${BG_DARK}" \
        "$output"
}

# --- Helper: Add subtle radial glow ---
add_glow() {
    local input="$1"
    local output="$2"
    local color="${3:-#D79A2B}"
    local cy="${4:-1400}"

    magick "$input" \
        \( -size ${CANVAS_W}x${CANVAS_H} xc:none \
           -fill "${color}18" \
           -draw "circle 645,${cy} 645,$((cy + 500))" \) \
        -composite "$output"
}

# --- Helper: Prepare screenshot with rounded corners and shadow ---
prepare_screenshot() {
    local input="$1"
    local output="$2"
    local target_w="${3:-1050}"
    local corner_radius="${4:-40}"

    # Resize screenshot
    magick "$input" -resize "${target_w}x" /tmp/ss_resized.png

    # Get resized dimensions
    local w h
    w=$(magick identify -format "%w" /tmp/ss_resized.png)
    h=$(magick identify -format "%h" /tmp/ss_resized.png)

    # Create rounded corner mask
    magick -size "${w}x${h}" xc:none \
        -fill white \
        -draw "roundrectangle 0,0 $((w-1)),$((h-1)) ${corner_radius},${corner_radius}" \
        /tmp/ss_mask.png

    # Apply mask for rounded corners
    magick /tmp/ss_resized.png /tmp/ss_mask.png \
        -alpha off -compose CopyOpacity -composite \
        /tmp/ss_rounded.png

    # Add subtle shadow
    magick /tmp/ss_rounded.png \
        \( +clone -background "#00000066" -shadow 60x20+0+15 \) \
        +swap -background none -layers merge +repage \
        "$output"
}

# --- Helper: Generate a promotional screenshot ---
generate_promo() {
    local screenshot="$1"
    local headline="$2"
    local subline="$3"
    local output="$4"
    local accent_color="${5:-$AMBER}"
    local ss_width="${6:-1050}"
    local ss_y_offset="${7:-0}"

    echo "Generating: $(basename "$output")"

    # 1. Create background
    create_background /tmp/bg.png

    # 2. Add glow
    add_glow /tmp/bg.png /tmp/bg_glow.png "${accent_color}" 1600

    # 3. Add a subtle top gradient overlay for text readability
    magick /tmp/bg_glow.png \
        \( -size ${CANVAS_W}x600 gradient:"#0E132088"-"#0E132000" \) \
        -gravity north -composite \
        /tmp/bg_final.png

    # 4. Prepare screenshot
    prepare_screenshot "$screenshot" /tmp/ss_final.png "$ss_width"

    # Get screenshot dimensions
    local ss_w ss_h
    ss_w=$(magick identify -format "%w" /tmp/ss_final.png)
    ss_h=$(magick identify -format "%h" /tmp/ss_final.png)

    # 5. Calculate layout positions
    # Text area: top ~15% of canvas
    # Screenshot: centered below text, with some bottom margin
    local text_y=280
    local ss_x=$(( (CANVAS_W - ss_w) / 2 ))
    local ss_y

    if [ "$ss_y_offset" -ne 0 ]; then
        ss_y=$ss_y_offset
    else
        # Position screenshot so it's vertically centered in remaining space
        local remaining_top=520
        local remaining_h=$((CANVAS_H - remaining_top - 80))
        ss_y=$(( remaining_top + (remaining_h - ss_h) / 2 ))
        # Ensure it doesn't go above text area
        if [ "$ss_y" -lt 500 ]; then
            ss_y=500
        fi
    fi

    # 6. Composite screenshot onto background
    magick /tmp/bg_final.png \
        /tmp/ss_final.png -geometry "+${ss_x}+${ss_y}" -composite \
        /tmp/composed.png

    # 7. Add headline text
    magick /tmp/composed.png \
        -font "$FONT_BOLD" \
        -pointsize 88 \
        -fill "$TEXT_WHITE" \
        -gravity north \
        -annotate +0+${text_y} "$headline" \
        /tmp/with_headline.png

    # 8. Add subline text (if provided)
    if [ -n "$subline" ]; then
        local sub_y=$((text_y + 120))
        magick /tmp/with_headline.png \
            -font "$FONT_MEDIUM" \
            -pointsize 48 \
            -fill "${accent_color}" \
            -gravity north \
            -annotate +0+${sub_y} "$subline" \
            "$output"
    else
        cp /tmp/with_headline.png "$output"
    fi

    # 9. Add thin accent line under headline
    local line_y=$((text_y + 110))
    if [ -n "$subline" ]; then
        line_y=$((text_y + 180))
    fi
    magick "$output" \
        -fill "${accent_color}" \
        -draw "rectangle $((CANVAS_W/2 - 60)),${line_y} $((CANVAS_W/2 + 60)),$((line_y + 4))" \
        "$output"

    echo "  -> Done: $(basename "$output")"
}


# ===== GENERATE ALL 6 SCREENSHOTS =====

echo ""
echo "=========================================="
echo "  筋肉ごめん App Store Screenshots"
echo "=========================================="
echo ""

# Screenshot 1: Hero - Angry character (most attention-grabbing)
generate_promo \
    "$SS_ANGRY" \
    "飲んだら、筋肉に謝れ。" \
    "怒りレベルMAX — 影響スコア 100" \
    "${OUTPUT_DIR}/01_hero_angry.png" \
    "$RED_ACCENT"

# Screenshot 2: Happy character (the positive contrast)
generate_promo \
    "$SS_HAPPY" \
    "控えめなら、ご機嫌。" \
    "1杯なら筋肉も許してくれる" \
    "${OUTPUT_DIR}/02_happy.png" \
    "#4CAF50"

# Screenshot 3: Drink entry screen
generate_promo \
    "$SS_ENTRY" \
    "記録はたった10秒。" \
    "種類・量・度数を選ぶだけ" \
    "${OUTPUT_DIR}/03_entry.png" \
    "$AMBER"

# Screenshot 4: Anger levels / Warning character
generate_promo \
    "$SS_WARNING" \
    "怒りレベルで本音がわかる" \
    "5段階で筋肉の気持ちを可視化" \
    "${OUTPUT_DIR}/04_anger_levels.png" \
    "$AMBER_LIGHT"

# Screenshot 5: Sage advice screen
generate_promo \
    "$SS_SAGE" \
    "筋トレ仙人の一言" \
    "厳しくも温かいアドバイス" \
    "${OUTPUT_DIR}/05_sage.png" \
    "$AMBER"

# Screenshot 6: Drinking session mode
generate_promo \
    "$SS_SESSION" \
    "飲み会を丸ごと記録" \
    "経過時間・杯数をリアルタイム表示" \
    "${OUTPUT_DIR}/06_session.png" \
    "$RED_ACCENT"


echo ""
echo "=========================================="
echo "  All 6 screenshots generated!"
echo "  Output: ${OUTPUT_DIR}"
echo "=========================================="
echo ""
ls -la "${OUTPUT_DIR}"/*.png
