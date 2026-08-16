#!/bin/sh
# Rejeu integral de la migration de palette — la campagne comme un script.
#
# REGLE (auteur, 16/08/2026) : toute conversion validee s'inscrit ICI, en
# commande et parametres, pour qu'on puisse repartir d'une copie fraiche de la
# branche principale et refaire le chemin a l'identique. Une image reecrite qui
# n'a pas sa ligne dans ce fichier n'existe pas : elle serait perdue au premier
# rebasage, et personne ne pourrait dire d'ou elle vient.
#
# Les deux moities du parametrage :
#   * ce fichier             — QUELLES ressources, dans QUEL ordre ;
#   * tools/palette-map.txt  — CE QUE devient chaque index, ressource par
#                              ressource, avec le pourquoi en commentaire.
# Aucune des deux ne suffit seule ; les deux sont versionnees sur `new-color`.
#
# L'ordre compte. Deux ressources peuvent declarer la MEME image (les impacts
# de `weapon` sont aussi ceux de `simplefire`) : la premiere nommee decide, la
# seconde herite. Ne pas reordonner ce fichier a la legere.
#
# Usage :
#   sh tools/palette-replay.sh              rejoue sur l'arbre courant
#   sh tools/palette-replay.sh --verifier   rejoue sur une copie fraiche de
#                                           origin/master et compare a l'arbre
#                                           courant — la preuve que ce script
#                                           EST la campagne, et pas son recit
#
# Rejouer sur un arbre deja migre ne casse rien : chaque ressource se voit
# deja faite et passe son tour. C'est le meme garde-fou d'idempotence que
# `--ecrire` applique image par image.

set -e
cd "$(dirname "$0")/.."
M="python3 tools/palette_migrate.py"

verifier() {
    racine=$(git rev-parse --show-toplevel)
    tmp=$(mktemp -d)
    echo "== copie fraiche de origin/master dans $tmp"
    git -C "$racine" worktree add --detach --quiet "$tmp/arbre" origin/master
    # les outils vivent sur new-color, pas sur master : on les y depose. TOUT
    # ce qui s'appelle palette*, sans liste a tenir a jour — une liste oubliee
    # fait echouer le rejeu loin de sa cause (vecu avec palette_code.py).
    cp -R tools/palette* "$tmp/arbre/games/r-type/tools/"
    echo "== rejeu"
    (cd "$tmp/arbre/games/r-type" && sh tools/palette-replay.sh)
    echo "== comparaison de src/ avec l'arbre courant"
    if diff -r -q "$tmp/arbre/games/r-type/src" src; then
        echo "IDENTIQUE — le script reproduit la campagne."
        etat=0
    else
        echo "ECART — le script ne reproduit PAS l'arbre courant (voir ci-dessus)."
        etat=1
    fi
    git -C "$racine" worktree remove --force "$tmp/arbre"
    rm -rf "$tmp"
    return $etat
}

[ "$1" = "--verifier" ] && { verifier; exit $?; }

# =========================================================================
# Groupe A — renumerotation pure. Valide par l'auteur le 16/08/2026.
# Aucune decision : ces ressources n'emploient que des couleurs conservees.
# `common.weapon` AVANT `common.simplefire` — les deux impacts partages.
# =========================================================================
$M common.weapon           --ecrire
$M common.beamcharge       --ecrire
$M common.beamp            --ecrire
$M common.reboundlaser     --ecrire
$M common.counterairlaser  --ecrire
$M common.simplefire       --ecrire
$M common.emflash          --ecrire
$M common.foefire          --ecrire
$M common.missileflame     --ecrire
$M common.engineflames     --ecrire
$M common.explosion.imgFwk --ecrire
$M lib.scantfire           --ecrire

# =========================================================================
# Groupe B — les deux explosions. Valide par l'auteur le 16/08/2026, sur
# planche, apres comparaison de trois candidats. Six valeurs employees de
# chaque cote : aucune fusion. Le detail de l'arbitrage est dans
# palette-map.txt, l'alternative rejetee dans palette-variantes/b-fusion.txt.
# =========================================================================
$M common.explosion.imgBig   --ecrire
$M common.explosion.imgSmall --ecrire

# =========================================================================
# Groupe C — les beiges, planche par planche. Valide par l'auteur le
# 16/08/2026. Chaque ligne porte SA decision : ce qui va au pow ne va pas au
# HUD, le detail et les recettes ecartees sont dans palette-map.txt.
# =========================================================================
$M common.hud      --ecrire     # beige clair au gris clair
$M common.missile  --ecrire     # idem
$M common.overlay  --ecrire     # idem
$M lib.pstaff      --ecrire     # idem
$M common.pow      --ecrire     # fusion blanche : le reflet rejoint le blanc

# =========================================================================
# Groupe C, planche 3/3 — l'olive. Regle etendue par l'auteur le 16/08 : le
# vert occupe un index propre au stage sur 1, 3, 4, 5 et 7. lib.patapata
# n'emploie que lui : garder l'olive en fait une renumerotation PURE.
# =========================================================================
$M lib.patapata    --ecrire     # que l'olive : renumerotation pure
$M lib.scant       --ecrire     # beiges fusionnes, olive gardee
$M lib.cancer      --ecrire     # idem
$M common.optionbox --ecrire    # fusion blanche + olive au gris (c'est un commun)
$M lib.bug         --ecrire     # aucun choix : 4 neutres pour 4 gris, bijection forcee

# =========================================================================
# Groupe C, planche 2/3 — beiges + orange. Valide par l'auteur le 16/08/2026.
# Le forcepod fusionne ses deux beiges sur le gris clair ; les trois autres
# versent le beige fonce dans le gris moyen (« fusion du sombre »).
# =========================================================================
$M common.forcepod  --ecrire
$M common.player    --ecrire
$M common.bitdevice --ecrire
$M lib.bink         --ecrire

# =========================================================================
# La PROSE que la migration rend fausse. Un commentaire qui nomme une couleur
# ment des que l'index bouge, et aucun outil de renumerotation ne peut le
# reecrire — mais il doit quand meme se rejouer, sinon `--verifier` signale un
# ecart a chaque fois qu'on corrige un commentaire. D'ou ce patch, applique
# AVANT les outils : ses contextes sont ceux de `master`.
# =========================================================================
if git apply -p1 -R --check tools/palette-prose.patch 2>/dev/null; then
    echo "prose : deja appliquee, rien a faire."
else
    git apply -p1 tools/palette-prose.patch
fi

# =========================================================================
# Groupe D — les couleurs ecrites en dur dans le code 6809. Renumerotation
# PURE des deux cotes : aucun pixel ne change de couleur, l'outil le mesure.
# La declaration de ce qui porte une couleur est dans tools/palette-code.txt.
#
# Depuis le groupe E, le meme outil traite une SECONDE forme : les tables de
# masques XOR du champ d'etoiles, ou l'octet vaut `ciel ^ couleur`. Elle
# n'avait ete vue ni par cet outil (qui lisait les immediats) ni par le releve
# de palette_usage.py — c'est la bascule de palette qui l'a fait sortir.
# =========================================================================
python3 tools/palette_code.py --ecrire

# =========================================================================
# Groupe E — la bascule. Le stage 1 charge DEUX palettes (le jeu et le
# tunnel) ; toutes deux sont derivees de pal-next.png, qui n'est jamais
# reecrit. La seule chose que la derivation change est la case 15 : sur le
# stage 1 elle ne porte pas une couleur mais un ROLE, le ciel — le fondu vers
# le tunnel n'est que son recoloriage. Le detail et les trois garde-fous sont
# en tete de tools/palette_stage.py.
#
# Ce que le groupe E ne fait PAS, contrairement a ce que le plan annoncait :
# toucher au starfield, aux effacements $FFFF ou a l'effaceur de shells. Le
# ciel reste l'index 15, donc ils sont deja justes.
# =========================================================================
python3 tools/palette_stage.py --ecrire
