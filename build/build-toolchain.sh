#!/bin/bash -e
# Build GCCSDK GCC 10.2.0 (arm-riscos-gnueabihf) into $GCCSDK_ENV, static
# linking only. Follows riscos-mesa build/TOOLCHAIN.md (GCCSDK's autobuilder
# recipe autobuilder/develop/gcc/setvars, without the GCC 4.7.4 bootstrap),
# plus: the target libraries (libgcc, UnixLib, libstdc++) are built with
# -fstack-clash-protection in the first place, so none has an unprobed frame.
#
# Needs on the host: gcc/g++, make, autogen, autoconf2.69, autoconf2.64,
# automake-1.11, libtool, flex, bison, m4, texinfo (any version).
# Sources in $DL (default $REPO_DIR/dl):
#   gccsdk-64c6f81.tar.gz    github.com/jhamby/riscos-gccsdk at 64c6f81
#   gcc-10.2.0.tar.gz        github.com/gcc-mirror/gcc tag releases/gcc-10.2.0
#   binutils_2.30.orig.tar.xz, gmp_6.2.1+dfsg.orig.tar.xz,
#   mpfr4_4.1.0.orig.tar.xz, mpclib3_1.2.1.orig.tar.gz   (Ubuntu pool)
# Usage: build-toolchain.sh [binutils|gcc|all]
. "$(dirname "$0")/env.sh"
# env.sh's cross settings must not leak into the host-side builds.
unset CC CXX AR RANLIB STRIP CFLAGS CXXFLAGS CPPFLAGS LDFLAGS PKG_CONFIG_LIBDIR PKG_CONFIG_SYSROOT_DIR
: "${DL:=$REPO_DIR/dl}"
: "${TC:=$REPO_DIR/toolchain}"          # work directory
WHAT=${1:-all}
T=arm-riscos-gnueabihf
mkdir -p "$TC" "$GCCSDK_ENV"; cd "$TC"
[ -d gccsdk ] || { tar xf "$DL"/gccsdk-64c6f81.tar.gz; mv riscos-gccsdk-64c6f81* gccsdk; }
H=$TC/gccsdk/autobuilder/develop/gcc
UL=$TC/gccsdk/gcc4/recipe/files/gcc/libunixlib

# texinfo 7 can't build the old manuals: a makeinfo that claims 4.2 makes
# both configure scripts skip the docs.
mkdir -p fakebin
printf '#!/bin/sh\necho "makeinfo (GNU texinfo) 4.2"\n' > fakebin/makeinfo
chmod +x fakebin/makeinfo
export PATH="$TC/fakebin:$GCCSDK_ENV/bin:$PATH" MAKEINFO="$TC/fakebin/makeinfo"
export GCCSDK_RISCOS_ABI_VERSION=armeabihf
export ac_cv_func_shl_load=no ac_cv_lib_dld_shl_load=no ac_cv_func_dlopen=yes \
       glibcxx_cv_c99_math_tr1=yes

if [ "$WHAT" != gcc ]; then
  echo "=== binutils 2.30"
  rm -rf binutils-2.30; tar xf "$DL"/binutils_2.30.orig.tar.xz
  ln -sf "$H"/ld.emulparams.armelf_riscos_eabi.sh binutils-2.30/ld/emulparams/armelf_riscos_eabi.sh
  ln -sf "$H"/gas.config.te-riscos.h binutils-2.30/gas/config/te-riscos.h
  for p in "$H"/*.pp; do patch -d binutils-2.30 -p0 -l -s < "$p"; done
  # ld/Makefile.am is patched: regenerate with the versions binutils 2.30 used.
  ( cd binutils-2.30/ld && ACLOCAL=aclocal-1.11 AUTOMAKE=automake-1.11 \
      AUTOCONF=autoconf2.64 AUTOHEADER=autoheader2.64 autoreconf2.64 )
  mkdir -p binutils-2.30/cross-build; cd binutils-2.30/cross-build
  CC=gcc CXX=g++ CFLAGS="-O2 -fcommon" ../configure --prefix="$GCCSDK_ENV" \
    --target=$T --disable-nls --disable-werror > ../../binutils-configure.log
  make -j$JOBS > ../../binutils-make.log 2>&1
  make install >> ../../binutils-make.log 2>&1
  cd "$TC"
fi

if [ "$WHAT" != binutils ]; then
  echo "=== GCC 10.2.0"
  S=$TC/gcc-10.2.0
  rm -rf "$S"; tar xf "$DL"/gcc-10.2.0.tar.gz; mv gcc-releases-gcc-10.2.0 "$S"
  for p in "$H"/*.p; do patch -d "$S" -p0 -l -s < "$p"; done
  # copy_link_gcc
  mkdir -p "$S"/libstdc++-v3/config/os/riscos
  for f in riscos-elf.h riscos-gnueabihf.h riscos-gcc.c riscos.c riscos.md riscos.opt \
           t-arm-riscos-elf t-riscos-gnueabihf xm-riscos.h; do
    ln -sf "$H"/gcc.config.arm.$f "$S"/gcc/config/arm/$f; done
  for f in t-arm-riscos-elf t-riscos-gnueabihf; do
    ln -sf "$H"/libgcc.config.arm.$f "$S"/libgcc/config/arm/$f; done
  for f in ctype_base.h ctype_configure_char.cc ctype_inline.h error_constants.h os_defines.h; do
    ln -sf "$H"/libstdc++-v3.config.os.riscos.$f "$S"/libstdc++-v3/config/os/riscos/$f; done
  cp -a "$UL" "$S"/libunixlib
  # gmp/mpfr/mpc in-tree instead of contrib/download_prerequisites
  tar xf "$DL"/gmp_6.2.1+dfsg.orig.tar.xz -C "$TC"; tar xf "$DL"/mpfr4_4.1.0.orig.tar.xz -C "$TC"
  tar xf "$DL"/mpclib3_1.2.1.orig.tar.gz -C "$TC"
  ln -sfn "$TC"/gmp-6.2.1+dfsg "$S"/gmp; ln -sfn "$TC"/mpfr-4.1.0 "$S"/mpfr; ln -sfn "$TC"/mpc-1.2.1 "$S"/mpc

  # TOOLCHAIN.md deviation 1: stubs so UnixLib's and libstdc++'s configure
  # link tests work before UnixLib exists (make install replaces them).
  L=$GCCSDK_ENV/$T/lib; mkdir -p "$L"; ( cd "$L"
    printf '.global _start\n_start:\n bx lr\n' | $T-as -o crt0.o
    : | $T-as -o empty.o
    for a in libunixlib.a libc.a libpthread.a; do [ -f $a ] || $T-ar rc $a empty.o; done
    [ -f libunixlib.so ] || $T-ld -m armelf_riscos_eabi -shared -o libunixlib.so empty.o
    rm empty.o )

  ( cd "$S" && autogen Makefile.def && autoconf2.69 && AUTOCONF=autoconf2.69 "$H"/reconf-libunixlib \
      && AUTOCONF=autoconf2.69 "$H"/reconf-libstdc++ ) > gcc-autogen.log 2>&1
  mkdir -p "$S"/cross-build; cd "$S"/cross-build
  TFLAGS="-g -O2 -fstack-clash-protection"
  CC=gcc CXX=g++ CFLAGS=-O1 CXXFLAGS=-O1 \
  CFLAGS_FOR_TARGET="$TFLAGS" CXXFLAGS_FOR_TARGET="$TFLAGS" \
  ../configure --prefix="$GCCSDK_ENV" --target=$T \
    --enable-shared=libunixlib,libgcc,libstdc++ --enable-languages=c,c++ \
    --enable-threads=posix --enable-sjlj-exceptions=no --enable-__cxa_atexit \
    --enable-c99 --enable-cmath --disable-libstdcxx-pch --disable-libquadmath \
    --disable-nls --disable-tls --disable-libssp --disable-libgomp --disable-libitm \
    --disable-lto --disable-multilib \
    --with-pkgversion='GCCSDK GCC 10.2.0 Release 2 (riscos-warzone2100)' \
    --with-bugurl=http://gccsdk.riscos.info/ --with-abi=aapcs-linux \
    --with-float=hard --with-fpu=vfpv3 --with-arch=armv7-a > "$TC"/gcc-configure.log
  make -j$JOBS > "$TC"/gcc-make.log 2>&1
  make install > "$TC"/gcc-install.log 2>&1
  cd "$TC"
  echo "=== smoke test"
  printf '#include <stdio.h>\nint main(void){puts("hi");return 0;}\n' > hello.c
  printf '#include <iostream>\nint main(){std::cout<<"hi"<<std::endl;}\n' > hello.cc
  $T-gcc -static -O2 hello.c -o hello-c && $T-g++ -static -O2 hello.cc -o hello-cc && ls -l hello-c hello-cc
fi
