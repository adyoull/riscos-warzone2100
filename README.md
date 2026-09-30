# Warzone 2100 2.3.9 for RISC OS

The build scripts, patches and application files for a RISC OS port of
[Warzone 2100](https://wz2100.net) 2.3.9 (2012). This is the last version
that draws everything with fixed-function OpenGL, so it runs on software
OpenGL. Target: RISC OS 5 on ARMv7 machines with VFPv3 or later (the
Raspberry Pi 2 onwards, and Cortex-A8/A9 boards); developed and tested on a
Raspberry Pi 4.

**Download:** the zip on the [releases page](https://github.com/adyoull/riscos-warzone2100/releases)
(latest: 2.3.9-11).

How to build it: [BUILDING.md](BUILDING.md). What the patches change:
[patches/README.md](patches/README.md).

## How it fits together

```
Warzone 2100 2.3.9 source (upstream, unmodified) + patches/warzone2100
        |  SDL2 (window, input)          OpenGL 2.1
        v                                v
riscos-mesa devkit: SDL 2.26 with a RISC OS Wimp driver, OSMesa 20.3.5 (swrast), GLU
        |
UnixLib + GCCSDK GCC 10.2 (arm-riscos-gnueabihf), statically linked
        |
elf2aif -> !Warzone2100.warzone2100,ff8 (Absolute: needs no !SharedLibs)
```

Everything is linked statically into one program. It needs SharedUnixLibrary
and ARMEABISupport, both from PackMan. For sound it also needs
SharedSoundBuffer and StreamManager, John Duffell's freeware: the `ssb.zip`
download on [Andrew Sellors' RDPClient page](https://orac.co.uk/software/rdpclient/rdpclient.html)
(merge its `!System` into yours). John Duffell's own site is on the Internet
Archive: <https://web.archive.org/web/20110920080106/http://www.duffell.riscos.me.uk/>.

Fonts: the game links fontconfig 2.14.1, the version in PackMan. With
PackMan's fontconfig (UnixFC) installed, it uses that setup like other
fontconfig programs: the system fonts, `fonts.conf` and font cache, plus
its own DejaVu fonts as a fallback. Without it, it uses only its own fonts,
so PackMan's fontconfig isn't required. Nothing global is set.

## What's in this repository

| Path | What |
|---|---|
| `build/` | `env.sh` (settings) and the build steps, in order: `fetch-sources.sh`, `build-toolchain.sh`, `build-deps.sh`, `build-wz.sh`, `package.sh`. `SHA256SUMS.txt` pins every source. |
| `patches/warzone2100/` | The changes to Warzone 2100, as a git patch series against upstream v2.3.9. |
| `patches/fontconfig`, `patches/physfs`, `patches/quesoglc` | Changes to three libraries (fontconfig's are the RISC OS changes from GCCSDK's recipe). |
| `patches/unixlib/` | UnixLib changes (from the RISC OS OpenTTD port), applied when the toolchain is built. |
| `app/!Warzone2100/` | `!Run`, `!Boot`, `!Help`, `!Sprites` and the fontconfig setup. `package.sh` adds the program, the game data and the fonts. |
| `riscos/riscos_output.c` | Sends stdout/stderr to the file named by `Warzone2100$Output` (from riscos-mesa, MIT). |
| `riscos/riscos_display.c` | `Warzone2100$RenderSize` / `$Overlay` to SDL's render size and overlay hints, for this program only. |
| `riscos/riscos_fontconfig.c` | Chooses the fontconfig setup (UnixFC's or the game's own), for this program only. |
| `riscos/wzcheck.c` | The start-up checker, run by `!Warzone2100.Check`. |
| `tools/wz-patches.sh` | Edit the patch series with git (see BUILDING.md). |
| `tools/check-unaligned.sh` | Finds code that can do unaligned loads and stores, which RISC OS traps. |
| `tools/check-unixlib.sh` | Checks the program's UnixLib claims the full 472-byte pthread ticker block and agrees with the C side (a stale build hung the machine). |
| `tools/check-fpu.sh` | Checks nothing in the program needs VFPv4, so it runs on Cortex-A8/A9 machines too. |
| `tools/check-stack-probes.py` | Finds big stack frames that don't probe the stack. |
| `tools/profile/` | Profile the renderer on Linux with the same Mesa (see its README): where the frame time goes. |
| `tools/elf2aif/` | ELF to Absolute converter with the >32MB fix (copy from riscos-openttd). |
| `tools/rozip.py`, `tools/png2sprite.py` | Zips with RISC OS filetypes; the icon sprite. |

## Using the game

See `app/!Warzone2100/!Help,fff`. In short:

- It opens a 1024x768 desktop window (smaller on small screens).
  Alt+Return switches to full screen.
- It has an icon bar icon. Quit (its menu), the window's close icon and a
  desktop shutdown all quit the game cleanly.
- Texture filtering: `Warzone2100$Filter` in `!Run` passes
  `--texfilter=` (`fast` by default; also `nearest`, `smooth`, `best`); the
  game saves it as `textureFilter` in its config.
- A new config starts with shadows off (Alt+S turns them on), vsync off,
  and fog set to "Fog Of War", not "Mist": each costs software OpenGL
  about 10%.
- Errors, and any crash backtrace, always go to
  `<Wimp$ScrapDir>.Warzone2100log` (empty after a normal run). Setting
  `Warzone2100$Log` (a line in `!Run`) adds the game's full log in
  `<Choices$Write>.Warzone2100.WZlog`.
- Render size and overlay: `Warzone2100$RenderSize` (e.g. `640x480`) makes
  the game render at that size, stretched to the window or the screen
  (riscos-mesa's SDL hint `SDL_RISCOS_GL_RENDER_SIZE`, set for this program
  only by `riscos/riscos_display.c`). Frames go through the Pi's hardware
  overlay whenever the VideoOverlay module is loaded (`Warzone2100$Overlay 0`
  turns it off), and then the render size defaults to 800x600 (640x480 on
  screens up to 1024x768; `Warzone2100$RenderSize off` turns that off).
  With a render size, full screen is a multitasking full window (no mode
  change; `Warzone2100$FullWindow 0` for the old full screen). All are
  lines in `!Run`.
- If the game doesn't start, `!Warzone2100.Check` runs a start-up checker
  (`riscos/wzcheck.c`): the modules and variables, the heap dynamic area,
  fontconfig, FreeType, PhysicsFS and the game's data, and a stack test,
  each step printed before it runs. The report is also written to
  `<Wimp$ScrapDir>.WZCheck`.

## Status

- **Release 2.3.9-11 (2026-09-29):** playable on a Raspberry Pi 4 in a
  1024x768 desktop window, with sound and music: menus, campaign,
  skirmish, settings, quitting. Other desktop tasks are safe while it runs
  (UnixLib 5.0.3 and PThreadTicker), and it's built for VFPv3, so it
  should also run on Cortex-A8/A9 boards (untested). Built with
  riscos-mesa 20.3.5-10. See [CHANGELOG.md](CHANGELOG.md).
- **Fonts:** fontconfig 2.14.1; checked on a Pi 4 with UnixFC's setup
  (61 system fonts, DejaVu Sans from the system, UnixFC's cache).
- **Sound:** OpenAL Soft 1.19.1 (from the riscos-mesa devkit) plays
  through the devkit SDL2's audio, which goes to SharedSoundBuffer.
  Music is included; `WZ_SOUND=0 build/build-wz.sh` builds without sound.
- **Missing:**
  - No campaign videos (sequences.wz, a separate download upstream).
  - No internet lobby (the server no longer exists).

## Licence

Warzone 2100 is GPL version 2 or later, and so are the patches and scripts
here. The package includes the licences of everything linked in
(`docs/` in the application).
