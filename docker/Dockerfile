# Buildroot build environment for the PICO-8 Raspberry Pi Zero 2 W image.
#
# Native linux/arm64 on Apple Silicon — do NOT add `--platform linux/amd64`.
# Buildroot compiles its own cross-toolchain from source, so the host being
# ARM costs nothing; emulating x86 would make a multi-hour build far worse.
#
# See docs/build-environment.md for why the build must not run on macOS directly.

FROM debian:bookworm-slim

# Buildroot's mandatory + recommended host dependencies, plus what the Linux
# kernel and the Raspberry Pi firmware packages need. Buildroot builds most of
# its own host tools (cmake, genimage, mtools, dosfstools), so this list is
# deliberately close to the documented minimum.
RUN apt-get update && apt-get install -y --no-install-recommends \
        bc \
        binutils \
        bison \
        build-essential \
        bzip2 \
        ca-certificates \
        cpio \
        diffutils \
        file \
        findutils \
        flex \
        gawk \
        git \
        gzip \
        libelf-dev \
        libncurses-dev \
        libssl-dev \
        locales \
        make \
        patch \
        perl \
        pkg-config \
        python3 \
        rsync \
        sed \
        tar \
        unzip \
        wget \
        which \
        xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Buildroot refuses to build as root. Create an unprivileged user whose UID
# matches the macOS default (501 maps to 1000 through Docker Desktop's
# virtiofs translation, so bind-mounted repo files stay writable).
ARG UID=1000
ARG GID=1000
RUN groupadd -g "${GID}" br 2>/dev/null || true \
 && useradd -m -u "${UID}" -g "${GID}" -s /bin/bash br

# A predictable locale — Buildroot's own scripts and several package builds
# misbehave under UTF-8 collation.
ENV LC_ALL=C \
    LANG=C

# /src  : this repository, bind-mounted from macOS (case-insensitive APFS)
# /build: Buildroot output — a named Docker volume on ext4 inside the Linux VM.
#         ALL tarball extraction happens here. This is the whole reason the
#         build works: the kernel source contains filenames differing only by
#         case, which APFS would silently collapse.
# /dl   : Buildroot download cache, also a named volume (persists across builds)
RUN mkdir -p /build /dl /ccache && chown -R br:br /build /dl /ccache

USER br
WORKDIR /src

CMD ["/bin/bash"]
