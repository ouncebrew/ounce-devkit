# SPDX-License-Identifier: MIT
#
# devkitPro's Switch image with the Switch 2 devkit installed from the [ounce]
# pacman repository, and glslang for Vulkan shaders:
#   docker build -t ounce-devkit .
FROM docker.io/devkitpro/devkita64:20260219

# devkitPro's newest image has devkitA64 r29 (GCC 15). Programs are built with
# the toolchain that devkitPro's repository serves now, and their C++ library
# must be at least as new as the one they were built with: update devkitA64,
# as libounce's package build does.
RUN dkp-pacman -Sy --noconfirm devkitA64 && \
    /opt/devkitpro/devkitA64/bin/aarch64-none-elf-gcc --version | head -n 1

RUN apt-get update && \
    apt-get install -y --no-install-recommends glslang-tools curl ca-certificates && \
    rm -rf /var/lib/apt/lists/*

COPY install.sh /tmp/install.sh
RUN sh /tmp/install.sh && rm /tmp/install.sh
