# mkv-aac-converter

Re-encode the audio of `.mkv` files to **AAC** so browser-based players such as
[asbplayer](https://github.com/asbplayer/asbplayer) can play them.

Video, subtitles and chapters are copied bit-for-bit. Only the audio tracks are
re-encoded. Original files are never modified or deleted.

## Why this exists

Plenty of releases ship with **E-AC3 (Dolby Digital Plus)** or AC3 audio.
Chromium-based browsers do not include a decoder for those codecs, so dragging
such a file into [app.asbplayer.dev](https://app.asbplayer.dev) gives you:

> Unable to play the audio of `<file>`. It is encoded in an unsupported EAC3 format.

**Try hardware acceleration first.** Per asbplayer's
[compatibility table](https://docs.asbplayer.dev/docs/compatibility), Chromium
can play Dolby-family audio when a modern GPU is present and hardware
acceleration is enabled:

- Edge: `edge://settings/system` → enable *Use hardware acceleration when available* → restart the browser
- Chrome: same idea under `chrome://settings/system`
- Verify with `edge://gpu` / `chrome://gpu`: look for `Video Decode: Hardware accelerated`

If the machine still refuses to decode the audio, re-encoding to AAC is the
reliable fallback. That is what this tool does.

## Requirements

- **Windows**: Windows 10/11 with PowerShell 5.1 (preinstalled)
- **Linux / macOS**: `bash`, `ffmpeg`, `ffprobe`
- **ffmpeg** (including `ffprobe`), found via any of:
  - your `PATH`, or
  - `ffmpeg.exe` / `bin/ffmpeg.exe` / `ffmpeg/bin/ffmpeg.exe` next to this script, or
  - `-FFmpegPath <path>`, or the `FFMPEG` environment variable

  (the shell script looks on `PATH` only)

Install ffmpeg:

```powershell
winget install Gyan.FFmpeg     # Windows
```

```bash
brew install ffmpeg            # macOS
sudo apt install ffmpeg        # Debian / Ubuntu
```

## Quick start (Windows)

1. Put `convert-aac.cmd` and `convert-aac.ps1` in the same folder as your `.mkv` files.
2. Double-click `convert-aac.cmd`, or drag a folder onto it.
3. Wait. Output lands in a subfolder called `aac`.
4. Drag the files from `aac` into asbplayer.

## Quick start (Linux / macOS)

```bash
./convert-aac.sh /path/to/episodes
```

## Options

`convert-aac.ps1` accepts:

| Parameter | Default | Meaning |
| --- | --- | --- |
| `-Folder` | script's own folder | Folder containing the `.mkv` files |
| `-OutputFolder` | `aac` | Name of the output subfolder |
| `-Bitrate` | `192k` | AAC bitrate |
| `-FFmpegPath` | auto-detected | Explicit path to `ffmpeg.exe` |
| `-DryRun` | off | List what would be converted and exit |
| `-ToolDir` | script's folder | Where the launcher looks for a bundled ffmpeg |

`convert-aac.sh` takes a folder argument and honours `BITRATE`, `OUTPUT_FOLDER`
and `DRY_RUN`.

## What it does not do

- It does **not** download anything. You supply your own files.
- It does **not** modify, move or delete the originals.
- It does **not** touch video or subtitle streams; they are stream-copied.
- It does **not** handle `.avi` (that needs the video re-encoded too).

## Re-running is safe

Already-converted files are skipped, but the script compares durations before
skipping. A file converted while its source was still downloading stays
truncated forever if you only test "does the output exist", so anything shorter
than the source is re-converted automatically.

A file is only skipped when **every** audio track is one the browser can decode
(`aac`, `mp3`, `opus`, `vorbis`, `flac`). Dual-audio releases routinely pair an
AAC dub with an E-AC3 original, and checking just the first track would leave you
with a silent video.

See [docs/GOTCHAS.md](docs/GOTCHAS.md) for the pitfalls that shaped this script.

## License

MIT. This project invokes `ffmpeg` as an external program and does not bundle it.

## 中文说明

把 `.mkv` 的音轨重新编码成 **AAC**，让 asbplayer 这类浏览器播放器能正常出声。
视频、字幕、章节都是原样复制，只有音轨重编；原文件不会被改动，也不会被删除。

**先试硬件加速**：按 asbplayer 官方兼容表，Chromium 在开启硬件加速、显卡较新时
可以直接播放杜比系音频（Edge：`edge://settings/system` → 使用硬件加速 → 重启浏览器）。
真的解不了，再用本工具转码兜底。

**用法（Windows）**：把 `convert-aac.cmd` 和 `convert-aac.ps1` 一起放进番剧文件夹，
双击 `.cmd`。转好的文件出现在 `aac` 子文件夹里，拖进 asbplayer 即可。

**用法（Linux / macOS）**：`./convert-aac.sh /番剧目录`
