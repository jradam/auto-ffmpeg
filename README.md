# auto-ffmpeg

Auto-compresses new macOS screen recordings (`Screen Recording*.mov`) to `.webm`. 
A LaunchAgent watches your capture directory and runs whenever a new recording is made.

## How it works

- `install.sh` renders `auto-ffmpeg.plist.template` from `settings.json` and loads the LaunchAgent (`com.auto-ffmpeg`).
- The agent watches your capture directory and runs `auto-ffmpeg.sh <capture_dir>` on changes.
- `auto-ffmpeg.sh` compresses each new recording, moves the original to `~/.Trash`, and opens the folder when done.

The capture directory is both watched and written to. `install.sh` reads it from `com.apple.screencapture location`, falling back to `~/Desktop`, and bakes it into the plist file.

## Requirements

- `ffmpeg` and `jq` (`brew install ffmpeg jq`)

## Install

```bash
./install.sh
```

- Run once to set up - it checks `ffmpeg` and `jq` are visible from `homebrew_path` before loading the agent
- The agent runs the scripts from this folder directly, so keep the folder where it is (or re-run `install.sh` after moving it)
- Re-run after changing `homebrew_path`, moving this folder, or changing your macOS screen-capture location
- The other options are read fresh on every run, so they take effect without reinstalling

## Settings (`settings.json`)

| Key | Meaning |
| --- | --- |
| `homebrew_path` | Homebrew bin dir (e.g. `/opt/homebrew/bin`) |
| `recording_prefix` | Filename prefix - matched and stripped from the output name - leave blank to match every `.mov` in capture dir |
| `max_height_px` | Caps output height - never upscales |
| `video_quality_crf` | VP9 quality: lower = better quality/bigger files, higher = worse/smaller |
| `audio_bitrate_kbps` | Opus audio bitrate |

## Notes

- Originals go to `~/.Trash`, not hard deleted
- Any change in the capture directory triggers a run, screenshots included - though runs with nothing to do exit immediately
- launchd runs one instance at a time - a second recording that lands mid-run is picked up by the automatic re-run after exit
- Screen recordings are already complete when the script sees it, but as a safety net the script still checks the file size is unchanged for 2s before encoding (gives up on a file that's still being written to after 60s)
- Encodes go to a hidden `.part` file first, so a failed run never leaves a broken `.webm` behind - it's deleted if ffmpeg fails, and if the script is killed mid-encode the leftover `.part` is overwritten next run
- Logs: `/tmp/auto-ffmpeg.out.log`, `/tmp/auto-ffmpeg.err.log`.

## Uninstall

```bash
launchctl bootout gui/$UID/com.auto-ffmpeg
rm ~/Library/LaunchAgents/com.auto-ffmpeg.plist
rm -f /tmp/auto-ffmpeg.out.log /tmp/auto-ffmpeg.err.log
```

Then delete this folder if you no longer need it.
