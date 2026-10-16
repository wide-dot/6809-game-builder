# Fidélité arcade : le banc trace contre trace (16/10/2026)

Un boss porté est fidèle quand, aux mêmes entrées, il passe par les mêmes
états aux mêmes trames que la borne. Ce document décrit la méthode et les
outils qui le vérifient sans jugement visuel, et ce qu'il faut respecter dans
le code d'un portage pour que la vérification soit possible.

Premier client : Bellmite, le boss du stage 5. Prochains : le Compiler (stage
4, dont les déplacements divergent encore), puis les boss des stages 6 à 8.

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
4. **Quatre crochets nommés.** `<boss>.Seeded`, après la création et avant
   la première trame jouée : le banc y écrit l'horloge et la graine de la
   borne. `<boss>.Spawned`, quand les records existent : le banc y écrit les
   **résidus** de la borne (voir plus bas). `<boss>.Tick`, en tête de chaque
   trame arcade : le banc y injecte les dégâts d'un scénario. `<boss>.Sample`,
   à la fin de chaque rendu : le banc y relève l'état.

## Les résidus d'un record recyclé

La première comparaison de Bellmite divergeait dès la trame 2 sur les
fractions de position : la borne ne remet pas à zéro les octets +3 et +7
d'un record qu'elle réalloue. Le noyau naissait avec x.frac = $46 et
y.frac = $F5, restes de l'occupant précédent, et ces fractions décalaient
d'un pixel les retenues de mouvement 66 trames plus tard. Ce sont des entrées
du combat au même titre que la graine : le port les pose à 0, le banc écrit
celles de la borne au crochet `Spawned`. Après cette injection, plus aucune
divergence.

## Les outils

| Étape | Outil | Sortie |
|---|---|---|
| Trace borne | `pilot/tools/trace_actors.lua` (fork MAME) : état d'entrée du stage, vaisseau épinglé, records de la famille à chaque trame | JSON Lines brut |
| Référence | `tools/fidelity/fidelity.py arcade <boss>` décode selon le profil du boss | `tools/fidelity/ref/<boss>.ref.jsonl.gz` (commitée ; `--check` la rejoue) |
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

Le combat tourne à 4 à 6 trames de jeu par rendu sur TO8 (8,5 images par
seconde en moyenne pendant le boss).

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

## Ce que le banc ne couvre pas

- Les vrais tirs. Les dégâts sont injectés, pas visés : la collision du
  moteur (une passe par rendu au lieu d'une par trame) reste un écart assumé.
- Le dessin. Le banc compare des états, pas des pixels.
