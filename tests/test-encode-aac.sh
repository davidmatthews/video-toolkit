#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
source "$SCRIPT_DIR/test-common.sh"

IMAGE=${1:?image name required}
WORKSPACE=${2:?workspace required}
setup_workspace "$WORKSPACE"
mkdir -p -- "$WORKSPACE/input"
copy_asset "$SCRIPT_DIR/assets/test-video-1080p-sdr.mkv" "$WORKSPACE/input/video.mkv"

# Keep the smoke test fast while checking argument parsing, discovery, and
# ffprobe. A later full test can assert the encoded AAC stream itself.
run_tool "$IMAGE" "$WORKSPACE" encode-aac /media/input --output-dir /media/output --dry-run
# Preview mode must not create an output file.
test ! -e "$WORKSPACE/output/video.mkv"

echo "encode-aac smoke test passed."
