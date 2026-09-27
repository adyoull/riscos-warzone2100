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
| 0006 | 1024x768 window by default (smaller on small screens); "started"/"quit requested" logged with `debug(LOG_INFO)`, exit marked on stderr. |
| 0007 | Shut down before `exit()`, not from `atexit()`. |
| 0008 | `WZ_DECL_PACKED` (wzglobal.h); the map file structures use it (unaligned reads). |
| 0009 | `wz_load_*`/`wz_store_*` in endian_hack.h; the network code uses them (unaligned). |
| 0010 | Script state in save games uses `wz_load_*`/`wz_store_*` (unaligned). |
| 0011 | Texture filtering setting: config `textureFilter`, `--texfilter=best\|smooth\|fast\|nearest`; RISC OS defaults to `fast` (bilinear, no mipmaps). |
| 0012 | No compressed textures on RISC OS: swrast decoded a DXT3 block per texel (half the frame time). |
| 0013 | A new config on RISC OS has shadows off, vsync off and "Fog Of War" instead of "Mist" (GL fog on every pixel). |
| 0014 | Terrain textures use `GL_REPEAT` on RISC OS: swrast's fast textured-triangle path needs it (30 -> 51 fps). |
| 0015 | Pump events (Wimp_Poll) from the loading screen callback, so the desktop keeps running while a level loads. |
| 0016 | glFlush() before the text code pushes the texture matrix: Mesa's classic swrast doesn't flush before glPushMatrix (skirmish buttons and map preview went missing). |

## physfs/ (PhysicsFS 2.0.3)

- Treat RISC OS as a POSIX platform, with no CD-ROM enumeration.
- Files opened for reading are buffered (32KB), and their position,
  length and end of file are kept in memory. The zip reader reads the
  archive directory 2 or 4 bytes at a time; on RISC OS each read() is a
  FileSwitch call, so loading a campaign made over 100,000 of them
  (2-3 minutes on a Pi 4). Now about 1,600.
- No `fsync()` when a read-only file is closed (UnixLib fails it with
  EBADF, which used to stop the file being closed); for files being
  written its result is ignored.

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
