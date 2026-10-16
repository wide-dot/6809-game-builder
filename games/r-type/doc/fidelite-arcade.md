# Fidélité arcade : le banc trace contre trace (16/10/2026)

Un boss porté est fidèle quand, aux mêmes entrées, il passe par les mêmes
états aux mêmes trames que la borne. Ce document décrit la méthode et les
outils qui le vérifient sans jugement visuel, et ce qu'il faut respecter dans
le code d'un portage pour que la vérification soit possible.

Clients : Bellmite, le boss du stage 5, puis le Compiler (stage 4), réécrit
1:1 le 16/10/2026 parce que ses déplacements divergeaient, puis l'essaim de
Dops (stage 6), porté le même jour. Prochains : les boss des stages 7 et 8.

## Le constat qui rend la méthode possible

Pendant un combat de boss, la borne est **déterministe à l'octet**. Trois
mesures sur la trace MAME de Bellmite :

- **le générateur aléatoire.** `random_ax` (0x40:EDE9) est un registre à
  trois octets (0x2F28..2A). Chaque transition de cet état entre deux trames
  s'explique par les tirages de la famille du boss : 2 par satellite en
  orbite les trames où `compteur & 7 == 0`, 1 à 3 par changement de cap du
  noyau. Aucun autre objet ne tire pendant le combat ;
- **le réensemencement.** La boucle principale remet l'état à (5, 1, 3)
  quand le compteur global (0x2EB6) franchit un multiple de 512
  (0x40:021D). Au spawn de Bellmite, l'état vaut (5, 1, 3) : rien n'a tiré
  depuis le dernier multiple ;
- **le vaisseau.** Les satellites visent le joueur et choisissent le plus
  proche de lui. Épinglé sur un point fixe, il cesse d'être une entrée
  variable.

Même graine, même horloge, même vaisseau : la borne rejoue le même combat. Un
port qui calcule comme elle doit le rejouer au même octet.

## Ce que le portage doit respecter

1. **Calculer en repère arcade.** Positions 16.8, vitesses 8.8, seuils et
   tables recopiés tels quels, x vers la droite et y vers le **haut**. Seul le
   dessin convertit : `x_écran = 8 + ((x − 320) × 3) >> 3`,
   `y_écran = 297 − (y × 3) >> 2`. Les boss précédents convertissaient les
   vitesses en unités TO8 et l'arrondi dérivait ; c'est l'origine probable
   des écarts de déplacement du Compiler.
2. **Une trame arcade à la fois.** Une routine joue exactement une trame de
   jeu pour toute la famille, dans l'ordre de la liste arcade (priorités
   croissantes). Le rendu la joue `frameDrop.count` fois. Les cadences (toutes
   les 8 trames, une trame sur 4, périodes) gardent ainsi leur phase.
3. **Le générateur de la borne, privé.** Une copie de `random_ax` et de son
   réensemencement, tenue par le boss, avec une copie du compteur global
   semée depuis `gfxlock.frame.gameCount` au spawn.
4. **Des crochets nommés.** `<boss>.Seeded`, après la création et avant
   la première trame jouée : le banc y écrit l'horloge et la graine de la
   borne. `<boss>.Spawned`, quand les records existent : le banc y écrit les
   **résidus** de la borne (voir plus bas). `<boss>.Tick`, en tête de chaque
   trame arcade : le banc y injecte les dégâts d'un scénario. `<boss>.Sample`,
   à la fin de chaque rendu : le banc y relève l'état. Un boss dont les
   tirages ne se reproduisent pas (voir plus bas) a un cinquième crochet,
   `<boss>.Drawn`, sur le `rts` de sa routine de tirage. Un boss sans
   résidus de création n'a pas de `Spawned` : ses résidus s'écrivent à
   `Tick`.

## Les résidus d'un record recyclé

La première comparaison de Bellmite divergeait dès la trame 2 sur les
fractions de position : la borne ne remet pas à zéro les octets +3 et +7
d'un record qu'elle réalloue. Le noyau naissait avec x.frac = $46 et
y.frac = $F5, restes de l'occupant précédent, et ces fractions décalaient
d'un pixel les retenues de mouvement 66 trames plus tard. Ce sont des entrées
du combat au même titre que la graine : le port les pose à 0, le banc écrit
celles de la borne au crochet `Spawned`. Après cette injection, plus aucune
divergence.

## Quand le flux aléatoire est partagé : rejouer les tirages

Le constat de Bellmite — tous les tirages pendant le combat viennent du
boss — ne tient pas pour le Compiler : son combat fait naître le champ
d'étoiles, et `star_ctor` tire trois fois par étoile (724 étoiles sur un
combat). Le port ne fait pas naître ces étoiles de la même façon ; il ne
peut pas reproduire le flux, seulement SES tirages.

La trace MAME porte alors, trame par trame, l'adresse de retour de chaque
appel à `random_ax` (`PILOT_RNGLOG=1`, champ `rc`). L'état du générateur
avant et après chaque trame étant connu, la valeur que chaque appelant a
reçue se recalcule. La référence garde la liste des tirages de la famille
(`d` : appelant, AX). Côté TO8, chaque tirage passe par `cpl.Draw` ; le banc
s'arrête sur `compiler.Drawn` et écrit dans D la valeur de la borne. Il
compte les tirages en trop ou manquants : un port qui tire au mauvais
endroit ou au mauvais moment se voit là, avant même la comparaison d'état.

**Piège du crochet de tirage.** Une IRQ prise SUR l'instruction du crochet
y revient après son RTI : le même tirage arrête le banc deux fois, et le
second arrêt consommait le tirage suivant (vu à la trame 4379 : la paire de
lasers roulants naissait avec les vitesses de la paire d'après). Un vrai
tirage fait toujours avancer le générateur du port ; un arrêt dont la pile,
l'adresse de retour et l'état du générateur sont ceux de l'arrêt précédent
est ce doublon, et le banc l'ignore. Tester D ne suffit pas : la valeur
propre du port coïncide souvent avec celle de la borne (même graine, et le
champ d'étoiles ne tire que par intermittence).

## Quand la trajectoire est écrite dans le décor : vérifier la carte

L'essaim de Dops du stage 6 ne tire aucun nombre au hasard. Un Dop avance
sur une « voie » et tourne quand une sonde à trois pas devant lui touche une
tuile pleine : toute sa trajectoire se lit dans la carte de tuiles. Le port
n'est fidèle que si SA carte rend les mêmes réponses que la RAM de tuiles de
la borne, case par case.

La trace MAME en porte donc un vidage (`PILOT_TILEDUMP`, 16 Ko de RAM de
tuiles à l'ouverture de l'enregistrement, caméra imprimée). Le modèle
(`tools/fidelity/models/dopswarm_model.py`) rejoue tout le combat deux fois :
une fois en sondant ce vidage comme la borne sonde sa RAM, une fois en
sondant la carte de collision du TO8 (`--to8`). Les deux sont identiques à
la trace : la carte du stage 6 (`level6_fc.bin`, un bit par tuile arcade de
8×8) est juste dans l'arène — ses 48 dernières colonnes, à partir de la 335,
lignes alignées. C'est cette vérification, faite avant le 6809, qui autorise
le port à sonder la carte du TO8 en coordonnées arcade.

La carte vit dans la région de collision, dans la fenêtre cartouche d'où le
code de l'essaim s'exécute : le port ne peut pas la lire directement. Sa
tranche d'arène est assemblée dans le boss depuis le même fichier
(`INCLUDEBIN fichier,offset,longueur`, une ligne par rangée) : aucune copie de
l'asset, une seule source.

## Les entrées que le port ne calcule pas comme la borne

Un écart assumé du port qui touche l'état du boss devient une ENTRÉE du
banc, comme la graine : la valeur de la borne est imposée, l'injection est
comptée et affichée. Le seul cas aujourd'hui est la mort d'un segment de
laser roulant du Compiler sur le décor. La borne garde ses chaînes de
gommes à l'écran pendant le combat et y perd ses segments ; le TO8 remplace
le décor par le champ d'étoiles et coupe ce plan de collision (décision du
28/08, `stage-main.asm`, `plainBackdrop`). Quand un segment manque à la
borne, et qu'il est le seul écart des segments, le banc le retire du port
(26 sur le combat sans tir). Un segment que le port perdrait seul resterait,
lui, une divergence.

## Les outils

| Étape | Outil | Sortie |
|---|---|---|
| Trace borne | `pilot/tools/trace_actors.lua` (fork MAME) : état d'entrée du stage, vaisseau épinglé, records de la famille à chaque trame | JSON Lines brut |
| Référence | `tools/fidelity/fidelity.py arcade <boss>` décode selon le profil du boss | `tools/fidelity/ref/<boss>.ref.jsonl.gz` (commitée ; `--check` la rejoue) |
| Spécification | `tools/fidelity/models/<boss>_model.py` : le boss en Python, routine par routine, vérifié contre la trace brute avant d'écrire une ligne de 6809 (Compiler) | `IDENTIQUE` ou la première divergence par champ |
| Trace TO8 | `tools/fidelity/fidelity.py to8 <boss> dist/to8.fd` : toje, saut par le cheat du title, graine écrite au spawn, relevé à chaque rendu | JSON Lines, même format |
| Verdict | `tools/fidelity/fidelity.py compare <boss>` : jointure sur l'horloge globale, comparaison champ par champ | première divergence de chaque champ et compte |

Les adresses viennent toutes du build courant (`.lwmap`, rapport
d'occupation) : aucun littéral.

Le vaisseau est épinglé en (512, 228) arcade, dont l'image TO8 est exacte :
(80, 126) en écran 0-base. Le port reconvertit la position du joueur en
unités arcade sans arrondi sur ce point (`x = 320 + 2v + (v·171 >> 8)`,
`y = w + (w·171 >> 9)`, exactes sur toute la plage).

## Un profil de boss

Le profil (classe Python dans `fidelity.py`) dit trois choses : les handlers
de tick qui forment la famille, comment décoder un record arcade en état
normalisé, et comment décoder la mémoire du port vers le même état. Les
états de la borne (adresse du handler) deviennent des numéros ; les champs
comparés sont ceux que le port tient en repère arcade.

## Les scénarios

Un scénario est une liste de coups `(trame après le spawn, cible)`. Côté
borne, le script Lua écrit l'octet de dégâts (+0x1F) de la cible avant la
trame ; côté TO8, le banc met le potentiel de sa boîte à zéro au crochet
`Tick` de la même trame. Le flash de coup n'est pas armé : la borne ne l'arme
que sur une vraie collision. `idle` est le combat sans tir (le boss sort par
son délai), `kill` tue 26 satellites puis le noyau.

| Scénario | Rendus TO8 comparés | Valeurs | Résultat (16/10/2026) |
|---|---|---|---|
| bellmite idle | 598 | 212 002 | identique |
| bellmite kill | 168 | 37 789 | identique |
| compiler idle | 1 684 | 87 478 | identique (26 morts de segments sur les gommes en entrée) |
| compiler kill | 328 | 11 416 | identique (gauche, bas puis droite, cascades jouées) |

Les valeurs de l'essaim comptent l'état du gestionnaire et la liste des
Dops comme une valeur chacune : chaque rendu compare toutes les positions
16.8, les voies et les variantes des Dops vivants.

`compiler idle` va jusqu'au bout des scripts : les trois pièces atteignent
leur terminateur, l'orchestrateur joue sa séquence de 256 trames et
disparaît. `compiler kill` détruit une pièce toutes les 200 trames.

Bellmite tourne à 4 à 6 trames de jeu par rendu sur TO8 (8,5 images par
seconde en moyenne pendant le boss), le Compiler à 4,3 (11,6 images par
seconde).

## Les captures appariées

`--shots k1,k2,...` sur les deux commandes enregistre l'écran de la borne à
la trame k et celui du TO8 au rendu qui suit (à six trames près), pour juger
le dessin, que le banc ne compare pas.

## Piège de banc : ne jamais détourner le PC sans reposer la pile

`run_frames` s'arrête n'importe où, gestionnaire d'IRQ compris. Un PC posé
à ce moment-là laisse le fil principal tourner sur `Irq_sys_stack`, et
l'interruption suivante écrase ses cadres. Le symptôme imite un bug du jeu :
DKCONT rendait la main en $0005 au milieu du chargement du stage 5. Avant
tout saut, le banc repose S sur `glb_system_stack`, DP sur $9F et masque les
IRQ (CC = $D0).

## La méthode, dans l'ordre (leçon du Compiler)

1. Tracer la famille sous MAME, tirages compris.
2. Écrire le **modèle Python** routine par routine, adresse arcade en
   commentaire, et le faire tomber à `IDENTIQUE` contre la trace brute. C'est
   là que se trouvent les vraies règles (tempo double des segments de combat,
   pièces qui avancent en bloc, compteur de tir `(AX·4) & (seuil−1)`,
   résidus des records recyclés), en secondes et non en minutes de toje.
3. Traduire le modèle en 6809, mêmes noms, même ordre.
4. Profil du banc, référence, comparaison TO8 : les écarts restants sont
   des fautes de traduction, pas de compréhension.

## Ce que le banc ne couvre pas

- Les vrais tirs. Les dégâts sont injectés, pas visés : la collision du
  moteur (une passe par rendu au lieu d'une par trame) reste un écart assumé.
- Le dessin. Le banc compare des états, pas des pixels.
