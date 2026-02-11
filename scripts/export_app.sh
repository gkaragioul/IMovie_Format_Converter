#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="VideoConverterOsx"
EXECUTABLE_NAME="VideoConverterOsx"
PRODUCT_EXECUTABLE="VideoConverterOsxApp"
DESKTOP_APP="$HOME/Desktop/${APP_NAME}.app"
BUILD_DIR="$ROOT_DIR/.build/release"
ICON_FILE="$ROOT_DIR/Assets/AppIcon.icns"

cd "$ROOT_DIR"

if [[ ! -f "$ICON_FILE" ]]; then
  "$ROOT_DIR/scripts/build_icon.sh"
fi

swift build -c release --product "$PRODUCT_EXECUTABLE"

rm -rf "$DESKTOP_APP"
mkdir -p "$DESKTOP_APP/Contents/MacOS"
mkdir -p "$DESKTOP_APP/Contents/Resources"

cp -f "$BUILD_DIR/$PRODUCT_EXECUTABLE" "$DESKTOP_APP/Contents/MacOS/$EXECUTABLE_NAME"
chmod +x "$DESKTOP_APP/Contents/MacOS/$EXECUTABLE_NAME"

if command -v ffmpeg >/dev/null 2>&1; then
  cp -f "$(command -v ffmpeg)" "$DESKTOP_APP/Contents/Resources/ffmpeg"
  chmod +x "$DESKTOP_APP/Contents/Resources/ffmpeg"
fi

if command -v ffprobe >/dev/null 2>&1; then
  cp -f "$(command -v ffprobe)" "$DESKTOP_APP/Contents/Resources/ffprobe"
  chmod +x "$DESKTOP_APP/Contents/Resources/ffprobe"
fi

cp -f "$ICON_FILE" "$DESKTOP_APP/Contents/Resources/AppIcon.icns"

cat > "$DESKTOP_APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$EXECUTABLE_NAME</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>com.georgek.videoconverterosx</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.video</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHumanReadableCopyright</key>
  <string>Copyright © 2026</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

touch "$DESKTOP_APP"

echo "Exported app to: $DESKTOP_APP"
