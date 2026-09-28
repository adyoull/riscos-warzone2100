# Building Warzone 2100 for RISC OS

Everything is cross-compiled on Linux: x86_64 or arm64 Ubuntu 22.04/24.04,
with about 6GB of disk. A full build from nothing takes about 20 minutes on
2 cores (GCC about 10, the game about 5).

## 1. Host packages

```sh
apt-get install build-essential autogen autoconf2.69 autoconf2.64 automake1.11 \
    automake libtool texinfo gperf flex bison m4 gawk cmake pkg-config python3 unzip curl
```

## 2. The riscos-mesa devkit

Unpack a riscos-mesa devkit (github.com/adyoull/riscos-mesa releases) into
`devkit/`. `build/env.sh` names the one this version is built with
(`DEVKIT`, currently `riscos-mesa-devkit-20.3.5-8c`):

```sh
mkdir -p devkit && tar xzf riscos-mesa-devkit-20.3.5-8c.tgz -C devkit
```

## 3. Build

```sh
build/fetch-sources.sh     # downloads to dl/, checks SHA256SUMS.txt, unpacks and patches into src/
build/build-toolchain.sh   # GCCSDK GCC 10.2 + UnixLib into $GCCSDK_ENV (~/gccsdk/env), and elf2aif
build/build-deps.sh        # static libraries into stage/
build/build-wz.sh          # configure + make: src/warzone2100-2.3.9/src/warzone2100
build/package.sh           # dist/!Warzone2100 and dist/Warzone2100-<VERSION>.zip
```

Each step can be run again on its own; `build-deps.sh` skips libraries it
has already built (delete `stage/lib/libX.a` to force one).

### Settings (`build/env.sh`; set them in the environment to override)

| Variable | Default | Meaning |
|---|---|---|
| `GCCSDK_ENV` | `~/gccsdk/env` | the cross compiler (`bin/arm-riscos-gnueabihf-gcc`) |
| `DEVKIT` | `devkit/riscos-mesa-devkit-…` | riscos-mesa devkit |
| `STAGE`, `SRC` | `stage/`, `src/` | built libraries, unpacked sources |
| `DL` | `dl/` | downloaded tarballs |
| `JOBS` | `nproc` | parallel make |

`STAGE`, `SRC`, `DEVKIT` and `GCCSDK_ENV` must not contain spaces:
autoconf and libtool can't handle them. `env.sh` stops if they do. The
repository itself may be in a path with spaces if those four point
elsewhere.

### Restricted networks

`fetch-sources.sh` downloads from archive.ubuntu.com and GitHub. If the
build machine can't reach one of them, fetch those files on another machine
and put them in `dl/`. The script only downloads what's missing, and checks
everything. The files and URLs are listed in the script.

### A prebuilt toolchain

`build-toolchain.sh` builds into `$GCCSDK_ENV`. The result is relocatable
only to the same path, so a tarball of `~/gccsdk/env` can be reused on
another machine as the same user. `elf2aif` is always built from
`tools/elf2aif` (`build-toolchain.sh elf2aif` builds only that).

## 4. Changing the game's source

The Warzone changes live only as the patch series in `patches/warzone2100`.
The `src/` tree is generated from it. Edit them with git:

```sh
tools/wz-patches.sh checkout            # work/warzone2100: upstream v2.3.9 + one commit per patch
cd work/warzone2100
# edit, then either a new commit ...
git commit -am "RISC OS: what and why"
# ... or fold a fix into an existing patch:
git commit -a --fixup <commit>; git rebase -i --autosquash v2.3.9
cd ../..
tools/wz-patches.sh export              # rewrites patches/warzone2100/*.patch
rm -rf src/warzone2100-2.3.9 && build/fetch-sources.sh   # re-patch (or copy the files across)
build/build-wz.sh
tools/wz-patches.sh check               # the series reproduces src/warzone2100-2.3.9
```

Keep one change per patch, with a commit message that says what went wrong
and why the change fixes it. Follow Warzone's own conventions:

- Guard RISC OS-only code with `#if defined(WZ_OS_RISCOS)` (from
  `wzglobal.h`), so other platforms keep upstream's behaviour. Use
  `__riscos__` only where `wzglobal.h` isn't included: GLee, and `tex.h`'s
  include chain, which tests `__APPLE__` the same way.
- Put compiler-specific syntax behind a `WZ_DECL_*` macro in `wzglobal.h`
  (for example `WZ_DECL_PACKED`), not raw `__attribute__`.
- New settings are config keys (`configuration.c`: load with a default,
  save), with a command-line option if useful (`clparse.c`). The rest of
  the game reads them through a setter and getter. RISC OS variables are
  only used in `!Run`, to build the command line.
- Log with `debug()`: `LOG_INFO`, `LOG_ERROR` and `LOG_WARNING` reach the
  WZlog file and stderr. Use plain `fprintf(stderr)` only after the debug
  system has shut down.

Don't run `make -B` in `src/warzone2100-2.3.9`. It re-runs configure
without `env.sh`'s settings and breaks the Makefile. If that happens, delete
`src/warzone2100-2.3.9/Makefile` and run `build/build-wz.sh` again.

## 5. Checks before a release

```sh
tools/wz-patches.sh check
tools/check-unaligned.sh                                   # must report 0 left to review
tools/check-unixlib.sh                                     # must say OK (UnixLib built consistently)
tools/check-fpu.sh                                         # must say OK (runs on VFPv3 machines)
PATH=$GCCSDK_ENV/bin:$PATH python3 tools/check-stack-probes.py src/warzone2100-2.3.9/src/warzone2100
                                                           # must report 0 without stack probes
```

**Rules for RISC OS code.** Each of these has crashed this port:

- **No unaligned 16/32-bit loads or stores.** RISC OS traps them. The crash
  shows as "EMT trap" (abort on data transfer). Linux doesn't trap them, so
  upstream code has them wherever a byte buffer is cast to a wider type:
  - network messages;
  - map files;
  - save games.
  Use `wz_load_u16/s16/u32/s32/float` and `wz_store_*`
  (`lib/framework/endian_hack.h`), or a `WZ_DECL_PACKED` struct.
  `check-unaligned.sh` finds the casts.
- **No `popen()`, `system()`, `fork()` or `exec()`.** UnixLib runs a child
  as a *command inside our own memory. To launch something, use
  `Wimp_StartTask`.
- **VFPv3, not VFPv4.** `build/env.sh` builds with `-mfpu=$FPU`, default
  `vfpv3`, so the program can run on Cortex-A8/A9 boards as well as the Pi
  2 onwards. VFPv4 only adds fused multiply-add, which GCC uses whenever it
  can. The devkit has to be built the same way: `tools/check-fpu.sh` lists
  any library or program with VFPv4-only instructions; it must say OK.
  The riscos-mesa devkit is VFPv3 from 20.3.5-8c.
- **Stack clash protection is required.** Everything is built with
  `-fstack-clash-protection`: ARMEABISupport maps the stack a page at a
  time, so a frame over 4KB must probe it page by page.
- **No thread joins from `atexit()`.** Older UnixLib can't switch threads
  during `exit()`.
- **Threads need riscos-unixlib's UnixLib.** While a program has a second
  thread, UnixLib's thread-switching ticker runs every 2cs, whichever task
  is paged in. In GCCSDK's UnixLib its handler (and the Wimp filters that
  should stop it while the program is paged out) are in our application
  space, and crashed other tasks ("abort on instruction fetch" in
  Organizer). `patches/unixlib/unixlib-riscos.diff` (riscos-unixlib
  v0.1.1-rc1) runs them from the PThreadTicker module when it's loaded
  (`!Run` loads the copy in the app), otherwise from a copy in the RMA.
- **After changing `patches/unixlib`, rebuild UnixLib from clean:**
  `build/build-toolchain.sh unixlib` (a few minutes; it re-patches GCCSDK
  and rebuilds only UnixLib and the module), then relink (delete
  `src/warzone2100-2.3.9/src/warzone2100` and run `build/build-wz.sh`).
  Two test builds shipped a stale `_syslib.o` that claimed a smaller
  ticker block than the C code used, which overwrote the RMA and hung the
  whole machine. `tools/check-unixlib.sh` catches that.

**Speed.** Before changing anything for speed, measure it on Linux with
`tools/profile` (the Pi has no profiler). Software OpenGL makes some
harmless-looking GL requests expensive: compressed textures, mipmaps,
wrap modes other than GL_REPEAT,
fog, stencil shadows.

## 6. Testing on a Pi

Copy `dist/!Warzone2100` (or unzip the zip) to the Pi. First-run
checklist:

1. **Title screen:** the title screen appears, the menus respond to
   clicks, and text is drawn (fontconfig + DejaVu).
2. **Settings:** Options > Video changes the size, and the change survives
   a restart (that is, `config` gets saved).
3. **Skirmish:** Single Player > Skirmish starts and plays.
4. **Campaign:** Single Player > New Campaign starts (the videos are
   missing, which is expected).
5. **Save/load:** save a game and load it back.
6. **Controls:** typing (a save name), the scroll wheel, Alt+Return (full
   screen), Alt+S (shadows).
7. **Quit:** quitting leaves no "Aborted" in
   `<Choices$Write>.Warzone2100.WZlog`.

Logging is off in a normal run: set `Warzone2100$Log` (in `!Run`, or
`*Set Warzone2100$Log 1`) for the tests. The game's stdout/stderr then go
to `<Wimp$ScrapDir>.Warzone2100log` (`riscos/riscos_output.c`; without the
variable they are discarded), and `--debugfile` writes its log to
`<Choices$Write>.Warzone2100.WZlog` (patch 0018: no automatic log file).

### Reading a crash

With logging on, UnixLib writes "Fatal signal received" and a backtrace
of `lr` values into the `WZlog` file. To turn them into source lines:

1. Rebuild the same version, unstripped: `src/warzone2100-2.3.9/src/warzone2100`.
2. Run:
   ```sh
   arm-riscos-gnueabihf-addr2line -f -i -e src/warzone2100-2.3.9/src/warzone2100 0x<lr> ...
   ```

The first frame after `non_fp_exception` often shows a stale `lr`, because
the fault was in a leaf function. Disassemble around it
(`arm-riscos-gnueabihf-objdump -d --start-address=...`).

For more output, set `Warzone2100$Debug` to `--debug=all
--flush-debug-stderr` before starting the game.
