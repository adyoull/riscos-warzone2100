#!/bin/bash -e
# Work on the Warzone 2100 patch series (patches/warzone2100) with git.
#
#   tools/wz-patches.sh checkout [DIR]  upstream 2.3.9 in DIR as a git repo
#                                       (tag v2.3.9), with every patch applied
#                                       as a commit (default: work/warzone2100)
#   tools/wz-patches.sh export [DIR]    write DIR's commits since v2.3.9 back to
#                                       patches/warzone2100 (replaces them all)
#   tools/wz-patches.sh check           apply the series to a clean copy and
#                                       compare with $SRC/warzone2100-2.3.9 (the
#                                       tree the build uses)
#
# Typical change: checkout; edit and `git commit` (or `git commit --fixup`
# and `git rebase -i --autosquash v2.3.9`); export; commit the new patches in
# this repo; then rebuild (build/fetch-sources.sh won't re-patch an existing
# src/warzone2100-2.3.9: delete it, or copy the edited files across).
# Needs dl/wz239.tgz (build/fetch-sources.sh downloads it).
REPO_DIR=$(cd "$(dirname "$0")/.." && pwd)
: "${DL:=$REPO_DIR/dl}"
: "${SRC:=$REPO_DIR/src}"
PATCHES=$REPO_DIR/patches/warzone2100
TARBALL=$DL/wz239.tgz
AUTHOR=(-c user.name="${GIT_AUTHOR_NAME:-Andrew Youll}" \
        -c user.email="${GIT_AUTHOR_EMAIL:-adyoull@users.noreply.github.com}")

unpack() {  # dir: pristine 2.3.9 as a git repo, tag v2.3.9
  local dir=$1 tmp
  [ -f "$TARBALL" ] || { echo "missing $TARBALL (run build/fetch-sources.sh)" >&2; exit 1; }
  [ -e "$dir" ] && { echo "$dir already exists" >&2; exit 1; }
  tmp=$(mktemp -d)
  tar xzf "$TARBALL" -C "$tmp"
  mkdir -p "$(dirname "$dir")"
  mv "$tmp/warzone2100-2.3.9" "$dir"; rmdir "$tmp"
  ( cd "$dir" && git init -q && git add -A && git "${AUTHOR[@]}" commit -q -m "Warzone 2100 2.3.9" \
    && git tag v2.3.9 )
}

case "$1" in
checkout)
  DIR=${2:-$REPO_DIR/work/warzone2100}
  unpack "$DIR"
  ( cd "$DIR" && git "${AUTHOR[@]}" am -q --whitespace=nowarn "$PATCHES"/*.patch )
  echo "$DIR: $(git -C "$DIR" rev-list --count v2.3.9..HEAD) patches applied on v2.3.9"
  ;;
export)
  DIR=${2:-$REPO_DIR/work/warzone2100}
  git -C "$DIR" rev-parse -q --verify v2.3.9 >/dev/null || { echo "$DIR: no v2.3.9 tag" >&2; exit 1; }
  [ -z "$(git -C "$DIR" status --porcelain --untracked-files=no)" ] || { echo "$DIR has uncommitted changes" >&2; exit 1; }
  rm -f "$PATCHES"/*.patch
  git -C "$DIR" format-patch -q --no-signature --zero-commit --no-numbered -o "$PATCHES" v2.3.9..HEAD
  ls "$PATCHES"
  ;;
check)
  TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
  unpack "$TMP/wz"
  ( cd "$TMP/wz" && git "${AUTHOR[@]}" am -q --whitespace=nowarn "$PATCHES"/*.patch )
  bad=0
  for f in $(git -C "$TMP/wz" diff --name-only v2.3.9 HEAD); do
    cmp -s "$TMP/wz/$f" "$SRC/warzone2100-2.3.9/$f" || { echo "differs: $f"; bad=1; }
  done
  [ $bad = 0 ] && echo "OK: the series reproduces $SRC/warzone2100-2.3.9"
  exit $bad
  ;;
*)
  sed -n '2,19p' "$0"; exit 1;;
esac
