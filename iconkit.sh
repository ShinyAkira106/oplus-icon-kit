#!/bin/bash
#
# Copyright (c) 2026 ShinyAkira. MIT License.
# https://github.com/ShinyAkira106/oplus-icon-kit
# O+iconKit main script
# Restores (and optionally customises) the O+ Connect icon after an update.
# Normally run by launchd; can also be run by hand with --force.
#

SUPPORT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG="$SUPPORT_DIR/config.sh"
STAMP_FILE="$SUPPORT_DIR/last_stamp"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

if [ ! -f "$CONFIG" ]; then
  log "Config not found at $CONFIG. Please run install.sh again."
  exit 1
fi
# shellcheck source=/dev/null
. "$CONFIG"

INFO_PLIST="$APP_PATH/Contents/Info.plist"

# Wait until the updater has finished writing the new app bundle:
# Info.plist must exist and its modification time must stay the same
# across two checks 10 seconds apart (up to 3 minutes in total).
prev=""
waited=0
settled=0
while [ "$waited" -lt 180 ]; do
  if [ -f "$INFO_PLIST" ]; then
    cur="$(stat -f '%m' "$INFO_PLIST" 2>/dev/null)"
    if [ -n "$prev" ] && [ "$cur" = "$prev" ]; then
      settled=1
      break
    fi
    prev="$cur"
  fi
  [ "$FORCE" -eq 1 ] && [ -n "$prev" ] && { settled=1; break; }
  sleep 10
  waited=$((waited + 10))
done

if [ "$settled" -ne 1 ]; then
  log "App not found or still changing: $APP_PATH. Skipping this run."
  exit 0
fi

# Skip if this exact version was already handled. This also stops the
# script from re-triggering itself, since applying an icon modifies the
# bundle folder that launchd is watching.
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST" 2>/dev/null)"
stamp="${version}:${prev}"
if [ "$FORCE" -ne 1 ] && [ -f "$STAMP_FILE" ] && [ "$(cat "$STAMP_FILE")" = "$stamp" ]; then
  exit 0
fi

log "Handling $APP_PATH (version ${version:-unknown})"

# Apply the custom icon, if one was configured.
if [ -n "${ICON_PATH:-}" ]; then
  if [ ! -f "$ICON_PATH" ]; then
    log "Custom icon file missing: $ICON_PATH. Keeping the default icon."
  elif [ ! -w "$APP_PATH" ]; then
    log "No write permission on $APP_PATH, so the custom icon cannot be applied."
    log "Fix with: sudo chown -R \"\$(whoami)\" \"$APP_PATH\""
  else
    result="$(OIK_APP="$APP_PATH" OIK_ICON="$ICON_PATH" /usr/bin/osascript -l JavaScript -e '
      ObjC.import("AppKit");
      var env = $.NSProcessInfo.processInfo.environment;
      var app = env.objectForKey("OIK_APP").js;
      var icon = env.objectForKey("OIK_ICON").js;
      var img = $.NSImage.alloc.initWithContentsOfFile(icon);
      if (img.isNil()) { "ERR_IMAGE" }
      else { $.NSWorkspace.sharedWorkspace.setIconForFileOptions(img, app, 0) ? "OK" : "ERR_SET" }
    ' 2>&1)"
    case "$result" in
      OK)        log "Custom icon applied." ;;
      ERR_IMAGE) log "Could not read the image at $ICON_PATH." ;;
      *)         log "Failed to set the custom icon: $result" ;;
    esac
  fi
fi

# Make macOS re-register the bundle as an app, then refresh the Dock.
touch "$APP_PATH"
"$LSREGISTER" -f "$APP_PATH"
killall Dock 2>/dev/null

echo "$stamp" > "$STAMP_FILE"
log "Done."
