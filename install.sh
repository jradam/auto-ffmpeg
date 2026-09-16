#!/bin/bash

# Renders the plist from settings.json and loads the LaunchAgent
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly SETTINGS_FILE="$SCRIPT_DIR/settings.json"
readonly TEMPLATE_FILE="$SCRIPT_DIR/auto-ffmpeg.plist.template"

command -v jq >/dev/null || {
  echo "jq required: brew install jq" >&2
  exit 1
}

readonly label="com.auto-ffmpeg"
homebrew_path=$(jq -r '.homebrew_path' "$SETTINGS_FILE")

# Check against the PATH the agent will actually run with
readonly agent_path="$homebrew_path:/usr/bin:/bin"
PATH="$agent_path" command -v jq >/dev/null || {
  echo "jq not found in $homebrew_path" >&2
  exit 1
}
PATH="$agent_path" command -v ffmpeg >/dev/null || {
  echo "ffmpeg not found in $homebrew_path" >&2
  exit 1
}

# Desktop/Documents/Downloads are TCC-protected so the agent can't read them
# Default is a folder at the user root which needs no permissions
watch_dir=$(jq -r '.capture_dir // ""' "$SETTINGS_FILE")
watch_dir="${watch_dir:-~/Recordings}" # Empty string counts as unset
watch_dir="${watch_dir/#\~/$HOME}" # Expand a leading ~
readonly watch_dir

case "$watch_dir" in
"$HOME/Desktop" | "$HOME/Desktop/"* | "$HOME/Documents" | "$HOME/Documents/"* | "$HOME/Downloads" | "$HOME/Downloads/"*)
  echo "capture_dir can't be under ~/Desktop, ~/Documents or ~/Downloads (TCC-protected) - use a new folder directly under ~ like ~/Recordings" >&2
  exit 1
  ;;
esac

mkdir -p "$watch_dir"

# Screen recordings save wherever screenshots do
defaults write com.apple.screencapture location "$watch_dir"
# Picks up the new location without a logout
killall SystemUIServer 2>/dev/null || true

script_path="$SCRIPT_DIR/auto-ffmpeg.sh"

readonly PLIST_DEST="$HOME/Library/LaunchAgents/$label.plist"

# Safe inside the sed replacement and the plist XML
plist_safe() {
  local value=$1
  value=${value//&/\\&amp;}
  value=${value//</\\&lt;}
  value=${value//>/\\&gt;}
  value=${value//|/\\|}
  printf '%s' "$value"
}

sed \
  -e "s|__LABEL__|$label|g" \
  -e "s|__SCRIPT_PATH__|$(plist_safe "$script_path")|g" \
  -e "s|__HOMEBREW_PATH__|$(plist_safe "$homebrew_path")|g" \
  -e "s|__WATCH_DIR__|$(plist_safe "$watch_dir")|g" \
  "$TEMPLATE_FILE" >"$PLIST_DEST"

# Reload picks up changes on re-run
launchctl bootout "gui/$UID/$label" 2>/dev/null || true
launchctl bootstrap "gui/$UID" "$PLIST_DEST"

echo "Loaded $label (screen captures now save to $watch_dir)"
