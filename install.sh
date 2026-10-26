#!/bin/bash
#
# Copyright (c) 2026 ShinyAkira. MIT License.
# https://github.com/ShinyAkira106/oplus-icon-kit
# O+iconKit installer
# Usage:
#   ./install.sh                         # just fix the folder icon after updates
#   ./install.sh --icon ~/my_icon.png    # also apply a custom icon after updates
#   ./install.sh --app "/Applications/O+Connect.app"   # only if it lives elsewhere
#   ./install.sh --dock always|never     # Dock refresh mode (default: auto)
#   A custom.icns or custom.png next to this script is used automatically
#   when --icon is not given.
#

set -euo pipefail

LABEL="io.github.shinyakira106.oplusiconkit"
OLD_LABEL="local.oplusiconkit"
APP_PATH="/Applications/O+Connect.app"
BUNDLE_ID="com.oplus.devicespace"
APP_GIVEN=0
ICON_SRC=""
DOCK_REFRESH="auto"
SUPPORT_DIR="$HOME/Library/Application Support/OplusIconKit"
KIT_APP="$SUPPORT_DIR/O+iconKit.app"
KIT_EXEC="$KIT_APP/Contents/MacOS/O+iconKit"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
OLD_PLIST="$HOME/Library/LaunchAgents/$OLD_LABEL.plist"
LOG_FILE="$HOME/Library/Logs/OplusIconKit.log"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
HERE="$(cd "$(dirname "$0")" && pwd)"
VERSION="1.1.0"

usage() {
  sed -n '5,12p' "$0" | sed 's/^# \{0,1\}//'
}

while [ $# -gt 0 ]; do
  case "$1" in
    --app)  APP_PATH="$2"; APP_GIVEN=1; shift 2 ;;
    --icon) ICON_SRC="$2"; shift 2 ;;
    --dock)
      case "$2" in auto|always|never) DOCK_REFRESH="$2" ;; *) echo "--dock must be auto, always or never"; exit 1 ;; esac
      shift 2 ;;
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

UID_NUM="$(id -u)"

# Remove the 1.0 background item (which showed up as "bash"), if present.
launchctl bootout "gui/$UID_NUM/$OLD_LABEL" 2>/dev/null || true
rm -f "$OLD_PLIST" "$SUPPORT_DIR/iconkit.sh"

mkdir -p "$SUPPORT_DIR" "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"

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

printf 'APP_PATH=%q\nICON_PATH=%q\nDOCK_REFRESH=%q\n' "$APP_PATH" "$ICON_PATH" "$DOCK_REFRESH" > "$SUPPORT_DIR/config.sh"
rm -f "$SUPPORT_DIR/last_stamp"

# Wrap the script in a tiny background app bundle, so macOS lists it as
# "O+iconKit" in Login Items & Extensions instead of "bash".
rm -rf "$KIT_APP"
mkdir -p "$KIT_APP/Contents/MacOS" "$KIT_APP/Contents/Resources"
cp "$HERE/iconkit.sh" "$KIT_EXEC"
chmod +x "$KIT_EXEC"

ICON_KEY=""
if [ -n "$ICON_PATH" ] && [ "${ICON_PATH##*.}" = "icns" ]; then
  cp "$ICON_PATH" "$KIT_APP/Contents/Resources/AppIcon.icns"
  ICON_KEY="  <key>CFBundleIconFile</key>
  <string>AppIcon</string>"
fi

cat > "$KIT_APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>O+iconKit</string>
  <key>CFBundleDisplayName</key>
  <string>O+iconKit</string>
  <key>CFBundleIdentifier</key>
  <string>$LABEL</string>
  <key>CFBundleExecutable</key>
  <string>O+iconKit</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$VERSION</string>
  <key>LSBackgroundOnly</key>
  <true/>
  <key>NSHumanReadableCopyright</key>
  <string>Copyright (c) 2026 ShinyAkira</string>
$ICON_KEY
</dict>
</plist>
EOF

# Ad hoc signature, so macOS can attribute the background item to the bundle.
codesign --force --sign - "$KIT_APP" >/dev/null 2>&1 || true
"$LSREGISTER" -f "$KIT_APP" 2>/dev/null || true

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
  <key>AssociatedBundleIdentifiers</key>
  <array>
    <string>$LABEL</string>
  </array>
  <key>ProgramArguments</key>
  <array>
    <string>$(xml_escape "$KIT_EXEC")</string>
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

launchctl bootout "gui/$UID_NUM/$LABEL" 2>/dev/null || true
if ! launchctl bootstrap "gui/$UID_NUM" "$PLIST" 2>/dev/null; then
  launchctl unload "$PLIST" 2>/dev/null || true
  launchctl load "$PLIST"
fi

echo "O+iconKit $VERSION installed."
echo "  Watching: $APP_PATH"
[ -n "$ICON_PATH" ] && echo "  Custom icon: $ICON_PATH"
echo "  Dock refresh: $DOCK_REFRESH"
echo "  Log: $LOG_FILE"
echo
echo "Applying once now..."
"$KIT_EXEC" --force
