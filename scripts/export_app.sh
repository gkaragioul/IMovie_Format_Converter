#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="iMovie Format Converter"
APP_VERSION="1.1"
EXECUTABLE_NAME="iMovieFormatConverter"
PRODUCT_EXECUTABLE="VideoConverterOsxApp"
DESKTOP_APP="$HOME/Desktop/${APP_NAME}.app"
BUILD_DIR="$ROOT_DIR/.build/release"
ICON_FILE="$ROOT_DIR/Assets/AppIcon.icns"
RESOURCES_DIR="$DESKTOP_APP/Contents/Resources"
BUNDLE_FFMPEG=0

for arg in "$@"; do
  case "$arg" in
    --bundle-ffmpeg)
      BUNDLE_FFMPEG=1
      ;;
    *)
      echo "Unknown option: $arg" >&2
      echo "Usage: scripts/export_app.sh [--bundle-ffmpeg]" >&2
      exit 2
      ;;
  esac
done

cd "$ROOT_DIR"

if [[ ! -f "$ICON_FILE" ]]; then
  "$ROOT_DIR/scripts/build_icon.sh"
fi

swift build -c release --product "$PRODUCT_EXECUTABLE"

rm -rf "$DESKTOP_APP"
mkdir -p "$DESKTOP_APP/Contents/MacOS"
mkdir -p "$RESOURCES_DIR"

cp -f "$BUILD_DIR/$PRODUCT_EXECUTABLE" "$DESKTOP_APP/Contents/MacOS/$EXECUTABLE_NAME"
chmod +x "$DESKTOP_APP/Contents/MacOS/$EXECUTABLE_NAME"

if [[ "$BUNDLE_FFMPEG" -eq 1 ]]; then
  if ! command -v ffmpeg >/dev/null 2>&1 || ! command -v ffprobe >/dev/null 2>&1; then
    echo "ffmpeg and ffprobe must be on PATH when using --bundle-ffmpeg." >&2
    exit 1
  fi

  FFMPEG_PATH="$(command -v ffmpeg)"
  FFPROBE_PATH="$(command -v ffprobe)"
  cp -f "$FFMPEG_PATH" "$RESOURCES_DIR/ffmpeg"
  cp -f "$FFPROBE_PATH" "$RESOURCES_DIR/ffprobe"
  chmod +x "$RESOURCES_DIR/ffmpeg" "$RESOURCES_DIR/ffprobe"
  "$FFMPEG_PATH" -L > "$RESOURCES_DIR/FFmpeg-LICENSE.txt" 2>/dev/null || true
  "$FFMPEG_PATH" -version > "$RESOURCES_DIR/FFmpeg-BUILD-CONFIG.txt" 2>/dev/null || true
  echo "Bundled ffmpeg/ffprobe. Review FFmpeg-LICENSE.txt and FFmpeg-BUILD-CONFIG.txt before redistribution."
else
  echo "Not bundling ffmpeg/ffprobe. Users must install ffmpeg separately, for example with Homebrew."
fi

cp -f "$ICON_FILE" "$RESOURCES_DIR/AppIcon.icns"
cp -f "$ROOT_DIR/LICENSE" "$RESOURCES_DIR/LICENSE.txt"
cp -f "$ROOT_DIR/THIRD_PARTY_NOTICES.md" "$RESOURCES_DIR/THIRD_PARTY_NOTICES.md"

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
  <string>com.georgek.imovieformatconverter</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>2</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.video</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHumanReadableCopyright</key>
  <string>Copyright (c) 2026 georgekgr12</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

touch "$DESKTOP_APP"

echo "Exported app to: $DESKTOP_APP"
