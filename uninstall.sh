#!/bin/bash

# Unloads the LaunchAgent and removes its plist and logs
set -euo pipefail

readonly label="com.auto-ffmpeg"
readonly plist="$HOME/Library/LaunchAgents/$label.plist"

launchctl bootout "gui/$UID/$label" 2>/dev/null || true
rm -f "$plist" /tmp/auto-ffmpeg.out.log /tmp/auto-ffmpeg.err.log

echo "Removed $label. Delete this folder to finish."
