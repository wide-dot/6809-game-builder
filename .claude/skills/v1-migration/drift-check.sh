#!/bin/sh
# Compare, for every line of engine/v1-manifest.csv, the recorded v1 commit
# with the latest v1 commit touching that file. Lists drifted files.
# Usage: ./.claude/skills/v1-migration/drift-check.sh  (from the repo root)

set -e
V1="${V1_REPO:-../thomson-to8-game-engine}"
MANIFEST="engine/v1-manifest.csv"

[ -f "$MANIFEST" ] || { echo "no $MANIFEST"; exit 1; }
[ -d "$V1/.git" ] || { echo "v1 repo not found at $V1 (set V1_REPO)"; exit 1; }

drift=0
tail -n +2 "$MANIFEST" | while IFS=, read -r v2_path v1_path v1_commit imported_on deviations; do
    [ -n "$v1_path" ] || continue
    head=$(git -C "$V1" log -1 --format=%H -- "$v1_path")
    if [ -z "$head" ]; then
        echo "GONE     $v1_path (removed or renamed in v1)"
    elif [ "$head" != "$v1_commit" ]; then
        echo "DRIFTED  $v1_path"
        echo "         imported at ${v1_commit%"${v1_commit#??????????}"}… on $imported_on, v1 now at ${head%"${head#??????????}"}…"
        git -C "$V1" log --oneline "$v1_commit..HEAD" -- "$v1_path" | sed 's/^/         /'
    fi
done

echo "done. (no output above the 'done' line = no drift)"
