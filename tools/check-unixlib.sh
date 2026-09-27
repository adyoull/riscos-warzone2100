#!/bin/bash
# Check that the linked program has patches/unixlib/unixlib-pthread-ticker-rma.diff
# built consistently: the start-up code (_syslib.s) must claim the whole
# pthread ticker block from the RMA, including the room for the handler
# that pthinit.c copies into it.
#
#   tools/check-unixlib.sh [program]   (default: the unstripped build)
#
# Why: _syslib.s includes asm_dec.s, but UnixLib's makefile doesn't rebuild
# assembler files when an include changes. riscos14/15 shipped a stale
# _syslib.o that claimed the old 120-byte block; the 72-byte handler was
# then copied past its end, corrupting the RMA and hanging the machine.
# After changing any UnixLib header, rebuild UnixLib with "make clean".
. "$(dirname "$0")/../build/env.sh"
ELF=${1:-$SRC/warzone2100-2.3.9/src/warzone2100}
OBJDUMP=$GCCSDK_ENV/bin/arm-riscos-gnueabihf-objdump
NM=$GCCSDK_ENV/bin/arm-riscos-gnueabihf-nm
"$NM" "$ELF" | grep -q ' __pthread_call_every_code$' || { echo "no __pthread_call_every_code: UnixLib without the ticker patch" >&2; exit 1; }
# The claim: "mov r3, #<size>" then OS_Module (svc 0x2001e) in no_dynamic_area.
size=$("$OBJDUMP" -d "$ELF" | awk '/^[0-9a-f]+ <no_dynamic_area>:$/{p=1;next} p&&/^$/{exit}
  p&&/mov\tr3, #/{s=$0} p&&/svc\t0x0002001e/{sub(/.*#/,"",s); sub(/[ \t;].*/,"",s); print s; exit}')
case $size in
  248) echo "OK: UnixLib claims the 248-byte pthread ticker block (handler included)";;
  "") echo "can't find the ticker block claim in $ELF" >&2; exit 1;;
  *) echo "WRONG: UnixLib claims $size bytes for the pthread ticker block, not 248." >&2
     echo "Rebuild UnixLib with make clean (see BUILDING.md)." >&2; exit 1;;
esac
