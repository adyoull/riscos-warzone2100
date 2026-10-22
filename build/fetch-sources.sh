#!/bin/bash -e
# Download the sources listed in build/SHA256SUMS.txt into $DL (default
# $REPO_DIR/dl), check them, and unpack them into $SRC. Also the riscos-mesa
# devkit .riscos-deps names, into devkit/, unless build/env.sh found it
# already (riscos-crossdev's image has one).
# Ubuntu orig tarballs come from archive.ubuntu.com, fontconfig from Debian,
# the rest from GitHub. If this machine can't reach them, put the files in
# $DL by hand. (GitHub's generated archives have very occasionally changed;
# if a checksum fails, compare the unpacked tree with upstream before
# updating it.)
# The toolchain's sources (for build/build-toolchain.sh) are fetched only
# when $GCCSDK_ENV has no compiler yet, or with FETCH_TOOLCHAIN=1.
. "$(dirname "$0")/env.sh"
: "${DL:=$REPO_DIR/dl}"
SUMS=$REPO_DIR/build/SHA256SUMS.txt
mkdir -p "$DL"; cd "$DL"
U=https://archive.ubuntu.com/ubuntu/pool
got=()
get() {  # file url
  got+=("$1")
  [ -s "$1" ] && return 0
  echo "fetch $1"
  curl -fsSL --retry 3 -o "$1.part" "$2" && mv "$1.part" "$1" || { rm -f "$1.part"; echo "FAILED: $2" >&2; exit 1; }
}
get libpng1.6_1.6.37.orig.tar.gz        $U/main/libp/libpng1.6/libpng1.6_1.6.37.orig.tar.gz
get libogg_1.3.5.orig.tar.gz            $U/main/libo/libogg/libogg_1.3.5.orig.tar.gz
get libvorbis_1.3.7.orig.tar.gz         $U/main/libv/libvorbis/libvorbis_1.3.7.orig.tar.gz
get libtheora_1.1.1+dfsg.1.orig.tar.gz  $U/main/libt/libtheora/libtheora_1.1.1+dfsg.1.orig.tar.gz
get freetype_2.10.1.orig.tar.gz         $U/main/f/freetype/freetype_2.10.1.orig.tar.gz
get expat_2.2.9.orig.tar.gz             $U/main/e/expat/expat_2.2.9.orig.tar.gz
# fontconfig 2.14.1 is the version in PackMan; Ubuntu no longer has it, Debian bookworm does.
get fontconfig_2.14.1.orig.tar.xz       https://deb.debian.org/debian/pool/main/f/fontconfig/fontconfig_2.14.1.orig.tar.xz
get popt_1.16.orig.tar.gz               $U/main/p/popt/popt_1.16.orig.tar.gz
get quesoglc_0.7.2.orig.tar.gz          $U/universe/q/quesoglc/quesoglc_0.7.2.orig.tar.gz
get physfs-2.0.3.tgz          https://codeload.github.com/icculus/physfs/tar.gz/refs/tags/release-2.0.3
get wz239.tgz                 https://codeload.github.com/Warzone2100/warzone2100/tar.gz/refs/tags/v2.3.9
get dejavu-fonts-ttf-2.37.zip https://github.com/dejavu-fonts/dejavu-fonts/releases/download/version_2_37/dejavu-fonts-ttf-2.37.zip
# The riscos-mesa devkit (a release asset of github.com/adyoull/riscos-mesa).
if [ ! -f "$DEVKIT/lib/libOSMesa.a" ]; then
  [ "$DEVKIT" = "$REPO_DIR/devkit/riscos-mesa-devkit-$MESA_VERSION" ] ||
    { echo "no devkit in $DEVKIT" >&2; exit 1; }
  dk=riscos-mesa-devkit-$MESA_VERSION.tgz
  grep -q "  $dk\$" "$SUMS" || { echo "$SUMS has no line for $dk (ci/riscos-deps-hook.sh adds it)" >&2; exit 1; }
  get $dk https://github.com/adyoull/riscos-mesa/releases/download/v$MESA_VERSION/$dk
fi
# Toolchain sources (build/build-toolchain.sh).
if [ "${FETCH_TOOLCHAIN:-}" = 1 ] || [ ! -x "$GCCSDK_ENV/bin/arm-riscos-gnueabihf-gcc" ]; then
  get binutils_2.30.orig.tar.xz           $U/main/b/binutils/binutils_2.30.orig.tar.xz
  get gmp_6.2.1+dfsg.orig.tar.xz          $U/main/g/gmp/gmp_6.2.1+dfsg.orig.tar.xz
  get mpfr4_4.1.0.orig.tar.xz             $U/main/m/mpfr4/mpfr4_4.1.0.orig.tar.xz
  get mpclib3_1.2.1.orig.tar.gz           $U/main/m/mpclib3/mpclib3_1.2.1.orig.tar.gz
  get gccsdk-64c6f81.tar.gz     https://codeload.github.com/jhamby/riscos-gccsdk/tar.gz/64c6f81
  get gcc-10.2.0.tar.gz         https://codeload.github.com/gcc-mirror/gcc/tar.gz/refs/tags/releases/gcc-10.2.0
fi
# Check what was fetched (or already there) against SHA256SUMS.txt.
: > "$DL/.check"
for f in "${got[@]}"; do
  grep "  $f\$" "$SUMS" >> "$DL/.check" || { echo "$SUMS has no line for $f" >&2; exit 1; }
done
sha256sum -c --quiet "$DL/.check"
echo "checked: ${#got[@]} files"
if [ ! -f "$DEVKIT/lib/libOSMesa.a" ]; then
  echo "unpack $dk"; mkdir -p "$REPO_DIR/devkit"; tar xzf "$DL/$dk" -C "$REPO_DIR/devkit"
  [ -f "$DEVKIT/lib/libOSMesa.a" ] || { echo "$dk didn't unpack to $DEVKIT" >&2; exit 1; }
fi

# Unpack into $SRC and apply the patches (skips anything already unpacked).
cd "$SRC"
for f in "$DL"/*.tar.* "$DL"/*.tgz; do
  case $(basename "$f") in   # toolchain sources (build-toolchain.sh unpacks
    # those) and the devkit (above)
    gccsdk-*|gcc-*|binutils_*|gmp_*|mpfr4_*|mpclib3_*|riscos-mesa-devkit-*) continue;;
  esac
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
pat fontconfig-2.14.1    -p1 "$REPO_DIR"/patches/fontconfig/*.diff
pat warzone2100-2.3.9    -p1 "$REPO_DIR"/patches/warzone2100/*.patch
