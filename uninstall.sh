#!/bin/bash
#
# Copyright (c) 2026 ShinyAkira. MIT License.
# https://github.com/ShinyAkira106/oplus-icon-kit
# O+iconKit uninstaller
# Usage:
#   ./uninstall.sh                  # stop watching and remove O+iconKit
#   ./uninstall.sh --restore-icon   # also remove the custom icon from the app
#

LABEL="io.github.shinyakira106.oplusiconkit"
OLD_LABEL="local.oplusiconkit"
SUPPORT_DIR="$HOME/Library/Application Support/OplusIconKit"
KIT_APP="$SUPPORT_DIR/O+iconKit.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
UID_NUM="$(id -u)"

RESTORE=0
[ "${1:-}" = "--restore-icon" ] && RESTORE=1

if [ "$RESTORE" -eq 1 ] && [ -f "$SUPPORT_DIR/config.sh" ]; then
  # shellcheck source=/dev/null
  . "$SUPPORT_DIR/config.sh"
  if [ -d "$APP_PATH" ]; then
    OIK_APP="$APP_PATH" /usr/bin/osascript -l JavaScript -e '
      ObjC.import("AppKit");
      var app = $.NSProcessInfo.processInfo.environment.objectForKey("OIK_APP").js;
      $.NSWorkspace.sharedWorkspace.setIconForFileOptions(null, app, 0) ? "Original icon restored." : "Could not restore the icon."
    '
    touch "$APP_PATH"
    "$LSREGISTER" -f "$APP_PATH"
    killall Dock 2>/dev/null
  fi
fi

for label in "$LABEL" "$OLD_LABEL"; do
  plist="$HOME/Library/LaunchAgents/$label.plist"
  launchctl bootout "gui/$UID_NUM/$label" 2>/dev/null || launchctl unload "$plist" 2>/dev/null
  rm -f "$plist"
done

[ -d "$KIT_APP" ] && "$LSREGISTER" -u "$KIT_APP" 2>/dev/null
rm -rf "$SUPPORT_DIR"

echo "O+iconKit removed. The log at ~/Library/Logs/OplusIconKit.log was kept; delete it if you like."
