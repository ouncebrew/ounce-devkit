# SPDX-License-Identifier: MIT
#
# The build environment for Switch 2 with libounce. Source this file before
# you configure a CMake, Meson or autotools project. It is the Switch 2
# version of devkitPro's switchvars.sh.
. "${DEVKITPRO}/devkita64.sh"

export PORTLIBS_PREFIX="${DEVKITPRO}/portlibs/switch2"
export PATH="${PORTLIBS_PREFIX}/bin:${DEVKITPRO}/portlibs/switch/bin:$PATH"

# The Switch 2's CPU, from libounce's switch2_cpu.mk.
SWITCH2_CPU="$(sed -n 's/^SWITCH2_CPU[[:space:]]*:=[[:space:]]*//p' "${DEVKITPRO}/libounce/switch2_cpu.mk")"
export ARCH="${SWITCH2_CPU} -mtp=soft -fPIC -ftls-model=local-exec"
export CFLAGS="${ARCH} -O2 -ffunction-sections -fdata-sections"
export CXXFLAGS="${CFLAGS}"
export CPPFLAGS="-D__SWITCH__ -D__SWITCH2__ -I${PORTLIBS_PREFIX}/include -I${DEVKITPRO}/portlibs/switch/include -isystem ${DEVKITPRO}/libounce/include"
export LDFLAGS="${ARCH} -L${PORTLIBS_PREFIX}/lib -L${DEVKITPRO}/portlibs/switch/lib -L${DEVKITPRO}/libounce/lib"
export LIBS="-lounce"
