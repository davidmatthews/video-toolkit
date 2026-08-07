# syntax=docker/dockerfile:1

FROM davidmatthews/handbrake-cli:latest

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
        ca-certificates \
        ffmpeg \
        git \
        mediainfo \
        mkvtoolnix \
    && rm -rf /var/lib/apt/lists/*

# Download and install custom Handbrake presets.
RUN git clone --depth 1 https://github.com/davidmatthews/handbrake-presets.git /tmp/handbrake-presets \
    && mkdir -p /opt/handbrake-presets \
    && find /tmp/handbrake-presets -type f -name '*.json' -exec cp '{}' /opt/handbrake-presets/ \; \
    && rm -rf /tmp/handbrake-presets

COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
