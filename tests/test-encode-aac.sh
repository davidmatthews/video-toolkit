#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
source "$SCRIPT_DIR/test-common.sh"

IMAGE=${1:?image name required}
WORKSPACE=${2:?workspace required}
setup_workspace "$WORKSPACE"
mkdir -p -- "$WORKSPACE/input"

for asset in test-video-1080p-sdr.mkv test-video-4k-hdr10.mkv; do
  input_dir="$WORKSPACE/input/${asset%.mkv}"
  output_dir="$WORKSPACE/output/${asset%.mkv}"
  mkdir -p -- "$input_dir"
  copy_asset "$SCRIPT_DIR/assets/$asset" "$input_dir/video.mkv"
  run_tool "$IMAGE" "$WORKSPACE" encode-aac "/media/input/${asset%.mkv}" \
    --output-dir "/media/output/${asset%.mkv}"

  audio_info=$(run_binary "$IMAGE" "$WORKSPACE" mediainfo \
    --Inform='Audio;%Format%|%Channels%|%ChannelLayout%' \
    "/media/output/${asset%.mkv}/video.mkv")
  test "$audio_info" = "AAC|2|L R"

  audio_bitrate=$(run_binary "$IMAGE" "$WORKSPACE" bash -c '
    duration=$(ffprobe -v error -show_entries format=duration \
      -of default=nk=1:nw=1 "$1")
    ffprobe -v error -select_streams a:0 -show_entries packet=size \
      -of csv=p=0 "$1" | awk -v duration="$duration" \
      "BEGIN { total = 0 } { total += \$1 } END { printf \"%.0f\\n\", total * 8 / duration / 1000 }"
  ' bash "/media/output/${asset%.mkv}/video.mkv")
  # The native AAC encoder writes short clips as VBR; assert the measured
  # bitrate remains around the requested 192 kbps target.
  test "$audio_bitrate" -ge 150
  test "$audio_bitrate" -le 210
done

echo "encode-aac test passed."
