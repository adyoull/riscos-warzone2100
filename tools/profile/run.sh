#!/bin/bash
# tools/profile/run.sh <tag> [game options]
# Runs campaign 1 (CAM_1A) at 800x600 on Xvfb, records a 30 second perf
# profile after 45 seconds, and prints the frame rate. See README.md.
#   WZ_HOST   the Linux build of the patched game (default ~/prof/wz)
#   MESA_LIB  directory with the riscos-mesa-patched xlib libGL.so.1
#   CFGTEXT   lines for a fresh config, e.g. $'shadows=1\nvisfog=0'
#   PERF      perf binary (default: perf)
# Output: /tmp/perf-<tag>.data, /tmp/shot-<tag>.png, /tmp/run-<tag>.log
TAG=${1:?tag}; shift
HERE=$(cd "$(dirname "$0")" && pwd)
WZ_HOST=${WZ_HOST:-$HOME/prof/wz}
MESA_LIB=${MESA_LIB:?set MESA_LIB to the directory with the xlib libGL.so.1}
PERF=${PERF:-perf}
[ "$HERE/shim.so" -nt "$HERE/shim.c" ] || gcc -O2 -shared -fPIC -o "$HERE/shim.so" "$HERE/shim.c" -ldl || exit 1
export DISPLAY=:99 LD_LIBRARY_PATH=$MESA_LIB
pgrep -x Xvfb >/dev/null || { Xvfb :99 -screen 0 1024x768x24 >/dev/null 2>&1 & sleep 2; }
CFG=$(mktemp -d)
[ -n "$CFGTEXT" ] && printf '%s\n' "$CFGTEXT" > "$CFG/config"
cd "$WZ_HOST"
LD_PRELOAD=$HERE/shim.so ./src/warzone2100 --datadir="$PWD/data" --configdir="$CFG" \
    --window --resolution=800x600 --game=CAM_1A "$@" > /tmp/run-$TAG.log 2>&1 &
PID=$!
sleep 45
"$PERF" record -e cpu-clock -F 499 -g -p $PID -o /tmp/perf-$TAG.data -- sleep 30 > /dev/null 2>&1
xwd -root -display :99 | convert xwd:- /tmp/shot-$TAG.png
kill $PID; sleep 1; kill -9 $PID 2>/dev/null
rm -rf "$CFG"
grep FPS /tmp/run-$TAG.log | tail -6
