#!/bin/bash -e
# Configure and cross-compile Warzone 2100 2.3.9 (with patches/warzone2100
# applied) for RISC OS. Run build/build-deps.sh first.
. "$(dirname "$0")/env.sh"
: "${WZ_SRC:=$SRC/warzone2100-2.3.9}"
# stdout/stderr -> the file named by Warzone2100$Output (riscos-mesa's
# riscos_output.c, MIT): Warzone logs to stderr, which in a Wimp task would
# otherwise open a command window.
$CC $CFLAGS -DOUTPUT_VAR='"Warzone2100$Output"' -c "$REPO_DIR/riscos/riscos_output.c" \
    -o "$STAGE/lib/riscos_output.o"
cd "$WZ_SRC"
[ -f configure ] || ./autogen.sh
# Static libraries don't carry their own dependencies: PhysicsFS needs zlib.
# No sound yet (the devkit's SDL2 has no RISC OS audio driver), no NLS.
[ -f Makefile ] || ./configure --host=$HOST --build=$BUILD \
  --prefix=/Warzone2100 --enable-static --disable-sound --disable-nls \
  --disable-motif LIBS="$STAGE/lib/riscos_output.o -lz" LDFLAGS="$LDFLAGS -static" \
  CC_FOR_BUILD=gcc CXX_FOR_BUILD=g++ CFLAGS_FOR_BUILD=-O2 CXXFLAGS_FOR_BUILD=-O2 \
  CPPFLAGS_FOR_BUILD= LDFLAGS_FOR_BUILD=
make -j$JOBS "$@"
