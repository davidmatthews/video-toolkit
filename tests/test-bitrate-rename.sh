#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=test-common.sh
source "$SCRIPT_DIR/test-common.sh"

IMAGE=${1:?image name required}
WORKSPACE=${2:?workspace required}
setup_workspace "$WORKSPACE"
mkdir -p -- "$WORKSPACE/input"
# Use a real video stream so MediaInfo can calculate a bitrate without the
# higher cost of the 4K fixture.
copy_asset "$SCRIPT_DIR/assets/test-video-1080p-sdr.mkv" "$WORKSPACE/input/video.mkv"

# Dry-run exercises discovery, dependency availability, and filename handling
# without making the test depend on an encoder's exact bitrate.
run_tool "$IMAGE" "$WORKSPACE" bitrate-rename /media/input --dry-run
# A dry-run must leave the source at its original path.
test -f "$WORKSPACE/input/video.mkv"

echo "bitrate-rename smoke test passed."
