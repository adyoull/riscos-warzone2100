#!/bin/bash
# Check that the linked program has riscos-unixlib's pthread ticker fix
# (patches/unixlib/unixlib-riscos.diff, UnixLib 5.0.1) built consistently:
# the start-up code (_syslib.s) must claim the whole 472-byte pthread ticker
# block from the RMA (counters and the RMA copy of the ticker routines,
# used when the PThreadTicker module isn't loaded), and agree with the C
# side's __pthread_callevery_block_size.
#
#   tools/check-unixlib.sh [program]   (default: the unstripped build)
#
# Why: _syslib.s includes asm_dec.s, and GCCSDK's UnixLib makefile didn't
# rebuild assembler files when an include changed. riscos14/15 shipped a
# stale _syslib.o that claimed a smaller block; the handler was then copied
# past its end, corrupting the RMA and hanging the machine. riscos-unixlib
# fixed the dependencies and checks the size at start-up, but after
# changing patches/unixlib still rebuild UnixLib from clean
# (build/build-toolchain.sh unixlib).
. "$(dirname "$0")/../build/env.sh"
ELF=${1:-$SRC/warzone2100-2.3.9/src/warzone2100}
OBJDUMP=$GCCSDK_ENV/bin/arm-riscos-gnueabihf-objdump
NM=$GCCSDK_ENV/bin/arm-riscos-gnueabihf-nm
"$NM" "$ELF" | grep -q ' __pthread_ticker_init$' || { echo "no __pthread_ticker_init: not UnixLib 5.0.1's ticker" >&2; exit 1; }
# The claim: "mov r3, #<size>" then OS_Module (svc 0x2001e) in no_dynamic_area.
size=$("$OBJDUMP" -d "$ELF" | awk '/^[0-9a-f]+ <no_dynamic_area>:$/{p=1;next} p&&/^$/{exit}
  p&&/mov\tr3, #/{s=$0} p&&/svc\t0x0002001e/{sub(/.*#/,"",s); sub(/[ \t;].*/,"",s); print s; exit}')
want=472
# __pthread_callevery_block_size, a little-endian word in .data
addr=$("$NM" "$ELF" | awk '$3=="__pthread_callevery_block_size"{print $1}')
csize=$("$OBJDUMP" -s -j .data --start-address=0x$addr --stop-address=$(printf '0x%x' $((0x$addr+4))) "$ELF" |
  awk 'NR>4&&NF>=2{w=$2; print strtonum("0x" substr(w,7,2) substr(w,5,2) substr(w,3,2) substr(w,1,2)); exit}')
[ "$csize" = "$want" ] || { echo "WRONG: __pthread_callevery_block_size is '$csize', not $want" >&2; exit 1; }
case $size in
  $want) echo "OK: UnixLib claims the $want-byte pthread ticker block, and the C side agrees";;
  "") echo "can't find the ticker block claim in $ELF" >&2; exit 1;;
  *) echo "WRONG: UnixLib claims $size bytes for the pthread ticker block, not $want." >&2
     echo "Rebuild UnixLib from clean: build/build-toolchain.sh unixlib." >&2; exit 1;;
esac
