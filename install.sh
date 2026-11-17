#!/bin/sh
# SPDX-License-Identifier: MIT
#
# Installs the Switch 2 homebrew devkit into a devkitPro installation, from
# the [ounce] pacman repository at https://pkg.ouncebrew.org:
#   sh install.sh
#
# It does these steps with devkitPro pacman (dkp-pacman, or pacman on Arch
# Linux and MSYS2 with devkitPro's repositories):
# 1. It adds the [ounce] repository's signing key, after checking that its
#    fingerprint is the one below.
# 2. It adds [ounce] to pacman's configuration.
# 3. It installs the devkit's packages, and with them the devkitPro packages
#    that they depend on (devkitA64, switch-tools, the CMake toolchains):
#    - libounce: the libnx-compatible library for Switch 2, in
#      $DEVKITPRO/libounce, with switch2vars.sh and the CMake toolchain.
#    - ouncevk: Vulkan, EGL, OpenGL and OpenGL ES, in
#      $DEVKITPRO/portlibs/switch2.
#    - libkaihen: kaiHEN's homebrew API (kaihen.h), in
#      $DEVKITPRO/portlibs/switch2.
# Update them later as other devkitPro packages: dkp-pacman -Syu.
set -eu

# The [ounce] repository and the fingerprint of its signing key.
REPO_URL="${OUNCE_REPO_URL:-https://pkg.ouncebrew.org}"
SIGNING_KEY=DFEAE7FA965D1E6C0D41D4D75DB9FDBFA4A4DE29
PACKAGES="libounce ouncevk libkaihen"

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

# Writes a URL to a file, with curl or wget.
download() {
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL -o "$2" "$1"
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "$2" "$1"
    else
        echo "install.sh: curl or wget is needed" >&2
        exit 1
    fi
}

# devkitPro pacman: dkp-pacman with its own configuration, or pacman on Arch
# Linux and MSYS2 when it has devkitPro's repositories.
if command -v dkp-pacman >/dev/null 2>&1; then
    PACMAN=dkp-pacman
    PACMAN_KEY=dkp-pacman-key
    PACMAN_CONF=/opt/devkitpro/pacman/etc/pacman.conf
elif command -v pacman >/dev/null 2>&1 && pacman -Sl dkp-libs >/dev/null 2>&1; then
    PACMAN=pacman
    PACMAN_KEY=pacman-key
    PACMAN_CONF=/etc/pacman.conf
else
    cat >&2 <<MESSAGE
install.sh: devkitPro pacman is not installed. The instructions are at
  https://devkitpro.org/wiki/devkitPro_pacman
Then run this script again. You can also use the Docker image instead; see
README.md.
MESSAGE
    exit 1
fi

echo "Adding the [ounce] signing key $SIGNING_KEY"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
download "$REPO_URL/ounce.gpg" "$work/ounce.gpg"
as_root "$PACMAN_KEY" --add "$work/ounce.gpg"
# Fails when the downloaded key is not the one named here.
as_root "$PACMAN_KEY" --lsign-key "$SIGNING_KEY"

if ! grep -q '^\[ounce\]' "$PACMAN_CONF"; then
    echo "Adding [ounce] to $PACMAN_CONF"
    printf '\n[ounce]\nServer = %s\n' "$REPO_URL" | as_root tee -a "$PACMAN_CONF" >/dev/null
fi

# The devkit before these packages was unpacked from an archive. Its files
# belong to no package; the packages replace them.
overwrite="--overwrite /opt/devkitpro/libounce/* --overwrite /opt/devkitpro/portlibs/switch2/*"
overwrite="$overwrite --overwrite /opt/devkitpro/switch2vars.sh"

echo "Installing $PACKAGES"
# The patterns are pacman's: the shell must not expand them.
set -f
# shellcheck disable=SC2086
as_root "$PACMAN" -Sy --needed --noconfirm $overwrite $PACKAGES
set +f
if [ -f /opt/devkitpro/ounce-devkit-version.txt ]; then
    as_root rm -f /opt/devkitpro/ounce-devkit-version.txt
fi
"$PACMAN" -Q $PACKAGES
