#!/bin/bash

# Auto-compresses new Mac screen recordings to webm
# Triggered by a LaunchAgent watching the screen capture dir
# launchd runs one instance at a time and re-runs after exit if triggered mid-run
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <capture_dir>" >&2
  exit 1
fi
readonly capture_dir="$1"

# Same settings.json install.sh reads
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly SETTINGS_FILE="$SCRIPT_DIR/settings.json"

# Fails fast on a missing key instead of passing "null" to ffmpeg
read_setting() {
  jq -er ".$1" "$SETTINGS_FILE" || { echo "settings.json: missing $1" >&2; exit 1; }
}

RECORDING_PREFIX=$(jq -r '.recording_prefix // ""' "$SETTINGS_FILE")
MAX_HEIGHT=$(read_setting max_height_px)
CRF=$(read_setting video_quality_crf)
AUDIO_KBPS=$(read_setting audio_bitrate_kbps)

# Stops us compressing a half-written recording
# Gives up after 60s
wait_until_stable() {
  local file=$1

  local attempt size_before size_after
  for attempt in {1..30}; do
    size_before=$(stat -f %z "$file")
    sleep 2
    size_after=$(stat -f %z "$file")
    if [[ "$size_before" == "$size_after" ]]; then
      return 0
    fi
  done

  return 1
}

compressed_any=false

shopt -s nullglob

for recording in "$capture_dir/$RECORDING_PREFIX"*.mov; do
  name=$(basename "$recording" .mov)
  name="${name#"$RECORDING_PREFIX"}"
  output="$capture_dir/$name.webm"
  partial_output="$capture_dir/.$name.webm.part"

  # Already compressed
  if [[ -f "$output" ]]; then
    continue
  fi

  if ! wait_until_stable "$recording"; then
    continue
  fi

  # -b:v 0 makes CRF the sole quality control for VP9
  # scale keeps width even (-2) and caps height without upscaling
  # Hidden .part file means a failed run never leaves a webm that blocks a retry
  if ffmpeg -nostdin -y -loglevel warning -nostats -i "$recording" \
    -c:v libvpx-vp9 -crf "$CRF" -b:v 0 \
    -vf "scale=-2:'min($MAX_HEIGHT,ih)'" \
    -c:a libopus -b:a "${AUDIO_KBPS}k" \
    -f webm "$partial_output"; then
    mv "$partial_output" "$output"
    # Trash keeps the original recoverable
    # -n never overwrites a same-named file already there
    mv -n "$recording" "$HOME/.Trash/"
    compressed_any=true
  else
    rm -f "$partial_output"
  fi
done

# Only reveal results when something was compressed
if [[ "$compressed_any" == true ]]; then
  open "$capture_dir"
fi
