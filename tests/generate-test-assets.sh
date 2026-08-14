#!/usr/bin/env bash

# Keep asset creation separate from the tests so every test run starts with
# the same small, known-good inputs without storing generated binary data in Git.
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
PROJECT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
OUTPUT_DIR="$SCRIPT_DIR/assets"
FORCE=false
IMAGE=${VIDEO_TOOLKIT_TEST_IMAGE:-video-toolkit:latest}
IN_CONTAINER=false

usage() {
  echo "Usage: $0 [--output-dir <folder>] [--force] [--image <image>] [--in-container]" >&2
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --help|-h)
      usage
      exit 0
      ;;
    --output-dir)
      if [[ $# -lt 2 ]]; then
        echo "Error: --output-dir requires a folder." >&2
        usage
        exit 1
      fi
      OUTPUT_DIR=$2
      shift 2
      ;;
    --force)
      FORCE=true
      shift
      ;;
    --image)
      if [[ $# -lt 2 ]]; then
        echo "Error: --image requires an image name." >&2
        usage
        exit 1
      fi
      IMAGE=$2
      shift 2
      ;;
    --in-container)
      IN_CONTAINER=true
      shift
      ;;
    *)
      echo "Error: unknown option '$1'." >&2
      usage
      exit 1
      ;;
  esac
done

# Keep media generation reproducible with the same ffmpeg build and codecs as
# the application. The --in-container path is deliberately explicit so this
# script cannot accidentally recurse when it is invoked by the container.
if [[ $IN_CONTAINER == false ]]; then
  if ! command -v docker >/dev/null 2>&1; then
    echo "Error: docker is required to generate test assets." >&2
    exit 1
  fi

  mkdir -p -- "$OUTPUT_DIR"
  container_args=(--in-container --output-dir /output)
  if [[ $FORCE == true ]]; then
    container_args+=(--force)
  fi
  docker run --rm \
    --user "$(id -u):$(id -g)" \
    --entrypoint /bin/bash \
    -v "$PROJECT_DIR:/workspace" \
    -v "$OUTPUT_DIR:/output" \
    -w /workspace \
    "$IMAGE" \
    /workspace/tests/generate-test-assets.sh "${container_args[@]}"
  exit $?
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "Error: ffmpeg is required but was not found in PATH." >&2
  exit 1
fi

mkdir -p -- "$OUTPUT_DIR"

generate_asset() {
  local output=$1
  shift

  if [[ -e $output && $FORCE == false ]]; then
    echo "Asset already exists: $output"
    return
  fi

  echo "Generating test asset: $output"
  ffmpeg -hide_banner -loglevel error -y "$@" "$output"
  echo "Created $(du -h "$output" | awk '{print $1}') asset."
}

# This asset deliberately includes audio because it is used by the AAC and
# E-AC-3 scripts as well as by video-only operations.
generate_asset "$OUTPUT_DIR/test-video-1080p-sdr.mkv" \
  -f lavfi -i "testsrc2=size=1920x1080:rate=24" \
  -f lavfi -i "sine=frequency=440:sample_rate=48000" \
  -t 8 \
  -map 0:v:0 -map 1:a:0 \
  -c:v libx264 -preset slower -crf 17 -pix_fmt yuv420p \
  -c:a aac -b:a 192k \
  -color_primaries bt709 -color_trc bt709 -colorspace bt709 \
  -metadata title="Video Toolkit 1080p SDR test asset" \
  -metadata:s:a:0 language=eng

# HDR10 is practical to synthesize: the asset uses a BT.2020/PQ 10-bit
# signal and carries static HDR10 mastering metadata. setparams supplies the
# source color information so zscale has an explicit conversion path.
generate_asset "$OUTPUT_DIR/test-video-4k-hdr10.mkv" \
  -f lavfi -i "testsrc2=size=3840x2160:rate=24" \
  -f lavfi -i "sine=frequency=440:sample_rate=48000" \
  -t 8 \
  -map 0:v:0 -map 1:a:0 \
  -vf "setparams=colorspace=bt709:color_primaries=bt709:color_trc=bt709,format=gbrpf32le,zscale=transfer=smpte2084:primaries=bt2020:matrix=bt2020nc,format=yuv420p10le" \
  -c:v libx265 -preset slow -crf 20 -pix_fmt yuv420p10le \
  -x265-params "colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc:hdr10=1:master-display=G(13250,34500)B(7500,3000)R(34000,16000)WP(15635,16450)L(10000000,1):max-cll=1000,400" \
  -color_primaries bt2020 -color_trc smpte2084 -colorspace bt2020nc \
  -af "pan=5.1|FL=c0|FR=c0|FC=c0|LFE=c0|BL=c0|BR=c0" \
  -c:a eac3 -b:a 640k -ac 6 \
  -metadata title="Video Toolkit 4K HDR10 test asset" \
  -metadata:s:a:0 language=eng
