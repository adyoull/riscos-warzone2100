# Source this. Settings shared by the riscos-warzone2100 build scripts.
# GCCSDK_ENV: the GCCSDK GCC 10 install (contains bin/arm-riscos-gnueabihf-gcc),
#   e.g. built by riscos-mesa's build/TOOLCHAIN.md recipe or the OpenTTD buildkit.
# DEVKIT: the unpacked riscos-mesa devkit (lib/libOSMesa.a, lib/libSDL2.a, ...).
REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
: "${GCCSDK_ENV:=$HOME/gccsdk/env}"
: "${DEVKIT:=$REPO_DIR/devkit/riscos-mesa-devkit-20.3.5-5}"
: "${STAGE:=$REPO_DIR/stage}"     # install prefix for the libraries built here
: "${SRC:=$REPO_DIR/src}"         # downloaded, unpacked sources
: "${JOBS:=$(nproc)}"
export REPO_DIR GCCSDK_ENV DEVKIT STAGE SRC JOBS
export PATH="$GCCSDK_ENV/bin:$PATH"
export HOST=arm-riscos-gnueabihf
export CC=$HOST-gcc CXX=$HOST-g++ AR=$HOST-ar RANLIB=$HOST-ranlib STRIP=$HOST-strip
# Same flags as riscos-mesa (Pi 4 benchmarked). -fstack-clash-protection is
# REQUIRED: ARMEABISupport maps the stack a page at a time, so any frame
# > 4 KB must probe page by page or it skips the guard page and aborts.
export RO_CFLAGS="-O3 -mtune=cortex-a72 -mfpu=vfpv4 -mfloat-abi=hard -fstack-clash-protection"
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
