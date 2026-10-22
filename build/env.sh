# Source this. Settings shared by the riscos-warzone2100 build scripts.
# GCCSDK_ENV: the GCCSDK GCC 10 install (contains bin/arm-riscos-gnueabihf-gcc):
#   riscos-crossdev's toolchain ($RISCOS_TOOLCHAIN, set in its container
#   image) when there is one, else one built by build/build-toolchain.sh.
# DEVKIT: the unpacked riscos-mesa devkit (lib/libOSMesa.a, lib/libSDL2.a, ...)
#   of the riscos-mesa release named in .riscos-deps: riscos-crossdev's
#   ($RISCOS_DEVKIT) if it's that version, else devkit/riscos-mesa-devkit-<v>
#   (build/fetch-sources.sh downloads it there).
REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
MESA_VERSION=$(awk '$1 == "riscos-mesa" || $1 == "adyoull/riscos-mesa" {sub(/^v/, "", $2); print $2}' "$REPO_DIR/.riscos-deps")
[ -n "$MESA_VERSION" ] || { echo "env.sh: .riscos-deps has no riscos-mesa line" >&2; return 1 2>/dev/null || exit 1; }
if [ -z "${GCCSDK_ENV:-}" ]; then
  if [ -n "${RISCOS_TOOLCHAIN:-}" ] && [ -x "$RISCOS_TOOLCHAIN/bin/arm-riscos-gnueabihf-gcc" ]; then
    GCCSDK_ENV=$RISCOS_TOOLCHAIN
  else
    GCCSDK_ENV=$HOME/gccsdk/env
  fi
fi
if [ -z "${DEVKIT:-}" ]; then
  if [ -n "${RISCOS_DEVKIT:-}" ] && [ "$(awk '{print $NF; exit}' "$RISCOS_DEVKIT/VERSION" 2>/dev/null)" = "$MESA_VERSION" ]; then
    DEVKIT=$RISCOS_DEVKIT
  else
    DEVKIT=$REPO_DIR/devkit/riscos-mesa-devkit-$MESA_VERSION
  fi
fi
: "${STAGE:=$REPO_DIR/stage}"     # install prefix for the libraries built here
: "${SRC:=$REPO_DIR/src}"         # downloaded, unpacked sources
: "${JOBS:=$(nproc)}"
export REPO_DIR GCCSDK_ENV DEVKIT MESA_VERSION STAGE SRC JOBS
# autoconf/libtool can't cope with spaces in --prefix, -I/-L flags or LIBS, so
# STAGE, SRC, DEVKIT and GCCSDK_ENV must be space-free even if the repo isn't
# (e.g. a folder name with a space in it): point them elsewhere or at a symlink.
case "$STAGE|$SRC|$DEVKIT|$GCCSDK_ENV" in *" "*)
  echo "env.sh: STAGE, SRC, DEVKIT and GCCSDK_ENV must not contain spaces" >&2
  echo "  (try: ln -s \"$REPO_DIR\" ~/wz && cd ~/wz)" >&2
  return 1 2>/dev/null || exit 1;;
esac
# The build machine's triplet (was hard-coded x86_64; the Mac's VM is aarch64).
export BUILD=$(gcc -dumpmachine)
export PATH="$GCCSDK_ENV/bin:$PATH"
export HOST=arm-riscos-gnueabihf
export CC=$HOST-gcc CXX=$HOST-g++ AR=$HOST-ar RANLIB=$HOST-ranlib STRIP=$HOST-strip
# Same flags as riscos-mesa (Pi 4 benchmarked). -fstack-clash-protection is
# REQUIRED: ARMEABISupport maps the stack a page at a time, so any frame
# > 4 KB must probe page by page or it skips the guard page and aborts.
# FPU: vfpv3 (default) runs on every ARMv7 RISC OS machine with VFP (Cortex-A8
# and A9 boards as well as the Pi 2 onwards); vfpv4 adds fused multiply-add,
# which only Cortex-A7/A15/A53/A72 have. The devkit must match (tools/check-fpu.sh).
: "${FPU:=vfpv3}"
export FPU
export RO_CFLAGS="-O3 -mtune=cortex-a72 -mfpu=$FPU -mfloat-abi=hard -fstack-clash-protection"
export CFLAGS="$RO_CFLAGS" CXXFLAGS="$RO_CFLAGS"
export CPPFLAGS="-I$STAGE/include" LDFLAGS="-L$STAGE/lib"
export PKG_CONFIG_LIBDIR="$STAGE/lib/pkgconfig:$STAGE/share/pkgconfig"
export PKG_CONFIG_SYSROOT_DIR=
mkdir -p "$STAGE/lib/pkgconfig" "$STAGE/include" "$SRC"

# configure scripts older than 2018 don't know "riscos": give them a current
# config.sub/config.guess (from the host's automake).
fresh_config_sub() {   # dir
  local d=$1 f
  for f in config.sub config.guess; do
    find "$d" -name $f -exec cp "$(ls /usr/share/automake-*/$f | tail -1)" {} \;
  done
}
