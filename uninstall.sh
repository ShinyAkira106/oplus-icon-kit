#!/bin/bash
#
# Copyright (c) 2026 ShinyAkira. MIT License.
# https://github.com/ShinyAkira106/oplus-icon-kit
# O+iconKit uninstaller
# Usage:
#   ./uninstall.sh                  # stop watching and remove O+iconKit
#   ./uninstall.sh --restore-icon   # also remove the custom icon from the app
#

LABEL="local.oplusiconkit"
SUPPORT_DIR="$HOME/Library/Application Support/OplusIconKit"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

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

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || launchctl unload "$PLIST" 2>/dev/null
rm -f "$PLIST"
rm -rf "$SUPPORT_DIR"

echo "O+iconKit removed. The log at ~/Library/Logs/OplusIconKit.log was kept; delete it if you like."
