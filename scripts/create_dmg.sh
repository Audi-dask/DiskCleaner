#!/usr/bin/env bash
# 先打 .app，再生成可「拖到应用程序」安装的 DMG（压缩只读映像）。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

EXEC_NAME="DiskCleanerApp"
VOL_NAME="Disk Cleaner"
VERSION="1.1.0"
BUILD_DATE=$(date +%Y%m%d)
DMG_NAME="DiskCleaner_v${VERSION}_${BUILD_DATE}_macOS.dmg"
APP_PATH="${ROOT}/dist/${EXEC_NAME}.app"
STAGE="${ROOT}/dist/dmg_staging"

"${ROOT}/scripts/package_mac_app.sh"

if [[ ! -d "$APP_PATH" ]]; then
  echo "缺少: $APP_PATH" >&2
  exit 1
fi

rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$APP_PATH" "$STAGE/"
ln -sf /Applications "$STAGE/Applications"

cat > "${STAGE}/安装说明.txt" << 'EOF'
1. 将左侧的 DiskCleanerApp 拖到右侧「应用程序」文件夹。
2. 在启动台或「应用程序」里打开。

若系统提示「无法打开」或「来自身份不明的开发者」：
打开「终端」，执行（路径按你实际安装位置调整）：

  xattr -cr /Applications/DiskCleanerApp.app

然后再次双击打开。

（未签名分发常见；仅当你信任此软件来源时再执行上述命令。）
EOF

OUT_DMG="${ROOT}/dist/${DMG_NAME}"
rm -f "$OUT_DMG"

echo "==> hdiutil → $OUT_DMG"
hdiutil create \
  -volname "$VOL_NAME" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$OUT_DMG"

echo "==> 完成: $OUT_DMG"
echo "    可把该 DMG 上传网盘或发给他人；对方挂载后拖拽安装即可。"
