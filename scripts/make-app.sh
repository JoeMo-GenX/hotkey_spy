#!/usr/bin/env bash
set -euo pipefail

APP="build/HotkeySpy.app"
BIN_NAME="HotkeySpy"

echo "Building release binary…"
swift build -c release --product "$BIN_NAME"

BIN_PATH="$(swift build -c release --product "$BIN_NAME" --show-bin-path)/$BIN_NAME"

echo "Assembling ${APP}…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp "$BIN_PATH" "$APP/Contents/MacOS/$BIN_NAME"
chmod +x "$APP/Contents/MacOS/$BIN_NAME"

# Ad-hoc signature so Accessibility/TCC keeps a stable identity across launches.
codesign --force --deep --sign - "$APP" || echo "codesign (ad-hoc) skipped/failed — app still runs"

echo "Done: $APP"
