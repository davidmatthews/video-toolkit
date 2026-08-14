#!/usr/bin/env bash

set -euo pipefail

setup_workspace() {
  TEST_WORKSPACE=$1
  mkdir -p -- "$TEST_WORKSPACE"

  # Each test owns its temporary directory and removes it even when an
  # assertion or Docker command fails. The runner also cleans the parent
  # directory as a final safety net.
  trap 'rm -rf -- "$TEST_WORKSPACE"' EXIT
}

run_tool() {
  local image=$1
  local workspace=$2
  shift 2

  # Match the bind-mounted output ownership to the caller so the host-side
  # cleanup trap can remove files created by the container.
  docker run --rm --user "$(id -u):$(id -g)" -v "$workspace:/media" "$image" "$@"
}

run_binary() {
  local image=$1
  local workspace=$2
  local binary=$3
  shift 3

  # Run image-provided media utilities directly when a test needs to derive a
  # fixture before invoking the toolkit command under test.
  docker run --rm --user "$(id -u):$(id -g)" -v "$workspace:/media" \
    --entrypoint "$binary" "$image" "$@"
}

copy_asset() {
  local source=$1
  local destination=$2
  # Copy inputs into each test workspace so tests cannot modify shared assets.
  mkdir -p -- "$(dirname -- "$destination")"
  cp -- "$source" "$destination"
}
