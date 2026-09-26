#!/bin/bash -e
# Download the library sources listed in build/SHA256SUMS.txt into $DL
# (default $REPO_DIR/dl), check them, and unpack them into $SRC.
# Ubuntu orig tarballs come from archive.ubuntu.com. The GitHub ones
# (wz239.tgz, physfs-2.0.3.tgz, dejavu-fonts-ttf-2.37.zip) are fetched from
# GitHub; if this machine can't reach GitHub, put them in $DL by hand.
. "$(dirname "$0")/env.sh"
: "${DL:=$REPO_DIR/dl}"
mkdir -p "$DL"; cd "$DL"
U=https://archive.ubuntu.com/ubuntu/pool
get() {  # file url
  [ -s "$1" ] && return 0
  echo "fetch $1"; curl -fsSL -o "$1.part" "$2" && mv "$1.part" "$1" || { rm -f "$1.part"; echo "  FAILED: $2" >&2; }
}
get libpng1.6_1.6.37.orig.tar.gz        $U/main/libp/libpng1.6/libpng1.6_1.6.37.orig.tar.gz
get libogg_1.3.5.orig.tar.gz            $U/main/libo/libogg/libogg_1.3.5.orig.tar.gz
get libvorbis_1.3.7.orig.tar.gz         $U/main/libv/libvorbis/libvorbis_1.3.7.orig.tar.gz
get libtheora_1.1.1+dfsg.1.orig.tar.gz  $U/main/libt/libtheora/libtheora_1.1.1+dfsg.1.orig.tar.gz
get freetype_2.10.1.orig.tar.gz         $U/main/f/freetype/freetype_2.10.1.orig.tar.gz
get expat_2.2.9.orig.tar.gz             $U/main/e/expat/expat_2.2.9.orig.tar.gz
get fontconfig_2.12.6.orig.tar.bz2      $U/main/f/fontconfig/fontconfig_2.12.6.orig.tar.bz2
get popt_1.16.orig.tar.gz               $U/main/p/popt/popt_1.16.orig.tar.gz
get quesoglc_0.7.2.orig.tar.gz          $U/universe/q/quesoglc/quesoglc_0.7.2.orig.tar.gz
get physfs-2.0.3.tgz          https://codeload.github.com/icculus/physfs/tar.gz/refs/tags/release-2.0.3
get wz239.tgz                 https://codeload.github.com/Warzone2100/warzone2100/tar.gz/refs/tags/v2.3.9
get dejavu-fonts-ttf-2.37.zip https://github.com/dejavu-fonts/dejavu-fonts/releases/download/version_2_37/dejavu-fonts-ttf-2.37.zip
sha256sum -c "$REPO_DIR/build/SHA256SUMS.txt"

# Unpack into $SRC and apply the patches (skips anything already unpacked).
cd "$SRC"
for f in "$DL"/*.tar.* "$DL"/*.tgz; do
  d=$(tar tf "$f" | head -1); d=${d%%/*}
  [ -d "$d" ] || { echo "unpack $d"; tar xf "$f"; }
done
[ -d dejavu-fonts-ttf-2.37 ] || unzip -q "$DL/dejavu-fonts-ttf-2.37.zip"
pat() {  # dir -pN patch...
  local d=$1 p=$2; shift 2
  [ -f "$d/.riscos-patched" ] && return 0
  for f; do echo "patch $d < $(basename "$f")"; patch -d "$d" $p -s < "$f"; done
  touch "$d/.riscos-patched"
}
pat physfs-release-2.0.3 -p1 "$REPO_DIR"/patches/physfs/*.diff
pat quesoglc-0.7.2       -p1 "$REPO_DIR"/patches/quesoglc/*.diff
pat warzone2100-2.3.9    -p1 "$REPO_DIR"/patches/warzone2100/*.patch
