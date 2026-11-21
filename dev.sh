#!/bin/bash
# BetterestDisplay (offline fork of Crisp): fast dev build & run (Command Line Tools are enough; with
# Xcode installed it also builds the Shortcuts actions, see scripts/appintents.sh).
#
# Compiles the binary with swiftc, swaps it into the installed /Applications/BetterestDisplay.app,
# syncs the version from project.yml, re-signs (stable identity if present, else ad
# hoc, hardened runtime either way), and relaunches. One command. When no install
# exists yet it runs scripts/build-app.sh to create one. Offline: no downloads.
#
# Override the target app with:  BD_APP=/path/to/BetterestDisplay.app ./dev.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd -P)"
cd "$ROOT"
APP="${BD_APP:-/Applications/BetterestDisplay.app}"

field() { grep -E "^[[:space:]]*$1:" project.yml | head -1 | sed -E 's/^[^:]*:[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/'; }
VERSION="$(field MARKETING_VERSION)"
BUILD="$(field CURRENT_PROJECT_VERSION)"
BD_BUNDLE_ID="$(field PRODUCT_BUNDLE_IDENTIFIER)"
export BD_BUNDLE_ID

if [ ! -d "$APP" ]; then
    echo "==> $APP not found; building the full bundle first (scripts/build-app.sh)"
    BD_APP="$APP" exec ./scripts/build-app.sh
fi

# Only swap into this fork's own bundle, never into an upstream Crisp install.
EXISTING_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist" 2>/dev/null || echo "?")
if [ "$EXISTING_ID" != "$BD_BUNDLE_ID" ]; then
    echo "error: $APP is $EXISTING_ID, not this fork ($BD_BUNDLE_ID). Run ./scripts/build-app.sh first." >&2
    exit 1
fi

source scripts/appintents.sh
SWIFTC=(swiftc)
AI_FLAGS=""
if appintents_init "$(mktemp -d -t crisp-appintents)"; then
    SWIFTC=(env DEVELOPER_DIR="$AI_DEV" xcrun swiftc)
    AI_FLAGS=$(appintents_swiftc_flags arm64)
fi

echo "==> Compiling BetterestDisplay $VERSION ($BUILD)..."
# The target is explicit: on macOS 27 swiftc with no -target stamps the binary
# with a deployment target above the running system, and LaunchServices then
# refuses to open the bundle ("requires conditional 28.0", -10825).
# shellcheck disable=SC2086 # AI_FLAGS is a list of flags
"${SWIFTC[@]}" -O -swift-version 6 -parse-as-library $AI_FLAGS \
    -target arm64-apple-macos14.0 \
    -import-objc-header Crisp/Crisp-Bridging-Header.h \
    -framework AppKit -framework SwiftUI -framework IOKit -framework CoreAudio \
    -Xlinker -undefined -Xlinker dynamic_lookup \
    Crisp/App/*.swift Crisp/Models/*.swift Crisp/Services/*.swift \
    Crisp/Views/*.swift Crisp/Utilities/*.swift \
    -o Crisp-bin

# Same sources as build-app.sh, so the app and its bdctl come from one branch.
echo "==> Compiling bdctl..."
swiftc -O -swift-version 6 -target arm64-apple-macos14.0 \
    Sources/bdctl/*.swift Crisp/Models/CrispControlModel.swift Crisp/Models/BrightnessKeySteps.swift \
    -o bdctl-bin

./scripts/check-no-network.sh --binary Crisp-bin --binary bdctl-bin

echo "==> Swapping into ${APP}..."
# Quit, not kill: killed with a virtual display on, the app is started again by
# launchd within ~150 ms, from the old binary, before the copy below lands.
if pgrep -f "$APP/Contents/MacOS/BetterestDisplay" >/dev/null; then
    osascript -e 'quit app "BetterestDisplay"' >/dev/null 2>&1 || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do pgrep -f "$APP/Contents/MacOS/BetterestDisplay" >/dev/null || break; sleep 0.5; done
    pkill -f "$APP/Contents/MacOS/BetterestDisplay" 2>/dev/null || true
    sleep 1
fi
cp Crisp-bin "$APP/Contents/MacOS/BetterestDisplay"
cp bdctl-bin "$APP/Contents/MacOS/bdctl"
if [ -n "$AI_DEV" ]; then
    echo "==> Writing Shortcuts actions metadata..."
    appintents_metadata "$APP/Contents/MacOS/BetterestDisplay" "$APP/Contents/Resources" arm64
else
    echo "==> Shortcuts actions not rebuilt (needs Xcode)"
fi
PLIST="$APP/Contents/Info.plist"
# Keep the installed bundle's reported version in step with project.yml,
# since the binary swap doesn't regenerate Info.plist.
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "$PLIST"
# Leftovers from a bundle that once carried the updater: no framework, no SU* keys.
rm -rf "$APP/Contents/Frameworks/Sparkle.framework"
for key in SUFeedURL SUPublicEDKey SUEnableAutomaticChecks SUVerifyUpdateBeforeExtraction SURequireSignedFeed; do
    /usr/libexec/PlistBuddy -c "Delete :$key" "$PLIST" 2>/dev/null || true
done
xattr -cr "$APP"
# Sign with a stable self-signed identity when one exists, so macOS keeps the
# Accessibility grant across rebuilds. Ad-hoc signing changes the code hash every
# build, which invalidates the CGEventTap permission the brightness keys rely on,
# forcing a re-grant after every deploy. Create the identity once, offline: Keychain
# Access > Certificate Assistant > Create a Certificate, name "BetterestDisplay Dev", Self
# Signed Root, type Code Signing. Falls back to ad-hoc when it is absent.
SIGN_ID="${BD_SIGN_ID:-BetterestDisplay Dev}"
# No -v: a self-signed identity is reported "not trusted" and excluded by -v, but
# codesign still signs with it fine, and that's all we need (a stable designated
# requirement so TCC keeps the grant across rebuilds).
if security find-identity -p codesigning 2>/dev/null | grep -qF "$SIGN_ID"; then
    echo "==> Signing with identity: $SIGN_ID (hardened runtime)"
else
    echo "==> Signing ad hoc ($SIGN_ID not found; Accessibility will reset each build)"
    SIGN_ID="-"
fi
codesign --force --options runtime -s "$SIGN_ID" "$APP/Contents/MacOS/bdctl"
codesign --force --options runtime -s "$SIGN_ID" --entitlements Crisp/Crisp.entitlements "$APP"

echo "==> Launching..."
open "$APP"
echo "Done. BetterestDisplay $VERSION running."
