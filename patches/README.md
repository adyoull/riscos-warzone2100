# Patches

## warzone2100/ (against upstream v2.3.9)

A git patch series: `git format-patch` output, one change per patch, each
explaining itself in its commit message. `build/fetch-sources.sh` applies
them in order with `patch -p1`. To edit them, use `tools/wz-patches.sh`
(see BUILDING.md).

| # | What |
|---|---|
| 0001 | SDL 1.2 -> SDL2: window and GL context, keys (SDL 1.2 key values kept via `wzkeys12.h`), text input, wheel, clipboard, thread names. Nothing RISC OS specific. One patch because intermediate states wouldn't build. |
| 0002 | `WZ_OS_RISCOS`; GLee without GLX (loads through `SDL_GL_GetProcAddress`); configure links OSMesa/GLU. |
| 0003 | Cross-build fixes: the RISC OS triplet in configure, host-built autorevision, current flex/bison, no Unix crash handler, missing includes. |
| 0004 | C heap in the dynamic area "Warzone2100 Heap" (up to 512MB). |
| 0005 | No `popen("which")` at start-up; URIdispatch through `Wimp_StartTask`. |
| 0006 | 800x600 window by default; the log records start, quit and exit. |
| 0007 | Shut down before `exit()`, not from `atexit()`. |
| 0008 | Map file structures packed (unaligned reads). |
| 0009 | Network messages: `memcpy` for 16/32-bit values (unaligned). |
| 0010 | Script state in save games: `WZ_LOAD`/`WZ_STORE` (unaligned). |
| 0011 | Cheaper 3D texture filtering (`Warzone2100$Filter`). |

## physfs/ (PhysicsFS 2.0.3)

- Treat RISC OS as a POSIX platform, with no CD-ROM enumeration.
- Ignore `fsync()`'s result: UnixLib fails it on read-only files, which
  used to stop them being closed. riscos-unixlib 751de68 fixes that
  failure; the patch is harmless with the fixed library.

## quesoglc/ (QuesoGLC 0.7.2)

- A hand-written makefile and `qglc_config.h` for RISC OS (in `riscos/`).
- `glew.c` loads GL functions with `OSMesaGetProcAddress`, and uses no
  thread-local storage.

## unixlib/

`unixlib-riscos-openttd.diff` comes from the RISC OS OpenTTD port.
`build/build-toolchain.sh` applies it to GCCSDK's UnixLib. Among other
things it adds real wide-character functions: the stubs aborted with
"wctype: Not implemented" when the C++ library started up. riscos-unixlib's
`unixlib-riscos.diff` is a superset of it and can replace it once that
library has been tested on a Pi.
