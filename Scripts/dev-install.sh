#!/bin/zsh
# Builds DNSwitch from source and installs it to /Applications (for development).
#
# Builds outside the project folder because ~/Desktop is iCloud-synced, which
# adds Finder metadata that breaks code signatures.
set -euo pipefail

cd "$(dirname "$0")/.."
DERIVED="$HOME/Library/Developer/Xcode/DerivedData/DNSwitch-cli"
CONFIG="${CONFIG:-Release}"
DEST="${DEST:-/Applications}"

command -v xcodegen >/dev/null || { echo "Install XcodeGen first: brew install xcodegen"; exit 1; }

xcodegen generate --quiet
xcodebuild -project DNSwitch.xcodeproj -scheme DNSwitch -configuration "$CONFIG" \
  -derivedDataPath "$DERIVED" build -quiet

APP="$DEST/DNSwitch.app"
osascript -e 'quit app "DNSwitch"' 2>/dev/null || true
rm -rf "$APP"
ditto --noextattr --norsrc "$DERIVED/Build/Products/$CONFIG/DNSwitch.app" "$APP"
codesign --force --sign - --timestamp=none "$APP"
codesign --verify --strict "$APP"

echo "Installed $APP"
echo "Launch it with: open \"$APP\""
