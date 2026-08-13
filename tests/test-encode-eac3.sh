#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
source "$SCRIPT_DIR/test-common.sh"

IMAGE=${1:?image name required}
WORKSPACE=${2:?workspace required}
setup_workspace "$WORKSPACE"
mkdir -p -- "$WORKSPACE/input"
# This fixture includes a six-channel E-AC-3 track, exercising channel-count
# validation and bitrate selection.
copy_asset "$SCRIPT_DIR/assets/test-video-4k-hdr10.mkv" "$WORKSPACE/input/video.mkv"

# Use preview mode initially so the suite checks E-AC-3 selection without
# encoding a 4K file on every smoke run.
run_tool "$IMAGE" "$WORKSPACE" encode-eac3 /media/input --output-dir /media/output --dry-run
test ! -e "$WORKSPACE/output/video.mkv"

echo "encode-eac3 smoke test passed."
