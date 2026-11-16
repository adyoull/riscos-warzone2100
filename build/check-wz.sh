#!/bin/bash -e
# riscos-crossdev's checks on the built game (the unstripped ELF): static
# linking or mixed, stack probes, FPU level, UnixLib; for the mixed program
# also that every library it needs, and every name they need, is in the
# devkit's !MesaLibs. Needs RCD_DIR (riscos-crossdev; set in its image).
. "$(dirname "$0")/env.sh"
: "${RCD_DIR:?set RCD_DIR to riscos-crossdev}"
P=$SRC/warzone2100-2.3.9/src/warzone2100
"$RCD_DIR/checks/check-all.sh" "$P"
if [ "${MIXED:-1}" = 1 ]; then
  "$RCD_DIR/checks/check-mixed-package.sh" "$P" "$DEVKIT/riscos/!MesaLibs/lib"
fi
