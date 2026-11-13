# SPDX-License-Identifier: MIT
#
# devkitPro's Switch image with the Switch 2 devkit installed, and glslang for
# Vulkan shaders:
#   docker build -t ounce-devkit .
# install.sh uses ounce-devkit.tar.xz in this folder when it is here, or else
# downloads its default devkit version. --build-arg DEVKIT_VERSION=VERSION
# downloads that version instead.
FROM docker.io/devkitpro/devkita64:20260219

RUN apt-get update && \
    apt-get install -y --no-install-recommends glslang-tools && \
    rm -rf /var/lib/apt/lists/*

ARG DEVKIT_VERSION=
COPY . /tmp/ounce-devkit/
RUN sh /tmp/ounce-devkit/install.sh ${DEVKIT_VERSION} && rm -rf /tmp/ounce-devkit
