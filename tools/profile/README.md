# Profiling the renderer on Linux

The Pi can't run `perf`, but the cost is almost all in Mesa's software
rasteriser, which behaves the same on x86. So build the patched game for
Linux, run it on riscos-mesa's Mesa built as an xlib libGL (the same
classic swrast OSMesa uses, with the same patches), and profile that.
Frame rates are about 5-8 times what a Pi 4 gets, but the proportions
hold.

## One-off setup

1. **Mesa.** Mesa 20.3.5 with riscos-mesa's patches, built as the xlib
   libGL with debug info:
   ```sh
   meson setup build-x -Dglx=xlib -Dosmesa=none -Dgallium-drivers= -Ddri-drivers= \
       -Dvulkan-drivers= -Dbuildtype=debugoptimized
   ninja -C build-x          # MESA_LIB=.../build-x/src/mesa/drivers/x11
   ```
2. **PhysicsFS 2.0.3 and QuesoGLC 0.7.2** for the host, static, into a
   prefix (the same patches as for RISC OS).
3. **The game.** A patched tree (`tools/wz-patches.sh checkout`, or a copy
   of `src/warzone2100-2.3.9`) configured for the host:
   ```sh
   CFLAGS="-O2 -g -fno-omit-frame-pointer" LIBS=-lz ./configure --disable-sound ...
   make LIBS="-lz -lfontconfig -lfreetype"
   ```
   The game's data must be in `data/` (as `make` leaves it).
4. `apt-get install xvfb x11-apps imagemagick linux-tools-generic`.

The RISC OS-only changes are behind `WZ_OS_RISCOS`, so the Linux build
has upstream's behaviour. To measure what the Pi runs, turn off texture
compression by hand in `lib/ivis_opengl/piemode.c` (patch 0012) and pass
the RISC OS defaults: `--texfilter=fast` and
`CFGTEXT=$'visfog=1\nshadows=0'`.

## Running

```sh
MESA_LIB=... WZ_HOST=... tools/profile/run.sh <tag> --texfilter=fast
perf report -i /tmp/perf-<tag>.data --no-children --sort symbol
```

It prints the frame rate every 5 seconds and leaves a screenshot in
`/tmp/shot-<tag>.png` to check that the picture is unchanged. Use
`-e cpu-clock` (the script does) where hardware counters aren't available.

## Results (September 2026, CAM_1A at 800x600)

| Change | fps | Top of the profile afterwards |
|---|---|---|
| riscos10 (`fast`, compressed textures) | 11 | DXT3 texel decode, 44% |
| no texture compression (0012) | 21 | bilinear sampling, mipmap lambda (`log2f`), fog |
| `fast` without mipmaps (0011) | 25 | bilinear sampling, fog 8% |
| "Fog Of War" instead of "Mist" (0013) | 28 | bilinear sampling |
| shadows off (0013) | 30 | bilinear sampling of RGBA8 (Mesa) |
| terrain `GL_REPEAT` (0014) | 51 | `persp_textured_triangle` 58% (swrast's fast path) |
| riscos-mesa 7pre11 Mesa (7pre10 fast paths), riscos19 settings | 52 | |
| + texture pages GL_CLAMP_TO_EDGE (0017) | 53.5 | |
| + GL_FASTEST hint (0017) | 56 | `fast_persp_span` |
| + "fast" filter mipmapped again (0011), = riscos21 | 58.7 | one mip level per triangle |
| (terrain GL_CLAMP_TO_EDGE instead of GL_REPEAT) | 53 | 0014 stays |
| (riscos-mesa 20.3.5-7pre6 instead of 7pre4, riscos11 settings) | 30.5 | +1-2%: its new fast paths need GL_REPEAT or constant q |
| (all texture pages `GL_REPEAT`, not done: UI images could bleed at page edges) | 55 | |
| (`nearest`, for comparison, with mipmaps) | 29 | |

What's left is Mesa's fast textured-triangle loop, mostly its per-pixel
perspective divide (`persp_textured_triangle`), and blending. The game's
code is under 1% of the time.

swrast's fast path (`_swrast_choose_triangle` in `s_triangle.c`) needs:
one 2D texture unit, `GL_REPEAT` both ways, a power-of-two RGBA8/RGB8
texture, min filter = mag filter (so no mipmapping), no fog, no separate
specular, env mode not `GL_COMBINE`. Anything else goes through the
general per-fragment path at about half the speed.
