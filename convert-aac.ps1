<#
.SYNOPSIS
    Re-encode MKV audio tracks to AAC so browser players (asbplayer & friends)
    can play them.

.DESCRIPTION
    Video, subtitle and chapter streams are stream-copied; only audio tracks are
    re-encoded. Originals are never modified or deleted.

    An existing output file is skipped only when its duration matches the
    source. A file converted while its source was still downloading stays
    truncated forever if you just test "does the output exist", so anything
    shorter than the source is re-converted automatically.

.PARAMETER Folder
    Folder containing the .mkv files. Defaults to the folder holding this script.

.PARAMETER OutputFolder
    Name of the output subfolder. Default: aac

.PARAMETER Bitrate
    AAC bitrate. Default: 192k

.PARAMETER FFmpegPath
    Explicit path to ffmpeg.exe. The FFMPEG environment variable is honoured too.

.PARAMETER ToolDir
    Folder searched for a bundled ffmpeg. Defaults to the script's own folder.

.PARAMETER DryRun
    Report what would be converted, then stop.

.EXAMPLE
    .\convert-aac.ps1 -Folder 'D:\Anime\Show' -Bitrate 256k

.NOTES
    Start it through convert-aac.cmd: that keeps the window open and takes care
    of the PowerShell execution policy for you.
#>
[CmdletBinding()]
param(
    [string]$Folder,
    [string]$OutputFolder = 'aac',
    [string]$Bitrate = '192k',
    [string]$FFmpegPath,
    [string]$ToolDir,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# Codecs Chromium-based browsers can decode out of the box. A file only
# qualifies for "nothing to do" when *every* audio track is on this list:
# dual-audio releases often pair an AAC dub with an E-AC3 original.
$browserCodecs = @('aac', 'mp3', 'opus', 'vorbis', 'flac')

function Get-Duration {
    param([string]$Probe, [string]$Path)
    try {
        $raw = & $Probe -v error -show_entries format=duration -of csv=p=0 "$Path" 2>$null
        $first = $raw | Select-Object -First 1
        $value = 0.0
        if ($first -and [double]::TryParse($first.Trim(), [ref]$value)) { return $value }
    } catch { }
    return 0.0
}

function Resolve-Ffmpeg {
    param([string]$Explicit, [string]$ToolDir)

    $candidates = New-Object System.Collections.Generic.List[string]
    if ($Explicit) { $candidates.Add($Explicit) }
    if ($env:FFMPEG) { $candidates.Add($env:FFMPEG) }
    if ($ToolDir) {
        $candidates.Add((Join-Path $ToolDir 'ffmpeg.exe'))
        $candidates.Add((Join-Path $ToolDir 'bin\ffmpeg.exe'))
        $candidates.Add((Join-Path $ToolDir 'ffmpeg\bin\ffmpeg.exe'))
    }
    $onPath = Get-Command ffmpeg -ErrorAction SilentlyContinue
    if ($onPath) { $candidates.Add($onPath.Source) }
    if ($env:LOCALAPPDATA) { $candidates.Add((Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links\ffmpeg.exe')) }
    $candidates.Add('C:\ffmpeg\bin\ffmpeg.exe')
    if ($env:ProgramFiles) { $candidates.Add((Join-Path $env:ProgramFiles 'ffmpeg\bin\ffmpeg.exe')) }

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    return $null
}

# ---------------------------------------------------------------- locate tools

if (-not $ToolDir) {
    if ($PSScriptRoot) { $ToolDir = $PSScriptRoot } else { $ToolDir = (Get-Location).Path }
}
if (-not $Folder) { $Folder = $ToolDir }

if (-not (Test-Path -LiteralPath $Folder)) {
    Write-Host "[error] folder not found: $Folder" -ForegroundColor Red
    exit 1
}
$Folder = (Resolve-Path -LiteralPath $Folder).Path

$ffmpeg = Resolve-Ffmpeg -Explicit $FFmpegPath -ToolDir $ToolDir
if (-not $ffmpeg) {
    Write-Host "[error] ffmpeg was not found." -ForegroundColor Red
    Write-Host "        Either install it (winget install Gyan.FFmpeg), or drop"
    Write-Host "        ffmpeg.exe next to this script, or pass -FFmpegPath."
    exit 1
}

$ffprobe = Join-Path (Split-Path -Parent $ffmpeg) 'ffprobe.exe'
if (-not (Test-Path -LiteralPath $ffprobe)) {
    $probeOnPath = Get-Command ffprobe -ErrorAction SilentlyContinue
    if ($probeOnPath) {
        $ffprobe = $probeOnPath.Source
    } else {
        Write-Host "[error] ffprobe was not found next to ffmpeg." -ForegroundColor Red
        exit 1
    }
}

# ------------------------------------------------------------------ look at files

$outputDir = Join-Path $Folder $OutputFolder
if (-not (Test-Path -LiteralPath $outputDir) -and -not $DryRun) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

Write-Host "folder : $Folder"
Write-Host "output : $outputDir"
Write-Host "ffmpeg : $ffmpeg"
Write-Host ""

$files = @(Get-ChildItem -LiteralPath $Folder -File | Where-Object { $_.Extension -ieq '.mkv' })
if ($files.Count -eq 0) {
    Write-Host "No .mkv files in this folder."
    exit 0
}

$converted = 0
$skipped = 0
$failed = 0
$unreadable = New-Object System.Collections.Generic.List[string]

foreach ($file in $files) {
    $target = Join-Path $outputDir $file.Name

    if (Test-Path -LiteralPath $target) {
        $sourceDuration = Get-Duration -Probe $ffprobe -Path $file.FullName
        $targetDuration = Get-Duration -Probe $ffprobe -Path $target

        if ($sourceDuration -gt 0 -and $targetDuration -ge ($sourceDuration - 2)) {
            Write-Host "[skip] already converted: $($file.Name)"
            $skipped++
            continue
        }
        Write-Host ("[redo] existing output is incomplete ({0:N1} min vs source {1:N1} min): {2}" -f ($targetDuration / 60), ($sourceDuration / 60), $file.Name)
    }

    $codecs = @()
    try {
        $codecs = @(
            & $ffprobe -v error -select_streams a -show_entries stream=codec_name -of csv=p=0 "$($file.FullName)" 2>$null |
                Where-Object { $_ -and $_.Trim() } |
                ForEach-Object { $_.Trim().ToLower() }
        )
    } catch { }

    if ($codecs.Count -eq 0) {
        Write-Host "[warn] cannot read an audio track (incomplete download?): $($file.Name)" -ForegroundColor Yellow
        $unreadable.Add($file.Name)
        $failed++
        continue
    }

    $codecList = $codecs -join '+'
    $unplayable = @($codecs | Where-Object { $browserCodecs -notcontains $_ })
    if ($unplayable.Count -eq 0) {
        Write-Host "[skip] every audio track is browser-friendly already ($codecList): $($file.Name)"
        $skipped++
        continue
    }

    if ($DryRun) {
        Write-Host "[dry-run] would convert $codecList -> aac: $($file.Name)"
        continue
    }

    Write-Host "[convert] $codecList -> aac: $($file.Name)"
    & $ffmpeg -hide_banner -loglevel error -nostats -y -i "$($file.FullName)" -map 0 -c copy -c:a aac -b:a $Bitrate "$target"

    if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $target)) {
        $sizeMb = [math]::Round((Get-Item -LiteralPath $target).Length / 1MB, 1)
        Write-Host "[done] $($file.Name)  ($sizeMb MB)"
        $converted++
    } else {
        Write-Host "[fail] $($file.Name)" -ForegroundColor Red
        $failed++
    }
}

Write-Host ""
Write-Host "================================"
Write-Host " converted: $converted   skipped: $skipped   failed: $failed"
Write-Host " output:    $outputDir"
if ($unreadable.Count -gt 0) {
    Write-Host " unreadable files (check the download):"
    foreach ($name in $unreadable) { Write-Host "   - $name" }
}
Write-Host "================================"
