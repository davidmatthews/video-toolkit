#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
source "$SCRIPT_DIR/test-common.sh"

IMAGE=${1:?image name required}
WORKSPACE=${2:?workspace required}
setup_workspace "$WORKSPACE"
mkdir -p -- "$WORKSPACE/input"
# Give the fixture the RF suffix expected by mkv-clean without changing its
# media contents.
copy_asset "$SCRIPT_DIR/assets/test-video-1080p-sdr.mkv" "$WORKSPACE/input/video-rf20.00.mkv"

run_tool "$IMAGE" "$WORKSPACE" mkv-clean /media/input/video-rf20.00.mkv
# Verify both normalized output naming and preservation of the input.
test -f "$WORKSPACE/input/video-RF20.mkv"
test -f "$WORKSPACE/input/video-rf20.00.mkv"

echo "mkv-clean smoke test passed."
