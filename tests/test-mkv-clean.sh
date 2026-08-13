#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
source "$SCRIPT_DIR/test-common.sh"

IMAGE=${1:?image name required}
WORKSPACE=${2:?workspace required}
setup_workspace "$WORKSPACE"
mkdir -p -- "$WORKSPACE/input"
copy_asset "$SCRIPT_DIR/assets/test-video-1080p-sdr.mkv" "$WORKSPACE/input/video-source.mkv"

# Generate the tiny global-tags input in the isolated workspace so the test
# does not depend on an ignored auxiliary file being present in a checkout.
run_binary "$IMAGE" "$WORKSPACE" bash -c \
  'printf "%s\\n" "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" "<Tags>" "  <Tag>" "    <Targets />" "    <Simple>" "      <Name>TEST_GLOBAL_TAG</Name>" "      <String>must be removed</String>" "    </Simple>" "  </Tag>" "</Tags>" > /media/tags.xml'

# Build the HandBrake-like input inside the image so the test exercises real
# Matroska tags and track names, rather than merely checking the output name.
run_binary "$IMAGE" "$WORKSPACE" mkvmerge \
  --output /media/input/video-rf20.00.mkv \
  --title "fixture title" \
  --global-tags /media/tags.xml \
  --track-name 1:Stereo \
  /media/input/video-source.mkv

run_tool "$IMAGE" "$WORKSPACE" mkv-clean /media/input/video-rf20.00.mkv
# Verify normalized output naming and preservation of the input.
test -f "$WORKSPACE/input/video-RF20.mkv"
test -f "$WORKSPACE/input/video-rf20.00.mkv"

general_title=$(run_binary "$IMAGE" "$WORKSPACE" mediainfo --Inform='General;%Title%' /media/input/video-RF20.mkv)
audio_title=$(run_binary "$IMAGE" "$WORKSPACE" mediainfo --Inform='Audio;%Title%' /media/input/video-RF20.mkv)
test -z "$general_title"
test -z "$audio_title"
if run_binary "$IMAGE" "$WORKSPACE" mkvinfo --verbose /media/input/video-RF20.mkv | grep -q 'TEST_GLOBAL_TAG\|must be removed'; then
  echo "Global tag survived mkv-clean." >&2
  exit 1
fi

echo "mkv-clean test passed."
