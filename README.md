# auto-ffmpeg

Auto-compresses new macOS screen recordings (`Screen Recording *.mov`) to `.webm` or `.mp4`. 

## Requirements

- `ffmpeg` and `jq` (`brew install ffmpeg jq`)

## Install

```bash
./install.sh
```

- Run once to set up - it also checks `ffmpeg` and `jq` are available
- Creates `~/Recordings` and sets it as your screen-capture location (see "Screen capture location" below for more info)
- Survives reboots, no reinstall needed
- Re-run after changing `homebrew_path` or `capture_dir`, or moving this folder
- The other options take effect without reinstalling

## Settings (`settings.json`)

| Key | Meaning |
| --- | --- |
| `homebrew_path` | Homebrew bin dir |
| `capture_dir` | Where screen captures save - see below |
| `recording_prefix` | Prefix to match and strip from the output name - blank matches every `.mov` |
| `format` | `webm` (VP9/Opus) or `mp4` (H.264/AAC) |
| `max_height_px` | Caps output height - never upscales |
| `max_fps` | Caps output frame rate - Mac recordings are 120fps, which is slow to encode |
| `video_quality_crf` | Quality on the VP9 scale (0-63): lower = better - auto-scaled for `mp4`, same value gives similar quality |
| `audio_bitrate_kbps` | Audio bitrate (Opus or AAC) |
| `reveal_in_finder` | `true` highlights the new file in Finder when done, `false` runs silently |

Also turn off "Show Floating Thumbnail" in screen-capture Options, as that delays the `.mov` file hitting the folder, and therefore the conversion as well.

### Screen capture location

`install.sh` sets `capture_dir` from `settings.json` as the macOS screen-capture location, so screenshots save there too, not just recordings. You can change this location, but Desktop/Documents/etc (and anything inside them) are TCC-protected, so use a folder directly under `~` like the default `~/Recordings`.

## How it works

- `install.sh` renders `auto-ffmpeg.plist.template` from `settings.json` and loads the LaunchAgent (`com.auto-ffmpeg`)
- The agent watches `capture_dir` and runs `auto-ffmpeg.sh <capture_dir>` on changes
- `auto-ffmpeg.sh` compresses each new `.mov`, moves original to `~/.Trash`, and optionally reveals the new file in Finder

`capture_dir` is both watched and written to - `install.sh` sets it via `com.apple.screencapture location`.

## Notes

- Originals go to `~/.Trash`, not hard deleted
- Any change in the capture directory triggers a run, screenshots included - though runs with nothing to do exit immediately
- Runs one instance at a time - a second recording that appears mid-run is picked up by the automatic re-run after exit
- Screen recordings are complete when the script sees it, but a safety net checks the file size is unchanged for 2s before encoding
- Encodes go to a `.part` file first, so a failed run never leaves a broken output - it's deleted if ffmpeg fails
- Logs: `/tmp/auto-ffmpeg.out.log`, `/tmp/auto-ffmpeg.err.log`.

## Uninstall

```bash
./uninstall.sh
```

- Unloads the agent and removes its plist and logs
- Leaves `capture_dir` and the screen-capture location in place - delete the folder if unwanted, and run `defaults delete com.apple.screencapture location` to restore the Desktop default
