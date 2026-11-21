#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

echo "=========================================="
echo " 🎙️  Building TypeLess for macOS"
echo "=========================================="

BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="TypeLess"
APP_BUNDLE="$PROJECT_DIR/$APP_NAME.app"
CACHE_DIR="/tmp/swift-cache"

mkdir -p "$CACHE_DIR"
mkdir -p "$BUILD_DIR"

echo "==> Compiling Swift sources..."
swiftc -O \
    -module-cache-path "$CACHE_DIR" \
    src/Config.swift \
    src/AudioRecorder.swift \
    src/WhisperService.swift \
    src/HotkeyManager.swift \
    src/AutoPaster.swift \
    src/FloatingHUD.swift \
    src/SettingsWindow.swift \
    src/AppDelegate.swift \
    src/main.swift \
    -o "$BUILD_DIR/$APP_NAME"

echo "==> Packaging into $APP_NAME.app..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$PROJECT_DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

if [ -f "$PROJECT_DIR/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

echo "==> Code signing application with stable identifier..."
codesign --force --deep -s - --identifier com.vedant.typeless "$APP_BUNDLE" 2>/dev/null || true

echo "=========================================="
echo " ✅ Build complete!"
echo " App location: $APP_BUNDLE"
echo " Run with: ./scripts/run.sh or 'open $APP_NAME.app'"
echo "=========================================="
