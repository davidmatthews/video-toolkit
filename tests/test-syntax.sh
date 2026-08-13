#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)

# Check helpers and asset-generation scripts too, even though they are not
# each invoked as standalone Docker commands by the integration suite.
while IFS= read -r -d '' script; do
  bash -n "$script"
done < <(find "$ROOT_DIR/scripts" "$ROOT_DIR/tests" -maxdepth 1 -type f -name '*.sh' -print0 | sort -z)

echo "Shell syntax checks passed."
