#!/bin/bash
# Build and replay every bench example — an example with a bench.json — under
# toje, each against its committed reference (ci/toje-bench/bench.py,
# docs/lang/en/benches.md).
#
#   ci/run-benches.sh              # cold build of each bench, then replay
#   ci/run-benches.sh --no-build   # replay the images as they are
#
# Exit code : 0 when every bench passes.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD=1
[ "${1:-}" = "--no-build" ] && BUILD=0
PASS=0; FAIL=0
for desc in "$ROOT"/examples/*/bench.json; do
  dir=$(dirname "$desc"); name=${dir#$ROOT/}
  if [ $BUILD = 1 ]; then
    ( cd "$dir" && { [ -e engine ] || ln -s ../../engine engine; } && rm -rf dist gen &&
      java -Dbasedir="$ROOT" -cp "$ROOT/repo/*" com.widedot.m6809.gamebuilder.MainCommand \
        -f to8.config.xml > "$ROOT/ci/run-benches.log" 2>&1 ) || {
      echo "BENCH $name BUILD FAILED (ci/run-benches.log)"; FAIL=$((FAIL+1)); continue; }
  fi
  if ( cd "$ROOT" && python3 ci/toje-bench/bench.py "$name" ); then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
  fi
done
echo "benches : $PASS pass, $FAIL fail"
[ $FAIL = 0 ]
