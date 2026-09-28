#!/bin/bash
# List the objects that use VFPv4-only instructions (fused multiply-add,
# half-precision conversion): they won't run on VFPv3 machines (Cortex-A8/A9).
#   tools/check-fpu.sh [program-or-library ...]   (default: the game + the devkit + stage libs)
. "$(dirname "$0")/../build/env.sh"
OD=$GCCSDK_ENV/bin/$HOST-objdump
[ $# -gt 0 ] || set -- "$SRC/warzone2100-2.3.9/src/warzone2100" "$DEVKIT"/lib/*.a "$STAGE"/lib/*.a
bad=0
for f in "$@"; do
  n=$("$OD" -d "$f" 2>/dev/null | grep -cE $'\t(vfma|vfms|vfnma|vfnms)|vcvt[bt]?\\.f(16|32)\\.f(32|16)')
  if [ "$n" -gt 0 ]; then echo "VFPv4: $n in $f"; bad=1; fi
done
[ $bad = 0 ] && echo "OK: no VFPv4-only instructions (runs on VFPv3)"
exit $bad
