#!/bin/bash
# Run by .github/workflows/riscos-deps-update.yml when a release named in
# .riscos-deps is newer than its pin, before .riscos-deps itself is changed:
#   ci/riscos-deps-hook.sh NAME OLD_TAG NEW_TAG
# riscos-mesa: put the new devkit's sha256 in build/SHA256SUMS.txt (in
# place of the old one), so build/fetch-sources.sh can check it. build/env.sh
# reads the version from .riscos-deps, so nothing else names it.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
NAME=${1:?usage: $0 NAME OLD_TAG NEW_TAG}; OLD=${2:?}; NEW=${3:?}
case $NAME in
  riscos-mesa|adyoull/riscos-mesa)
    f=riscos-mesa-devkit-${NEW#v}.tgz
    url=https://github.com/adyoull/riscos-mesa/releases/download/$NEW/$f
    tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
    curl -fsSL --retry 3 -o "$tmp/$f" "$url"
    sum=$(sha256sum "$tmp/$f" | cut -d' ' -f1)
    grep -v '  riscos-mesa-devkit-.*\.tgz$' "$ROOT/build/SHA256SUMS.txt" > "$tmp/sums"
    echo "$sum  $f" >> "$tmp/sums"
    cat "$tmp/sums" > "$ROOT/build/SHA256SUMS.txt"
    echo "build/SHA256SUMS.txt: $f ($sum)"
    ;;
  *)
    echo "riscos-deps-hook.sh: nothing to do for $NAME $OLD -> $NEW"
    ;;
esac
