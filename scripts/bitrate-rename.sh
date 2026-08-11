#!/usr/bin/env bash

set -euo pipefail

usage() {
  echo "Usage: $0 <folder> [--dry-run]" >&2
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage
  exit 1
fi

FOLDER=$1
DRY_RUN=false

if [[ $# -eq 2 ]]; then
  if [[ $2 == "--dry-run" ]]; then
    DRY_RUN=true
  else
    echo "Error: unknown option '$2'." >&2
    usage
    exit 1
  fi
fi

if [[ ! -d $FOLDER ]]; then
  echo "Error: '$FOLDER' is not a valid directory." >&2
  exit 1
fi

if ! command -v mediainfo >/dev/null 2>&1; then
  echo "Error: mediainfo is required but was not found in PATH." >&2
  exit 1
fi

# Process matching video files in the folder itself, not recursively.
find -- "$FOLDER" -maxdepth 1 -type f \( -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.mov' -o -iname '*.avi' -o -iname '*.flv' -o -iname '*.wmv' -o -iname '*.m4v' \) -print0 |
while IFS= read -r -d '' FILE; do
  DIR=$(dirname -- "$FILE")
  BASENAME=$(basename -- "$FILE")
  EXT=${BASENAME##*.}
  NAME=${BASENAME%.*}

  # Skip files that already use this script's naming convention.
  if [[ $NAME =~ -[0-9]+kbps$ ]]; then
    echo "Skipping (already renamed): $FILE"
    continue
  fi

  if ! BITRATE=$(mediainfo --Inform='Video;%BitRate%' "$FILE"); then
    echo "Skipping (could not read bitrate): $FILE" >&2
    continue
  fi

  # MediaInfo can return an empty or non-numeric value for some files.
  if [[ ! $BITRATE =~ ^[0-9]+$ ]]; then
    echo "Skipping (no valid bitrate found): $FILE"
    continue
  fi

  # Round to the nearest kbps rather than always rounding down.
  KBPS=$(((BITRATE + 500) / 1000))
  NEW_PATH="$DIR/${NAME}-${KBPS}kbps.${EXT}"

  if [[ -e $NEW_PATH || -L $NEW_PATH ]]; then
    echo "Skipping (destination already exists): $NEW_PATH" >&2
    continue
  fi

  if [[ $DRY_RUN == true ]]; then
    echo "[Dry run] Would rename '$FILE' → '$NEW_PATH'"
  else
    echo "Renaming '$FILE' → '$NEW_PATH'"
    mv -- "$FILE" "$NEW_PATH"
  fi
done
