# SPDX-License-Identifier: MIT
#
# devkitPro's Switch image with the Switch 2 devkit installed from the [ounce]
# pacman repository, and glslang for Vulkan shaders:
#   docker build -t ounce-devkit .
FROM docker.io/devkitpro/devkita64:20260219

RUN apt-get update && \
    apt-get install -y --no-install-recommends glslang-tools curl ca-certificates && \
    rm -rf /var/lib/apt/lists/*

COPY install.sh /tmp/install.sh
RUN sh /tmp/install.sh && rm /tmp/install.sh
