#!/usr/bin/env bash
# 将 SwiftPM release 可执行文件打成带图标的 .app。
# 优先 actool → Assets.car（需完整 Xcode）；否则用 iconutil → AppIcon.icns（命令行工具通常即可）。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="Disk Cleaner"
BUNDLE_ID="local.DiskCleaner"
EXEC_NAME="DiskCleanerApp"
APP_DIR="${ROOT}/dist/${EXEC_NAME}.app"
CONTENTS="${APP_DIR}/Contents"
RES="${CONTENTS}/Resources"
MACOS_DIR="${CONTENTS}/MacOS"
BIN_DIR="$(swift build -c release --show-bin-path)"
BIN="${BIN_DIR}/${EXEC_NAME}"
BUNDLE_SRC="${BIN_DIR}/DiskCleanerApp_DiskCleanerApp.bundle"

echo "==> swift build (release)"
swift build -c release

if [[ ! -x "$BIN" ]]; then
  echo "找不到可执行文件: $BIN" >&2
  exit 1
fi
if [[ ! -d "$BUNDLE_SRC" ]]; then
  echo "找不到资源包: $BUNDLE_SRC" >&2
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RES"

ASSETS="${ROOT}/Sources/DiskCleanerApp/Resources/Assets.xcassets"
ICON_SRC="${ASSETS}/AppIcon.appiconset"

if xcrun --find actool &>/dev/null; then
  echo "==> actool → Assets.car"
  xcrun actool \
    "$ASSETS" \
    --compile "$RES" \
    --platform macosx \
    --minimum-deployment-target 13.0 \
    --app-icon AppIcon \
    --output-partial-info-plist "${RES}/actool_partial.plist"
elif xcrun --find iconutil &>/dev/null && [[ -d "$ICON_SRC" ]]; then
  # 说明：这不是报错。actool 只在「完整 Xcode」里；你提供的 AppIcon.appiconset 会原样用来合成 .icns，效果正常。
  echo "==> iconutil → AppIcon.icns（正常流程：当前未指向完整 Xcode，故不用 actool；仍使用工程内 AppIcon 全套 PNG）"
  ICONSET_TMP="${ROOT}/dist/_iconutil_staging/AppIcon.iconset"
  rm -rf "${ROOT}/dist/_iconutil_staging"
  mkdir -p "$ICONSET_TMP"
  shopt -s nullglob
  for f in "${ICON_SRC}"/icon_*.png; do
    cp "$f" "$ICONSET_TMP/"
  done
  shopt -u nullglob
  # 部分工具会导出「扩展名为 .png 实为 JPEG」的文件，iconutil 会失败，先统一转成真 PNG
  for f in "$ICONSET_TMP"/*.png; do
    [[ -e "$f" ]] || continue
    t="${f}.sips.png"
    sips -s format png "$f" --out "$t" &>/dev/null && mv "$t" "$f"
  done
  PNG_COUNT="$(find "$ICONSET_TMP" -name '*.png' | wc -l | tr -d ' ')"
  if [[ "${PNG_COUNT}" -ge 8 ]]; then
    xcrun iconutil -c icns "$ICONSET_TMP" -o "${RES}/AppIcon.icns"
  else
    echo "==> 警告: AppIcon.appiconset 内 PNG 不足，无法生成 .icns" >&2
  fi
else
  echo "==> 警告: 未找到 actool / iconutil，或未找到 AppIcon.appiconset；应用将无自定义图标。" >&2
  echo "    可安装 Xcode 后执行: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
fi

cp "$BIN" "${MACOS_DIR}/${EXEC_NAME}"
chmod +x "${MACOS_DIR}/${EXEC_NAME}"

# SPM 运行时从 Bundle.main.bundleURL（即 .app/Contents）下加载模块资源包
cp -R "$BUNDLE_SRC" "${CONTENTS}/"

PLIST="${CONTENTS}/Info.plist"
plutil -create xml1 "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleDevelopmentRegion string en" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string ${EXEC_NAME}" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string ${BUNDLE_ID}" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleInfoDictionaryVersion string 6.0" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleName string ${EXEC_NAME}" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string ${APP_NAME}" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string APPL" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string 1.0" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string 1" "$PLIST"
if [[ -f "${RES}/Assets.car" ]]; then
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconName string AppIcon" "$PLIST"
elif [[ -f "${RES}/AppIcon.icns" ]]; then
  # 使用 .icns 时键名为 CFBundleIconFile，且不要带扩展名
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$PLIST"
fi
/usr/libexec/PlistBuddy -c "Add :LSMinimumSystemVersion string 13.0" "$PLIST"

if [[ -f "${RES}/actool_partial.plist" ]]; then
  /usr/libexec/PlistBuddy -c "Merge ${RES}/actool_partial.plist :" "$PLIST" 2>/dev/null || true
fi

echo "==> 完成: $APP_DIR"
