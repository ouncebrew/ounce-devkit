# SPDX-License-Identifier: MIT
#
# The NintendoSwitch platform for Switch 2 (see ../Switch2.cmake). It loads
# devkitPro's platform file, which reads NX_ROOT (libounce) for the headers,
# libraries and linker specs, and keeps its helpers (nx_create_nro and the
# others). Then it adds what Switch 2 needs, as libounce's switch2_rules
# does for Makefiles:
# - The Switch 2's CPU flags, from libounce's switch2_cpu.mk, in
#   place of devkitPro's Switch 1 flags.
# - __SWITCH2__, which the libounce headers need.
# - The Switch 2 portlibs headers and libraries, before the Switch 1
#   portlibs.
include_guard(GLOBAL)

# The headers: libounce, then the Switch 2 portlibs. devkitPro's platform
# file sets these cache entries only when they are not set.
foreach(lang IN ITEMS C CXX ASM)
	set(CMAKE_${lang}_STANDARD_INCLUDE_DIRECTORIES
		"${NX_ROOT}/include;${OUNCE_PORTLIBS}/include" CACHE STRING "")
endforeach()

include("${DEVKITPRO}/cmake/Platform/NintendoSwitch.cmake")

set(NINTENDO_SWITCH2 TRUE)

# Set the flags again with the Switch 2's CPU in place of the Switch 1's.
file(STRINGS "${NX_ROOT}/switch2_cpu.mk" OUNCE_SWITCH2_CPU REGEX "^SWITCH2_CPU[ \t]*:=")
string(REGEX REPLACE "^SWITCH2_CPU[ \t]*:=[ \t]*" "" OUNCE_SWITCH2_CPU "${OUNCE_SWITCH2_CPU}")
if(NOT OUNCE_SWITCH2_CPU)
	message(FATAL_ERROR "No SWITCH2_CPU in ${NX_ROOT}/switch2_cpu.mk: install the Switch 2 devkit again")
endif()
set(NX_ARCH_SETTINGS "${OUNCE_SWITCH2_CPU} -mtp=soft -ftls-model=local-exec")
__dkp_init_platform_settings(NX)

foreach(lang IN ITEMS C CXX ASM)
	string(APPEND CMAKE_${lang}_FLAGS_INIT " -D__SWITCH2__")
endforeach()

if(NOT DKP_PLATFORM_BOOTSTRAP)
	set(CMAKE_EXE_LINKER_FLAGS_INIT "-L${OUNCE_PORTLIBS}/lib ${CMAKE_EXE_LINKER_FLAGS_INIT}")
endif()
