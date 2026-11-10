#!/bin/bash
# Regenerates the README screenshots (docs/settings-light.png, docs/settings-dark.png).
# The app runs in demo mode: fake networks, no DNS changes, nothing saved.
set -euo pipefail

cd "$(dirname "$0")/.."
DERIVED="$HOME/Library/Developer/Xcode/DerivedData/DNSwitch-screenshots"

xcodegen generate --quiet
xcodebuild -project DNSwitch.xcodeproj -scheme DNSwitch -configuration Debug \
  -derivedDataPath "$DERIVED" build -quiet

# Launch through LaunchServices so the app becomes active and controls draw
# in their active (colored) state.
open -W -n "$DERIVED/Build/Products/Debug/DNSwitch.app" --args --screenshots "$PWD/docs"
ls -l docs/settings-*.png
