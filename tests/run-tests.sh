#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
IMAGE=${VIDEO_TOOLKIT_TEST_IMAGE:-video-toolkit:latest}

test_path() {
  case $1 in
    entrypoint) echo "$SCRIPT_DIR/test-entrypoint.sh" ;;
    bitrate-rename) echo "$SCRIPT_DIR/test-bitrate-rename.sh" ;;
    encode-aac) echo "$SCRIPT_DIR/test-encode-aac.sh" ;;
    encode-eac3) echo "$SCRIPT_DIR/test-encode-eac3.sh" ;;
    mkv-clean) echo "$SCRIPT_DIR/test-mkv-clean.sh" ;;
    sample-encode) echo "$SCRIPT_DIR/test-sample-encode.sh" ;;
    *) return 1 ;;
  esac
}

usage() {
  echo "Usage: $0 [--image <name:tag>] [script ...]" >&2
  echo "Scripts: entrypoint bitrate-rename encode-aac encode-eac3 mkv-clean sample-encode" >&2
}

selected=()
while [[ $# -gt 0 ]]; do
  case $1 in
    --image)
      if [[ $# -lt 2 ]]; then
        echo "Error: --image requires an image name or tag." >&2
        usage
        exit 1
      fi
      IMAGE=$2
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      selected+=("$1")
      shift
      ;;
  esac
done

if [[ ${#selected[@]} -eq 0 ]]; then
  selected=(entrypoint bitrate-rename encode-aac encode-eac3 mkv-clean sample-encode)
fi

for test_name in "${selected[@]}"; do
  if ! test_path "$test_name" >/dev/null; then
    echo "Error: unknown test '$test_name'." >&2
    usage
    exit 1
  fi
done

"$SCRIPT_DIR/test-syntax.sh"

if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker is required to run the tests." >&2
  exit 1
fi

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "Error: Docker image '$IMAGE' does not exist. Build it first, for example:" >&2
  echo "  docker build --tag '$IMAGE' '$ROOT_DIR'" >&2
  exit 1
fi

echo "Generating test assets in Docker image: $IMAGE"
VIDEO_TOOLKIT_TEST_IMAGE="$IMAGE" \
  "$SCRIPT_DIR/generate-test-assets.sh" --image "$IMAGE"

TEST_ROOT=$(mktemp -d)
cleanup() {
  rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT

for test_name in "${selected[@]}"; do
  echo "Running test: $test_name"
  "$(test_path "$test_name")" "$IMAGE" "$TEST_ROOT/$test_name"
done

echo "All selected tests passed."
