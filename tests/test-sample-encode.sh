#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
source "$SCRIPT_DIR/test-common.sh"

IMAGE=${1:?image name required}
WORKSPACE=${2:?workspace required}
setup_workspace "$WORKSPACE"
mkdir -p -- "$WORKSPACE/input"
copy_asset "$SCRIPT_DIR/assets/test-video-1080p-sdr.mkv" "$WORKSPACE/input/video.mkv"
copy_asset "$SCRIPT_DIR/assets/test-video-4k-hdr10.mkv" "$WORKSPACE/input/video-4k.mkv"

source_info=$(run_binary "$IMAGE" "$WORKSPACE" mediainfo \
  --Inform='Video;%Width%x%Height%|%HDR_Format%' /media/input/video.mkv)
test "$source_info" = "1920x1080|"
source_info=$(run_binary "$IMAGE" "$WORKSPACE" mediainfo \
  --Inform='Video;%Width%x%Height%|%HDR_Format%' /media/input/video-4k.mkv)
test "$source_info" = "3840x2160|SMPTE ST 2086"

run_tool "$IMAGE" "$WORKSPACE" sample-encode /media/input/video.mkv 20 >"$WORKSPACE/sdr.log"
run_tool "$IMAGE" "$WORKSPACE" sample-encode /media/input/video-4k.mkv 20 >"$WORKSPACE/hdr.log"

grep -Fq 'Detected resolution: 1920x1080' "$WORKSPACE/sdr.log"
grep -Fq 'Dynamic range: SDR' "$WORKSPACE/sdr.log"
grep -Fq 'Using preset: 1080p' "$WORKSPACE/sdr.log"
grep -Fq 'Sample MediaInfo: 1920x1080||' "$WORKSPACE/sdr.log"
grep -Eq 'Sample MediaInfo: .*crf=20([.]0)?' "$WORKSPACE/sdr.log"

grep -Fq 'Detected resolution: 3840x2160' "$WORKSPACE/hdr.log"
grep -Fq 'Dynamic range: HDR' "$WORKSPACE/hdr.log"
grep -Fq 'Using preset: 4k' "$WORKSPACE/hdr.log"
grep -Fq 'Sample MediaInfo: 3840x2160|SMPTE ST 2086|' "$WORKSPACE/hdr.log"
grep -Eq 'Sample MediaInfo: .*crf=20([.]0)?' "$WORKSPACE/hdr.log"

echo "sample-encode test passed."
