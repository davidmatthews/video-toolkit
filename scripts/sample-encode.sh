#!/usr/bin/env bash
set -euo pipefail

# These values are kept here so the sampling strategy can be adjusted without
# changing the command-line interface.
SAMPLE_DURATION_SECONDS=10
SAMPLE_INTERVAL_SECONDS=300
PRESET_DIR="/opt/handbrake-presets"

SOURCE="${1:-}"
CRF="${2:-}"
MODE="${3:-}"

if [[ -z "$SOURCE" || -z "$CRF" ]]; then
    echo "Usage: $0 <input_file> <crf> [animation]" >&2
    exit 1
fi

if [[ ! -f "$SOURCE" ]]; then
    echo "Input file does not exist: $SOURCE" >&2
    exit 1
fi

WIDTH=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=nk=1:nw=1 "$SOURCE")
HEIGHT=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=nk=1:nw=1 "$SOURCE")
TRANSFER=$(ffprobe -v error -select_streams v:0 -show_entries stream=color_transfer -of default=nk=1:nw=1 "$SOURCE")
DURATION=$(ffprobe -v error -show_entries format=duration -of default=nk=1:nw=1 "$SOURCE")

if [[ -z "$WIDTH" || -z "$HEIGHT" || -z "$DURATION" ]]; then
    echo "Could not determine the input video dimensions and duration" >&2
    exit 1
fi

echo "Detected resolution: ${WIDTH}x${HEIGHT}"

# Get the source video bitrate for consistency with the old script's output.
VIDEO_BITRATE=$(mediainfo --Inform="Video;%BitRate%" "$SOURCE" | head -n1)
if [[ -z "$VIDEO_BITRATE" || ! "$VIDEO_BITRATE" =~ ^[0-9]+$ ]]; then
    echo "Warning: Could not determine source video bitrate"
    VIDEO_BITRATE_KBPS=0
else
    VIDEO_BITRATE_KBPS=$((VIDEO_BITRATE / 1000))
fi
echo "Source video bitrate: ${VIDEO_BITRATE_KBPS} Kbps"

# Resolution thresholds (~10% buffer above 1080p).
WIDTH_THRESHOLD=2100
HEIGHT_THRESHOLD=1200
if [[ "$WIDTH" -gt "$WIDTH_THRESHOLD" || "$HEIGHT" -gt "$HEIGHT_THRESHOLD" ]]; then
    RES="4k"
else
    RES="1080p"
fi

# Keep this detection for future HDR/SDR-specific preset choices.
if [[ "$TRANSFER" == "smpte2084" || "$TRANSFER" == "arib-std-b67" ]]; then
    DYNAMIC_RANGE="HDR"
else
    DYNAMIC_RANGE="SDR"
fi
echo "Dynamic range: $DYNAMIC_RANGE ($TRANSFER)"

if [[ "$MODE" == "animation" ]]; then
    PRESET="${RES}-animation"
else
    PRESET="$RES"
fi
echo "Using preset: $PRESET"

PRESET_FILE=$(find "$PRESET_DIR" -maxdepth 1 -type f -name "${PRESET}.json" -print -quit)
if [[ -z "$PRESET_FILE" ]]; then
    echo "Could not find preset file for '$PRESET' in $PRESET_DIR" >&2
    exit 1
fi

SAMPLE_DIR=$(mktemp -d)
trap 'rm -rf "$SAMPLE_DIR"' EXIT

total_bits=0
total_sampled_seconds=0
sample_count=0
start_seconds=0
TOTAL_SAMPLES=$(awk -v duration="$DURATION" -v interval="$SAMPLE_INTERVAL_SECONDS" \
    'BEGIN { print int((duration + interval - 0.000001) / interval) }')

echo "Total samples: ${TOTAL_SAMPLES}"

while awk -v start="$start_seconds" -v duration="$DURATION" \
    'BEGIN { exit !(start < duration) }'; do
    sample_file="$SAMPLE_DIR/sample-${sample_count}.mkv"

    echo "Encoding sample $((sample_count + 1))/${TOTAL_SAMPLES} at ${start_seconds}s..."
    # Explicitly disable these streams because the presets are intended for
    # normal encodes and may otherwise passthrough their configured tracks.
    handbrake_log="$SAMPLE_DIR/handbrake-${sample_count}.log"
    if ! HandBrakeCLI \
            --input "$SOURCE" \
            --output "$sample_file" \
            --preset-import-file "$PRESET_FILE" \
            --preset "$PRESET" \
            --audio none \
            --subtitle none \
            --start-at "duration:${start_seconds}" \
            --stop-at "duration:${SAMPLE_DURATION_SECONDS}" \
            --verbose=0 2>&1 | tee "$handbrake_log" | awk -v RS='\r' \
            -v sample="$((sample_count + 1))" -v total="$TOTAL_SAMPLES" '
                BEGIN { last_bucket = -1 }

                /Encoding: task [0-9]+ of [0-9]+,/ {
                    progress = $0
                    sub(/^.*Encoding: task [0-9]+ of [0-9]+, /, "", progress)
                    sub(/ %.*/, "", progress)

                    fps = $0
                    sub(/^.*% \(/, "", fps)
                    sub(/ fps.*/, "", fps)

                    # HandBrake writes progress with carriage returns. Emit
                    # one readable line per 5% bucket instead of relying on
                    # terminal carriage-return rendering.
                    bucket = int(progress / 5)
                    if (bucket > last_bucket || progress >= 99.9) {
                        printf "Encoding sample %d/%d: %s%% (%s fps)\n", sample, total, progress, fps
                        last_bucket = bucket
                    }
                }
                END { fflush() }
            '; then
        echo "HandBrake failed while encoding sample at ${start_seconds}s:" >&2
        cat "$handbrake_log" >&2
        exit 1
    fi

    sample_seconds=$(ffprobe -v error -show_entries format=duration \
        -of default=nk=1:nw=1 "$sample_file")
    sample_bytes=$(stat -c '%s' "$sample_file" 2>/dev/null || stat -f '%z' "$sample_file")

    if [[ -z "$sample_seconds" || "$sample_seconds" == 0 || -z "$sample_bytes" ]]; then
        echo "Could not determine encoded sample size or duration" >&2
        exit 1
    fi

    sample_bitrate=$(awk -v bytes="$sample_bytes" -v seconds="$sample_seconds" \
        'BEGIN { printf "%.0f", bytes * 8 / seconds / 1000 }')
    echo "Sample bitrate: ${sample_bitrate} Kbps"

    total_bits=$(awk -v total="$total_bits" -v bytes="$sample_bytes" \
        'BEGIN { printf "%.0f", total + bytes * 8 }')
    total_sampled_seconds=$(awk -v total="$total_sampled_seconds" \
        -v seconds="$sample_seconds" 'BEGIN { printf "%.6f", total + seconds }')
    # Remove each sample as soon as its measurement has been incorporated so
    # long inputs do not require retaining all encoded chunks simultaneously.
    rm -f -- "$sample_file"
    sample_count=$((sample_count + 1))
    start_seconds=$((start_seconds + SAMPLE_INTERVAL_SECONDS))
done

if [[ "$sample_count" -eq 0 || "$total_sampled_seconds" == 0 ]]; then
    echo "No samples could be taken from the input video" >&2
    exit 1
fi

PREDICTED_BITRATE=$(awk -v bits="$total_bits" -v seconds="$total_sampled_seconds" \
    'BEGIN { printf "%.0f", bits / seconds / 1000 }')

if [[ "$VIDEO_BITRATE_KBPS" -gt 0 ]]; then
    BITRATE_PERCENTAGE=$(awk -v encoded="$PREDICTED_BITRATE" \
        -v original="$VIDEO_BITRATE_KBPS" \
        'BEGIN { printf "%.1f", encoded / original * 100 }')
else
    BITRATE_PERCENTAGE="unknown"
fi

echo ""
echo "Sample encode complete."
echo "Preset: ${PRESET}"
echo "CRF: ${CRF}"
echo "Original video bitrate: ${VIDEO_BITRATE_KBPS} Kbps"
echo "Predicted encoded video bitrate: ${PREDICTED_BITRATE} Kbps (${BITRATE_PERCENTAGE}% of original)"
