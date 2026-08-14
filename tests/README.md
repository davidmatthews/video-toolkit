# Tests

This directory contains tests and the test inputs used to exercise the video
toolkit's Docker commands and scripts.

## Running tests

Build the image first, then run the complete Docker-backed smoke suite from the
repository root:

```bash
docker build --tag video-toolkit:latest .
./tests/run-tests.sh
```

The runner does not build the image; it verifies that the requested image
already exists. Use `--image` or `VIDEO_TOOLKIT_TEST_IMAGE` when the image has a
different name or tag. Individual tests can be selected by name:

```bash
./tests/run-tests.sh --image my-video-toolkit:dev encode-aac mkv-clean
```

The test runner generates the media assets using the requested image and runs
each selected test in an isolated temporary workspace. The same command is
intended for local use and GitHub Actions.

## Assets

Run `generate-test-assets.sh` before the tests to create the generated video
inputs under `assets/`:

- `test-video-1080p-sdr.mkv` — 1080p SDR H.264 video with AAC audio.
- `test-video-4k-hdr10.mkv` — 4K HDR10 10-bit HEVC video with 5.1 E-AC-3 audio.

The videos are generated locally and ignored by Git. Tests that need a
specialized input should derive it from one of these base assets rather than
adding another generated binary file to the repository.
