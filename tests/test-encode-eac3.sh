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
  run_tool "$IMAGE" "$WORKSPACE" encode-eac3 "/media/input/${asset%.mkv}" \
    --output-dir "/media/output/${asset%.mkv}"
  audio_info=$(run_binary "$IMAGE" "$WORKSPACE" mediainfo \
    --Inform='Audio;%Format%|%Channels%|%BitRate%' \
    "/media/output/${asset%.mkv}/video.mkv")
  case "$asset" in
    test-video-1080p-sdr.mkv) test "$audio_info" = "E-AC-3|1|96000" ;;
    test-video-4k-hdr10.mkv) test "$audio_info" = "E-AC-3|6|640000" ;;
  esac
done

echo "encode-eac3 test passed."
