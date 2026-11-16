#!/bin/bash -e
# Configure and cross-compile Warzone 2100 2.3.9 (with patches/warzone2100
# applied) for RISC OS. Run build/build-deps.sh first.
. "$(dirname "$0")/env.sh"
: "${WZ_SRC:=$SRC/warzone2100-2.3.9}"
# stdout/stderr -> the file named by Warzone2100$Output (riscos-mesa's
# riscos_output.c, MIT): Warzone logs to stderr, which in a Wimp task would
# otherwise open a command window.
$CC $CFLAGS -DOUTPUT_VAR='"Warzone2100$Output"' \
    -DOUTPUT_DEFAULT='"/<Wimp$ScrapDir>/Warzone2100log"' -c "$REPO_DIR/riscos/riscos_output.c" \
    -o "$STAGE/lib/riscos_output.o"
# fontconfig's FONTCONFIG_FILE, set for this program only (riscos_fontconfig.c).
$CC $CFLAGS -c "$REPO_DIR/riscos/riscos_fontconfig.c" -o "$STAGE/lib/riscos_fontconfig.o"
# Warzone2100$RenderSize / $Overlay -> SDL's hints, for this program only.
$CC $CFLAGS -c "$REPO_DIR/riscos/riscos_display.c" -o "$STAGE/lib/riscos_display.o"
# OpenAL Soft's settings (ALSOFT_CONF -> !Warzone2100.alsoft/conf), for this program only.
$CC $CFLAGS -c "$REPO_DIR/riscos/riscos_sound.c" -o "$STAGE/lib/riscos_sound.o"
# The start-up checker (riscos/wzcheck.c, run by !Warzone2100.Check): the
# same fontconfig, FreeType and PhysicsFS as the game, and the same set-up.
mkdir -p "$STAGE/bin"
$CC $CFLAGS -static -I"$STAGE/include" -I"$STAGE/include/freetype2" \
    "$REPO_DIR/riscos/wzcheck.c" "$STAGE/lib/riscos_fontconfig.o" "$STAGE/lib/riscos_display.o" -L"$STAGE/lib" \
    -lphysfs -lfontconfig -lexpat -lfreetype -lpng -lz -lm -o "$STAGE/bin/wzcheck"
cd "$WZ_SRC"
[ -f configure ] || ./autogen.sh
# Static libraries don't carry their own dependencies: PhysicsFS needs zlib,
# vorbisfile needs vorbis and ogg. Sound (OpenAL -> SDL2 -> SharedSoundBuffer)
# unless WZ_SOUND=0. No NLS.
SOUND=--enable-sound; [ "${WZ_SOUND:-1}" = 0 ] && SOUND=--disable-sound
[ -f Makefile ] || ./configure --host=$HOST --build=$BUILD \
  --prefix=/Warzone2100 --enable-static $SOUND --disable-nls \
  --disable-motif LIBS="$STAGE/lib/riscos_output.o $STAGE/lib/riscos_fontconfig.o $STAGE/lib/riscos_display.o $STAGE/lib/riscos_sound.o -lvorbis -logg -lz" LDFLAGS="$LDFLAGS -static" \
  CC_FOR_BUILD=gcc CXX_FOR_BUILD=g++ CFLAGS_FOR_BUILD=-O2 CXXFLAGS_FOR_BUILD=-O2 \
  CPPFLAGS_FOR_BUILD= LDFLAGS_FOR_BUILD=
make -j$JOBS "$@"

# MIXED=1: relink the game as a *mixed* program (riscos-crossdev 1.11 or
# later, riscos-mesa devkit with lib/shared): UnixLib, libstdc++ and the
# game's other libraries stay linked in, but OpenGL, EGL, GLU, SDL 2 and
# OpenAL come from !MesaLibs at run time, through !SharedLibs. configure and
# the first link stay static (configure's test links can't be -rdynamic:
# binutils 2.30's ld crashes on a dynamic link with no shared library);
# only the program is linked again. The checker (wzcheck) stays static.
if [ "${MIXED:-0}" = 1 ]; then
  [ -f "$DEVKIT/lib/shared/libOSMesa.so" ] || { echo "MIXED=1: $DEVKIT has no lib/shared" >&2; exit 1; }
  STUBS=$($CC -print-file-name=mixed-stubs)
  [ -d "$STUBS" ] || { echo "MIXED=1: the toolchain has no mixed-stubs (riscos-crossdev 1.11 or later)" >&2; exit 1; }
  cd src
  rm -f warzone2100
  # lib/shared before $STAGE/lib, so -lSDL2 -lEGL -lOSMesa -lGLU -lopenal
  # find the shared libraries; -ldl after them for SDL's SDL_LoadObject.
  # With a devkit that has libMesaGPU (riscos-mesa 20.3.5-20 on), -lMesaGPU
  # after -lOSMesa: the program then names libMesaGPU.so.1 too, and on
  # native RISC OS EGL and OSMesa draw on the GPU through it when RISC3D
  # (loaded by !RISC3D at boot) has a GPU driver. RISC3D decides; the
  # program names no driver and needs nothing in !Run for it.
  GPU=; [ -f "$DEVKIT/lib/shared/libMesaGPU.so" ] && GPU=-lMesaGPU
  make warzone2100 LDFLAGS="-L$DEVKIT/lib/shared ${LDFLAGS} -rdynamic -Wl,-rpath-link=$STUBS" \
    LIBS="$(sed -n 's/^LIBS = //p' Makefile) $GPU -ldl"
fi
