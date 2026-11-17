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

The devkit is three packages for devkitPro's pacman, in the `[ounce]`
repository at <https://pkg.ouncebrew.org>
([ouncebrew/pacman](https://github.com/ouncebrew/pacman)):

- `libounce`, with `switch2vars.sh` and the CMake toolchain;
- `ouncevk`;
- `libkaihen`.

Install [devkitPro pacman](https://devkitpro.org/wiki/devkitPro_pacman),
then run `sh install.sh`. It adds the repository and its signing key to
pacman, and installs the three packages with the devkitPro packages they
need. Update them later as other devkitPro packages:

```sh
sudo dkp-pacman -Syu
```

`install.sh` also replaces a devkit that an earlier version of it unpacked
from an archive.

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

## Releases

Each library is released from its own repository, which publishes its
package when a version tag is pushed; ouncebrew/pacman's `sources` pins the
releases that the repository serves. The archives of earlier devkit
versions stay on this repository's releases.

## License

MIT (`LICENSE`). The installed libraries have their own licenses.
