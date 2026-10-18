#!/bin/bash
# 编译 AudioSwitch.app（菜单栏音频切换工具）
# 用法：bash tools/build-audiobar.sh
set -euo pipefail

ROOT="/Users/geek/Documents/Macintosh"
SRC="$ROOT/AudioSwitch/src"
APP="$ROOT/AudioSwitch/AudioSwitch.app"
ALC="$ROOT/AppleALC/build/Release/alc-verb"

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

[ -x "$ALC" ] || { echo "缺 alc-verb: $ALC"; exit 1; }

echo "== 1. 清理旧产物 =="
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "== 2. 编译 =="
swiftc -O -o "$APP/Contents/MacOS/AudioSwitch" "$SRC/main.swift" -framework Cocoa 2>&1 | head -20

echo "== 3. 组装 bundle =="
cp "$SRC/Info.plist" "$APP/Contents/Info.plist"
cp "$ALC" "$APP/Contents/Resources/alc-verb"
if [ -f "$ROOT/AudioSwitch/icon/AppIcon.icns" ]; then
  cp "$ROOT/AudioSwitch/icon/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
  echo "   已装入 AppIcon.icns"
else
  echo "   未找到 AppIcon.icns（先跑：swift tools/make-icon.swift AudioSwitch/icon && iconutil -c icns AudioSwitch/icon/AudioSwitch.iconset -o AudioSwitch/icon/AppIcon.icns）"
fi
chmod +x "$APP/Contents/MacOS/AudioSwitch" "$APP/Contents/Resources/alc-verb"

echo "== 4. ad-hoc 签名 =="
codesign --force --deep -s - "$APP" 2>&1 | tail -2

echo "== 5. 校验 =="
codesign -dv "$APP" 2>&1 | /usr/bin/grep -E "Identifier|Signature" | head -2
ls -la "$APP/Contents/MacOS/" "$APP/Contents/Resources/"
echo
echo "完成：$APP"
echo "运行：open \"$APP\""
echo "装到应用程序：cp -R \"$APP\" /Applications/"
