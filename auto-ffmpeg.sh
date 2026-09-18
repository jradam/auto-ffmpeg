#!/bin/bash

# Auto-compresses new Mac screen recordings to webm or mp4
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
  jq -er ".$1" "$SETTINGS_FILE" || {
    echo "settings.json: missing $1" >&2
    exit 1
  }
}

RECORDING_PREFIX=$(jq -r '.recording_prefix // ""' "$SETTINGS_FILE")
MAX_HEIGHT=$(read_setting max_height_px)
MAX_FPS=$(read_setting max_fps)
CRF=$(read_setting video_quality_crf)
AUDIO_KBPS=$(read_setting audio_bitrate_kbps)
REVEAL_IN_FINDER=$(jq -r '.reveal_in_finder // false' "$SETTINGS_FILE")
FORMAT=$(jq -r '.format // "webm"' "$SETTINGS_FILE")
RECORDING_TYPE=$(jq -r '.recording_type // "mov"' "$SETTINGS_FILE")

# video_quality_crf is on the VP9 scale (0-63), x264 uses 0-51 so scale it down
readonly X264_CRF_MULTIPLIER=0.72

# Per-format codec args
case "$FORMAT" in
webm)
  # -b:v 0 makes CRF the sole quality control for VP9
  # -row-mt 1 -threads 0 uses every core, -cpu-used 4 trades a little quality for a much faster encode
  codec_args=(
    -c:v libvpx-vp9 -crf "$CRF" -b:v 0
    -row-mt 1 -cpu-used 4 -threads 0
    -c:a libopus -b:a "${AUDIO_KBPS}k"
  )
  ;;
mp4)
  x264_crf=$(awk -v crf="$CRF" -v mult="$X264_CRF_MULTIPLIER" 'BEGIN { printf "%d", crf * mult + 0.5 }')
  # yuv420p keeps QuickTime and browsers happy, faststart lets playback begin before download finishes
  codec_args=(
    -c:v libx264 -crf "$x264_crf" -preset fast -pix_fmt yuv420p
    -c:a aac -b:a "${AUDIO_KBPS}k"
    -movflags +faststart
  )
  ;;
*)
  echo "settings.json: format must be webm or mp4, got '$FORMAT'" >&2
  exit 1
  ;;
esac
readonly codec_args

# Allows spaces after commas
IFS=',' read -ra RECORDING_TYPES <<<"${RECORDING_TYPE// /}"
readonly RECORDING_TYPES

if [[ ${#RECORDING_TYPES[@]} -eq 0 ]]; then
  echo "settings.json: recording_type must list mov and/or mp4" >&2
  exit 1
fi

for recording_type in "${RECORDING_TYPES[@]}"; do
  case "$recording_type" in
  mov | mp4) ;;
  *)
    echo "settings.json: recording_type entries must be mov or mp4, got '$recording_type'" >&2
    exit 1
    ;;
  esac

  # Output would land on its own input
  if [[ "$recording_type" == "$FORMAT" && -z "$RECORDING_PREFIX" ]]; then
    echo "settings.json: recording_prefix is required when recording_type includes the output format ($FORMAT)" >&2
    exit 1
  fi
done

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

last_output=""

shopt -s nullglob

for recording_type in "${RECORDING_TYPES[@]}"; do
  for recording in "$capture_dir/$RECORDING_PREFIX"*."$recording_type"; do
    name=$(basename "$recording" ".$recording_type")
    name="${name#"$RECORDING_PREFIX"}"
    output="$capture_dir/$name.$FORMAT"
    partial_output="$capture_dir/.$name.$FORMAT.part"

    # Already compressed
    if [[ -f "$output" ]]; then
      continue
    fi

    if ! wait_until_stable "$recording"; then
      continue
    fi

    # fps caps the frame rate, scale caps height without upscaling and keeps both dimensions even (x264 rejects odd sizes)
    # Hidden .part file means a failed run never leaves an output that blocks a retry
    # -f is needed because .part hides the extension ffmpeg would otherwise infer from
    if ffmpeg -nostdin -y -loglevel warning -nostats -i "$recording" \
      "${codec_args[@]}" \
      -vf "fps=$MAX_FPS,scale=-2:'2*trunc(min($MAX_HEIGHT,ih)/2)'" \
      -f "$FORMAT" "$partial_output"; then
      mv "$partial_output" "$output"
      # Trash keeps the original recoverable
      # -n never overwrites a same-named file already there
      mv -n "$recording" "$HOME/.Trash/"
      last_output="$output"
    else
      rm -f "$partial_output"
    fi
  done
done

# Only reveal results when enabled and something was compressed
# -R highlights the newest output in Finder
if [[ "$REVEAL_IN_FINDER" == true && -n "$last_output" ]]; then
  open -R "$last_output"
fi
