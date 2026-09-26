#!/bin/bash
# List casts in Warzone 2100's own code that can produce unaligned 16/32-bit
# loads or stores. RISC OS traps those ("abort on data transfer", reported
# by UnixLib as "Fatal signal received: EMT trap"); Linux doesn't, so the
# upstream code has them. Fix any it reports with wz_load_*/wz_store_*
# (lib/framework/endian_hack.h) or a packed struct.
#
#   tools/check-unaligned.sh [-a]     (after build/build-wz.sh has configured)
#
# Compiles every .c/.cpp with -fsyntax-only -Wcast-align=strict and hides the
# warnings known to be safe (patterns below: casts of malloc'd buffers plus
# fixed 4-byte-multiple headers and sizeof strides, endian_* calls that do
# nothing on little-endian, debug-only code). -a shows everything.
# Exit status 1 if anything is left to review.
. "$(dirname "$0")/../build/env.sh"
WZ=${WZ_SRC:-$SRC/warzone2100-2.3.9}
[ -f "$WZ/config.h" ] || { echo "run build/build-wz.sh first (needs config.h)" >&2; exit 2; }
cd "$WZ"
LOG=$(mktemp); trap 'rm -f "$LOG"' EXIT
I="-I$STAGE/include -I$STAGE/include/SDL2 -I$STAGE/include/libpng16"
for f in $(find src lib -name '*.c' -o -name '*.cpp' | grep -v -e '/test' -e 'lib/sound/' \
           -e exchndl.c -e x-motif-messagebox.c -e miniupnpcmodule.c | sort); do
  case $f in *.cpp) C=$CXX;; *) C=$CC;; esac
  $C -fsyntax-only -Wcast-align=strict -DHAVE_CONFIG_H -DYY_NO_INPUT -D_REENTRANT \
     -I. -I"$(dirname "$f")" -Isrc -Ilib/ivis_opengl $I "$f" 2>&1 \
    | awk '/warning: cast increases required alignment/ { w=$0; getline src; print w " @@ " src }'
done > "$LOG"

SAFE='endian_(u|s)(word|dword)\(|_HEADER_SIZE\)|\+ *sizeof|HEADER ?\*\) ?\*?p?pFileData|\(SAVE_[A-Z_0-9]+ ?\*\) ?pFileData|COMPONENT_STATS ?\*\)|BASE_STATS ?\*\)\(\(char|NewData\+pt|sockaddr_in|codeprint\.c|\(NETMSG ?\*\)\(bs->buffer|\(EVENT_SAVE_HDR \*\)pPos|\(char \*\)psSave[A-Za-z]+ \+ *$'
if [ "$1" = -a ]; then cat "$LOG"; else grep -Ev "$SAFE" "$LOG"; fi
total=$(wc -l < "$LOG"); left=$(grep -Evc "$SAFE" "$LOG")
echo "$total cast-align warnings, $left not on the known-safe list"
[ "$left" = 0 ]
