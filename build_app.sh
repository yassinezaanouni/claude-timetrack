#!/bin/bash
#
# Builds a macOS .app bundle from the SwiftPM binary and installs it
# to ~/Applications/ClaudeTimeTrack.app. A real bundle (with Info.plist) is
# required so SMAppService can register it for launch-at-login.
#
set -euo pipefail
cd "$(dirname "$0")"

NAME="ClaudeTimeTrack"
APP_DIR="$HOME/Applications/$NAME.app"
BUNDLE_ID="com.yassinezaanouni.claudetimetrack"

echo "[1/4] Compiling release build..."
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/$NAME"
if [[ ! -x "$BIN_PATH" ]]; then
    echo "ERROR: expected binary at $BIN_PATH but did not find it" >&2
    exit 1
fi

echo "[2/4] Assembling .app at $APP_DIR..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"
cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/$NAME"

echo "[3/4] Writing Info.plist..."
cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>$NAME</string>
    <key>CFBundleExecutable</key>
    <string>$NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "[4/4] Ad-hoc codesigning..."
codesign --force --deep --sign - "$APP_DIR" >/dev/null

echo
echo "Done. Installed at $APP_DIR"
echo
echo "Next steps:"
echo "  open \"$APP_DIR\""
echo "  (then click the timer icon in your menu bar)"
