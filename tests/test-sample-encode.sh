#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
source "$SCRIPT_DIR/test-common.sh"

IMAGE=${1:?image name required}
WORKSPACE=${2:?workspace required}
setup_workspace "$WORKSPACE"
mkdir -p -- "$WORKSPACE/input"
# The 1080p SDR fixture selects the standard preset while keeping this smoke
# test cheaper than running the 4K HDR input.
copy_asset "$SCRIPT_DIR/assets/test-video-1080p-sdr.mkv" "$WORKSPACE/input/video.mkv"

# This is intentionally a smoke test initially; detailed bitrate and preset
# assertions can be added without changing the runner contract.
run_tool "$IMAGE" "$WORKSPACE" sample-encode /media/input/video.mkv 20

echo "sample-encode smoke test passed."
