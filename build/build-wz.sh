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
# The start-up checker (riscos/wzcheck.c, run by !Warzone2100.Check): the
# same fontconfig, FreeType and PhysicsFS as the game, and the same set-up.
mkdir -p "$STAGE/bin"
$CC $CFLAGS -static -I"$STAGE/include" -I"$STAGE/include/freetype2" \
    "$REPO_DIR/riscos/wzcheck.c" "$STAGE/lib/riscos_fontconfig.o" -L"$STAGE/lib" \
    -lphysfs -lfontconfig -lexpat -lfreetype -lpng -lz -lm -o "$STAGE/bin/wzcheck"
cd "$WZ_SRC"
[ -f configure ] || ./autogen.sh
# Static libraries don't carry their own dependencies: PhysicsFS needs zlib,
# vorbisfile needs vorbis and ogg. Sound (OpenAL -> SDL2 -> SharedSoundBuffer)
# unless WZ_SOUND=0. No NLS.
SOUND=--enable-sound; [ "${WZ_SOUND:-1}" = 0 ] && SOUND=--disable-sound
[ -f Makefile ] || ./configure --host=$HOST --build=$BUILD \
  --prefix=/Warzone2100 --enable-static $SOUND --disable-nls \
  --disable-motif LIBS="$STAGE/lib/riscos_output.o $STAGE/lib/riscos_fontconfig.o -lvorbis -logg -lz" LDFLAGS="$LDFLAGS -static" \
  CC_FOR_BUILD=gcc CXX_FOR_BUILD=g++ CFLAGS_FOR_BUILD=-O2 CXXFLAGS_FOR_BUILD=-O2 \
  CPPFLAGS_FOR_BUILD= LDFLAGS_FOR_BUILD=
make -j$JOBS "$@"
