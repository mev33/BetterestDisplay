#!/bin/bash
# Builds the full BetterestDisplay.app bundle with swiftc and installs it. Offline: no
# downloads, no notarization, no publishing (this fork has no updater).
#
# Usage:
#   ./scripts/build-app.sh                 # build + sign + install to /Applications/BetterestDisplay.app
#   BD_APP=~/Applications/BetterestDisplay.app ./scripts/build-app.sh
#   BD_SIGN_ID="BetterestDisplay Dev" ./scripts/build-app.sh
#   BD_INSTALL=0 ./scripts/build-app.sh # build into ./build/BetterestDisplay.app only
#
# Signing: a stable self-signed identity keeps the Accessibility grant (brightness
# keys) across rebuilds. Create it once, offline: Keychain Access > Certificate
# Assistant > Create a Certificate, name "BetterestDisplay Dev", Self Signed Root, type Code
# Signing. Without it the build is signed ad hoc and Accessibility resets each build.
#
# Builds arm64 only (this fork targets Apple Silicon). Shortcuts actions metadata
# needs full Xcode; without it the app builds and runs, but Shortcuts won't list
# its actions.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$ROOT"
BUILD="$ROOT/build"
STAGE="$BUILD/BetterestDisplay.app"
DEST="${BD_APP:-/Applications/BetterestDisplay.app}"
INSTALL="${BD_INSTALL:-1}"

field() { grep -E "^[[:space:]]*$1:" project.yml | head -1 | sed -E 's/^[^:]*:[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/'; }
VERSION="$(field MARKETING_VERSION)"
BUILD_NUMBER="$(field CURRENT_PROJECT_VERSION)"
BD_BUNDLE_ID="$(field PRODUCT_BUNDLE_IDENTIFIER)"
export BD_BUNDLE_ID

rm -rf "$BUILD"; mkdir -p "$STAGE/Contents/MacOS" "$STAGE/Contents/Resources"

source "$ROOT/scripts/appintents.sh"
SWIFTC=(swiftc)
AI_FLAGS=""
if appintents_init "$BUILD/appintents"; then
    SWIFTC=(env DEVELOPER_DIR="$AI_DEV" xcrun swiftc)
    AI_FLAGS=$(appintents_swiftc_flags arm64)
fi

echo "==> Compiling BetterestDisplay $VERSION ($BUILD_NUMBER), $BD_BUNDLE_ID…"
SRC=$(find Crisp -name '*.swift')
# shellcheck disable=SC2086 # AI_FLAGS and SRC are lists
"${SWIFTC[@]}" -O -swift-version 6 -parse-as-library -target arm64-apple-macos14.0 $AI_FLAGS \
    -import-objc-header Crisp/Crisp-Bridging-Header.h \
    -framework AppKit -framework SwiftUI -framework IOKit -framework CoreAudio \
    -Xlinker -U -Xlinker _SLSConfigureDisplayEnabled \
    -Xlinker -U -Xlinker _SLSGetDisplayList \
    -Xlinker -U -Xlinker _SLSSetDisplayRotation \
    $SRC -o "$STAGE/Contents/MacOS/BetterestDisplay"

if [ -n "$AI_DEV" ]; then
    echo "==> Writing Shortcuts actions metadata…"
    appintents_metadata "$STAGE/Contents/MacOS/BetterestDisplay" "$STAGE/Contents/Resources" arm64
else
    echo "==> Shortcuts actions metadata skipped (needs full Xcode)"
fi

# Same source list as the bdctl target in project.yml. No -parse-as-library:
# main.swift is top-level code.
echo "==> Compiling bdctl…"
swiftc -O -swift-version 6 -target arm64-apple-macos14.0 \
    Sources/bdctl/*.swift Crisp/Models/CrispControlModel.swift Crisp/Models/BrightnessKeySteps.swift \
    -o "$STAGE/Contents/MacOS/bdctl"

echo "==> Building app icon…"
ICONSET="$BUILD/AppIcon.iconset"; mkdir -p "$ICONSET"
ICONS="Crisp/Assets.xcassets/AppIcon.appiconset"
cp "$ICONS/icon_16.png"   "$ICONSET/icon_16x16.png"
cp "$ICONS/icon_32.png"   "$ICONSET/icon_16x16@2x.png"
cp "$ICONS/icon_32.png"   "$ICONSET/icon_32x32.png"
cp "$ICONS/icon_64.png"   "$ICONSET/icon_32x32@2x.png"
cp "$ICONS/icon_128.png"  "$ICONSET/icon_128x128.png"
cp "$ICONS/icon_256.png"  "$ICONSET/icon_128x128@2x.png"
cp "$ICONS/icon_256.png"  "$ICONSET/icon_256x256.png"
cp "$ICONS/icon_512.png"  "$ICONSET/icon_256x256@2x.png"
cp "$ICONS/icon_512.png"  "$ICONSET/icon_512x512.png"
cp "$ICONS/icon_1024.png" "$ICONSET/icon_512x512@2x.png"
iconutil -c icns "$ICONSET" -o "$STAGE/Contents/Resources/AppIcon.icns"

echo "==> Compiling localizations…"
LANGS=$(python3 "$ROOT/scripts/xcstrings-compile.py" Crisp/Resources/Localizable.xcstrings "$STAGE/Contents/Resources")
LOC_XML=""; for l in $LANGS; do LOC_XML="${LOC_XML}<string>${l}</string>"; done

echo "==> Writing Info.plist…"
printf 'APPL????' > "$STAGE/Contents/PkgInfo"
# No SU* (Sparkle) keys: this build has no updater.
cat > "$STAGE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key><string>BetterestDisplay</string>
	<key>CFBundleDisplayName</key><string>BetterestDisplay</string>
	<key>CFBundleIdentifier</key><string>${BD_BUNDLE_ID}</string>
	<key>CFBundleExecutable</key><string>BetterestDisplay</string>
	<key>CFBundleIconFile</key><string>AppIcon</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
	<key>CFBundleDevelopmentRegion</key><string>en</string>
	<key>CFBundleLocalizations</key><array>${LOC_XML}</array>
	<key>CFBundleShortVersionString</key><string>${VERSION}</string>
	<key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
	<key>LSMinimumSystemVersion</key><string>14.0</string>
	<key>LSUIElement</key><true/>
	<key>NSHumanReadableCopyright</key><string>BetterestDisplay - an offline fork of Crisp, free &amp; open source</string>
	<key>NSAppleEventsUsageDescription</key><string>BetterestDisplay uses System Events to switch Dark Mode with the system's animated transition.</string>
	<key>CFBundleSupportedPlatforms</key><array><string>MacOSX</string></array>
</dict>
</plist>
PLIST

# Inside-out, no --deep (it would stamp the app's entitlements onto bdctl).
# Hardened runtime on every build, not only releases.
xattr -cr "$STAGE"
SIGN_ID="${BD_SIGN_ID:-BetterestDisplay Dev}"
if security find-identity -p codesigning 2>/dev/null | grep -qF "$SIGN_ID"; then
    echo "==> Signing with identity: $SIGN_ID (hardened runtime)"
else
    echo "==> Signing ad hoc ($SIGN_ID not found; Accessibility will reset each build)"
    SIGN_ID="-"
fi
codesign --force --options runtime --sign "$SIGN_ID" "$STAGE/Contents/MacOS/bdctl"
codesign --force --options runtime --sign "$SIGN_ID" --entitlements Crisp/Crisp.entitlements "$STAGE"
codesign --verify --strict "$STAGE"

./scripts/check-no-network.sh --binary "$STAGE"

if [ "$INSTALL" != 1 ]; then
    echo "==> Built $STAGE (not installed: BD_INSTALL=$INSTALL)"
    exit 0
fi

# Refuse to replace a bundle that isn't this app (for example an upstream Crisp
# install, which has its own bundle ID and settings) unless asked to.
if [ -d "$DEST" ]; then
    EXISTING_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$DEST/Contents/Info.plist" 2>/dev/null || echo "?")
    if [ "$EXISTING_ID" != "$BD_BUNDLE_ID" ] && [ "${BD_REPLACE:-0}" != 1 ]; then
        echo "error: $DEST is a different app ($EXISTING_ID), not this fork ($BD_BUNDLE_ID)." >&2
        echo "Remove it first, choose another path with BD_APP=..., or set BD_REPLACE=1." >&2
        exit 1
    fi
fi

echo "==> Installing to $DEST…"
# Quit, not kill: killed with a virtual display on, the app is started again by
# launchd from the old binary before the copy lands.
if pgrep -f "$DEST/Contents/MacOS/BetterestDisplay" >/dev/null; then
    osascript -e 'quit app "BetterestDisplay"' >/dev/null 2>&1 || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do pgrep -f "$DEST/Contents/MacOS/BetterestDisplay" >/dev/null || break; sleep 0.5; done
    pkill -f "$DEST/Contents/MacOS/BetterestDisplay" 2>/dev/null || true
    sleep 1
fi
rm -rf "$DEST"
ditto "$STAGE" "$DEST"
codesign --verify --strict "$DEST"

echo "==> Launching…"
open "$DEST"
echo "Done. BetterestDisplay $VERSION installed at $DEST."
