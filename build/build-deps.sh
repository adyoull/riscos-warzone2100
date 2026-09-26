#!/bin/bash -e
# Cross-build Warzone 2100 2.3.9's libraries for RISC OS into $STAGE (static).
# Sources must already be unpacked in $SRC (build/fetch-sources.sh).
# GL, GLU, SDL2 and zlib come from the riscos-mesa devkit.
. "$(dirname "$0")/env.sh"
cd "$SRC"
HOSTARGS="--host=$HOST --prefix=$STAGE --disable-shared --enable-static"

step() { echo; echo "=== $*"; }
# have LIB: true if $STAGE/lib/LIB exists (lets a failed run be resumed)
have() { [ -f "$STAGE/lib/$1" ] && echo "    (already built)"; }

step "riscos-mesa devkit -> stage"
cp -r "$DEVKIT"/include/* "$STAGE/include/"
cp "$DEVKIT"/lib/libOSMesa.a "$DEVKIT"/lib/libGLU.a "$DEVKIT"/lib/libSDL2.a \
   "$DEVKIT"/lib/libSDL2main.a "$DEVKIT"/lib/libz.a "$STAGE/lib/"
cat > "$STAGE/lib/pkgconfig/sdl2.pc" <<EOT
prefix=$STAGE
libdir=\${prefix}/lib
includedir=\${prefix}/include
Name: sdl2
Description: SDL 2.26 with the RISC OS Wimp driver and OSMesa GL (riscos-mesa devkit)
Version: 2.26.0
Libs: -L\${libdir} -lSDL2 -lOSMesa -lstdc++ -lz -lm
Cflags: -I\${includedir}/SDL2 -D_REENTRANT
EOT
cat > "$STAGE/lib/pkgconfig/zlib.pc" <<EOT
prefix=$STAGE
Name: zlib
Description: zlib (riscos-mesa devkit)
Version: 1.3.1
Libs: -L\${prefix}/lib -lz
Cflags: -I\${prefix}/include
EOT

step "libpng 1.6.37"
have libpng16.a || {
cd libpng-1.6.37; fresh_config_sub .
./configure $HOSTARGS --disable-arm-neon > ../libpng.log
make -j$JOBS >> ../libpng.log && make install >> ../libpng.log; cd ..
}

step "libogg 1.3.5"
have libogg.a || {
cd libogg-1.3.5; fresh_config_sub .
./configure $HOSTARGS > ../ogg.log && make -j$JOBS >> ../ogg.log && make install >> ../ogg.log; cd ..
}

step "libvorbis 1.3.7"
have libvorbisfile.a || {
cd libvorbis-1.3.7; fresh_config_sub .
./configure $HOSTARGS --disable-oggtest --disable-docs --disable-examples > ../vorbis.log
make -j$JOBS >> ../vorbis.log && make install >> ../vorbis.log; cd ..
}

step "libtheora 1.1.1 (decoder only is used)"
have libtheora.a || {
cd libtheora-1.1.1; fresh_config_sub .
./configure $HOSTARGS --disable-oggtest --disable-vorbistest --disable-sdltest \
  --disable-examples --disable-spec --disable-asm > ../theora.log
# library + headers + .pc only (the doc/ spec target needs tools we skip)
make -j$JOBS -C lib >> ../theora.log && make -C lib install >> ../theora.log
make -C include install >> ../theora.log
install -m644 theora.pc theoradec.pc theoraenc.pc "$STAGE/lib/pkgconfig/"; cd ..
}

step "FreeType 2.10.1"
have libfreetype.a || {
cd freetype-2.10.1; fresh_config_sub .
./configure $HOSTARGS --with-zlib=yes --with-png=no --with-bzip2=no \
  --with-harfbuzz=no > ../freetype.log
make -j$JOBS >> ../freetype.log && make install >> ../freetype.log; cd ..
}

step "expat 2.2.9 (CMake)"
have libexpat.a || {
mkdir -p expat-build; cd expat-build
cmake ../libexpat-R_2_2_9/expat -DCMAKE_TOOLCHAIN_FILE="$REPO_DIR/build/riscos.cmake" \
  -DCMAKE_INSTALL_PREFIX="$STAGE" -DEXPAT_SHARED_LIBS=OFF \
  -DEXPAT_BUILD_TOOLS=OFF -DEXPAT_BUILD_EXAMPLES=OFF -DEXPAT_BUILD_TESTS=OFF \
  -DEXPAT_BUILD_DOCS=OFF -DCMAKE_BUILD_TYPE=Release > ../expat.log
make -j$JOBS >> ../expat.log && make install >> ../expat.log; cd ..
}

step "fontconfig 2.12.6 (needs gperf on the host)"
have libfontconfig.a || {
cd fontconfig-2.12.6; fresh_config_sub .
# UnixLib has no <sys/statfs.h>-style fs type probing; fontconfig copes.
./configure $HOSTARGS --disable-docs --with-expat="$STAGE" \
  --sysconfdir=/FontConfig --localstatedir=/FontConfig/var \
  --with-default-fonts=/Warzone2100/fonts > ../fontconfig.log
make -j$JOBS -C src >> ../fontconfig.log && make -C src install >> ../fontconfig.log
make -C fontconfig install >> ../fontconfig.log
install -m644 fontconfig.pc "$STAGE/lib/pkgconfig/"; cd ..
}

step "PhysicsFS 2.0.3 (CMake; patches/physfs)"
have libphysfs.a || {
mkdir -p physfs-build; cd physfs-build
cmake ../physfs-release-2.0.3 -DCMAKE_TOOLCHAIN_FILE="$REPO_DIR/build/riscos.cmake" \
  -DCMAKE_INSTALL_PREFIX="$STAGE" -DPHYSFS_BUILD_SHARED=OFF -DPHYSFS_BUILD_STATIC=ON \
  -DPHYSFS_BUILD_TEST=OFF -DPHYSFS_BUILD_WX_TEST=OFF -DCMAKE_BUILD_TYPE=Release > ../physfs.log
make -j$JOBS >> ../physfs.log && make install >> ../physfs.log; cd ..
}

step "popt 1.16"
have libpopt.a || {
cd popt-1.16; fresh_config_sub .
./configure $HOSTARGS --disable-nls > ../popt.log
make -j$JOBS >> ../popt.log && make install >> ../popt.log; cd ..
}

step "QuesoGLC 0.7.2 (hand-written makefile, see patches/quesoglc)"
make -C quesoglc-0.7.2/riscos -j$JOBS CC=$CC AR=$AR STAGE="$STAGE" CFLAGS="$CFLAGS" > quesoglc.log
make -C quesoglc-0.7.2/riscos install STAGE="$STAGE" >> quesoglc.log

step "done: $(ls $STAGE/lib/*.a | wc -l) static libraries in $STAGE/lib"
