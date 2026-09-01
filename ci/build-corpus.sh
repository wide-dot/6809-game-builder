#!/bin/bash
# Build every config of the corpus and hash the produced images.
#
# The binary-identity harness of the migration method : run it before a
# change, run it after, diff the two files — a byte that moved without
# being announced is a bug, in either direction.
#
# Every build is COLD : gen/ and dist/ go before each one. A kept measurement
# is exactly what makes two runs disagree for reasons the diff cannot show.
#
#   ci/build-corpus.sh /tmp/ref.hashes
#   ...change...
#   ci/build-corpus.sh /tmp/new.hashes && diff /tmp/ref.hashes /tmp/new.hashes
#
# Linux notes : lwasm ships in toolbox/third-party/bin/linux (4.25, rebuilt
# from the versioned sources) ; hxcfe does not, so <hfe .../> outputs are
# stripped for the build and the config restored right after — identically
# on every side of a comparison, which keeps the diff meaningful.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT=${1:?usage: build-corpus.sh <output file>}
: > "$OUT"; : > "$OUT.log"
CONFIGS=$(cd "$ROOT" && find examples games -name "*.config.xml" -not -path "*/parked/*" | sort)
FAIL=0
for cfg in $CONFIGS; do
  dir=$ROOT/$(dirname "$cfg"); file=$(basename "$cfg")
  cd "$dir" || exit 1
  [ -e engine ] || ln -s ../../engine engine
  # gen ET dist : une mesure gardee d'un run precedent (taille d'un fichier,
  # placement d'une arene) masque ce que le build dirait a froid. Un
  # chevauchement reel entre la collision du stage 3 et trois fichiers communs
  # de r-type s'est cache derriere un gen/ rance jusqu'au 01/09/2026 : le
  # controle de composition ne le voyait pas, parce qu'il ne voyait pas la
  # vraie taille. Une comparaison d'empreintes ne vaut que sur un build a froid.
  rm -rf dist gen
  sed -i.hfebak -E 's|<hfe[^>]*/>||' "$file"
  if ! java -Dbasedir="$ROOT" -cp "$ROOT/repo/*" \
        com.widedot.m6809.gamebuilder.MainCommand -f "$file" >> "$OUT.log" 2>&1; then
    echo "BUILD FAILED: $cfg" | tee -a "$OUT"
    FAIL=1
  else
    for img in dist/*.fd dist/*.sap dist/*.sd; do
      [ -f "$img" ] && echo "$(sha256sum "$img" | cut -d' ' -f1)  $cfg/$(basename "$img")" >> "$OUT"
    done
  fi
  mv "$file.hfebak" "$file"
done
sort -k2 -o "$OUT" "$OUT"
echo "DONE fail=$FAIL images=$(grep -vc FAILED "$OUT")"
[ "$FAIL" = 0 ]
