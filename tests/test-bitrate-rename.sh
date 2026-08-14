#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=test-common.sh
source "$SCRIPT_DIR/test-common.sh"

IMAGE=${1:?image name required}
WORKSPACE=${2:?workspace required}
setup_workspace "$WORKSPACE"
mkdir -p -- "$WORKSPACE/input"
copy_asset "$SCRIPT_DIR/assets/test-video-1080p-sdr.mkv" "$WORKSPACE/input/video-1080p.mkv"
copy_asset "$SCRIPT_DIR/assets/test-video-4k-hdr10.mkv" "$WORKSPACE/input/video-4k.mkv"

initial_1080_bitrate=$(run_binary "$IMAGE" "$WORKSPACE" mediainfo --Inform='Video;%BitRate%' /media/input/video-1080p.mkv)
initial_4k_bitrate=$(run_binary "$IMAGE" "$WORKSPACE" mediainfo --Inform='Video;%BitRate%' /media/input/video-4k.mkv)
test -z "$initial_1080_bitrate"
test "$initial_4k_bitrate" -gt 0

# The old 1080p fixture has no stored video bitrate. Add Matroska per-track
# statistics with mkvtoolnix, matching the repair path used before renaming.
run_binary "$IMAGE" "$WORKSPACE" mkvpropedit \
  --add-track-statistics-tags /media/input/video-1080p.mkv

bitrate_1080=$(run_binary "$IMAGE" "$WORKSPACE" mediainfo --Inform='Video;%BitRate%' /media/input/video-1080p.mkv)
test "$bitrate_1080" -gt 0
expected_1080_kbps=$(((bitrate_1080 + 500) / 1000))
expected_4k_kbps=$(((initial_4k_bitrate + 500) / 1000))

run_tool "$IMAGE" "$WORKSPACE" bitrate-rename /media/input
test -f "$WORKSPACE/input/video-1080p-${expected_1080_kbps}kbps.mkv"
test -f "$WORKSPACE/input/video-4k-${expected_4k_kbps}kbps.mkv"

echo "bitrate-rename test passed."
