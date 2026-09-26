#!/bin/bash -e
# Assemble !Warzone2100 and zip it with RISC OS filetypes. Output: ./dist
#   package.sh            (after build-deps.sh and build-wz.sh)
. "$(dirname "$0")/env.sh"
: "${WZ_SRC:=$SRC/warzone2100-2.3.9}"
# elf2aif with the >32MB image fix, from the RISC OS OpenTTD port
# (github.com/adyoull/riscos-openttd, tools/elf2aif). Build it first.
: "${ELF2AIF:=$REPO_DIR/../riscos-openttd/tools/elf2aif/elf2aif}"
: "${DEJAVU:=$SRC/dejavu-fonts-ttf-2.37}"
VERSION=2.3.9-riscos7
OUT="$REPO_DIR/dist"; APP="$OUT/!Warzone2100"
rm -rf "$OUT"; mkdir -p "$OUT"
cp -a "$REPO_DIR/app/!Warzone2100" "$APP"

# Program: stripped, then Absolute (AIF) so it needs no ELF loader.
$STRIP -o "$OUT/warzone2100.elf" "$WZ_SRC/src/warzone2100"
"$ELF2AIF" -e "$OUT/warzone2100.elf" "$APP/warzone2100,ff8"
rm "$OUT/warzone2100.elf"

# Game data (zip archives, typed Data so SparkFS leaves them alone).
mkdir -p "$APP/data"
cp "$WZ_SRC/data/base.wz" "$WZ_SRC/data/mp.wz" "$APP/data/"

# Fonts (the game asks fontconfig for "DejaVu Sans").
cp "$DEJAVU/ttf/DejaVuSans.ttf" "$DEJAVU/ttf/DejaVuSans-Bold.ttf" "$APP/fonts/"
cp "$DEJAVU/LICENSE" "$APP/docs/DejaVu-LICENSE,fff"

# Licences and the source changes (GPL: the patches, with the upstream
# version they apply to, are the corresponding source for this build).
cp "$WZ_SRC/COPYING" "$APP/docs/COPYING,fff"
cp "$WZ_SRC/COPYING.NONGPL" "$APP/docs/COPYING-NONGPL,fff"
cp "$WZ_SRC/COPYING.README" "$APP/docs/COPYING-README,fff"
cp "$DEVKIT/LICENCES.txt" "$APP/docs/riscos-mesa-LICENCES,fff"
mkdir -p "$APP/docs/patches"
for p in "$REPO_DIR"/patches/*/*; do cp "$p" "$APP/docs/patches/$(basename "$p"),fff"; done

( cd "$OUT" && python3 "$REPO_DIR/tools/rozip.py" "Warzone2100-$VERSION.zip" '!Warzone2100' )
ls -l "$OUT"/*.zip
