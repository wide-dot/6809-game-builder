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
#
# REPRISE du 20/08/2026 — la palette du stage 3 devient AUTHOREE, et sa couche
# battleship entre dans la campagne. Trois decisions de l'auteur, dans l'ordre
# ou elles ont ete prises :
#
#   1. FUSION des deux verts en un seul (#616100, emplacement PNG 15). Ils
#      etaient #617A00 (l'olive) et #304020 — mais #304020 n'est pas
#      representable : le TO8 l'affichait #006100, un vert vif qui salissait
#      toutes les ombres de coque. La fusion libere un emplacement ET corrige
#      le defaut. Voir « L'espace d'affichage » dans arcade_to_in.py : c'est
#      ce cas qui a fait passer les outils a la metrique CIEDE2000 de png2pal.
#   2. L'emplacement libere (PNG 16) va au BEIGE #b89e61 des nuages — mesure :
#      il sert le tan #b89860, 19,8 % de la couche, qui tombait sur le
#      vert-gris. Retenu a l'oeil par l'auteur contre un creme #faf2cc qui
#      gagnait plus en erreur moyenne (-25 % contre -14 %).
#   3. Les VERTS SOMBRES sont FORCES vers #616100, des deux cotes. La rampe
#      arcade a quatre verts ; le plus proche voisin en ecrasait trois sur le
#      seul vert clair — des aplats a l'ecran — parce que #616100 n'etait le
#      plus proche d'aucun d'eux (33 contre 23). Deux niveaux valent mieux
#      qu'une erreur moyenne plus basse : constat de l'auteur sur planche.
#
# Les quatre cases propres du stage sont donc GRAVEES (--fixe) et plus
# calculees : leurs valeurs sont des decisions. Sans ca le calcul remettait un
# vert vif en PNG 14 et evinçait le vert clair du vaisseau (mesure).
# Le jaune n'a plus besoin de son --epingle : sa case est fixee (13).
python3 tools/arcade_to_in.py 03 src/stages/03/map/images/original/level3_f.png --pal-next \
    --plan 'src/stages/03/map/images/original/level3_b.png:576,16,1168,192*3' \
    --fixe 13=212,194,0 --fixe 14=143,143,97 --fixe 15=97,97,0 --fixe 16=184,158,97 \
    --force 72,104,72=15 --force 48,72,48=15
# La couche battleship (plan ARRIERE), carte du module mscroll : meme palette,
# memes regles. Ses trois verts sombres sont forces vers #616100 pour la meme
# raison que ceux des nuages.
python3 tools/arcade_to_mscroll.py 03 src/stages/03/map/images/original/level3_b.png \
    --force 88,96,72=15 --force 48,64,32=15 --force 104,104,80=15
python3 tools/arcade_to_in.py 04 src/stages/04/map/images/original/level4_f.png --pal-next \
    --masque src/stages/04/terrain/level4_ball.bin
# Le champ de gommes du stage 4 (1 618 cellules) sort du decor : une couche de
# rendu dediee le dessine et le detruit au runtime depuis le bitfield de
# collision, il n'a donc rien a faire dans les tuiles compilees. Le masque ne
# touche QUE l'image : les gommes restent affichees a l'ecran, donc elles
# gardent leur voix au choix de la palette (les sortir du vote permuterait les
# trois emplacements du stage). Le bitfield vient de
# re.arcade.r-type --extract-ballfield.
#
# Sur un in.png DEJA converti, le meme masque s'applique sans rien regenerer :
#   python3 tools/strip_cells.py src/stages/04/map/in.png \
#       src/stages/04/terrain/level4_ball.bin
# C'est ce qui a ete fait au 21/08/2026 : regenerer le stage 4 rejouerait AUSSI
# la correction « espace d'affichage » du 20/08, pas encore passee sur ce stage
# — 1 649 px changent d'emplacement de palette (11 -> 10, un peche clair vers un
# orange soutenu). Legitime, mais c'est une decision de campagne palette, pas de
# champ de gommes.
# Stage 5 : son cast vote (regle actee aux stages 2 et 6, poids 1). Le slither
# — 10 915 px reduits, le plus gros ennemi converti — etait le pire du corpus a
# dE 24,2 : ses bruns tombaient sur l'or de la carte. Mesure du vote :
# slither 24,2 -> 17,4, la carte paie 4,1 -> 6,5 (une case passe de D09030 au
# brun 583810 du serpent), pursuer 18,9 -> 21,1, cheetah stable. Le poids 2
# gagnait plus au slither mais coutait 12,2 a la carte — ecarte.
# REPRIS LE 24/08/2026, palette GRAVEE (choix auteur « P12+P11 »). Deux causes.
# 1) La palette du body du slither etait fausse dans le catalog arcade (0x25,
#    celle de la tete ; le code dit 0x26 — create_slither_body_segment). Le
#    corps portait donc le turquoise de l'oeil. Corrige en amont, l'export
#    rejoue par `--export-catalog`, le recensement change.
# 2) Le vote sur ce nouveau recensement rendait la case 16 MUETTE : il lui
#    donnait une couleur que l'ecran ne distingue pas de celle du 13. Ce n'est
#    pas un defaut d'arbitrage mais le GAMUT — TO = [0, 97, 122, ...], il n'y a
#    rien entre 0 et 97, et QUATRE bruns sources (886800 de la carte, 583810 du
#    slither, 705810 et 887030 du cheetah) tombent tous sur 7A6100.
# D'ou une palette gravee plutot que votee, et le routage des rampes a la main.
# Le critere n'est pas l'ecart moyen mais le NOMBRE DE NIVEAUX conserves : c'est
# la regle du 18/08 (cf. --forcer de arcade_to_sprites), et elle fait MONTER
# l'ecart. Mesure (tools/pal05_candidats.py) : quatre rampes sur quatre passent
# a 3/3 contre une seule avant. slither 583 -> 556, cheetah 482 -> 389, carte
# 108 -> 194 ; le pursuer monte 522 -> 623 et c'est le prix de son brun sombre,
# qui partait sur le ROUGE du 8 et rejoint la rampe brune. Le vert sombre est en
# 14 par convention (le vert sombre du cheetah cessait de tomber sur le GRIS du
# 2) ; son moyen prend l'olive gelee du 15 et son clair le jaune du 12, donc
# trois niveaux verts sans case supplementaire.
# Ecarte : P11 (vert MOYEN en 14, cheetah 370 mais vert sombre sur le gris).
python3 tools/arcade_to_in.py 05 src/stages/05/map/images/original/level5_f.png --pal-next \
    --plan sprites:slither --plan sprites:pursuer --plan sprites:cheetah \
    --fixe 13=88,56,16 --fixe 14=8,72,32 --fixe 16=168,128,88 \
    --force 248,200,152=11 \
    --force 144,72,32=13 --force 200,128,48=16 --force 248,176,136=11 \
    --force 0,128,144=5 --force 0,176,144=6 --force 0,232,176=7 \
    --force 16,144,56=15 --force 128,200,112=12
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
# --dedup : le cycle du gouger fait un aller-retour et repasse par les memes
# poses. Seules les distinctes sont importees (19 au lieu de 32) et la table
# slot -> pose part dans cycle.txt, que le code objet indexe.
python3 tools/arcade_to_sprites.py gouger  --palette 02 --dedup
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
python3 tools/arcade_to_sprites.py cytron   --palette 04 --marge-droite 4
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
#   TROIS cases pour le dome depuis le 29/08 (decision auteur) : l'ombre, le
#   corps et le halo de la bulle oscillent chacun sur sa case — la rampe
#   4 etapes (aucun noir, aucune etape unie) est etablie en simulation TO8,
#   pixels larges et courbe DAC compris. Cases CONSECUTIVES 12-14 : le
#   runtime n'a qu'une boucle sur trois entrees.
#   LE CORPS EST LA PLANCHE A (decision auteur, 29/08 : « le A est parfait »,
#   objectif enonce : MAXIMISER LES DEGRADES, quitte a s'ecarter de l'art
#   d'origine). Deux rampes de 4 marches sur 6 cases, a SOMMETS PARTAGES :
#     rouge : nuit (97,0,0) -> sombre (171,0,0) -> rose (204,97,97) -> BLANC
#     or    : nuit (97,0,0) -> brun (143,97,0) -> or (204,143,97) -> creme (250,219,143)
#   Le blanc commun et le rouge nuit servent chacun DEUX rampes — c'est ce qui
#   fait tenir 8 marches percues sur 6 cases.
#
#   LE ROSE EST SUR LA CASE PROPRE 15, PAS SUR LE COMMUN 7 (auteur, 29/08 :
#   « positionne le mat15 en mat7, c'est la meme couleur !! »). Le rouge nuit
#   de la rampe EST deja la valeur du materiel 7 dans le jeu — le poser sur la
#   case propre et mettre le rose sur le commun deplacait un commun de 174
#   POUR RIEN. Echanges, les deux rampes sont identiques a l'oeil et le
#   materiel 7 ne bouge plus D'UN IOTA : les explosions, le Force Pod et le
#   HUD gardent leur rouge sombre pendant le combat. Ne restent deplaces que
#   9, 10 et 11 — chacun dans sa famille (orange->brun, saumon->or,
#   jaune->creme), ce qu'autorise la decision du 17/08.
#
#   Les valeurs du DOME sont celles de l'etape 0 de la table d'oscillation,
#   POSEES SUR LA GRILLE DAC (gen_dome_pulse.py les calcule ainsi) : un PNG
#   qui porte la valeur arcade brute ment sur ce que le materiel affichera.
python3 tools/arcade_to_sprites.py compiler --stage 04 \
    --ecrire-palette src/stages/04/palette/pal-boss.png \
    --reserver "143,250,158:12;0,143,0:13;0,204,0:14" \
    --poser "97,0,0:7;171,0,0:8;143,97,0:9;204,143,97:10;250,219,143:11;204,97,97:15" \
    --forcer "88,40,0:7"     --forcer "160,0,56:8" \
    --forcer "200,88,88:15"  --forcer "248,168,168:3" \
    --forcer "64,48,0:7"     --forcer "144,88,24:9" \
    --forcer "208,144,56:10" --forcer "248,216,144:11"
# Le routage des rampes du stage 5 (24/08/2026) : les memes decisions que le
# --force de arcade_to_in, cote sprites. Indices MATERIELS ici (PNG - 1).
# Sans ces lignes le plus proche voisin refait exactement ce qu'on vient de
# defaire : creme du slither sur le tan, oeil ecrase sur deux niveaux, brun du
# pursuer sur le rouge, vert clair du cheetah sur l'olive.
python3 tools/arcade_to_sprites.py slither  --palette 05 \
    --forcer 248,200,152:10 \
    --forcer 0,128,144:4 --forcer 0,176,144:5 --forcer 0,232,176:6
python3 tools/arcade_to_sprites.py pursuer  --palette 05 \
    --forcer 144,72,32:12 --forcer 200,128,48:15 --forcer 248,176,136:10
python3 tools/arcade_to_sprites.py cheetah  --palette 05 \
    --forcer 16,144,56:14 --forcer 128,200,112:11
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
# zoid : 4 verts arcade, une seule case verte au stage 2 (308840). La rampe
# brune (V1) perdait le vert ; l'auteur le veut. Choix auteur sur planche a
# 4 variantes (18/08) : V4 — vert pur en clair, TRAME vert~brun sombre en
# moyen (le barreau fabrique, damier 15~13), brun sombre 503810 en ombre.
# 3 niveaux percus ancres sur le vert, l'oeuf garde ses rouges.
python3 tools/arcade_to_sprites.py zoid --palette 02 \
    --forcer 88,192,104:15 --forcer 56,144,80:15~13 \
    --forcer 16,120,56:15~13 --forcer 0,80,8:13
# win : 5 turquoises dont 2 partaient sur le GRIS commun ; par rang sur les
# 3 bleus communs, la plus claire va d'elle-meme au blanc (4 niveaux).
python3 tools/arcade_to_sprites.py win --palette 08 \
    --forcer 8,72,72:4 --forcer 8,96,96:4 \
    --forcer 56,152,152:5 --forcer 136,208,208:6
# warship-elements : Lab suffit — ses bleus acier tombent sur la rampe des
# gris communs (3 niveaux, une famille), rien a forcer.
python3 tools/arcade_to_sprites.py warship-elements --palette 03

# =========================================================================
# Groupe H — les sprites PROPRES au stage 1 (18/08).
#
# Ils etaient hors du perimetre de palette_migrate.py, qui ne connaissait que
# les communs, les lots du cast et les cartes : ces unites-la n'entrent que par
# `scenes.stage1`. Perimetre etendu, et c'est tout ce qu'il a fallu — leur
# migration ne se decide pas, elle se lit dans la palette du stage.
#
# Les trois couleurs que la nouvelle palette a chassees des communs sont
# precisement ce que le stage 1 a mis dans ses cases propres : 12 #9E8F7A,
# 13 #CCC2AB, 14 #617A00. Un sprite du stage 1 les garde donc TOUTES, a la
# couleur exacte — `3>12 4>13 12>14`, un report d'index, pas un arbitrage.
# 17 des 20 ressources sont des renumerotations pures, prouvees identiques
# pixel par pixel par l'outil.
#
# Le seul pixel qui bouge est l'ancien orange #F2AB00, que la nouvelle palette
# n'a plus : 54 px sur le blaster (-> #F99B68 par `defaut`), 6 px sur imgFace
# et 6 px sur imgNerves1 (-> #CC5A3C).
#
# Ces deux dernieres prennent `10>9 14>10` et NON la recette du groupe B :
# elles sont faites de saumon (793 et 118 px), et faire descendre le saumon les
# repeindrait entierement. Arbitrage auteur a l'oeil le 18/08 — la recette suit
# les PIXELS, pas le rang dans la rampe. Detail dans palette-map.txt.
#
# Le bleu #00618F du blaster, de la coquille et du tabrok est de l'art v1
# assume (auteur, 18/08) : `defaut 5>4` le reporte a couleur identique. Les
# 114 images sont byte-identiques a la v1 avant comme apres renumerotation.
$M stage1.blaster                   --ecrire
$M stage1.dobkeratops.imgEyes       --ecrire
$M stage1.dobkeratops.imgFace       --ecrire   # 6 px d'orange, le saumon intact
$M stage1.dobkeratops.imgNerves0    --ecrire
$M stage1.dobkeratops.imgNerves1    --ecrire   # idem
$M stage1.dobkeratops.imgNerves2    --ecrire
$M stage1.dobkeratops.imgNerves3    --ecrire
$M stage1.dobkeratops.imgNerves4    --ecrire
$M stage1.dobkeratops.imgWipe0      --ecrire
$M stage1.dobkeratops.imgWipe1      --ecrire
$M stage1.dobkeratops.imgWipe2      --ecrire
$M stage1.dobkeratops.imgWipe3      --ecrire
$M stage1.dobkeratopsjaw            --ecrire
$M stage1.dobkeratopsmonster        --ecrire
$M stage1.dobkeratopssaw            --ecrire
$M stage1.shell                     --ecrire
$M stage1.tabrok.imgFlight          --ecrire
$M stage1.tabrok.imgGround          --ecrire
$M stage1.tabrok.imgWalk            --ecrire
$M stage1.tabrokcanon               --ecrire

# =========================================================================
# Groupe H — harmonisation des communs sur des valeurs REPRESENTABLES
# (20/08/2026, decisions auteur sur planches).
#
# Le maillon qui manquait a toute la campagne : png2pal quantifie chaque
# couleur sur le gamut TO8 au build (CIEDE2000), et cinq des douze communs
# n'etaient pas representables. L'editeur de palette montrait donc autre
# chose que l'ecran — deux campagnes couleur du stage 3 ont ete jugees sur
# un rendu faux avant qu'on le voie.
#
# Trois gravures sans enjeu (les deux methodes de quantification s'accordent,
# et sur ce que png2pal embarquait deja : zero changement a l'ecran) :
#   hw2 #a8a8a8 -> #ababab   hw6 #08d4eb -> #00d4eb   hw8 #ac0000 -> #ab0000
# Deux decisions, tranchees sur la REGULARITE DE LA RAMPE des rouges et pas
# sur la distance a la couleur isolee :
#   hw9  #cc5a3c -> #cc6100   hw10 #f99b68 -> #fa9e61
# Ce que png2pal embarquait pour hw9 (#d47a61) etait 7 points de L* trop
# clair : il collait a hw10 et la rampe perdait une marche. Detail et
# mesures dans l'en-tete de tools/palette_harmonise.py.
#
# Portee : tout PNG indexe dont les 12 communs sont ceux de la reference
# (884 fichiers) ; seules les entrees de palette changent, aucun index de
# pixel n'est touche. Idempotent.
python3 tools/palette_harmonise.py

# =========================================================================
# Groupe I — la TRANSPARENCE des cartes de stage (21/08/2026).
#
# Le plan arcade declare ses pixels transparents (le pen 0 de chacune des 16
# banques de couleur est le pen transparent de la couche) et l'export les
# porte depuis 08/2026 en chunk tRNS — re.arcade.r-type --extract-tiles, les
# plans committes dans src/stages/NN/map/images/original/ sont a jour.
#
# En overlay le champ de jeu est efface au noir puis repeint chaque trame :
# une cellule sans pixel opaque n'a pas de tuile du tout. map_alpha.py reporte
# donc le masque arcade dans les in.png, en index 0. Sa regle est
# conservatrice — seul un pixel NOIR devient transparent, jamais un pixel
# colore — et sur les stages 02 a 08 elle ne coute rien : le masque arcade y
# tombe a 100 % sur du noir. Le stage 01 est le seul ecart (son in.png vient
# de l'art v1 migre, pas de l'arcade) et le rapport le chiffre a chaque
# execution.
#
# Ceci REMPLACE tools/sky_transparent.py (supprime), qui devinait le ciel par
# blocs de 3x6 pixels entierement noirs et ratait tout ciel plus fin que sa
# maille. arcade_to_in.py pose desormais la meme information a la conversion :
# ce passage est le chemin des images deja converties, et le garde-fou qui
# verifie l'accord entre les deux.
python3 tools/map_alpha.py

# La timeline d'effacement du stage 1 se DEDUIT de la carte : elle change avec
# le masque (le masque exact rend la rangee du bas non zappable, ce que
# l'heuristique 3x6 cachait). A rejouer apres map_alpha.
python3 tools/gen_clear_timeline.py 01
