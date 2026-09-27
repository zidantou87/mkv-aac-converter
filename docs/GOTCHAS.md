# Pitfalls

Every item below was hit while building this tool, and each one presents as a
symptom that looks like something else. They are written down because they cost
hours and they are not specific to this script.

## 1. A batch file containing non-ASCII bytes can vanish instantly

**Symptom:** you double-click the `.cmd`, a black window flashes and disappears.

**Cause:** `cmd.exe` reads batch files using the *console code page* (gbk/936,
cp1252, ...), not UTF-8. A Chinese comment, or a reference to a Chinese-named
script, turns into mojibake. In our case the line

```bat
set "PS1=%~dp0转AAC音频.ps1"
```

was read as garbage and the parser even swallowed the start of the following
line, so the script "did not exist" and the launcher exited immediately.

**Fix:** keep the `.cmd` pure ASCII and move translated strings into the
PowerShell script, which is read with an explicit encoding. Note that putting
`chcp 65001` at the top helps with *output* but is not a dependable fix for
parsing the same file.

## 2. Parentheses in folder names break batch blocks

**Symptom:** `\[Group] Show was unexpected at this time.`

**Cause:** `if ( ... )` and `for %%F in ( ... )` are delimited by parentheses, and
a `)` inside a quoted path still closes the block. Release folder names are
full of them:

```
[Group] Show - 001-154 (AMZN 1920x1080 VBR AVC E-AC3)
```

**Fix:** drive the script with `goto` labels instead of parenthesised blocks, and
assign paths to variables with `set "VAR=..."`.

## 3. Windows PowerShell 5.1 reads a BOM-less UTF-8 .ps1 as ANSI

**Symptom:** `The string is missing the terminator: '.` plus mojibake, often at
the first non-ASCII string in the file.

**Fix:** save the script as UTF-8 **with BOM**, or keep it ASCII-only. This
launcher sidesteps the problem by reading and executing the file itself:

```bat
set "AAC_PS1=%~dp0convert-aac.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$sb=[scriptblock]::Create((Get-Content -LiteralPath $env:AAC_PS1 -Raw -Encoding UTF8)); & $sb -Folder $env:AAC_FOLDER"
```

Two bonuses: `-Command` is not affected by the execution policy the way `-File`
is, and a parse error is reported instead of silently closing the window.

## 4. LF line endings in a .cmd

**Symptom:** fragments of lines get executed:
`'PEG' is not recognized as an internal or external command`.

**Fix:** CRLF. `cmd.exe` is not a POSIX shell.

## 5. "The file exists" is not "the download finished"

BitTorrent clients preallocate: a file can already have its final size while the
first megabytes are all zero bytes. Two different symptoms come from this:

* the browser shows a black screen (there is no EBML header yet), and
* a converter produces a four-minute file out of a 24-minute episode, because
  it read the part that happened to be present.

**Cheap check:** an MKV file must start with the EBML magic `1A 45 DF A3`.

```powershell
$head = [System.IO.File]::ReadAllBytes($path)[0..3]
if ($head -ne [byte[]](0x1A,0x45,0xDF,0xA3)) { "not a usable MKV yet" }
```

**Consequence for tooling:** never skip an existing output just because the path
exists. Compare durations, and treat a shorter output as a stale artifact — that
is exactly what `convert-aac` does.

## 6. Browsers do not decode AC3 / E-AC3 by default

Chromium ships no Dolby-family decoder. It can decode through the platform when
hardware acceleration is enabled and the GPU supports it; otherwise you get
*"It is encoded in an unsupported EAC3 format"*. So the first thing to try is
`edge://settings/system` → *Use hardware acceleration when available*, then
restart. Re-encoding to AAC is the fallback for machines where that is not
available.

## 7. Windows APIs that quietly treat `[` and `]` as wildcards

`-like`, `Get-ChildItem -Filter`, and `Start-Process -WorkingDirectory` all
accept wildcard patterns, so a folder named `[Group] Show` may fail to resolve
with *"the wildcard path did not resolve to a file"*. Use `-LiteralPath` for
filesystem cmdlets, and `Set-Location -LiteralPath` before `Start-Process`.

## 8. Checking only the first audio track is not enough

Dual-audio releases are common: an AAC English dub sitting next to an E-AC3
Japanese original. Ask `ffprobe` about `a:0`, see `aac`, skip the file, and the
browser still plays a silent video because it picks the other track. Enumerate
**all** audio streams and only skip when every one of them is decodable:

```bash
ffprobe -v error -select_streams a -show_entries stream=codec_name -of csv=p=0 file.mkv
```

Note the flip side: when you do convert, `-c:a aac` applies to every audio
track, so a 2-track file gets two AAC tracks. That is intended — the alternative
is a file that plays fine until someone switches the audio language.

## 9. Paths with a single quote break PowerShell string literals

Wrapping a path in single quotes (`-Folder '%~1'`) is fine until a folder is
called something like `Bob's anime`. The quote closes the literal and the rest of
the path becomes stray commands. Passing values through **environment
variables** sidesteps every quoting and escaping rule at once:

```bat
set "AAC_FOLDER=%~1"
powershell -NoProfile -Command "... & $sb -Folder $env:AAC_FOLDER"
```

## Why ffmpeg is not bundled

The convenient Windows builds are GPLv3 and weigh ~185 MB. Redistributing one
means shipping the licence, the source offer and modification notices. Calling an
externally installed ffmpeg as a separate process sidesteps all of that — this
repository only contains the wrapper.
