#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

if [ ! -d "$PROJECT_DIR/TypeLess.app" ]; then
    echo "TypeLess.app not found. Building now..."
    "$PROJECT_DIR/scripts/build.sh"
fi

# If already running, terminate old instance
if pgrep -x "TypeLess" > /dev/null; then
    echo "==> Stopping running instance of TypeLess..."
    pkill -x "TypeLess" || true
    sleep 0.5
fi

# Also clean up any lingering old process
pkill -x "WisperFlow" 2>/dev/null || true

echo "==> Launching TypeLess..."
open "$PROJECT_DIR/TypeLess.app"

echo "=========================================="
echo " 🎙️ TypeLess is now active!"
echo " Look for the floating mic widget or the menu bar icon."
echo ""
echo " How to use:"
echo " 1. Click the floating 🎙️ button (or press Option + Space)."
echo " 2. Speak naturally."
echo " 3. Pause for ~1.4s — it automatically finishes and types at your cursor!"
echo "=========================================="
