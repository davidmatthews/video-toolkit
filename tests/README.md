# Tests

This directory contains tests and the test inputs used to exercise the video
toolkit's Docker commands and scripts.

## Assets

Run `generate-test-assets.sh` before the tests to create the generated video
inputs under `assets/`:

- `test-video-1080p-sdr.mkv` — 1080p SDR H.264 video with AAC audio.
- `test-video-4k-hdr10.mkv` — 4K HDR10 10-bit HEVC video with 5.1 E-AC-3 audio.

The videos are generated locally and ignored by Git. Tests that need a
specialized input should derive it from one of these base assets rather than
adding another generated binary file to the repository.
