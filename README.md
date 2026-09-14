# auto-ffmpeg

Auto-compresses new macOS screen recordings (`Screen Recording *.mov`) to `.webm`. 

## Requirements

- `ffmpeg` and `jq` (`brew install ffmpeg jq`)

## Install

```bash
./install.sh
```

- Run once to set up - it also checks `ffmpeg` and `jq` are available 
- Survives reboots, no reinstall needed
- The agent runs the scripts from this folder directly, so keep the folder where it is
- Re-run after changing `homebrew_path`, moving this folder, or changing your screen-capture location
- The other options take effect without reinstalling

## Settings (`settings.json`)

| Key | Meaning |
| --- | --- |
| `homebrew_path` | Homebrew bin dir |
| `recording_prefix` | Prefix to match and strip from the output name - blank matches every `.mov` |
| `max_height_px` | Caps output height - never upscales |
| `video_quality_crf` | VP9 quality: lower = better quality |
| `audio_bitrate_kbps` | Opus audio bitrate |
| `reveal_in_finder` | `true` highlights the new `.webm` in Finder when done, `false` runs silently |

Also turn off "Show Floating Thumbnail" in screen-capture Options, as that delays the `.mov` file hitting the folder, and therefore the conversion as well.

## How it works

- `install.sh` renders `auto-ffmpeg.plist.template` from `settings.json` and loads the LaunchAgent (`com.auto-ffmpeg`)
- The agent watches your capture directory and runs `auto-ffmpeg.sh <capture_dir>` on changes
- `auto-ffmpeg.sh` compresses each new `.mov`, moves original to `~/.Trash`, and optionally reveals new `.webm` in Finder

The capture directory is both watched and written to. `install.sh` reads it from `com.apple.screencapture location`, falling back to `~/Desktop`.

## Notes

- Originals go to `~/.Trash`, not hard deleted
- Any change in the capture directory triggers a run, screenshots included - though runs with nothing to do exit immediately
- Runs one instance at a time - a second recording that appears mid-run is picked up by the automatic re-run after exit
- Screen recordings are complete when the script sees it, but a safety net checks the file size is unchanged for 2s before encoding
- Encodes go to a `.part` file first, so a failed run never leaves a broken `.webm` - it's deleted if ffmpeg fails
- Logs: `/tmp/auto-ffmpeg.out.log`, `/tmp/auto-ffmpeg.err.log`.

## Uninstall

```bash
./uninstall.sh
```

- Removes everything: unloads the agent and removes its plist and logs
- Delete this folder to finish
