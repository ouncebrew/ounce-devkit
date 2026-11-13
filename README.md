# ounce-devkit

Switch 2 support for a devkitPro installation:

- **[libounce](https://github.com/ouncebrew/libounce)**, a libnx-compatible
  library for Switch 2.
- **[OunceVK](https://github.com/ouncebrew/ouncevk)**: Vulkan, EGL, OpenGL
  and OpenGL ES.
- **[libkaihen](https://github.com/ouncebrew/kaihen)**, kaiHEN's homebrew
  API (`kaihen.h`).
- A CMake toolchain and `switch2vars.sh` for CMake, Meson and autotools.

The compiler, tools and other portlibs come from devkitPro unchanged.

## Install

Install [devkitPro pacman](https://devkitpro.org/wiki/devkitPro_pacman),
then run in this folder:

```sh
sh install.sh              # the default devkit version
sh install.sh 20261114     # a given version
```

Or use the Docker image (devkitPro's `devkitpro/devkita64` with the devkit):

```sh
docker build -t ounce-devkit .
docker run --rm -v "$PWD:/build/${PWD##*/}" -w "/build/${PWD##*/}" ounce-devkit make
```

## Build a program

In a libnx Makefile, replace the include line with:

```make
include $(DEVKITPRO)/libounce/switch2_rules
```

`-lnx` then links libounce. Add `-lvulkan` for Vulkan or `-lEGL` for
OpenGL. devkitPro's Switch portlibs that use only the C library and libnx,
such as SDL 2, work unchanged.

For CMake, Meson or autotools:

```sh
source $DEVKITPRO/switch2vars.sh
aarch64-none-elf-cmake -S . -B build && cmake --build build
```

`examples/` has a Vulkan program, an OpenGL ES program, a kaiHEN plugin and
a client for that plugin. For kaiHEN's JIT and plugin APIs, see `JIT.md`
and `PLUGINS.md` in kaiHEN's `libkaihen/`.

## Build the devkit

`sh build/make-devkit.sh` builds `ounce-devkit.tar.xz` from the commits that
`build/sources` pins. It needs Podman or Docker. See the script for its
options.

## License

MIT (`LICENSE`). The installed libraries have their own licenses.
