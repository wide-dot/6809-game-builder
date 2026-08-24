#!/bin/sh
# new-clone.sh — un clone local pret a travailler, pour une session dediee.
#
#     ci/new-clone.sh <destination> [branche]
#
# Regle du depot (22/08/2026) : UN clone par session de travail, jamais deux
# sessions sur le meme checkout. Le clone part de CE depot (rapide, hors
# ligne), son origin est rebranche sur GitHub : les push/pull passent par le
# remote partage, jamais par l'arbre local d'une autre session.
set -e

SRC=$(cd "$(dirname "$0")/.." && pwd)
DEST=${1:?usage: ci/new-clone.sh <destination> [branche]}
BRANCH=${2:-}

git clone "$SRC" "$DEST"
ORIGIN=$(git -C "$SRC" remote get-url origin)
git -C "$DEST" remote set-url origin "$ORIGIN"
git -C "$DEST" fetch origin --quiet

if [ -n "$BRANCH" ]; then
    git -C "$DEST" checkout -b "$BRANCH" 2>/dev/null || git -C "$DEST" checkout "$BRANCH"
fi

# le lien engine des jeux (gitignore, requis par les config.xml)
for game in "$DEST"/games/*/; do
    [ -e "${game}engine" ] || ln -s ../../engine "${game}engine"
done

# les jars du builder (repo/ est gitignore) : copies depuis le clone source
# pour builder tout de suite — 'mvn clean install' dans le clone pour les
# reconstruire en local le jour ou la toolchain y change
if [ -d "$SRC/repo" ]; then
    cp -R "$SRC/repo" "$DEST/repo"
fi

echo ""
echo "clone pret : $DEST (branche $(git -C "$DEST" branch --show-current))"
echo "build d'un jeu :"
echo "  cd $DEST/games/r-type"
echo "  java -Dbasedir=$DEST -cp '../../repo/*' com.widedot.m6809.gamebuilder.MainCommand -f to8.config.xml"
