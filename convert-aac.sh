#!/usr/bin/env bash
#
# Re-encode the audio of .mkv files to AAC so browser players such as asbplayer
# can play them. Video / subtitle / chapter streams are copied, originals are
# never modified or deleted.
#
# Usage:  ./convert-aac.sh [folder]
#         BITRATE=256k OUTPUT_FOLDER=aac DRY_RUN=1 ./convert-aac.sh [folder]

set -euo pipefail

folder="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
bitrate="${BITRATE:-192k}"
out_name="${OUTPUT_FOLDER:-aac}"
dry_run="${DRY_RUN:-0}"

command -v ffmpeg  >/dev/null 2>&1 || { echo "[error] ffmpeg not found on PATH";  exit 1; }
command -v ffprobe >/dev/null 2>&1 || { echo "[error] ffprobe not found on PATH"; exit 1; }
[ -d "$folder" ] || { echo "[error] folder not found: $folder"; exit 1; }

out_dir="$folder/$out_name"
mkdir -p "$out_dir"

duration() {
    # Prints the duration in seconds, or nothing when the file cannot be read.
    ffprobe -v error -show_entries format=duration -of csv=p=0 "$1" 2>/dev/null || true
}

converted=0
skipped=0
failed=0

echo "folder : $folder"
echo "output : $out_dir"
echo

shopt -s nullglob
files=("$folder"/*.mkv)
shopt -u nullglob

if [ ${#files[@]} -eq 0 ]; then
    echo "No .mkv files in this folder."
    exit 0
fi

for file in "${files[@]}"; do
    name="$(basename "$file")"
    target="$out_dir/$name"

    if [ -e "$target" ]; then
        src_dur="$(duration "$file")"
        out_dur="$(duration "$target")"
        if awk -v a="${src_dur:-0}" -v b="${out_dur:-0}" 'BEGIN { exit !(a > 0 && b >= a - 2) }'; then
            echo "[skip] already converted: $name"
            skipped=$((skipped + 1))
            continue
        fi
        echo "[redo] existing output is incomplete: $name"
    fi

    # Every audio track has to be browser-friendly before a file is skipped:
    # dual-audio releases often pair an AAC dub with an E-AC3 original.
    codecs="$(ffprobe -v error -select_streams a -show_entries stream=codec_name -of csv=p=0 "$file" 2>/dev/null || true)"
    if [ -z "$(printf '%s' "$codecs" | tr -d '[:space:]')" ]; then
        echo "[warn] cannot read an audio track (incomplete download?): $name"
        failed=$((failed + 1))
        continue
    fi

    needs_convert=0
    codec_list=""
    for codec in $codecs; do
        codec_list="${codec_list:+$codec_list+}$codec"
        case "$codec" in
            aac|mp3|opus|vorbis|flac) ;;
            *) needs_convert=1 ;;
        esac
    done

    if [ "$needs_convert" -eq 0 ]; then
        echo "[skip] every audio track is browser-friendly already ($codec_list): $name"
        skipped=$((skipped + 1))
        continue
    fi

    if [ "$dry_run" = "1" ]; then
        echo "[dry-run] would convert $codec_list -> aac: $name"
        continue
    fi

    echo "[convert] $codec_list -> aac: $name"
    if ffmpeg -hide_banner -loglevel error -nostats -y -i "$file" \
              -map 0 -c copy -c:a aac -b:a "$bitrate" "$target"; then
        echo "[done] $name"
        converted=$((converted + 1))
    else
        echo "[fail] $name"
        failed=$((failed + 1))
    fi
done

echo
echo "================================"
echo " converted: $converted   skipped: $skipped   failed: $failed"
echo " output:    $out_dir"
echo "================================"
