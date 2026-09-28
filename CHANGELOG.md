# Changelog

## 2.3.9-6 (2026-09-28)

- **Fonts: fixed "Cannot load default config file" in 2.3.9-5.**
  QuesoGLC sets up fontconfig in its own start-up constructor, which ran
  before the one that told fontconfig where its configuration is. The
  game's constructors now run first (priorities 101 and 102), so the log
  redirection is also in place before any library prints.
- **Uses PackMan's fontconfig setup when it's installed** (UnixFC,
  `UnixFC$Dir`): its `fonts.conf`, font mapping and cache, like other
  fontconfig programs such as Iris. The game's DejaVu fonts are added on
  top (QuesoGLC patch: `RISCOS_APPFONTS`), so the text still shows if the
  system has no DejaVu. Without UnixFC it uses its own `fonts.conf`.
  Suggested by Chris Gransden. The game links fontconfig 2.12.6; PackMan's
  is 2.14.1: they read the same files, and their cache files have
  different names.
- Nothing global is set for fonts.

## 2.3.9-5 (2026-09-28)

- **Other fontconfig programs are no longer affected.** Up to 2.3.9-4,
  `!Run` set `FONTCONFIG_FILE` to the game's own fonts.conf. That is a
  global variable, which UnixLib passes to every program started later,
  so programs such as Iris used Warzone's font list and put their font
  cache in its scrap directory (reported by Chris Gransden). The game now
  sets it for itself only (`riscos/riscos_fontconfig.c`), and `!Run`
  removes the old global setting if it's still Warzone's. A reboot also
  clears it.

## 2.3.9-4 (2026-09-28)

- A game that fails to start no longer does so silently. Errors, and any
  crash backtrace, now always go to `<Wimp$ScrapDir>.Warzone2100log`
  (empty after a normal run); before, they were discarded unless
  `Warzone2100$Log` was set. `Warzone2100$Log` now adds the game's full
  log (`<Choices$Write>.Warzone2100.WZlog`) and the thread-switcher
  counters.
- Docs: where to get SharedSoundBuffer and StreamManager (ssb.zip on the
  RDPClient page), and John Duffell's site on the Internet Archive.

## 2.3.9-3 (2026-09-28)

- Rebuilt with the released riscos-mesa devkit 20.3.5-8 (2.3.9-2 used
  its 20.3.5-8c pre-release). Mesa, SDL2, GLU and OpenAL are the release
  builds; still VFPv3 throughout and linked with UnixLib 5.0.1. No change
  to the game.

## 2.3.9-2 (2026-09-28)

Built with UnixLib 5.0.1 (riscos-unixlib) and riscos-mesa devkit 20.3.5-8c.

**Other tasks no longer crash while the game runs**
- With 2.3.9-1, another desktop task could occasionally stop with "abort
  on instruction fetch" (seen in Organizer). UnixLib's thread switcher
  (a 2cs timer, active while a program has more than one thread) lived in
  the game's memory and was meant to be paused by Wimp filters whenever
  the game was swapped out. The game's first thread starts before it
  becomes a desktop task, so the old UnixLib never set the filters up and
  the timer fired into whichever task was running.
- UnixLib 5.0.1 (`patches/unixlib/unixlib-riscos.diff`) registers the
  filters once the game is a task, and runs the timer from the new
  **PThreadTicker** module (included in the app and loaded by `!Run`), or
  from a copy in the RMA without it. It replaces the OpenTTD UnixLib diff
  and our own RMA ticker diff.
- Tested on a Pi 4: an hour of play with other tasks running, no errors
  in the game or elsewhere; the ticker stats confirmed the module and the
  filters.

**Runs on more machines**
- Built for VFPv3 (`-mfpu=vfpv3`), and so is the riscos-mesa devkit from
  20.3.5-8c: Cortex-A8/A9 boards (BeagleBoard-xM, PandaBoard, ARMini,
  i.MX6) as well as the Pi 2 onwards. riscos-mesa measured no difference
  on a Pi 4. Not yet tried on an A8/A9 board; expect a small window there.

**Other**
- With logging on, `!Run` sets `UnixLib$TickerStats`: a line of thread
  switcher counters goes to `<Wimp$ScrapDir>.WZTickerStats` at exit.
- Build: `build/build-toolchain.sh unixlib` rebuilds only UnixLib, from
  clean; `tools/check-fpu.sh` joins the release checks; `check-unixlib.sh`
  checks the 472-byte ticker block.

## 2.3.9-1 (2026-09-27)

First release of Warzone 2100 2.3.9 for RISC OS. Tested on a Raspberry
Pi 4 (RISC OS 5).

Built with GCCSDK GCC 10.2 and riscos-mesa devkit 20.3.5-7pre11 (OSMesa
software OpenGL, SDL 2.26 with the RISC OS Wimp driver, OpenAL Soft
1.19.1), statically linked into one Absolute file.

**Running**
- 1024x768 desktop window by default (smaller on small screens);
  Alt+Return for full screen.
- Icon bar icon; Quit from its menu, the close icon and a desktop
  shutdown quit cleanly.
- The desktop keeps running while a level loads.
- Logging is off unless `Warzone2100$Log` is set (see `!Run`).

**Sound**
- Sound effects and music through OpenAL Soft, SDL2 and SharedSoundBuffer.
  Without SharedSoundBuffer the game runs silently.

**Speed** (software OpenGL; see `tools/profile`)
- No compressed textures, `GL_FASTEST` perspective, textures set up for
  riscos-mesa's fast textured-triangle path (terrain `GL_REPEAT`, pages
  `GL_CLAMP_TO_EDGE`), mipmapped "fast" texture filtering by default.
- A new config starts with shadows off, vsync off and fog set to
  "Fog Of War". About 5x the frame rate of the first playable build.
- Loading: PhysicsFS reads files through a buffer (a campaign loaded in
  2-3 minutes before, from over 100,000 small reads).

**Fixes for RISC OS**
- No unaligned 16/32-bit memory access (map files, network messages,
  saved games), which RISC OS traps.
- No `popen()`/`system()`; shut down before `exit()`; C heap in a dynamic
  area.
- UnixLib: the thread-switching ticker runs from the RMA; it used to crash
  other tasks (`patches/unixlib`). Real wide-character functions.
- Works around a Mesa swrast bug (buffered vertices not flushed before
  `glPushMatrix`) that hid most of the skirmish setup screen.

**Not included**
- Campaign videos (a separate download upstream); the internet lobby
  (its server no longer exists).
