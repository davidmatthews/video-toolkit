#!/usr/bin/env bash
set -euo pipefail

commands=(
    mkv-clean
    bitrate-rename
    sample-encode
    encode-aac
    encode-eac3
)

if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <command> [arguments...]" >&2
    echo "Available commands: ${commands[*]}" >&2
    exit 1
fi

command_name="$1"
shift

case "$command_name" in
    mkv-clean|bitrate-rename|sample-encode|encode-aac|encode-eac3)
        exec "/usr/local/lib/video-toolkit/$command_name.sh" "$@"
        ;;
    *)
        echo "Unknown command: $command_name" >&2
        echo "Available commands: ${commands[*]}" >&2
        exit 1
        ;;
esac
