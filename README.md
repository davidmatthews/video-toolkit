# Video Toolkit

A Docker image containing small command-line tools for working with video files.

## Status

`bitrate-rename`, `mkv-clean`, `encode-aac`, and `encode-eac3` are implemented.
`sample-encode` is implemented.

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

### `encode-aac`

Encodes the first audio track in each supported video file as stereo AAC at
192 kbps, while copying video and subtitle streams. Output defaults to a
sibling directory named `<input> (AAC)`.

Use `--dry-run` to preview work, or `--output-dir <folder>` to choose the
destination directory:

```bash
docker run --rm -v "$PWD:/media" video-toolkit \
  encode-aac /media --output-dir /media/aac --dry-run
```

### `encode-eac3`

Encodes only the first audio track as E-AC-3. Its bitrate is selected from the
track's channel count: 96k, 192k, 320k, 384k, 448k, 640k, 768k, or 1024k for
one through eight channels respectively. Video and subtitle streams are copied.
Output defaults to a sibling directory named `<input> (EAC3)`. It also supports
`--dry-run` and `--output-dir <folder>`.

### `mkv-clean`

Cleans a HandBrake-produced MKV by removing attachments, the container title,
global tags, and track tags. It also removes HandBrake-generated audio mixdown
titles while preserving other track metadata, subtitles, and chapters. The
output is written beside the input with an uppercase `RF` suffix and trailing
RF decimal zeroes removed. The input is left unchanged, and an existing output
path is never overwritten:

```bash
docker run --rm -v "$PWD:/media" video-toolkit \
  mkv-clean /media/video-rf20.00.mkv
```

### `sample-encode`

Encodes short video-only samples with the resolution-appropriate HandBrake
preset and estimates the resulting average video bitrate. Samples default to
10 seconds every 5 minutes and are deleted automatically after measurement.
The optional `animation` argument selects the animation preset.

```bash
docker run --rm -v "$PWD:/media" video-toolkit \
  sample-encode /media/video.mkv 20 animation
```

Omit `animation` to use the live-action preset.

## Requirements

- Docker
