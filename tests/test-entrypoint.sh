#!/usr/bin/env bash

set -euo pipefail

IMAGE=${1:?image name required}
WORKSPACE=${2:?workspace required}

source "$(dirname -- "${BASH_SOURCE[0]}")/test-common.sh"
setup_workspace "$WORKSPACE"

# Both invocations must fail because the entrypoint requires a known command
# and arguments; suppress output so the assertions focus on exit status.
if docker run --rm "$IMAGE" >/dev/null 2>&1; then
  echo "Expected missing command to fail." >&2
  exit 1
fi

if docker run --rm "$IMAGE" unknown-command >/dev/null 2>&1; then
  echo "Expected unknown command to fail." >&2
  exit 1
fi

echo "Entrypoint tests passed."
