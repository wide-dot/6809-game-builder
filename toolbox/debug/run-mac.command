#!/bin/sh
# wddebug launcher for macOS.
#
# GLFW must run on the JVM's first thread on macOS, hence -XstartOnFirstThread
# (this flag is macOS-only, which is why it lives here and not in the shared
# appassembler launcher).
#
# Prerequisite: build the assembled output once from the repo root:
#   mvn -pl toolbox/debug -am package
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
REPO="$ROOT/repo"

if [ ! -d "$REPO" ]; then
  echo "Build output missing ($REPO)."
  echo "From the repo root run: mvn -pl toolbox/debug -am package"
  exit 1
fi

CP="$(find "$REPO" -name '*.jar' | tr '\n' ':')"
exec java -XstartOnFirstThread --enable-native-access=ALL-UNNAMED \
  -cp "$CP" com.widedot.toolbox.debug.MainCommand "$@"
