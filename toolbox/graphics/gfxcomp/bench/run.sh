#!/bin/sh
# Generator vs generator : same PNG through the v1 java-generator and through
# gfxcomp, both assembled with the same lwasm, binaries compared.
#
# Both generators now seed their reordering search with the same constant, so
# every case compares byte for byte. That was not always true: the search is
# random past a node size, and while both were unseeded neither reproduced
# itself — v1 gave 543 then 544 bytes on the same sprite. The two regimes below
# are kept because they are what proves it: the bench measures whether v1 is
# reproducible rather than assuming it, and only falls back to comparing sizes
# if it is not. A FAIL there would mean the seeding regressed on one side.
#
# The v2 side deliberately drops ORG/SETDP (the load time linker relocates, and
# setdp is rejected by the obj target) and renames the entry labels to the
# adr_/pge_ form the imageset index references. That is why the source diff is
# only shown as context on failure ; the verdict is on the assembled binary.
#
# usage: run.sh [outdir]   (env: V1_REPO, LWASM, PNG_DIR, SAMPLES, CASES)
set -e

ROOT=$(cd "$(dirname "$0")/../../../.." && pwd)
V1="${V1_REPO:-$ROOT/../thomson-to8-game-engine}"
LWASM="${LWASM:-lwasm.exe}"
OUT="${1:-$ROOT/target/gfxcomp-bench}"
V1JAR="$V1/java-generator/target/game-engine-0.0.1-SNAPSHOT-jar-with-dependencies.jar"
GFXJAR="$ROOT/toolbox/graphics/gfxcomp/target/gfxcomp-0.0.1.jar"
PNG_DIR="${PNG_DIR:-$V1/game-projects/r-type/objects}"
SAMPLES="${SAMPLES:-3}"
# Full exhaustive coverage : the threshold saturates at 9! = 362880, and this
# is the value r-type configures. Do not raise it blindly — in the random
# branch it is also the iteration count, so a huge value would hang the build.
MAXTRIES="${MAXTRIES:-500000}"

[ -f "$V1JAR" ] || { echo "build the v1 generator first: (cd $V1/java-generator && mvn package assembly:single)"; exit 1; }
[ -f "$GFXJAR" ] || { echo "build gfxcomp first: mvn -pl toolbox/graphics/gfxcomp -am package"; exit 1; }

# sprites of increasing size, one per encoder the runtime uses
CASES="${CASES:-enemies/shell/images/shell_0.png:NB0
enemies/shell/images/shell_3.png:NB0
test/ball/images/ball.png:ND0
test/launcher/images/launcher.png:NB0}"

rm -rf "$OUT"; mkdir -p "$OUT/work"
javac -cp "$V1JAR" -d "$OUT/work" "$(dirname "$0")/V1Harness.java"

pass=0; fail=0
for case in $CASES; do
    png="$PNG_DIR/${case%%:*}"; variant="${case##*:}"
    [ -f "$png" ] || { echo "SKIP  $case (no such png)"; continue; }
    name=$(basename "$png" .png)
    enc=$(echo "$variant" | cut -c2)
    case "$enc" in B) encoder=bdraw;; D) encoder=draw;; *) echo "unknown variant $variant"; exit 1;; esac
    mirror=none; shift=$(echo "$variant" | cut -c3)

    mkdir -p "$OUT/$name/v2"
    # gfxcomp resolves image paths against the configuration file
    cp "$png" "$OUT/$name/$name.png"

    # v1, sampled : the same generator run several times
    i=1
    while [ "$i" -le "$SAMPLES" ]; do
        mkdir -p "$OUT/$name/v1_$i/debug"
        (cd "$V1" && java -cp "$V1JAR:$OUT/work" V1Harness "$png" "$name" "$variant" \
            "$OUT/$name/v1_$i" "$LWASM" "$MAXTRIES" 2>/dev/null | grep '^x1=' > "$OUT/$name/v1_$i/geometry.txt")
        i=$((i+1))
    done

    cat > "$OUT/$name/gfxcomp.xml" <<EOF
<configuration>
    <process dirOut="v2">
        <memory linearBits="4" planarBits="8" lineBytes="40" nbPlanes="2"/>
        <imageset type="0" fileOut="v2/index.asm">
            <image name="$name" file="$name.png" index="0">
                <encoder name="$encoder" mirror="$mirror" shift="$shift"/>
            </image>
        </imageset>
    </process>
</configuration>
EOF
    (cd "$OUT/$name" && java -cp "$ROOT/repo/*:$GFXJAR" \
        com.widedot.toolbox.graphics.gfxcomp.MainCommand -f gfxcomp.xml >/dev/null 2>&1) \
        || { echo "FAIL  $name ($variant) : gfxcomp exited non zero"; fail=$((fail+1)); continue; }

    # the geometry must match whatever the search picked
    geom1=$(cat "$OUT/$name/v1_1/geometry.txt")
    geomN=$(cat "$OUT/$name"/v1_*/geometry.txt | sort -u | wc -l | tr -d ' ')
    [ "$geomN" = "1" ] || echo "WARN  $name : v1 geometry itself varies across runs"

    # the imageset index is the contract the runtime reads : same geometry on
    # both sides, and a cell count that follows the tracked margin deviation
    if [ -f "$OUT/$name/v2/index.asm" ]; then
        if python3 "$(dirname "$0")/checkindex.py" "$OUT/$name/v2/index.asm" "$name" "$geom1"; then
            pass=$((pass+1))
        else
            fail=$((fail+1))
        fi
    fi

    for part in "" _erase; do
        v1part=$(echo "$part" | sed 's/_erase/_Erase/')
        v2asm="$OUT/$name/v2/${name}_${variant}${part}.asm"
        [ -f "$OUT/$name/v1_1/${name}_0_${variant}${v1part}.asm" ] || continue
        [ -f "$v2asm" ] || { echo "FAIL  $name$part : gfxcomp produced nothing"; fail=$((fail+1)); continue; }

        # same ORG as v1, then assemble with the same options
        { echo '	ORG $A000'; cat "$v2asm"; } > "$OUT/$name/v2${part}_org.asm"
        (cd "$V1" && "$LWASM" "$OUT/$name/v2${part}_org.asm" --output="$OUT/$name/v2${part}.bin" \
            --6809 --includedir=./ --raw --pragma=undefextern --includedir=. --includedir=../.. >/dev/null 2>&1)
        v2size=$(wc -c < "$OUT/$name/v2${part}.bin" | tr -d ' ')

        # is v1 reproducible on this sprite ?
        stable=1; min=; max=
        i=1
        while [ "$i" -le "$SAMPLES" ]; do
            b="$OUT/$name/v1_$i/${name}_0_${variant}${v1part}.bin"
            s=$(wc -c < "$b" | tr -d ' ')
            [ -z "$min" ] && { min=$s; max=$s; }
            [ "$s" -lt "$min" ] && min=$s
            [ "$s" -gt "$max" ] && max=$s
            cmp -s "$b" "$OUT/$name/v1_1/${name}_0_${variant}${v1part}.bin" || stable=0
            i=$((i+1))
        done

        if [ "$stable" = "1" ]; then
            if cmp -s "$OUT/$name/v2${part}.bin" "$OUT/$name/v1_1/${name}_0_${variant}${v1part}.bin"; then
                echo "PASS  $name$part ($variant) : IDENTICAL, $v2size bytes (v1 deterministic over $SAMPLES runs)"
                pass=$((pass+1))
            else
                echo "FAIL  $name$part ($variant) : v1 is deterministic here but gfxcomp differs"
                diff "$OUT/$name/v1_1/${name}_0_${variant}${v1part}.asm" "$v2asm" | head -20
                fail=$((fail+1))
            fi
        else
            # v1 is not reproducing itself : its seeding regressed, or a new
            # source of nondeterminism appeared. Byte comparison is meaningless
            # then, so fall back to asking whether gfxcomp finds code as good as
            # v1's best sample, within 1% (at least 2 bytes, one instruction).
            echo "WARN  $name$part : v1 is not reproducible here, seeding regressed ?"
            tol=$((min / 100)); [ "$tol" -lt 2 ] && tol=2
            budget=$((min + tol))
            if [ "$v2size" -le "$budget" ]; then
                echo "PASS  $name$part ($variant) : EQUIVALENT, $v2size bytes vs v1 best $min (spread [$min..$max], budget $budget)"
                pass=$((pass+1))
            else
                echo "FAIL  $name$part ($variant) : $v2size bytes, over the $budget budget (v1 best $min, spread [$min..$max])"
                fail=$((fail+1))
            fi
        fi
    done
    echo "      $name geometry: $geom1"
done

echo "---"
echo "$pass ok, $fail failing"
[ "$fail" -eq 0 ]
