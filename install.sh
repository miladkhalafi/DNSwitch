#!/bin/bash
# DNSwitch installer: downloads the latest release from GitHub and installs it
# to /Applications.
#
#   curl -fsSL https://raw.githubusercontent.com/miladkhalafi/DNSwitch/main/install.sh | bash
#
# Options (pass after `bash -s --`):
#   --version v1.2.0   install a specific release instead of the latest
#   --uninstall        quit DNSwitch (it restores your DNS) and remove it
#
# DNSwitch is not notarized by Apple. Files downloaded with curl aren't
# quarantined, so Gatekeeper doesn't block the app; this script also clears
# the quarantine flag in case it was set.
set -euo pipefail

REPO="miladkhalafi/DNSwitch"
APP_DIR="/Applications"
APP="$APP_DIR/DNSwitch.app"
VERSION="latest"
ACTION="install"

while [ $# -gt 0 ]; do
  case "$1" in
    --version) VERSION="$2"; shift 2 ;;
    --uninstall) ACTION="uninstall"; shift ;;
    -h|--help) sed -n '2,15p' "$0" 2>/dev/null || true; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

say() { printf '\033[1m==>\033[0m %s\n' "$*"; }
die() { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || die "DNSwitch only runs on macOS."

# Run a command, using sudo only if /Applications isn't writable.
maybe_sudo() { if [ -w "$APP_DIR" ]; then "$@"; else sudo "$@"; fi; }

quit_app() {
  if pgrep -x DNSwitch >/dev/null 2>&1; then
    say "Quitting DNSwitch"
    osascript -e 'quit app "DNSwitch"' >/dev/null 2>&1 || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do pgrep -x DNSwitch >/dev/null 2>&1 || break; sleep 0.5; done
  fi
}

if [ "$ACTION" = "uninstall" ]; then
  quit_app
  [ -d "$APP" ] && maybe_sudo rm -rf "$APP"
  say "DNSwitch removed. (Settings remain in ~/Library/Preferences/com.milad.DNSwitch.plist)"
  exit 0
fi

MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
[ "$MAJOR" -ge 14 ] || die "DNSwitch needs macOS 14 Sonoma or newer (you have $(sw_vers -productVersion))."

if [ "$VERSION" = "latest" ]; then
  API="https://api.github.com/repos/$REPO/releases/latest"
else
  API="https://api.github.com/repos/$REPO/releases/tags/$VERSION"
fi

say "Looking up DNSwitch release ($VERSION)"
JSON="$(curl -fsSL "$API")" || die "Couldn't reach GitHub or the release doesn't exist."
ZIP_URL="$(printf '%s' "$JSON" | grep -o '"browser_download_url": *"[^"]*\.zip"' | head -1 | sed 's/.*"\(https[^"]*\)"/\1/')"
SHA_URL="$(printf '%s' "$JSON" | grep -o '"browser_download_url": *"[^"]*\.zip\.sha256"' | head -1 | sed 's/.*"\(https[^"]*\)"/\1/')"
[ -n "$ZIP_URL" ] || die "No .zip asset found in the release."

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

say "Downloading $(basename "$ZIP_URL")"
curl -fL --progress-bar -o "$TMP/DNSwitch.zip" "$ZIP_URL"

if [ -n "$SHA_URL" ]; then
  EXPECTED="$(curl -fsSL "$SHA_URL" | awk '{print $1}')"
  ACTUAL="$(shasum -a 256 "$TMP/DNSwitch.zip" | awk '{print $1}')"
  [ "$EXPECTED" = "$ACTUAL" ] || die "Checksum mismatch: download is corrupted or tampered with."
  say "Checksum verified"
fi

ditto -x -k "$TMP/DNSwitch.zip" "$TMP/out"
[ -d "$TMP/out/DNSwitch.app" ] || die "Archive doesn't contain DNSwitch.app."

quit_app
say "Installing to $APP"
maybe_sudo rm -rf "$APP"
maybe_sudo ditto "$TMP/out/DNSwitch.app" "$APP"
maybe_sudo xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true

say "Launching DNSwitch (look for the Wi-Fi icon in the menu bar)"
open "$APP"
