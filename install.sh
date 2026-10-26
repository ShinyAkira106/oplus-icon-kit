#!/bin/bash
#
# Copyright (c) 2026 ShinyAkira. MIT License.
# https://github.com/ShinyAkira106/oplus-icon-kit
# O+iconKit installer
# Usage:
#   ./install.sh                         # just fix the folder icon after updates
#   ./install.sh --icon ~/my_icon.png    # also apply a custom icon after updates
#   ./install.sh --app "/Applications/O+Connect.app"   # only if it lives elsewhere
#   A custom.icns or custom.png next to this script is used automatically
#   when --icon is not given.
#

set -euo pipefail

LABEL="local.oplusiconkit"
APP_PATH="/Applications/O+Connect.app"
BUNDLE_ID="com.oplus.devicespace"
APP_GIVEN=0
ICON_SRC=""
SUPPORT_DIR="$HOME/Library/Application Support/OplusIconKit"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG_FILE="$HOME/Library/Logs/OplusIconKit.log"
HERE="$(cd "$(dirname "$0")" && pwd)"

usage() {
  sed -n '5,11p' "$0" | sed 's/^# \{0,1\}//'
}

while [ $# -gt 0 ]; do
  case "$1" in
    --app)  APP_PATH="$2"; APP_GIVEN=1; shift 2 ;;
    --icon) ICON_SRC="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

if [ "$(uname)" != "Darwin" ]; then
  echo "O+iconKit only runs on macOS."
  exit 1
fi

# If the default path is missing, look the app up by its bundle identifier.
if [ ! -d "$APP_PATH" ] && [ "$APP_GIVEN" -eq 0 ]; then
  found="$(mdfind "kMDItemCFBundleIdentifier == '$BUNDLE_ID'" 2>/dev/null | head -n 1)"
  if [ -n "$found" ] && [ -d "$found" ]; then
    APP_PATH="$found"
    echo "Found O+ Connect at: $APP_PATH"
  fi
fi

if [ ! -d "$APP_PATH" ]; then
  echo "App not found: $APP_PATH"
  echo "Check the exact name in /Applications and pass it with --app."
  exit 1
fi

mkdir -p "$SUPPORT_DIR" "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
cp "$HERE/iconkit.sh" "$SUPPORT_DIR/iconkit.sh"
chmod +x "$SUPPORT_DIR/iconkit.sh"

if [ -z "$ICON_SRC" ]; then
  for candidate in "$HERE/custom.icns" "$HERE/custom.png"; do
    if [ -f "$candidate" ]; then
      ICON_SRC="$candidate"
      echo "Using custom icon found in the kit folder: $(basename "$candidate")"
      break
    fi
  done
fi

ICON_PATH=""
if [ -n "$ICON_SRC" ]; then
  if [ ! -f "$ICON_SRC" ]; then
    echo "Icon file not found: $ICON_SRC"
    exit 1
  fi
  ext="${ICON_SRC##*.}"
  rm -f "$SUPPORT_DIR"/icon.*
  ICON_PATH="$SUPPORT_DIR/icon.$ext"
  cp "$ICON_SRC" "$ICON_PATH"
fi

printf 'APP_PATH=%q\nICON_PATH=%q\n' "$APP_PATH" "$ICON_PATH" > "$SUPPORT_DIR/config.sh"
rm -f "$SUPPORT_DIR/last_stamp"

xml_escape() {
  printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$(xml_escape "$SUPPORT_DIR/iconkit.sh")</string>
  </array>
  <key>WatchPaths</key>
  <array>
    <string>$(xml_escape "$APP_PATH")</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>ThrottleInterval</key>
  <integer>30</integer>
  <key>StandardOutPath</key>
  <string>$(xml_escape "$LOG_FILE")</string>
  <key>StandardErrorPath</key>
  <string>$(xml_escape "$LOG_FILE")</string>
</dict>
</plist>
EOF

UID_NUM="$(id -u)"
launchctl bootout "gui/$UID_NUM/$LABEL" 2>/dev/null || true
if ! launchctl bootstrap "gui/$UID_NUM" "$PLIST" 2>/dev/null; then
  launchctl unload "$PLIST" 2>/dev/null || true
  launchctl load "$PLIST"
fi

echo "O+iconKit installed."
echo "  Watching: $APP_PATH"
[ -n "$ICON_PATH" ] && echo "  Custom icon: $ICON_PATH"
echo "  Log: $LOG_FILE"
echo
echo "Applying once now..."
/bin/bash "$SUPPORT_DIR/iconkit.sh" --force
