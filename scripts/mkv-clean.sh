#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <file.mkv>" >&2
}

if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

INPUT=$1

if [[ ! -f $INPUT ]]; then
  echo "Error: '$INPUT' is not a regular file." >&2
  exit 1
fi

if [[ ${INPUT##*.} != [mM][kK][vV] ]]; then
  echo "Error: input must have an .mkv extension: '$INPUT'." >&2
  exit 1
fi

DIR=$(dirname -- "$INPUT")
BASENAME=$(basename -- "$INPUT")
NAME=${BASENAME%.*}

# HandBrake's RF suffix is part of the filename convention used by this
# toolkit. Keep the prefix and separator intact while normalising only the
# RF marker and numeric representation.
if [[ ! $NAME =~ ^(.*)[Rr][Ff]([0-9]+([.][0-9]+)?)$ ]]; then
  echo "Error: filename does not end with an RF value: '$BASENAME'." >&2
  exit 1
fi

PREFIX=${BASH_REMATCH[1]}
RF_VALUE=${BASH_REMATCH[2]}
if [[ $RF_VALUE == *.* ]]; then
  INTEGER=${RF_VALUE%%.*}
  FRACTION=${RF_VALUE#*.}
  # Trailing zeroes carry no information in an RF value.
  FRACTION=$(printf '%s' "$FRACTION" | sed 's/0*$//')
  if [[ -n $FRACTION ]]; then
    NORMALIZED_RF="$INTEGER.$FRACTION"
  else
    NORMALIZED_RF=$INTEGER
  fi
else
  NORMALIZED_RF=$RF_VALUE
fi

OUTPUT="$DIR/${PREFIX}RF${NORMALIZED_RF}.mkv"
if [[ $OUTPUT == "$INPUT" ]]; then
  echo "Error: output path is the same as the input; refusing to replace '$INPUT'." >&2
  exit 1
fi
if [[ -e $OUTPUT || -L $OUTPUT ]]; then
  echo "Error: destination already exists: '$OUTPUT'." >&2
  exit 1
fi

for command in mkvmerge mediainfo; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "Error: $command is required but was not found in PATH." >&2
    exit 1
  fi
done

# MediaInfo's audio StreamOrder matches mkvmerge's track IDs for a single
# Matroska input. Using the already-required MediaInfo avoids adding a JSON
# runtime solely to inspect one small piece of track metadata.
TRACK_IDS=()
while IFS='|' read -r track_id title; do
  [[ -n $track_id ]] || continue
  case ${title,,} in
    mono|stereo|surround)
      TRACK_IDS+=("$track_id")
      ;;
  esac
done < <(mediainfo --Inform='Audio;%StreamOrder%|%Title%\n' "$INPUT")

TEMP_OUTPUT=$(mktemp "$DIR/.mkv-clean.XXXXXX.mkv")
rm -f -- "$TEMP_OUTPUT"
cleanup() {
  rm -f -- "$TEMP_OUTPUT"
}
trap cleanup EXIT

MKVMERGE_ARGS=(
  --output "$TEMP_OUTPUT"
  --title ""
  --no-global-tags
  --no-track-tags
  --no-attachments
)
for track_id in "${TRACK_IDS[@]}"; do
  MKVMERGE_ARGS+=(--track-name "$track_id:")
done
MKVMERGE_ARGS+=("$INPUT")

# Write beside the input so the final rename is on the same filesystem.
mkvmerge "${MKVMERGE_ARGS[@]}"
mv -- "$TEMP_OUTPUT" "$OUTPUT"
trap - EXIT

echo "Created '$OUTPUT'"
