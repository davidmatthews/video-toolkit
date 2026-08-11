#!/usr/bin/env bash

set -euo pipefail

usage() {
  echo "Usage: $0 <folder> [--dry-run] [--output-dir <folder>]" >&2
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

INPUT_DIR=$1
shift
DRY_RUN=false
OUTPUT_DIR=

while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --output-dir)
      if [[ $# -lt 2 ]]; then
        echo "Error: --output-dir requires a folder." >&2
        usage
        exit 1
      fi
      OUTPUT_DIR=$2
      shift 2
      ;;
    *)
      echo "Error: unknown option '$1'." >&2
      usage
      exit 1
      ;;
  esac
done

if [[ ! -d $INPUT_DIR ]]; then
  echo "Error: '$INPUT_DIR' is not a valid directory." >&2
  exit 1
fi

for REQUIRED_COMMAND in ffmpeg ffprobe; do
  if ! command -v "$REQUIRED_COMMAND" >/dev/null 2>&1; then
    echo "Error: $REQUIRED_COMMAND is required but was not found in PATH." >&2
    exit 1
  fi
done

# E-AC-3 needs more bitrate as channel count increases; these values keep the
# output proportional to the first audio track's channel layout.
eac3_bitrate_for_channels() {
  case $1 in
    1) echo 96k ;;
    2) echo 192k ;;
    3) echo 320k ;;
    4) echo 384k ;;
    5) echo 448k ;;
    6) echo 640k ;;
    7) echo 768k ;;
    8) echo 1024k ;;
    *) return 1 ;;
  esac
}

if [[ -z $OUTPUT_DIR ]]; then
  PARENT_DIR=$(dirname -- "$INPUT_DIR")
  BASENAME=$(basename -- "$INPUT_DIR")
  OUTPUT_DIR="$PARENT_DIR/${BASENAME} (EAC3)"
fi

INPUT_REALPATH=$(cd -- "$INPUT_DIR" && pwd -P)
if [[ -d $OUTPUT_DIR ]]; then
  OUTPUT_REALPATH=$(cd -- "$OUTPUT_DIR" && pwd -P)
  if [[ $OUTPUT_REALPATH == "$INPUT_REALPATH" ]]; then
    echo "Error: output directory must differ from input directory." >&2
    exit 1
  fi
fi

if [[ $DRY_RUN == false ]] && ! mkdir -p -- "$OUTPUT_DIR"; then
  echo "Error: could not create output directory '$OUTPUT_DIR'." >&2
  exit 1
fi

echo "Input folder : $INPUT_DIR"
echo "Output folder: $OUTPUT_DIR"
echo

processed=0
skipped=0
found_files=false

while IFS= read -r -d '' INPUT_PATH; do
  found_files=true
  FILENAME=$(basename -- "$INPUT_PATH")
  NAME_NO_EXT=${FILENAME%.*}
  EXT=${FILENAME##*.}
  OUTPUT_PATH="$OUTPUT_DIR/$NAME_NO_EXT.$EXT"

  if [[ -e $OUTPUT_PATH || -L $OUTPUT_PATH ]]; then
    echo "Skipping (destination already exists): $OUTPUT_PATH" >&2
    ((skipped += 1))
    continue
  fi

  CHANNELS=$(ffprobe -v error \
    -select_streams a:0 \
    -show_entries stream=channels \
    -of default=noprint_wrappers=1:nokey=1 \
    "$INPUT_PATH" 2>/dev/null || true)

  if [[ ! $CHANNELS =~ ^[1-8]$ ]]; then
    echo "Skipping (first audio track has unsupported channel count): $INPUT_PATH" >&2
    ((skipped += 1))
    continue
  fi

  AUDIO_BITRATE=$(eac3_bitrate_for_channels "$CHANNELS")

  if [[ $DRY_RUN == true ]]; then
    echo "[Dry run] Would encode '$INPUT_PATH' at $AUDIO_BITRATE → '$OUTPUT_PATH'"
    ((processed += 1))
    continue
  fi

  echo "Processing: $FILENAME ($CHANNELS channels, $AUDIO_BITRATE)"
  if ffmpeg -hide_banner -loglevel error -stats \
    -i "$INPUT_PATH" \
    -map 0 -map -0:a -map 0:a:0? \
    -c:v copy \
    -c:s copy \
    -c:a eac3 -b:a "$AUDIO_BITRATE" \
    -map_metadata 0 \
    -map_chapters 0 \
    "$OUTPUT_PATH"; then
    echo "Done -> $OUTPUT_PATH"
    ((processed += 1))
  else
    rm -f -- "$OUTPUT_PATH"
    echo "Skipping (encoding failed): $INPUT_PATH" >&2
    ((skipped += 1))
  fi
  echo
done < <(find -- "$INPUT_DIR" -maxdepth 1 -type f \
  \( -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.mov' -o -iname '*.avi' \
     -o -iname '*.flv' -o -iname '*.wmv' -o -iname '*.m4v' \) -print0)

if [[ $found_files == false ]]; then
  echo "No supported video files found."
fi
echo "Summary: $processed processed, $skipped skipped."
