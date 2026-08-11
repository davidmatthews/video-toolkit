# Video Toolkit

A Docker image containing small command-line tools for working with video files.

## Status

`bitrate-rename` is currently implemented. The other commands are placeholders and
are not ready for use yet.

## Getting started

Build the image from the repository root:

```bash
docker build -t video-toolkit .
```

Commands operate on files mounted into the container. To work with the files in
your current directory, mount it at `/media`:

```bash
docker run --rm -v "$PWD:/media" video-toolkit <command> [arguments...]
```

## Commands

### `bitrate-rename`

Reads each supported video file in a directory and appends its video bitrate to
the filename. For example, `video.mkv` might become `video-8000kbps.mkv`.

The command processes files in the specified directory only; it does not search
subdirectories. Supported extensions are `.mp4`, `.mkv`, `.mov`, `.avi`, `.flv`,
`.wmv`, and `.m4v` (case-insensitive).

#### Preview changes

Use `--dry-run` to see what would be renamed without changing any files:

```bash
docker run --rm -v "$PWD:/media" video-toolkit \
  bitrate-rename /media --dry-run
```

#### Rename files

Omit `--dry-run` to apply the renames:

```bash
docker run --rm -v "$PWD:/media" video-toolkit \
  bitrate-rename /media
```

Files that already end in `-<number>kbps`, or whose destination filename
already exists, are skipped.

### Planned commands

The following commands are exposed by the image but currently contain TODOs:

- `mkv-clean`
- `sample-encode`
- `encode-aac`
- `encode-eac3`

## Requirements

- Docker
