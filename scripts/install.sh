#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

echo "=========================================="
echo " 🎙️  Installing TypeLess to Applications"
echo "=========================================="

# Build if not already built
if [ ! -d "$PROJECT_DIR/TypeLess.app" ]; then
    echo "==> Building TypeLess.app first..."
    "$PROJECT_DIR/scripts/build.sh"
fi

# Target location
TARGET_DIR="/Applications"
if [ ! -w "$TARGET_DIR" ]; then
    TARGET_DIR="$HOME/Applications"
    mkdir -p "$TARGET_DIR"
fi

echo "==> Closing any running instance..."
pkill -x "TypeLess" 2>/dev/null || true
pkill -x "WisperFlow" 2>/dev/null || true
sleep 0.5

echo "==> Installing to $TARGET_DIR/TypeLess.app..."
rm -rf "$TARGET_DIR/TypeLess.app"
cp -R "$PROJECT_DIR/TypeLess.app" "$TARGET_DIR/TypeLess.app"

echo "==> Registering with macOS Launch Services..."
xattr -cr "$TARGET_DIR/TypeLess.app" 2>/dev/null || true

echo "==> Launching TypeLess from Applications..."
open "$TARGET_DIR/TypeLess.app"

echo "=========================================="
echo " 🎉 TypeLess is installed successfully!"
echo " Location: $TARGET_DIR/TypeLess.app"
echo ""
echo " You will now find TypeLess in:"
echo " - Your Mac Menu Bar (top right 🎙️ icon)"
echo " - Floating on-screen Mic Widget"
echo " - Spotlight Search (press ⌘ Space and type 'TypeLess')"
echo " - Launchpad and Applications folder"
echo "=========================================="
