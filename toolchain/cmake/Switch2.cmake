# SPDX-License-Identifier: MIT
#
# The CMake toolchain file for Switch 2 programs that use libounce. It is
# installed as $DEVKITPRO/libounce/cmake/Switch2.cmake. Use it with
#
#   aarch64-none-elf-cmake -S . -B build    (after sourcing switch2vars.sh)
#
# or give it to CMake directly:
#
#   cmake -DCMAKE_TOOLCHAIN_FILE=$DEVKITPRO/libounce/cmake/Switch2.cmake ...
#
# It is devkitPro's Switch toolchain (cmake/Switch.cmake, from switch-cmake)
# with these changes:
# - The platform root, NX_ROOT, is libounce in place of libnx. -lnx links
#   libounce, and the default icon and linker specs are libounce's.
# - Packages are found in the Switch 2 portlibs first, then in the Switch 1
#   portlibs. Thus Vulkan and EGL are OunceVK's, and a library that uses only
#   the C library can still come from the Switch 1 portlibs.
# - Platform/NintendoSwitch.cmake next to this file adds __SWITCH2__ and the
#   Switch 2 portlibs to the compile and link flags.
# CMAKE_SYSTEM_NAME stays NintendoSwitch, and NINTENDO_SWITCH is set, so
# projects that test for the Switch build as they do with libnx.
# NINTENDO_SWITCH2 is also set.
cmake_minimum_required(VERSION 3.13)

if(NOT CMAKE_SYSTEM_NAME)
	set(CMAKE_SYSTEM_NAME NintendoSwitch)
endif()

# Our Platform/NintendoSwitch.cmake comes before devkitPro's.
list(INSERT CMAKE_MODULE_PATH 0 "${CMAKE_CURRENT_LIST_DIR}")

# devkitPro's devkitA64 toolchain, from the devkitPro that this devkit is
# installed in. It sets DEVKITPRO.
get_filename_component(OUNCE_DEVKITPRO "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
include("${OUNCE_DEVKITPRO}/cmake/devkitA64.cmake")

set(NX_ROOT ${DEVKITPRO}/libounce)
set(OUNCE_PORTLIBS ${DEVKITPRO}/portlibs/switch2)
set(DKP_INSTALL_PREFIX_INIT ${OUNCE_PORTLIBS})

__dkp_platform_prefix(
	${OUNCE_PORTLIBS}
	${DEVKITPRO}/portlibs/switch
	${NX_ROOT}
)

find_program(PKG_CONFIG_EXECUTABLE NAMES aarch64-none-elf-pkg-config HINTS "${OUNCE_PORTLIBS}/bin" NO_DEFAULT_PATH)
if(NOT PKG_CONFIG_EXECUTABLE)
	message(FATAL_ERROR "Could not find ${OUNCE_PORTLIBS}/bin/aarch64-none-elf-pkg-config: install the Switch 2 devkit again")
endif()

find_program(NX_ELF2NRO_EXE NAMES elf2nro HINTS "${DEVKITPRO}/tools/bin")
find_program(NX_ELF2KIP_EXE NAMES elf2kip HINTS "${DEVKITPRO}/tools/bin")
find_program(NX_ELF2NSO_EXE NAMES elf2nso HINTS "${DEVKITPRO}/tools/bin")
find_program(NX_BUILD_PFS0_EXE NAMES build_pfs0 HINTS "${DEVKITPRO}/tools/bin")
find_program(NX_NACPTOOL_EXE NAMES nacptool HINTS "${DEVKITPRO}/tools/bin")
find_program(NX_NPDMTOOL_EXE NAMES npdmtool HINTS "${DEVKITPRO}/tools/bin")
find_program(NX_UAM_EXE NAMES uam HINTS "${DEVKITPRO}/tools/bin")

find_file(NX_DEFAULT_ICON NAMES default_icon.jpg HINTS "${NX_ROOT}" NO_CMAKE_FIND_ROOT_PATH)
