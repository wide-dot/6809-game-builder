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
    # Les outils et leurs tables vivent sur new-color, pas sur master : on
    # depose TOUT `tools/`. Pas un glob, pas une liste — les deux ont echoue
    # une fois chacun (palette_code.py oublie d'une liste, puis objid_rename.py
    # rate par le glob `arcade_*`), et a chaque fois l'erreur sort tres loin de
    # sa cause. `tools/` contient les outils ET leurs entrees : les deux
    # palettes de reference, la table des ObjID arcade, les tables de
    # correspondance. Le ledger ne reecrit jamais aucune d'elles.
    cp -R tools/. "$tmp/arbre/games/r-type/tools/"
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
# Groupe E — la bascule. Le stage 1 charge la nouvelle palette telle quelle :
# 12 index communs et 4 propres au stage, dont la case 15 (vert clair) que
# l'auteur reserve a des sprites du stage 1. Le fichier lui-meme est pose au
# groupe G, avec les palettes dediees des sept autres stages.
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
#
# Metrique Lab par defaut depuis le 17/08 (constat auteur : le boss du stage 8
# devenait gris). La distance RGB traitait « orange un peu faux » et « vert qui
# devient gris » comme comparables ; Lab separe la clarte de la chroma. Elle
# gagne sur les SEPT stages, pas seulement sur le 8 — le tableau des ecarts est
# dans l'en-tete de arcade_to_in.py. Le plancher de 0,1 % vient avec : en Lab
# une poussiere isolee (89 px de magenta au stage 6) raflait un emplacement.
# =========================================================================
# Stage 2 : ses quatre cases sont choisies sur la carte ET sur les sprites de
# son cast (--plan sprites:, decision auteur 17/08). Sans ca elles sortaient de
# la carte seule, et le brood — SIX verts arcade — les perdait tous d'un coup
# sur l'unique vert du stage. Poids 1 : les sprites pesent leur propre nombre de
# pixels reduits (29 650 face aux 49 356 de la carte), aucun pouce sur la
# balance, et le poids 2 n'apporte plus rien (mesure).
#   Le BROOD ne vote PAS, et c'est le seul ecart a la regle : sa base verte est
#   cachee a 95 % sous le decor dans le jeu arcade (observation de l'auteur —
#   l'export livre chaque sprite isole, l'outil ne peut pas voir l'occlusion).
#   Or c'etait le SEUL votant qui deplacait la case verte, mesure : avec lui
#   elle passait de 308840 a 208860, soit une case depensee pour des pixels
#   qu'on ne voit pas. Sans lui le vert reste celui de la carte.
#   Ce que le vote change, dE moyen : gouger 8,8 -> 6,4 ; la carte paie
#   9,7 -> 11,1 ; wick 28,5 -> 28,8 et brood 15,3 -> 14,6 (aucun ne perd).
python3 tools/arcade_to_in.py 02 src/stages/02/map/images/original/level2_f.png --pal-next \
    --plan sprites:gouger --plan sprites:wick --plan sprites:outslay
# Stage 8 : l'art est dans le plan ARRIERE. Mesure — le plan avant reduit
# n'a qu'UNE couleur (tout noir), l'arriere en a 30, et les deux collent a
# 75,9 % avec l'ancien in.png : exactement ses pixels noirs. C'est donc _b
# qui portait deja la carte du stage 8, et qui la porte encore.
# Stage 8, arbitrages de l'auteur (18/08) : le mikun garde 3 niveaux de vert
# et 3 de bleu (le NOMBRE de niveaux prime sur la proximite Lab), la rampe
# vit dans UNE famille de teinte, et — dernier arbitrage — la teinte de la
# rampe est choisie pour le BOSS, pas pour le mikun : « l'important est le
# degrade, pas grave si la teinte mikun derive de l'arcade ». La rampe est
# donc les TROIS kakis du boss lui-meme : clair 168,184,112 / moyen
# 136,136,80 / sombre 64,64,16 (A8B870/888850/404010) — un balayage de
# triples a confirme que les couleurs propres du boss battent toute variante
# interpolee (boss dE 15,1 -> 10,5, carte 13,3 -> 9,7, mieux qu'avant toute
# epingle : le boss retrouve ses 3 niveaux au lieu de 2). Le mikun ne vote
# plus (--plan retire) : sa rampe lui est imposee par rang a la conversion.
# La quatrieme case va d'elle-meme au feu F85000.
python3 tools/arcade_to_in.py 08 src/stages/08/map/images/original/level8_b.png --pal-next \
    --epingle 64,64,16 --epingle 136,136,80 --epingle 168,184,112
# Stage 3 : le battleship vit dans le plan ARRIERE (boite x 576..1167,
# y 16..191 mesuree sur les pixels non noirs) et sera affiche par du code a
# part, hors tilemap — mais il peint avec Pal_stage, donc la palette du stage
# doit le porter. Decision auteur (17/08) : « vert et jaune avant tout ».
#   * le plan arriere entre dans le CHOIX des couleurs a poids 3 — c'est le
#     palier ou les deux verts du vaisseau prennent leurs emplacements, et il
#     est stable jusqu'a 5 (mesure) ; l'in.png reste le plan avant ;
#   * le jaune est EPINGLE : sa rampe pese 1 200 px reduits face aux 17 000 px
#     du terrain, aucun poids ne la fait gagner (mesure, poids 1 a 5).
# Ce que ca coute, mesure : les trois teintes du terrain (71 % des pixels
# opaques du plan avant) perdent leurs emplacements — beige clair vers le
# blanc (dE 17), tan vers le vert moyen (19), brun vers le gris (19).
python3 tools/arcade_to_in.py 03 src/stages/03/map/images/original/level3_f.png --pal-next \
    --plan 'src/stages/03/map/images/original/level3_b.png:576,16,1168,192*3' \
    --epingle 208,192,0
python3 tools/arcade_to_in.py 04 src/stages/04/map/images/original/level4_f.png --pal-next
# Stage 5 : son cast vote (regle actee aux stages 2 et 6, poids 1). Le slither
# — 10 915 px reduits, le plus gros ennemi converti — etait le pire du corpus a
# dE 24,2 : ses bruns tombaient sur l'or de la carte. Mesure du vote :
# slither 24,2 -> 17,4, la carte paie 4,1 -> 6,5 (une case passe de D09030 au
# brun 583810 du serpent), pursuer 18,9 -> 21,1, cheetah stable. Le poids 2
# gagnait plus au slither mais coutait 12,2 a la carte — ecarte.
python3 tools/arcade_to_in.py 05 src/stages/05/map/images/original/level5_f.png --pal-next \
    --plan sprites:slither --plan sprites:pursuer --plan sprites:cheetah
# Stage 6 : son cast vote (constat auteur sur planche — le dop ne va pas).
# Mesure : SEPT couleurs arcade du dop s'ecrasaient sur le seul 144,168,136
# (3570 px sur 10 832). Le vote lui donne une case a lui (808018) et la carte ne
# paie presque rien : dE carte 6,1 -> 6,3, dop 19,5 -> 14,3, newt 22,9 -> 18,7.
# Le newt profite sans avoir rien demande — il vote quand meme, la regle est
# « le cast exclusif vote », et ici il ne coute rien (son vote seul ne change
# aucune case, mesure).
python3 tools/arcade_to_in.py 06 src/stages/06/map/images/original/level6_f.png --pal-next \
    --plan sprites:dop --plan sprites:newt
python3 tools/arcade_to_in.py 07 src/stages/07/map/images/original/level7_f.png --pal-next

# =========================================================================
# Groupe G — la palette dediee de chaque stage (demande auteur, 17/08).
#
# Les stages 2 a 8 ont la leur depuis le groupe F : arcade_to_in.py ecrit
# src/stages/NN/palette/pal.png depuis la MEME affectation que l'in.png, donc
# les deux ne peuvent pas diverger. Restait le stage 1, seul hors convention.
#
# Pourquoi il l'etait : `src/stages/01/palette/pal.png` ne portait pas la
# palette du stage 1 mais l'ANCIENNE palette du jeu — l'entree de
# palette_migrate.py, le « avant » de toute la campagne — et le stage 1 lisait
# sa palette dans `pal-next.png`, un nom de campagne, pas de stage. Un fichier
# pour deux roles, et le role visible etait le faux.
#
# Demele : les deux palettes de REFERENCE de la campagne (l'ancienne, la
# nouvelle) vivent desormais dans tools/palette-reference/, avec le reste du
# parametrage ; `src/stages/01/palette/pal.png` porte la palette du stage 1,
# comme les sept autres. Le config pointe dessus.
#
# La palette du stage 1 EST la nouvelle palette : ses quatre cases propres sont
# celles que l'auteur a choisies au groupe E (12 beige fonce, 13 beige clair,
# 14 olive, 15 vert clair reserve a de futurs sprites du stage 1). Ce n'est pas
# une mesure comme pour les stages 2-8, c'est une decision — d'ou une copie et
# pas un calcul. Le garde-fou que les 12 communs ne derivent nulle part est
# palette_usage.py, qui les recoupe sur les huit palettes.
#
# Les deux `git mv` sont hors ledger : ce sont des deplacements versionnes, ils
# vivent dans l'historique. Ce que le ledger doit garantir, c'est que l'arbre
# migre porte le bon CONTENU a `src/stages/01/palette/pal.png` — que l'on parte
# de master (ou il porte l'ancienne palette) ou d'un arbre deja migre.
# =========================================================================
cp tools/palette-reference/nouvelle.png src/stages/01/palette/pal.png

# Les fichiers que la campagne SUPPRIME. Une suppression s'enonce en commande,
# pas en patch : c'est le role de ce ledger.
rm -f src/stages/01/background/fadetotunnel.unit.asm \
      src/stages/01/background/obj_fadetotunnel.asm \
      src/stages/01/palette/pal-inside.png \
      src/stages/01/palette/pal-inside-black.png \
      src/stages/01/palette/pal-inside-blue.png \
      src/stages/01/palette/pal-inside-grey.png \
      src/stages/01/palette/pal-next.png

# =========================================================================
# Groupe H — les sprites arcade des ennemis (demande auteur, 17/08).
#
# L'export arcade vit dans src/enemies/<e>/images/original/ (605 PNG, deja sur
# master : rien a semer). arcade_to_sprites.py les rogne au cadre commun de
# l'animation, reduit 3/8 x 3/4 et quantifie en Lab. Geometrie et metrique
# mesurees, pas supposees — voir l'en-tete de l'outil.
#
# Pourquoi SEULEMENT ces quatre : la palette de sortie depend du stage, et
# l'affectation ennemi -> stage n'existe aujourd'hui que pour le stage 2, dont
# le cast est nomme (objid.const.asm : gouger, wick, brood, outslay, gomander).
# Les stages 3 a 8 citent encore des ObjID NUMERIQUES sans ennemi derriere.
# gomander n'a pas d'export arcade. Les 15 autres ennemis exportes attendent
# leur affectation ; les convertir a l'aveugle serait a refaire.
#
# Un ennemi charge par PLUSIEURS stages se convertira en `--palette communs`
# (12 index communs, cases de stage en magenta, couleur donnee par Pal_stage) :
# c'est le defaut de l'outil, et ca ne se refait jamais.
# =========================================================================
python3 tools/arcade_to_sprites.py gouger  --palette 02
python3 tools/arcade_to_sprites.py wick    --palette 02
python3 tools/arcade_to_sprites.py brood   --palette 02
python3 tools/arcade_to_sprites.py outslay --palette 02

# =========================================================================
# Groupe I — nommer les ObjID numeriques des waves (demande auteur, 17/08).
#
# Hors campagne palette, mais DANS ce ledger pour une raison mecanique : le
# `--verifier` compare tout `src/` a un rejeu depuis master. Une edition de
# source qui ne s'y rejoue pas casserait le garde-fou pour toutes les autres.
# Le ledger est donc devenu le rejeu de la BRANCHE, pas seulement de la palette.
#
# La table vient de `data/routines.yaml` du depot arcade (une liste dont
# l'index EST l'ObjID) et vit dans src/enemies/objid-arcade.csv, avec l'adresse
# ROM de chaque routine — seule identite disponible pour les six objets que
# l'arcade ne nomme pas lui-meme (1, 2, 34, 39, 46, 47).
#
# Le controle est plus fort qu'une relecture : `objid_rename.py --verifier`
# compare CHAQUE ligne portant un ObjID a la ligne de meme rang du fichier
# arcade — les deux fichiers sont le meme document. 626 lignes, 626 conformes,
# un seul ecart tolere et declare (`Geld` -> `geld`, la casse du dossier).
# =========================================================================
python3 tools/objid_rename.py

# Les onze ennemis nommes au groupe I qui ont leur export arcade. Chacun est
# EXCLUSIF a un stage (mesure sur les waves, colonne `stages` de
# tools/objid-arcade.csv) : sa palette peut donc etre celle du stage, cases
# propres comprises. Un ennemi partage aurait `--palette communs`.
# Ils ne VOTENT pas pour la palette de leur stage — c'est une decision separee,
# et la lecon du brood est qu'un votant peut depenser une case pour des pixels
# qu'on ne voit pas.
python3 tools/arcade_to_sprites.py cytron   --palette 04
python3 tools/arcade_to_sprites.py geld     --palette 04
# Le compiler est le BOSS de fin du stage 4, et il combat dans une zone ou la
# tilemap n'existe plus — mesure : les 144 derniers pixels de l'in.png du
# stage 4 (12 colonnes de tuiles, presque un ecran) sont entierement noirs.
# Les cases propres au stage n'y sont donc disputees par personne : il a sa
# palette a lui, chargee par un echange a l'entree de l'arene.
#   Mesure : dE 19,2 avec la palette du stage -> 13,5 avec la sienne, et
#   12 index employes au lieu de 10 sur ses 22 couleurs arcade.
#   L'olive reste GELEE : elle ne coute presque rien (13,5 contre 13,1 en la
#   liberant) et c'est elle qui laisse un sprite COMMUN affiche pendant le
#   combat garder sa couleur. Les 12 communs ne bougent pas non plus.
#   Le DOME est reserve au materiel 14 (decision auteur) : le runtime y fera
#   un clignotement/fondu, et un effet de palette doit savoir OU taper — il lui
#   faut une case connue d'avance que personne d'autre ne partage. Le materiel
#   14 est libre pendant ce combat : c'est la case de l'olive des lots, et
#   aucun lot n'est a l'ecran a ce moment (constat auteur).
#   La rampe CHAUDE entiere est ajustee pour ce combat (--ajuster 7,8,9,10,
#   auteur 17/08 : « en phase de boss on utilise une palette ajustee, c'est
#   tout » — les communs du jeu, eux, ne bougent PAS). Chaque index garde son
#   role, sa valeur est choisie parmi les couleurs du compiler qui tombaient
#   deja sur lui. 7,8 ne suffisaient pas : les tons CLAIRS tiraient encore sur
#   le rose-orange (constat auteur) — le rose (200,88,88) tombait sur l'orange
#   CC5A3C et l'or (208,144,56) sur le saumon F99B68. Avec 9 et 10 ajustes, le
#   rose obtient sa case (C85858), l'or la sienne (D09038).
#   dE : stage 19,1 -> boss 7,8 : 10,6 -> boss 7,8,9,10 : 8,4 (12 index).
python3 tools/arcade_to_sprites.py compiler --stage 04 \
    --ecrire-palette src/stages/04/palette/pal-boss.png \
    --reserver 0,208,0:14 --ajuster 7,8,9,10
python3 tools/arcade_to_sprites.py slither  --palette 05
python3 tools/arcade_to_sprites.py pursuer  --palette 05
python3 tools/arcade_to_sprites.py cheetah  --palette 05
python3 tools/arcade_to_sprites.py dop      --palette 06
python3 tools/arcade_to_sprites.py newt     --palette 06
python3 tools/arcade_to_sprites.py fast     --palette 07
python3 tools/arcade_to_sprites.py boldo    --palette 07
# Le mikun se convertit par RANG, pas par proximite (regle auteur, 18/08 : le
# nombre de niveaux d'un degrade compte plus que Lab, et un degrade se lit
# dans UNE famille de teinte). La rampe est celle du BOSS (arbitrage auteur :
# la teinte mikun peut deriver de l'arcade) : ses 4 verts tombent par rang sur
# clair A8B870 (mat14) / moyen 888850 (mat13) / sombre 404010 (mat12, les 2
# verts sombres arcade fusionnent dessus). Les 3 bleus vont sur les 3 bleus
# communs, que Lab reduisait a 2 en sautant le bleu profond 00618F.
python3 tools/arcade_to_sprites.py mikun --palette 08 \
    --forcer 80,136,104:14 --forcer 56,112,80:13 \
    --forcer 32,88,56:12   --forcer 8,64,32:12 \
    --forcer 0,128,160:4   --forcer 0,176,192:5 --forcer 0,248,248:6
# Les enfants d'objets (jamais cites par une wave, donc absents de l'inventaire
# de cast) : le zoid eclot du brood (stage 2), le win est la spirale du kit
# mikun (stage 8, ses images suivent celles du mikun en ROM), les
# warship-elements sont les pieces du battleship (stage 3, dont la palette a
# ete choisie pour lui). Les ObjID anonymes 1/2/34/39/46/47 sont des objets de
# flux, pas ces ennemis. Blaster reste art v1 comme tout le stage 1.
# zoid : 4 verts arcade, une seule case verte au stage 2 -> rampe BRUNE du
# stage par rang (regle generale : une famille, la teinte derive) —
# clair B8A068 / moyens 886838 / sombre 503810. L'oeuf garde ses rouges.
python3 tools/arcade_to_sprites.py zoid --palette 02 \
    --forcer 88,192,104:12 --forcer 56,144,80:14 \
    --forcer 16,120,56:14  --forcer 0,80,8:13
# win : 5 turquoises dont 2 partaient sur le GRIS commun ; par rang sur les
# 3 bleus communs, la plus claire va d'elle-meme au blanc (4 niveaux).
python3 tools/arcade_to_sprites.py win --palette 08 \
    --forcer 8,72,72:4 --forcer 8,96,96:4 \
    --forcer 56,152,152:5 --forcer 136,208,208:6
# warship-elements : Lab suffit — ses bleus acier tombent sur la rampe des
# gris communs (3 niveaux, une famille), rien a forcer.
python3 tools/arcade_to_sprites.py warship-elements --palette 03
