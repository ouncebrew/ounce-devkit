#!/bin/sh
# SPDX-License-Identifier: MIT
#
# Installs the Switch 2 homebrew devkit into a devkitPro installation.
#
#   sh install.sh                    ounce-devkit.tar.xz next to this script, or
#                                    else download the default version
#   sh install.sh VERSION            download that devkit version, e.g. 20261114
#   sh install.sh ounce-devkit.tar.xz   install that archive
#
# A download comes from the devkit releases (OUNCE_DEVKIT_RELEASES), as
# devkit-VERSION/ounce-devkit-VERSION.tar.xz, and is checked against its SHA-256:
# the one below for the default version, otherwise the published .sha256.
# The script does these steps:
# 1. It makes sure that devkitPro has the Switch toolchain (switch-dev), zlib
#    (switch-zlib) and the environment scripts (dkp-toolchain-vars, which
#    switch2vars.sh sources). If they are missing, it installs them with
#    devkitPro pacman. If devkitPro pacman is missing, it tells you how to
#    get it.
# 2. It unpacks the devkit archive into $DEVKITPRO. This adds:
#    - $DEVKITPRO/libounce: the libounce library, headers and build rules.
#    - $DEVKITPRO/portlibs/switch2: Vulkan, EGL and OpenGL (OunceVK).
#    - $DEVKITPRO/libounce/cmake/Switch2.cmake: the CMake toolchain, and
#      aarch64-none-elf-cmake in portlibs/switch2/bin, which uses it.
#    - $DEVKITPRO/switch2vars.sh: the environment for CMake and autotools.
#    - $DEVKITPRO/ounce-devkit-version.txt: the devkit version.
#
# Set DEVKITPRO to use a devkitPro directory other than /opt/devkitpro.
# The script does not change libnx or the Switch 1 portlibs.

set -eu

# The devkit version that this script installs by default, and its SHA-256.
DEFAULT_VERSION=20261114
DEFAULT_SHA256=f24d5773b1ee1c2b19317f57e8ae54a60fcdcefe493a0e495297c241c4912f59
# Where devkit versions are published.
RELEASES="${OUNCE_DEVKIT_RELEASES:-https://github.com/ouncebrew/ounce-devkit/releases/download}"

usage() {
    echo "usage: sh install.sh [VERSION | ounce-devkit.tar.xz]" >&2
    exit 2
}

# Writes a URL to a file, with curl or wget.
download() {
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL -o "$2" "$1"
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "$2" "$1"
    else
        echo "install.sh: curl or wget is needed to download the devkit" >&2
        exit 1
    fi
}

sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | cut -d' ' -f1
    else
        shasum -a 256 "$1" | cut -d' ' -f1
    fi
}

# Downloads devkit version $1 into ARCHIVE and checks its SHA-256.
download_version() {
    version=$1
    name="ounce-devkit-$version.tar.xz"
    url="$RELEASES/devkit-$version/$name"
    work=$(mktemp -d)
    trap 'rm -rf "$work"' EXIT
    ARCHIVE="$work/$name"
    echo "Downloading $url"
    download "$url" "$ARCHIVE" || {
        echo "install.sh: could not download $url" >&2
        echo "Set OUNCE_DEVKIT_RELEASES, or pass a downloaded ounce-devkit.tar.xz." >&2
        exit 1
    }
    if [ "$version" = "$DEFAULT_VERSION" ]; then
        expected=$DEFAULT_SHA256
    else
        download "$url.sha256" "$work/sha256"
        expected=$(cut -d' ' -f1 "$work/sha256")
    fi
    actual=$(sha256 "$ARCHIVE")
    [ "$actual" = "$expected" ] || {
        echo "install.sh: $name has SHA-256 $actual, expected $expected" >&2
        exit 1
    }
}

[ $# -le 1 ] || usage
HERE=$(cd "$(dirname "$0")" && pwd)
case "${1:-}" in
"")
    if [ -f "$HERE/ounce-devkit.tar.xz" ]; then
        ARCHIVE="$HERE/ounce-devkit.tar.xz"
    else
        download_version "$DEFAULT_VERSION"
    fi
    ;;
*.tar.xz | */*)
    ARCHIVE=$1
    ;;
*)
    download_version "$1"
    ;;
esac
[ -f "$ARCHIVE" ] || {
    echo "install.sh: $ARCHIVE: no such file" >&2
    exit 1
}

DEVKITPRO="${DEVKITPRO:-/opt/devkitpro}"
export DEVKITPRO

# True on Windows (MSYS2), which has no sudo.
is_windows() {
    case "$(uname -s)" in
    MINGW* | MSYS*) return 0 ;;
    *) return 1 ;;
    esac
}

# Runs a command as root, unless the current user is root or on Windows.
as_root() {
    if [ "$(id -u)" -eq 0 ] || is_windows; then
        "$@"
    else
        sudo "$@"
    fi
}

# Runs a command as root if the current user cannot write DIRECTORY.
#   as_owner DIRECTORY COMMAND...
as_owner() {
    directory="$1"
    shift
    if [ -w "$directory" ]; then
        "$@"
    else
        as_root "$@"
    fi
}

# Writes the devkitPro pacman command, or nothing if there is none.
find_pacman() {
    if command -v dkp-pacman >/dev/null 2>&1; then
        echo dkp-pacman
    elif command -v pacman >/dev/null 2>&1 &&
        pacman -Sl dkp-libs >/dev/null 2>&1; then
        # Arch Linux and MSYS2 use pacman with the devkitPro repositories.
        echo pacman
    fi
}

# True if the parts of devkitPro that the devkit needs are installed.
have_devkitpro() {
    [ -x "$DEVKITPRO/devkitA64/bin/aarch64-none-elf-gcc" ] &&
        [ -f "$DEVKITPRO/devkitA64/base_rules" ] &&
        [ -x "$DEVKITPRO/tools/bin/elf2nro" ] &&
        [ -x "$DEVKITPRO/tools/bin/nacptool" ] &&
        [ -f "$DEVKITPRO/portlibs/switch/lib/libz.a" ] &&
        [ -f "$DEVKITPRO/devkita64.sh" ]
}

install_devkitpro() {
    pacman_command="$(find_pacman)"
    if [ -z "$pacman_command" ]; then
        cat >&2 <<EOF
install.sh: the devkitPro Switch toolchain is not in $DEVKITPRO, and
devkitPro pacman is not installed.

Install devkitPro pacman first. The instructions are at
  https://devkitpro.org/wiki/devkitPro_pacman
Then run this script again. It installs switch-dev, switch-zlib and
dkp-toolchain-vars.

You can also use the Docker image instead. See README.md.
EOF
        exit 1
    fi

    echo "Installing switch-dev, switch-zlib and dkp-toolchain-vars with $pacman_command"
    as_root "$pacman_command" -S --needed --noconfirm \
        switch-dev switch-zlib dkp-toolchain-vars || {
        echo "install.sh: $pacman_command failed." >&2
        echo "Run '$pacman_command -Syu' to update the package lists, then" \
            "run this script again." >&2
        exit 1
    }
}

if ! have_devkitpro; then
    install_devkitpro
fi
have_devkitpro || {
    echo "install.sh: devkitPro in $DEVKITPRO is not complete." >&2
    exit 1
}

echo "Unpacking $ARCHIVE into $DEVKITPRO"
as_owner "$DEVKITPRO" rm -rf "$DEVKITPRO/libounce" "$DEVKITPRO/portlibs/switch2"
as_owner "$DEVKITPRO" tar -xJf "$ARCHIVE" -C "$DEVKITPRO"

cat <<EOF

The Switch 2 devkit is installed in $DEVKITPRO.

To build a libnx-style Makefile project for Switch 2, change its include
line to:
  include \$(DEVKITPRO)/libounce/switch2_rules

-lnx then links libounce. For Vulkan, add -lvulkan to LIBS. For OpenGL or
OpenGL ES, add -lEGL. For CMake, Meson or autotools, source
\$DEVKITPRO/switch2vars.sh first. Then use aarch64-none-elf-cmake in
place of cmake.
EOF
