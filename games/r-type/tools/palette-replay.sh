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
    # arcade_to_in.py est sur master mais SANS le mode --pal-next : on depose
    # aussi la version de la campagne.
    cp -R tools/palette* tools/arcade_to_in.py "$tmp/arbre/games/r-type/tools/"
    # Les plans arcade sont des ENTREES de la campagne, au meme titre que les
    # outils : identiques octet pour octet a wide-dot/re.arcade.r-type@4276f7c
    # (verifie par cmp au commit d'entree), absents de master. On les seme.
    for d in src/stages/*/map/images/original; do
        mkdir -p "$tmp/arbre/games/r-type/$d"
        cp "$d"/* "$tmp/arbre/games/r-type/$d/"
    done
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
# Groupe E — la bascule. Le stage 1 charge `pal-next.png` telle quelle : la
# nouvelle palette entiere, 12 index communs et 4 propres au stage, dont la
# case 15 (vert clair) que l'auteur reserve a des sprites du stage 1.
#
# L'ancienne palette avait DEUX noirs et le ciel du niveau occupait le second
# (index 15) ; le fondu vers le tunnel n'etait que le recoloriage de cette
# case. La nouvelle n'a qu'un noir : le ciel devient le nibble 0, et le fondu
# de tunnel est retire (decision auteur, 16/08).
#
# Ce que ca entraine, et que les OUTILS ne savent pas ecrire — le patch
# ci-dessous s'en charge :
#   * les quatre macros du starfield testent le ciel sur 0 (deux `coma` en
#     moins par etoile sur les nibbles bas) ; ses six tables de masques, elles,
#     sont bien reencodees par palette_code.py (`cible=$0`) ;
#   * les effacements de tampon passent de $FFFF a $0000 (checkpoint, x2) et
#     l'effaceur de shells tamponne du ciel a $0000 ;
#   * l'objet fadetotunnel, ses 9 lignes de wave et son id d'objet s'en vont.
# =========================================================================

# Les modifications que les deux outils ne peuvent pas exprimer : du CODE (les
# tests de ciel, les effacements, le retrait du fondu de tunnel) et de la PROSE
# (un commentaire qui nomme une couleur ment des que l'index bouge). Elles
# doivent se rejouer comme le reste, sinon `--verifier` signale un ecart a
# chaque correction. Applique APRES les outils : ses contextes sont ceux de
# l'arbre migre.
if git apply -p1 -R --check tools/palette-edits.patch 2>/dev/null; then
    echo "edits : deja appliques, rien a faire."
else
    git apply -p1 tools/palette-edits.patch
fi

# =========================================================================
# Groupe F — les tuiles. La source est l'image du niveau : le BUILD en derive
# tout le reste (leanscroll -> tuiles + carte -> gfxcomp -> tilemap), donc il
# n'y a qu'un fichier a migrer par stage.
#
# Le stage 1 est une renumerotation PURE, prouvee au pixel : les deux beiges
# retrouvent leur couleur exacte dans les cases propres au stage (12 et 13), et
# le ciel — un MARQUEUR magenta dans la source, du noir sur la machine — rejoint
# le noir 0. Pas de planche : il n'y a rien a arbitrer.
#
# Les stages 2 a 8 ARRETENT l'outil : leurs cartes reaffectent des emplacements
# a des teintes propres au niveau, donc la table des anciens index ne leur
# convient pas telle quelle. C'est leur tour de travail, pas un defaut.
# =========================================================================
$M stage1.map --ecrire

# =========================================================================
# Groupe F, stages 2-8 — reconversion depuis les plans arcade contre la
# nouvelle palette (etude : analyse-palettes-stages-2026-08.md). La source de
# chaque stage vit dans src/stages/NN/map/images/original/ ; l'outil ecrit
# l'in.png ET la palette dediee src/stages/NN/palette/pal.png depuis la meme
# affectation. L'olive est pre-chargee en materiel 14 quand un lot du stage la
# porte — mesure dans le cast, jamais une liste.
# =========================================================================
python3 tools/arcade_to_in.py 02 src/stages/02/map/images/original/level2_f.png --pal-next
# Stage 8 : l'art est dans le plan ARRIERE. Mesure — le plan avant reduit
# n'a qu'UNE couleur (tout noir), l'arriere en a 30, et les deux collent a
# 75,9 % avec l'ancien in.png : exactement ses pixels noirs. C'est donc _b
# qui portait deja la carte du stage 8, et qui la porte encore.
python3 tools/arcade_to_in.py 08 src/stages/08/map/images/original/level8_b.png --pal-next
python3 tools/arcade_to_in.py 03 src/stages/03/map/images/original/level3_f.png --pal-next
python3 tools/arcade_to_in.py 04 src/stages/04/map/images/original/level4_f.png --pal-next
python3 tools/arcade_to_in.py 05 src/stages/05/map/images/original/level5_f.png --pal-next
python3 tools/arcade_to_in.py 06 src/stages/06/map/images/original/level6_f.png --pal-next
python3 tools/arcade_to_in.py 07 src/stages/07/map/images/original/level7_f.png --pal-next

# Les fichiers que la campagne SUPPRIME. Une suppression s'enonce en commande,
# pas en patch : c'est le role de ce ledger.
rm -f src/stages/01/background/fadetotunnel.unit.asm \
      src/stages/01/background/obj_fadetotunnel.asm \
      src/stages/01/palette/pal-inside.png \
      src/stages/01/palette/pal-inside-black.png \
      src/stages/01/palette/pal-inside-blue.png \
      src/stages/01/palette/pal-inside-grey.png
