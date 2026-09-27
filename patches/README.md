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
| 0006 | 800x600 window by default; "started"/"quit requested" logged with `debug(LOG_INFO)`, exit marked on stderr. |
| 0007 | Shut down before `exit()`, not from `atexit()`. |
| 0008 | `WZ_DECL_PACKED` (wzglobal.h); the map file structures use it (unaligned reads). |
| 0009 | `wz_load_*`/`wz_store_*` in endian_hack.h; the network code uses them (unaligned). |
| 0010 | Script state in save games uses `wz_load_*`/`wz_store_*` (unaligned). |
| 0011 | Texture filtering setting: config `textureFilter`, `--texfilter=best\|smooth\|fast\|nearest`; RISC OS defaults to `fast` (bilinear, no mipmaps). |
| 0012 | No compressed textures on RISC OS: swrast decoded a DXT3 block per texel (half the frame time). |
| 0013 | A new config on RISC OS has shadows off and "Fog Of War" instead of "Mist" (GL fog on every pixel). |
| 0014 | Terrain textures use `GL_REPEAT` on RISC OS: swrast's fast textured-triangle path needs it (30 -> 51 fps). |

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

`unixlib-pthread-ticker-rma.diff` (ours): UnixLib's thread-switching
ticker (OS_CallEvery, every 2cs while a program has more than one thread)
runs a copy of its handler kept in the RMA instead of the one in the
program. On a Pi it fired while another task was paged in and that task
died with "abort on instruction fetch" at the handler's address (seen
from Organizer while Warzone ran its path-finding thread). The handler
already checks that its program is paged in before it does anything, using
only its RMA block, so from the RMA it's safe whichever task is current.
Offered to riscos-unixlib.

`unixlib-riscos-openttd.diff` comes from the RISC OS OpenTTD port.
`build/build-toolchain.sh` applies it to GCCSDK's UnixLib. Among other
things it adds real wide-character functions: the stubs aborted with
"wctype: Not implemented" when the C++ library started up. riscos-unixlib's
`unixlib-riscos.diff` is a superset of it and can replace it once that
library has been tested on a Pi.
