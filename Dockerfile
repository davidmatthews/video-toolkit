# syntax=docker/dockerfile:1

# Using BtbN's FFmpeg builds, pin a month-end autobuild which are retained for two years.
# Other daily builds are only retained for 14 days and could break a later rebuild.
ARG FFMPEG_BUILD=8.1.2-34-g9b6c8969e0
ARG FFMPEG_RELEASE=autobuild-2026-07-31-14-10

FROM davidmatthews/handbrake-cli:latest

ARG TARGETARCH
ARG FFMPEG_BUILD
ARG FFMPEG_RELEASE

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
        ca-certificates \
        curl \
        git \
        mediainfo \
        mkvtoolnix \
        xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Download and install BtbN's GPL FFmpeg build
RUN set -eux; \
    case "$TARGETARCH" in \
        amd64) \
            FFMPEG_ARCH=linux64; \
            FFMPEG_SHA256=09fc77be269c7053e438b7e96548e4af97604faf96a42c4a3c56a1ad74c22c0a; \
            ;; \
        arm64) \
            FFMPEG_ARCH=linuxarm64; \
            FFMPEG_SHA256=177e40c91564dec3840096f3bf1ffe696b94330585972462cfc739fa29fe0e1a; \
            ;; \
        *) \
            echo "Unsupported architecture: $TARGETARCH" >&2; \
            exit 1; \
            ;; \
    esac; \
    FFMPEG_ARCHIVE="ffmpeg-n${FFMPEG_BUILD}-${FFMPEG_ARCH}-gpl-8.1.tar.xz"; \
    curl --fail --location --retry 3 --show-error --silent \
        --output "/tmp/$FFMPEG_ARCHIVE" \
        "https://github.com/BtbN/FFmpeg-Builds/releases/download/${FFMPEG_RELEASE}/${FFMPEG_ARCHIVE}"; \
    echo "$FFMPEG_SHA256  /tmp/$FFMPEG_ARCHIVE" | sha256sum --check --strict; \
    mkdir --parents /tmp/ffmpeg; \
    tar --extract --file "/tmp/$FFMPEG_ARCHIVE" --strip-components=1 --directory /tmp/ffmpeg; \
    install --mode=0755 /tmp/ffmpeg/bin/ffmpeg /usr/local/bin/ffmpeg; \
    install --mode=0755 /tmp/ffmpeg/bin/ffprobe /usr/local/bin/ffprobe; \
    FFMPEG_INSTALLED_VERSION="$(ffmpeg -version | sed -n 's/^ffmpeg version \([^ ]*\).*/\1/p')"; \
    case "$FFMPEG_INSTALLED_VERSION" in \
        "n${FFMPEG_BUILD}-"*) ;; \
        *) echo "Unexpected FFmpeg version: $FFMPEG_INSTALLED_VERSION" >&2; exit 1 ;; \
    esac; \
    rm -rf /tmp/ffmpeg "/tmp/$FFMPEG_ARCHIVE"

# Download and install custom Handbrake presets.
RUN git clone --depth 1 https://github.com/davidmatthews/handbrake-presets.git /tmp/handbrake-presets \
    && mkdir -p /opt/handbrake-presets \
    && find /tmp/handbrake-presets -type f -name '*.json' -exec cp '{}' /opt/handbrake-presets/ \; \
    && rm -rf /tmp/handbrake-presets

COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY scripts/ /usr/local/lib/video-toolkit/

RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/lib/video-toolkit/*

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
