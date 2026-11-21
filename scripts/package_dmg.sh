#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

APP_NAME="TypeLess"
ZIP_NAME="TypeLess-macOS.zip"
DMG_NAME="TypeLess-macOS.dmg"
STAGE_DIR="/tmp/typeless_dmg_stage"

echo "=========================================="
echo " 📦 Creating Release Packages for TypeLess"
echo "=========================================="

# 1. Build latest version
"$PROJECT_DIR/scripts/build.sh"

# 2. Create release ZIP (Works everywhere, Gumroad & Lemon Squeezy ready)
echo "==> Creating $ZIP_NAME..."
rm -f "$PROJECT_DIR/$ZIP_NAME"
zip -q -r "$PROJECT_DIR/$ZIP_NAME" "$APP_NAME.app"

# 3. Create release DMG if hdiutil is available
echo "==> Creating $DMG_NAME..."
rm -rf "$STAGE_DIR" "$PROJECT_DIR/$DMG_NAME"
mkdir -p "$STAGE_DIR"
cp -R "$PROJECT_DIR/$APP_NAME.app" "$STAGE_DIR/$APP_NAME.app"
ln -s /Applications "$STAGE_DIR/Applications"

if hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE_DIR" -ov -format UDZO "$PROJECT_DIR/$DMG_NAME" 2>/dev/null; then
    echo "✅ DMG created successfully: $DMG_NAME"
else
    echo "ℹ️  DMG requires direct terminal execution. ZIP archive is ready: $ZIP_NAME"
fi
rm -rf "$STAGE_DIR"

echo "=========================================="
echo " 🎉 Release package ready to sell!"
ls -lh "$PROJECT_DIR/$ZIP_NAME"
echo "=========================================="
