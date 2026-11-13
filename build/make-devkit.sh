#!/bin/sh
# SPDX-License-Identifier: MIT
#
# Builds the Switch 2 devkit archive from source:
#   sh build/make-devkit.sh
#
# The sources are the commits that build/sources pins: libounce, OunceVK and
# kaiHEN (for libkaihen). The script fetches each into sources/<name> (kept
# between runs), builds OunceVK's build image from OunceVK's
# switch2/toolchain/Dockerfile, and in that image builds libounce, OunceVK
# (its Rust sysroot, host tools and the archives that the devkit ships) and
# libkaihen. It writes ounce-devkit.tar.xz in this repository (or OUT), which
# install.sh installs and the Dockerfile builds the devkit image from.
#
# The archive contains:
# - libounce/: libounce (make install-switch2), with its licenses, and
#   libounce/cmake/: the CMake toolchain (toolchain/cmake).
# - portlibs/switch2/: the OunceVK portlib (switch2/build/package-portlib.sh)
#   and libkaihen (libkaihen's make install): include/kaihen.h,
#   include/kaihen/, -lkaihen and -lkaihen_plugin; and
#   bin/aarch64-none-elf-cmake.
# - switch2vars.sh: the build environment for CMake, Meson and autotools.
# - ounce-devkit-version.txt: the version and the source commits.
#
# Environment:
#   LIBOUNCE, OUNCEVK, KAIHEN
#               a local checkout to use in place of the pinned commit (its
#               committed HEAD for libounce; OunceVK builds in the checkout)
#   OUNCEVK_PREBUILT=1
#               use OunceVK's existing build/native-headless and
#               build/native-gl instead of building them
#   IMAGE       the OunceVK build image to use (default: built from OunceVK's
#               switch2/toolchain/Dockerfile, tagged ounce-devkit-ouncevk:<commit>)
#   VERSION     the devkit version (default: the date)
#   OUT         the archive to write (default: ounce-devkit.tar.xz here)
#   CONTAINER   podman or docker (default: podman when it is installed)
#   WORK        the work folder (default: work/ here; it is replaced)

set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
DEVKIT="$(cd "$HERE/.." && pwd)"
TOOLCHAIN="$DEVKIT/toolchain"
SOURCES="$DEVKIT/sources"
VERSION="${VERSION:-$(date +%Y%m%d)}"
OUT="${OUT:-$DEVKIT/ounce-devkit.tar.xz}"
WORK="${WORK:-$DEVKIT/work}"
OUNCEVK_PREBUILT="${OUNCEVK_PREBUILT:-0}"
CONTAINER="${CONTAINER:-$(command -v podman > /dev/null && echo podman || echo docker)}"

# Runs a container as the current user, so that the files it writes in the
# mounted folders belong to that user.
run_container() {
    if [ "$CONTAINER" = podman ]; then
        podman run --rm --security-opt label=disable --userns=keep-id "$@"
    else
        docker run --rm --user "$(id -u):$(id -g)" "$@"
    fi
}

# Prints the checkout to build NAME from: the local checkout that the
# environment names, or the commit that build/sources pins, fetched into
# sources/NAME.
#   source_tree NAME OVERRIDE
source_tree() {
    if [ -n "$2" ]; then
        (cd "$2" && pwd)
        return
    fi
    line=$(grep "^$1 " "$HERE/sources")
    url=$(echo "$line" | awk '{print $2}')
    commit=$(echo "$line" | awk '{print $3}')
    tree="$SOURCES/$1"
    if [ "$(git -C "$tree" rev-parse HEAD 2> /dev/null)" != "$commit" ]; then
        echo "== fetch $1 $commit" >&2
        mkdir -p "$tree"
        git -C "$tree" init -q
        git -C "$tree" fetch -q --depth=1 "$url" "$commit"
        git -C "$tree" checkout -q --force FETCH_HEAD
    fi
    echo "$tree"
}

LIBOUNCE=$(source_tree libounce "${LIBOUNCE:-}")
OUNCEVK=$(source_tree ouncevk "${OUNCEVK:-}")
KAIHEN=$(source_tree kaihen "${KAIHEN:-}")
revision() {
    git -C "$1" rev-parse --short=12 HEAD
}

rm -rf "$WORK"
mkdir -p "$WORK/libounce"
# libounce builds in a clean copy, so its debug information names no host
# path.
git -C "$LIBOUNCE" archive HEAD | tar -x -C "$WORK/libounce"
{
    echo "ounce-devkit $VERSION"
    echo "libounce $(revision "$LIBOUNCE")"
    echo "ouncevk $(revision "$OUNCEVK")"
    echo "kaihen $(revision "$KAIHEN")"
} > "$WORK/ounce-devkit-version.txt"

image="${IMAGE:-ounce-devkit-ouncevk:$(revision "$OUNCEVK")}"
if ! "$CONTAINER" image inspect "$image" > /dev/null 2>&1; then
    echo "== build image $image" >&2
    "$CONTAINER" build -t "$image" "$OUNCEVK/switch2/toolchain" > "$WORK/image.log" 2>&1
fi

echo "== build libounce, OunceVK and libkaihen; package" >&2
# OunceVK's cross files take libounce's nx/ from /ounce-nx.
run_container -v "$WORK/libounce:/libounce" -v "$WORK/libounce/nx:/ounce-nx" \
    -v "$OUNCEVK:/work" \
    -v "$TOOLCHAIN:/tools:ro" -v "$KAIHEN/libkaihen:/kaihen/libkaihen:ro" \
    -v "$WORK:/out" -w /work -e DEVKITPRO=/opt/devkitpro -e SRC=/work \
    -e NVK_LIBOUNCE_NX=/ounce-nx -e OUNCEVK_PREBUILT="$OUNCEVK_PREBUILT" \
    "$image" bash -euc '
        root=/out/stage/opt/devkitpro
        make -C /libounce/nx -j"$(nproc)" SWITCH2=1 install-switch2 \
            DESTDIR=/out/stage > /out/libounce-build.log

        if [ "$OUNCEVK_PREBUILT" != 1 ]; then
            # OunceVK, as its switch2/README.md builds it: the Rust standard
            # library and host tools, then the two Horizon builds; of these
            # only the archives that package-portlib.sh ships.
            export PATH=/work/build/host-tools/bin:$PATH
            {
                bash switch2/toolchain/rust/build-sysroot.sh
                bash switch2/toolchain/build-host-tools.sh
                bash switch2/build/configure-native-headless.sh
                bash switch2/build/configure-gl.sh
                archives() {
                    for list in "$@"; do
                        sed -n "/^$list=\"/,/^\"/p" switch2/build/package-portlib.sh | grep "^src/"
                    done
                }
                nvk="src/nouveau/vulkan/libnvk.a src/nouveau/vulkan/libnvk_native_map.a"
                ninja -C build/native-headless $nvk $(archives DRIVER_ARCHIVES)
                ninja -C build/native-gl $nvk $(archives DRIVER_ARCHIVES GL_ARCHIVES)
            } > /out/ouncevk-build.log 2>&1
        fi
        sh switch2/build/package-portlib.sh $root/portlibs/switch2 > /out/ouncevk-package.log

        cp /tools/switch2vars.sh /out/ounce-devkit-version.txt $root/
        cp -r /tools/cmake $root/libounce/
        cp /tools/aarch64-none-elf-cmake $root/portlibs/switch2/bin/
        make -C /kaihen/libkaihen -j"$(nproc)" install \
            LIBOUNCE=$root/libounce PORTLIB=$root/portlibs/switch2 \
            OUT=/out/libkaihen > /out/libkaihen-build.log
        tar -C $root -cJf /out/ounce-devkit.tar.xz libounce portlibs switch2vars.sh \
            ounce-devkit-version.txt
    '

mv "$WORK/ounce-devkit.tar.xz" "$OUT"
rm -rf "$WORK/stage" "$WORK/libounce"
cat "$WORK/ounce-devkit-version.txt"
ls -la "$OUT"
