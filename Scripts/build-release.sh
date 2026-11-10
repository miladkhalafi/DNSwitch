#!/bin/bash
# Builds a universal (Apple silicon + Intel) Release of DNSwitch and packages it:
#   dist/DNSwitch-<version>.zip  and  dist/DNSwitch-<version>.zip.sha256
#
# Usage: Scripts/build-release.sh [version]     (default: 0.0.0-dev)
# Used by .github/workflows/release.yml and runnable locally.
set -euo pipefail

cd "$(dirname "$0")/.."
VERSION="${1:-0.0.0-dev}"
VERSION="${VERSION#v}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
DERIVED="${DERIVED:-$HOME/Library/Developer/Xcode/DerivedData/DNSwitch-release}"
DIST="$PWD/dist"

command -v xcodegen >/dev/null || { echo "error: XcodeGen is required (brew install xcodegen)" >&2; exit 1; }

xcodegen generate --quiet
rm -rf "$DERIVED/Build/Products/Release"
xcodebuild -project DNSwitch.xcodeproj -scheme DNSwitch -configuration Release \
  -derivedDataPath "$DERIVED" \
  -destination 'generic/platform=macOS' \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
  MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  build -quiet

APP="$DERIVED/Build/Products/Release/DNSwitch.app"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

# Copy without extended attributes, then ad-hoc sign the clean copy.
ditto --noextattr --norsrc "$APP" "$STAGE/DNSwitch.app"
codesign --force --sign - --timestamp=none "$STAGE/DNSwitch.app"
codesign --verify --strict "$STAGE/DNSwitch.app"
lipo -info "$STAGE/DNSwitch.app/Contents/MacOS/DNSwitch"

mkdir -p "$DIST"
ZIP="$DIST/DNSwitch-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$STAGE/DNSwitch.app" "$ZIP"
(cd "$DIST" && shasum -a 256 "$(basename "$ZIP")" > "$(basename "$ZIP").sha256")

echo "Built $ZIP"
cat "$ZIP.sha256"
