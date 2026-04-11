#!/usr/bin/env bash
# 从 Branding 同步 AppIcon.appiconset：优先使用各尺寸 PNG；否则用 1024 主图 + sips 缩放。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
B="${ROOT}/Branding"
DST="${ROOT}/Sources/DiskCleanerApp/Resources/Assets.xcassets/AppIcon.appiconset"

mkdir -p "$DST"

from_master_sips() {
  local MASTER="$1"
  resize() {
    local side="$1"
    local out="$2"
    sips -z "$side" "$side" "$MASTER" --out "$out" >/dev/null
  }
  resize 16  "${DST}/icon_16x16.png"
  resize 32  "${DST}/icon_16x16@2x.png"
  resize 32  "${DST}/icon_32x32.png"
  resize 64  "${DST}/icon_32x32@2x.png"
  resize 128 "${DST}/icon_128x128.png"
  resize 256 "${DST}/icon_128x128@2x.png"
  resize 256 "${DST}/icon_256x256.png"
  resize 512 "${DST}/icon_256x256@2x.png"
  resize 512 "${DST}/icon_512x512.png"
  resize 1024 "${DST}/icon_512x512@2x.png"
}

if [[ -f "$B/16.png" && -f "$B/32.png" && -f "$B/64.png" && -f "$B/128.png" && -f "$B/256.png" && -f "$B/512.png" && -f "$B/1024.png" ]]; then
  cp "$B/16.png"   "${DST}/icon_16x16.png"
  cp "$B/32.png"   "${DST}/icon_16x16@2x.png"
  cp "$B/32.png"   "${DST}/icon_32x32.png"
  cp "$B/64.png"   "${DST}/icon_32x32@2x.png"
  cp "$B/128.png"  "${DST}/icon_128x128.png"
  cp "$B/256.png"  "${DST}/icon_128x128@2x.png"
  cp "$B/256.png"  "${DST}/icon_256x256.png"
  cp "$B/512.png"  "${DST}/icon_256x256@2x.png"
  cp "$B/512.png"  "${DST}/icon_512x512.png"
  cp "$B/1024.png" "${DST}/icon_512x512@2x.png"
  echo "==> AppIcon 已从 Branding/16.png … 1024.png 复制 → ${DST}/"
elif [[ -f "$B/1024.png" ]]; then
  from_master_sips "$B/1024.png"
  echo "==> AppIcon 已由 Branding/1024.png 缩放生成 → ${DST}/"
elif [[ -f "$B/icon_1024x1024_master.png" ]]; then
  from_master_sips "$B/icon_1024x1024_master.png"
  echo "==> AppIcon 已由 Branding/icon_1024x1024_master.png 缩放生成 → ${DST}/"
else
  echo "缺少图标源：请提供 Branding/{16,32,64,128,256,512,1024}.png 全套，或至少 Branding/1024.png（或 icon_1024x1024_master.png）。" >&2
  exit 1
fi
