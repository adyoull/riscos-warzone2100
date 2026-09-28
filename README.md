# Warzone 2100 2.3.9 for RISC OS

The build scripts, patches and application files for a RISC OS port of
[Warzone 2100](https://wz2100.net) 2.3.9 (2012). This is the last version
that draws everything with fixed-function OpenGL, so it runs on software
OpenGL. Target: a Raspberry Pi 4 running RISC OS 5.

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
and ARMEABISupport, both from PackMan.

## What's in this repository

| Path | What |
|---|---|
| `build/` | `env.sh` (settings) and the build steps, in order: `fetch-sources.sh`, `build-toolchain.sh`, `build-deps.sh`, `build-wz.sh`, `package.sh`. `SHA256SUMS.txt` pins every source. |
| `patches/warzone2100/` | The changes to Warzone 2100, as a git patch series against upstream v2.3.9. |
| `patches/physfs`, `patches/quesoglc` | Changes to two libraries. |
| `patches/unixlib/` | UnixLib changes (from the RISC OS OpenTTD port), applied when the toolchain is built. |
| `app/!Warzone2100/` | `!Run`, `!Boot`, `!Help`, `!Sprites` and the fontconfig setup. `package.sh` adds the program, the game data and the fonts. |
| `riscos/riscos_output.c` | Sends stdout/stderr to the file named by `Warzone2100$Output` (from riscos-mesa, MIT). |
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
- Logging is off unless `Warzone2100$Log` is set (a line in `!Run`): then
  the game's output goes to `<Wimp$ScrapDir>.Warzone2100log` and its log,
  with any crash backtrace, to `<Choices$Write>.Warzone2100.WZlog`.

## Status

- **Release 2.3.9-3 (2026-09-28):** playable on a Raspberry Pi 4 in a
  1024x768 desktop window, with sound and music: menus, campaign,
  skirmish, settings, quitting. Other desktop tasks are safe while it runs
  (UnixLib 5.0.1 and PThreadTicker), and it's built for VFPv3, so it
  should also run on Cortex-A8/A9 boards (untested). Built with riscos-mesa 20.3.5-8. See
  [CHANGELOG.md](CHANGELOG.md).
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
