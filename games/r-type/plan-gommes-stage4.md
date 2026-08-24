# Stage 4 — plan d'implémentation du champ de gommes

Compagnon de [`analyse-gommes-stage4.md`](analyse-gommes-stage4.md), qui porte
les mesures, l'extraction arcade et la structure retenue. Ce document-ci dit
**dans quel ordre le faire, où toucher, et à quoi on sait que c'est bon**.

Principe de découpe : chaque phase est **livrable seule et vérifiable seule**.
Les données avant le runtime, le sans-écran avant l'écran, le rendu avant le
gameplay. À aucun moment le stage 4 ne doit être cassé plus d'une phase.

---

## Phase 0 — Trois arbitrages, avant la première ligne

Aucun code. Ces trois-là changent la suite, et deux d'entre eux ne sont pas à
ma main.

### 0.1 — Le champ se remet-il à neuf à la mort ?

La région `collision` est en page `$17` à `$0000`, et le stage y écrit **sur
place** (c'est déjà ce que fait le mur de la rotonde du stage 1). Deux
conséquences opposées :

- si le champ doit **persister** à travers une mort, il n'y a rien à faire :
  l'écriture sur place suffit, zéro octet de plus ;
- s'il doit **repousser à neuf**, il faut une copie pristine `C0` en page,
  et `pellet.reset` la recopie. Coût : 1 440 octets dans la région.

La place existe dans les deux cas — le stage 1 occupe jusqu'à `$136F`, le
stage 4 est bien plus petit, et la page est libre au-delà de `$1400`.

**TRANCHÉ le 21/08 : le champ repart à neuf.** La raison est la vague
elle-même — elle rejoue le *même* Cytron depuis le point de reprise, et s'il
retraçait sa ligne par-dessus celle laissée avant la mort, les traces
s'accumuleraient à chaque reprise. Ça n'a pas de sens.

Implémenté en phase 2, avec une contrainte de place qui a demandé un détour :
la région est bornée par l'unité du stage 1 (`stageinit.address` = `$136F`), et
une copie pristine brute de 1 440 octets faisait déborder celle du stage 4. Les
gommes d'origine sont donc stockées en **RLE — 263 octets au lieu de 1 440**
(`tools/rle_mask.py`), et `pellet.reset` recompose `C = T OR D0` en le
déroulant. L'unité passe de 3 971 à 4 264 octets, 711 de marge.

Le crochet : `checkpoint.load` appelle `stage.checkpointReset`, exporté par
`stage-main.asm` — vide pour sept stages sur huit, un `paged.call` vers
`pellet.reset` pour le stage 4.

### 0.2 — L'ordre de dessin

L'analyse (§4) établit qu'**aucun bit de priorité n'existe** dans les données
arcade : la profondeur découle de la couche. Ce qui reste inconnu est l'ordre
global entre couche sprite et plan de premier plan, qui n'est pas dans les
données du jeu — il faut le lire dans le pilote vidéo M72 ou l'observer sous
MAME.

Tant qu'il n'est pas tranché, la phase 6 (profondeur par objet) reste en
attente et le champ se dessine **en fond**. C'est le choix qui rend le
vaisseau visible et qui coûte le moins ; c'est aussi celui qui ne ferme aucune
porte, puisque la ré-application par objet s'ajoute par-dessus sans rien
défaire.

### 0.3 — Cytron entre-t-il dans le lot du stage 4 ?

La repousse (phase 5) n'a de sens que si cytron est porté. Son cast est un
direntry ; l'ajouter coûte de la page dans l'arène ennemis.

**TRANCHÉ le 21/08 : oui, cytron entre dans le budget du stage 4.** La phase 5
est donc au programme, et la phase 2 a livré `pellet.set` pour elle.

Le reste du plan ne dépend pas de cytron : le champ est jouable et creusable
sans lui, simplement il ne se recomble pas.

---

## Phase 1 — Les données (build seul, aucun runtime)

Isolable et sans risque pour le jeu : à la fin de cette phase le stage 4
s'affiche **sans ses gommes**, le champ est un vide noir, et tout le reste est
inchangé.

### 1.1 — Le masque de terrain dur — **FAIT**

`re.arcade.r-type --extract-ballfield` produit `out/tiles/level4_hard.bin`
(1 025 cellules) et `level4_ball.bin` (1 618). Vérifié : `ball OR hard` égale
`level4_fc.bin` bit pour bit, les deux masques sont disjoints.

Reste à les copier dans le jeu, à côté de `level4_fc.bin` :
`src/stages/04/collision/level4_hard.bin`.

### 1.2 — Retirer les gommes de `in.png`

`in.png` est produit par `tools/arcade_to_in.py <stage> <plane>` depuis le plan
avant exporté. Il faut masquer les cellules de gomme **avant** la conversion,
en index 0 (la transparence de la chaîne).

Le plus simple et le plus rejouable : une option `--masque <fichier.bin>` qui
prend un bitfield packé au format du masque de collision (48 octets par
rangée, bit 7 à gauche) et force ces cellules 3×6 à l'index transparent. Le
fichier passé est `level4_ball.bin`, déjà produit.

Écrire l'invocation dans `tools/`, comme les autres, pour qu'elle se rejoue.

### 1.3 — Reconstruire les tuiles et la carte

Rien à changer dans `to8.config.xml` : la chaîne `<leanscroll>` →
`<gfxcomp grid>` → `<tilemap>` repart de `in.png`. Attendu :

- les **9 tuiles de gomme pure** disparaissent des tilesets (2 505 octets) ;
- les **164 occurrences** de la salle deviennent des tuiles vides dans la
  carte, donc `DrawTiles` n'y fait plus qu'un tour de boucle à vide ;
- les 4 tuiles qui mélangent gomme et décor gardent leur décor.

**Piège connu** : effacer `gen/` avant toute conclusion, un run raté empoisonne
le suivant.

### 1.4 — Régénérer la timeline d'effacement

`tools/gen_clear_timeline.py` déduit de la carte les rangées entièrement
peintes. La carte du stage 4 change, donc la timeline aussi — la régénérer et
committer `src/stages/04/clear-timeline.asm` (le stage n'en a peut-être pas
encore : le créer sur le modèle du stage 1).

### Validation de la phase 1

- le build passe, sans erreur ni avertissement nouveau ;
- **empreintes du corpus** : les sept autres stages et les exemples doivent
  sortir identiques (`ci/build-corpus.sh`) — cette phase ne touche qu'aux
  données du stage 4 ;
- à l'écran, le stage 4 montre son décor sans les gommes. Le champ est noir.

---

## Phase 2 — La carte mutable (sans écran)

Tout se vérifie en mémoire, sans rendu.

### 2.1 — Les deux masques dans le direntry de collision

`src/stages/04/collision/collision.asm` gagne, à côté de `collisionMapForeground` :

```
terrainCollision.hard          ; T, statique, jamais écrit
        INCLUDEBIN "./objects/collision/map/level4_hard.bin"
```

et, si la phase 0.1 le décide, une copie pristine `C0` du masque solide.

Contrôle de taille au passage : le direntry doit rester sous `$1400` (la
frontière au-delà de laquelle la page `$17` est ouverte au commun).

### 2.2 — Les quatre primitives

Dans le commun, à côté de la collision. Toutes travaillent sur `(colonne
d'octet, masque de bit)`, pas sur des pixels :

| primitive | effet | ~coût |
|---|---|---|
| `pellet.test` | `C AND NOT T AND masque` → Z | ~20 cy |
| `pellet.clear` | `C[i] &= ~masque` | ~25 cy |
| `pellet.set` | `C[i] \|= masque` | ~25 cy |
| `pellet.reset` | recopie `C0 → C` (1 440 o) | une fois |

`pellet.reset` n'est **pas écrite** : elle attend l'arbitrage 0.1. Tant que le
champ persiste à la mort, il n'y a pas de `C0` à embarquer et la routine
n'aurait pas de donnée.

`terrainCollision` **n'est pas modifié** : il lit `C` exactement comme
aujourd'hui, donc aucun écart au 1:1 v1 à consigner.

### 2.3 — ~~Exposer la cellule touchée~~ → reporté en phase 4

**Décidé le 21/08 à l'écriture.** Les trois fichiers `terrainCollision*` sont
importés v1 en 1:1, sans aucun écart consigné au manifeste. Y toucher pour
exposer la cellule d'impact coûterait une déviation à consigner et un signal
au drift-check — pour économiser une résolution d'adresse.

Les primitives prennent donc leur cellule dans `terrainCollision.sensor.x/y`,
la convention de `terrainCollision.do`, et la résolvent par `loadMap` : **le
même calcul d'adresse que la collision**, donc aucune divergence possible entre
la cellule testée et la cellule effacée. Un appelant qui part d'`impact.x`
repose le senseur et rappelle — une quarantaine de cycles, contre une déviation
v1 permanente.

Si la phase 4 montre que le coût compte sur un chemin chaud, la question se
rouvrira là, avec le vrai appelant sous les yeux.

### Validation de la phase 2

Banc mémoire, sans affichage, sur le modèle d'`examples/objects` (résultats en
`$9C00`) : poser et effacer des bits aux quatre coins du champ, vérifier la
dérivation `C AND NOT T`, vérifier qu'une cellule de terrain dur refuse d'être
effacée, vérifier `reset`. Le banc r-type existant doit rester vert.

---

## Phase 3 — La passe de rendu

C'est le cœur, et c'est la phase la plus délicate. Elle ne touche pas au
gameplay : à la fin, le champ **s'affiche à nouveau**, à l'identique de la
phase 0, mais dessiné par la nouvelle passe.

### 3.1 — Les tables de constantes (build)

12 phases de scroll × 6 lignes × 2 bancs × 9 octets = **1 296 octets**. Une
phase est `caméra_x mod 12` : le motif de gomme est périodique de 3 px, la
paire d'octets BM16 de 4 px, donc le motif d'octets se répète tous les 12 px.

Générateur Python dans `tools/`, sortie committée, invocation écrite à côté —
la convention du projet pour tout art et toute table générée.

### 3.2 — La passe blast

**CONTRAINTE DÉCOUVERTE le 21/08, à trancher avec l'auteur.** Le plan disait
« dans `common.overlay`, à côté de `clearblast` ». Ça ne marche pas tel quel :
la passe doit lire le bitfield `C` et le masque `T`, qui vivent en page `$17`,
et **une seule page est montée à la fois** — le code de la passe ne peut pas
s'exécuter depuis une autre page pendant qu'il les lit. La VRAM, elle, n'est
pas paginée : elle ne pose aucun problème.

Trois issues, par coût croissant en mémoire :

| | où vit la passe | coût |
|---|---|---|
| **a** | une région à `$17:$1400`, dans la page des cartes | ~2 Ko pris à la zone d'arène de dernier recours ; runtime le plus simple, aucun transfert |
| **b** | tables + rendu dans `common.overlay`, un helper dans la page collision, un pilote résident qui alterne | ~60 o résidents + ~2 400 cy/trame de bascules ; **la carte mémoire n'est pas touchée** |
| **c** | tout dans l'unité de collision | **ne tient pas** : 432 o de tables + ~300 de code contre 711 de marge, et l'unité deviendrait la plus grosse, poussant `stageinit` au-delà de `$1400` |

**TRANCHÉ le 21/08 : (d), la zone résidente par-stage.** Ni (a) ni (b) — les
deux partaient d'une lecture fausse de la carte mémoire, que l'auteur a
corrigée. Les fenêtres sont **quatre**, pas deux, et elles sont indépendantes :

| fenêtre | registre | contenu | pendant la passe |
|---|---|---|---|
| `$0000-$3FFF` cartouche | `$E7E6` | page `$17` : les cartes `C` et `T` | montée, **lue** |
| `$4000-$5FFF` demi-page 0 | `$E7C3` bit 0 | le pool d'objets | **intouché** |
| `$6000-$9FFF` page 1 | fixe | la passe et ses tables | **exécutée** |
| `$A000-$DFFF` données | `$E7E5` | l'écran (double tampon) | **écrite** |

Il n'y a donc aucun conflit : du code en RAM fixe lit la page cartouche montée
et écrit l'écran, les trois en même temps. Mon (b) inventait un relais pour un
problème qui n'existe pas.

La passe vit dans la **bande résidente par-stage** `$92DB-$9DCA` de la page 1,
créée le 21/08. Elle fait **2 800 octets et ils sont tous au stage 4**, pour un
besoin d'environ 1 020 (432 de tables réduites à 3 octets par phase/ligne/plan,
288 de bords, ~300 de code).

La bande ne porte que les données du stage **en cours** : les réservations qu'on
y lit — `stage.outslay` du stage 2 en `$9A00` — sont des **alternatives à la
même place**, pas des occupants cumulés. Rien d'un stage passé n'y survit.

Écartée au passage, la piste de l'auteur : basculer `$E7C3` bit 0 pour ouvrir
les 8 Ko de l'autre demi-page (libre depuis que l'overlay a supprimé les
cellules de fond). Elle marche et donne huit fois plus de place, mais elle rend
le pool d'objets **inadressable** pendant les ~20 000 cycles de la passe — une
IRQ qui y toucherait lirait du vide. C'est le filet si la passe grossit, pas le
premier choix.

Une fois l'hébergement tranché, le reste est écrit :

Structure, par rangée de cellules (30) :

1. lire les 6 octets de `C` et les 6 de `T` de la rangée visible, calculer
   `C AND NOT T` → le masque de gommes de la rangée ;
2. si nul → émettre le motif d'effacement ordinaire pour ses 6 lignes ;
3. sinon → pour chacune des 6 lignes et chacun des 2 bancs, charger le jeu de
   registres de la phase et blaster les plages.

Idiome : **le `PSHS A,B,DP,X,Y,U` de `clearblast`**, 9 octets / 14 cycles —
et 9 octets valent exactement 3 périodes du motif, la division tombe juste.
Entrée dans le déroulé par saut calculé, comme la fenêtre de `clearWindow`.

**Les trois pièges de `clearblast` s'appliquent tels quels** et sont déjà
documentés dans son en-tête : aucun `bsr`/`rts` tant que `S` est le pointeur
d'écriture ; `CC` inpoussable sous IRQ ouvertes (d'où 9 octets et pas 10) ;
`DP` passe à zéro et fait partie des octets poussés. Les relire avant
d'écrire une ligne.

### 3.3 — Brancher dans la boucle

Dans `src/stages/stage-main.asm`, entre l'effacement et le starfield, sous une
garde `IFEQ STAGE_ID-4` — le stage 4 est le seul concerné, et la garde évite
de faire payer quoi que ce soit aux sept autres.

### 3.4 — Rendre l'effacement à la passe

Le champ couvre toute la largeur du viewport sur les rangées où il vit. La
passe y **remplace** `clearBlast` plutôt que de s'y ajouter — c'est ce qui
fait tomber le coût net à ~20 000 cycles au lieu de ~38 000 bruts. Deux
routes, à choisir à l'écriture :

- la timeline du stage 4 exclut les rangées du champ, et la passe les peint ;
- ou la passe **est** l'effacement du stage 4 sur toute sa hauteur, et
  `clearBlast` ne fait plus que les bandes hors champ.

La seconde est plus simple à raisonner (une seule passe possède le rectangle)
et c'est celle que je prendrais.

### Validation de la phase 3

- **à l'écran** : le champ intact doit être indiscernable du rendu par tuiles
  d'avant la phase 1. Comparaison de captures ;
- **mesure de cadence** avant/après, dans la salle, au même point de caméra.
  Attendu : la salle passe de ~6 trames vidéo à ~2 ;
- le scroll doit être propre sur les 12 phases — c'est là que se cachent les
  bugs de cette phase. Traverser la salle lentement.

---

## Phase 4 — Le gameplay : creuser

Le champ devient destructible. Chaque brique est petite et se teste seule.

| # | quoi | où | note |
|---|---|---|---|
| 4.1 | le tir mange une gomme | passe de collision des tirs | sur impact, `pellet.test` → `pellet.clear`, décrémenter le potentiel `AABB.p`, le tir survit s'il en reste |
| 4.2 | arrêt franc sur terrain dur | idem | `C` posé **et** `T` posé → le tir meurt quel que soit le potentiel |
| 4.3 | le Force pod efface son amas | objet Force pod | 4 amas 2×2 aux coins (x±8, y±8), jusqu'à 16 cellules/trame — c'est le vrai outil de creusement |
| 4.4 | le son | à l'effacement | SFX arcade 0x5E, **une fois par trame** quel que soit le nombre de gommes mangées (c'est ce que fait l'arcade) |
| 4.5 | le vaisseau meurt au contact | rien à faire | une gomme est déjà solide dans `C` |

Pas de score : l'arcade n'en donne pas (§4 de l'analyse).

Coût attendu : ~80 effacements par trame au pire, ~1 500 cycles. Rien.

**Validation** : creuser un tunnel à l'écran et le voir rester ouvert ; mourir
contre une gomme ; vérifier qu'un mur arrête le tir.

---

## Phase 5 — Cytron et la repousse

Conditionnée par l'arbitrage 0.3. Suit le mode opératoire du skill
`enemy-port` ; la spec arcade est déjà extraite dans l'analyse (§4).

- 5.1 porter l'objet (16 images déjà converties, ~50 entrées de wave
  commentées dans `src/stages/04/wave.asm`) ;
- 5.2 la repousse : une cellule par trame sous son centre, **si et seulement
  si** `NOT C AND NOT T` — `pellet.set` ;
- 5.3 décommenter sa wave.

Ce qui manque encore côté arcade : sa **trajectoire** (script de mouvement en
ROM, non extrait), qui détermine où il recomble. À extraire au moment du
portage.

**Validation** : creuser, laisser cytron passer, voir le champ se recombler —
et la gomme repoussée tuer.

---

## Phase 6 — La profondeur par objet

En attente de l'arbitrage 0.2. Passe de ré-application masquée après
`BuildSprites`, sur la seule boîte des sprites marqués « dans le champ ».
Mesuré : **1 488 cycles** pour un cytron (4×4 cellules), 1 575 pour un
patapata. La passe se saute d'elle-même si la boîte ne recouvre aucune gomme.

---

## Ce que ça donne, phase par phase

| phase | salle, cycles/trame | destructible | état |
|---|---|---|---|
| aujourd'hui | 120 597 (6,04 trames) | non | — |
| après 1 | ~12 500 | non | champ invisible |
| après 3 | ~33 000 (1,65 trame) | non | champ rendu |
| après 4 | ~34 500 (1,73 trame) | **oui** | jouable |
| après 5 | ~35 000 | oui + repousse | complet |
| après 6 | ~41 000 (2,05 trames) | oui | + profondeur |

---

## Pièges à relire avant de commencer

- **`gen/` empoisonné** : un run de build raté fausse le suivant. `rm -rf gen`
  avant toute conclusion, et comparer le corpus avant/après pour tout
  changement côté builder.
- **Les trois pièges de `clearblast`** (S pointeur, CC, DP) — en-tête du
  fichier, phase 3.
- **Le contrat de page directe** : `$60` moniteur / `$9F` globales engine, et
  la passation dans les deux sens. La passe blast met `DP` à zéro.
- **La page `$17`** : le direntry de collision doit rester sous `$1400`.
- **Le masque extrait fait autorité** sur mon comptage initial : 1 618 gommes,
  pas 1 620 — deux cellules de décor ressemblaient à des gommes.
- **Les tests sont à ta main** : je livre le build et je rends la main ; toje
  seulement sur demande explicite.

## Ordre de dépendance

```
0 (arbitrages)
└─ 1 (données)         ← livrable seul, corpus à empreintes
   └─ 2 (carte mutable)   ← banc mémoire, sans écran
      └─ 3 (rendu)           ← la phase délicate : scroll 12 phases
         └─ 4 (creuser)         ← jouable ici
            └─ 5 (cytron)          ← si 0.3 le veut
               └─ 6 (profondeur)      ← si 0.2 est tranché
```

Les phases 1 et 2 sont **indépendantes l'une de l'autre** et peuvent se faire
dans les deux sens ; c'est la 3 qui a besoin des deux.
