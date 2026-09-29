#!/bin/bash -e
# Assemble !Warzone2100 and zip it with RISC OS filetypes. Output: ./dist
#   package.sh            (after build-deps.sh and build-wz.sh)
. "$(dirname "$0")/env.sh"
: "${WZ_SRC:=$SRC/warzone2100-2.3.9}"
# elf2aif (with the >32MB image fix; tools/elf2aif), built by
# build/build-toolchain.sh (all, or just: build-toolchain.sh elf2aif).
: "${ELF2AIF:=$REPO_DIR/toolchain/elf2aif}"
[ -x "$ELF2AIF" ] || { echo "no $ELF2AIF: run build/build-toolchain.sh elf2aif" >&2; exit 1; }
: "${DEJAVU:=$SRC/dejavu-fonts-ttf-2.37}"
VERSION=${VERSION:-2.3.9-7}
OUT="$REPO_DIR/dist"; APP="$OUT/!Warzone2100"
rm -rf "$OUT"; mkdir -p "$OUT"
cp -a "$REPO_DIR/app/!Warzone2100" "$APP"

# Program: stripped, then Absolute (AIF) so it needs no ELF loader.
$STRIP -o "$OUT/warzone2100.elf" "$WZ_SRC/src/warzone2100"
"$ELF2AIF" -e "$OUT/warzone2100.elf" "$APP/warzone2100,ff8"
rm "$OUT/warzone2100.elf"

# PThreadTicker module (riscos-unixlib, built with UnixLib by
# build-toolchain.sh; BSD licence), loaded by !Run.
cp "$REPO_DIR/toolchain/gcc-10.2.0/cross-build/arm-riscos-gnueabihf/libunixlib/pthticker" "$APP/PThrTicker,ffa"

# Game data (zip archives, typed Data so SparkFS leaves them alone).
mkdir -p "$APP/data/music"
cp "$WZ_SRC/data/base.wz" "$WZ_SRC/data/mp.wz" "$APP/data/"
# Music (Ogg Vorbis) and its playlist, played when the build has sound.
cp "$WZ_SRC"/data/music/*.ogg "$WZ_SRC/data/music/music.wpl" "$APP/data/music/"

# Fonts (the game asks fontconfig for "DejaVu Sans").
cp "$DEJAVU/ttf/DejaVuSans.ttf" "$DEJAVU/ttf/DejaVuSans-Bold.ttf" "$APP/fonts/"
cp "$DEJAVU/LICENSE" "$APP/docs/DejaVu-LICENSE,fff"

# Licences and the source changes (GPL: the patches, with the upstream
# version they apply to, are the corresponding source for this build).
cp "$REPO_DIR/CHANGELOG.md" "$APP/docs/Changes,fff"
cp "$WZ_SRC/COPYING" "$APP/docs/COPYING,fff"
cp "$WZ_SRC/COPYING.NONGPL" "$APP/docs/COPYING-NONGPL,fff"
cp "$WZ_SRC/COPYING.README" "$APP/docs/COPYING-README,fff"
cp "$DEVKIT/LICENCES.txt" "$APP/docs/riscos-mesa-LICENCES,fff"
# The libraries linked in from stage/ (see build/build-deps.sh).
mkdir -p "$APP/docs/licences"
lic() { cp "$SRC/$2" "$APP/docs/licences/$1,fff"; }
lic libpng       libpng-1.6.37/LICENSE
lic FreeType     freetype-2.10.1/docs/FTL.TXT
lic fontconfig   fontconfig-2.12.6/COPYING
lic expat        libexpat-R_2_2_9/expat/COPYING
lic PhysicsFS    physfs-release-2.0.3/LICENSE.txt
lic popt         popt-1.16/COPYING
lic QuesoGLC     quesoglc-0.7.2/COPYING
lic libogg       libogg-1.3.5/COPYING
lic libvorbis    libvorbis-1.3.7/COPYING
lic libtheora    libtheora-1.1.1/COPYING
cp "$REPO_DIR/riscos/PThreadTicker-Licence" "$APP/docs/licences/PThreadTicker,fff"
mkdir -p "$APP/docs/patches"
for p in "$REPO_DIR"/patches/*/*; do cp "$p" "$APP/docs/patches/$(basename "$p"),fff"; done

( cd "$OUT" && python3 "$REPO_DIR/tools/rozip.py" "Warzone2100-$VERSION.zip" '!Warzone2100' )
ls -l "$OUT"/*.zip
