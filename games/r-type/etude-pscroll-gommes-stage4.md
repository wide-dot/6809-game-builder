# Étude — `pscroll` : le champ de gommes en buffer de code persistant

> 2026-08-22. **Cette étude remplace la phase 3 de
> [`plan-gommes-stage4.md`](plan-gommes-stage4.md)**, dont la stratégie
> « run-blast » est livrée, juste au pixel, et **échoue son critère
> d'acceptation d'un facteur 17** (mesuré sous toje, voir §2).
> Références : [`docs/lang/fr/etude-mscroll-2026-08.md`](../../docs/lang/fr/etude-mscroll-2026-08.md)
> (le modèle de coût et la machinerie de ruban sont repris tels quels),
> `engine/graphics/tilemap/mscroll/mscroll.asm` (1 095 l., la base à cloner),
> `examples/mscroll` (le démonstrateur), [`analyse-gommes-stage4.md`](analyse-gommes-stage4.md)
> (géométrie, extraction arcade, structure de données — inchangées).

## TL;DR

**Le contrat, rappelé par l'auteur : les gfx sont GRAVÉS dans un méga-sprite
compilé qui persiste d'une trame à l'autre ; on ne met à jour que le delta —
ce que le scroll fait entrer, et les gommes ajoutées ou supprimées.** La passe
actuelle fait l'inverse : elle reconstruit le champ entier à chaque trame
depuis le bitfield.

La mesure tranche : la passe coûte **691 537 cycles par trame**, dont **5 %
seulement dans le blast** et **49 % dans le parcours de structure** refait
chaque trame. Le buffer persistant ramène le coût à **~54 000 cycles
constants**, et il **absorbe `clearBlast`** sur sa bande — soit **~33 000
cycles nets**, exactement le budget que le plan visait.

Cadence attendue dans la salle : **~7 img/s contre 1,25 aujourd'hui**
(stage 1 : 10,4). Mémoire : **2 pages en 2 px, 4 en 1 px** — et **10 pages
sont libres pendant que le stage 4 est chargé** (§5).

**La couture n'est pas un sujet** : mscroll l'a supprimée le 20/08/2026 par
une compensation de cisaillement ancrée à la map, validée 0 défaut sur
4 × 8 000 contrôles et mesurée à coût **nul** (12,50 img/s contre 12,55).
Le clone en hérite. Et le **1 px** (§6) ne coûte **aucun cycle de blast** :
il double le buffer de code, rien d'autre.

---

## 1. Le contrat

| | passe actuelle (run-blast) | `pscroll` (le contrat) |
|---|---|---|
| source du rendu | le bitfield `C AND NOT T`, relu en entier | un **buffer de code**, gravé une fois |
| par trame | scanner 1 440 cellules, découper les plages, calculer la géométrie par ligne et par plan, écrire les octets | **exécuter le buffer**, rien d'autre |
| au scroll | tout est recalculé | **entrée du ruban** déplacée, la colonne qui entre est gravée |
| creuser une gomme | rien à faire (recalculé) | **patcher les opérandes** de cette cellule, une fois |
| coût | proportionnel au contenu, refait 50 fois/s | **constant**, proportionnel à la seule hauteur de bande |

C'est le principe de mscroll, appliqué à une couche **horizontale pure** et
dont la source n'est pas une tilemap mais un **bitfield mutable**.

## 2. Pourquoi la passe actuelle ne peut pas y arriver

Mesure sous toje, stage 4, caméra 805 (la grande salle), profileur attribué par
plage d'adresses sur 200 trames machine / 5 trames rendues :

| poste de `pellet.blast` | cy/trame rendue | part |
|---|---|---|
| `dpBytes` — la boucle octet par octet | 305 385 | 44 % |
| `drawPlane` — découpe, par ligne × plan | 164 977 | 24 % |
| `cellSet` — le scan cellule par cellule | 86 341 | 12 % |
| `rowRuns` — le découpage en plages | 62 787 | 9 % |
| `drawRun` | 25 419 | 4 % |
| **`dpChain` — le blast** | **34 653** | **5 %** |
| setup + `dpSlow` | 11 974 | 2 % |
| **total** | **691 537** | 87 % de la trame |

Deux enseignements, et le second est le vrai :

1. **Optimiser le blast ne pouvait rien sauver** : il pèse 5 %. La session du
   22/08 a porté sur les 5 %.
2. **La moitié du coût est du parcours de structure** (339 524 cy : `rowRuns`,
   `cellSet`, `drawRun`, `drawPlane`) — du travail refait à l'identique tant que
   le champ ne change pas. Même avec un blast gratuit couvrant *tous* les
   octets, la passe resterait à ~340 000 cycles, soit 17 trames vidéo.

**Pourquoi l'étude annonçait 33 204.** Le simulateur émettait le flux
d'instructions du *dessin* et comptait ses cycles ; il ne modélisait pas la
structure autour (scan, découpe, géométrie par ligne et par plan). L'écart est
là, et entièrement là. **Leçon portée en critère d'acceptation au §7 : toute
estimation de cette couche se valide par une mesure de cycles SUR MACHINE,
attribuée par plage d'adresses — jamais par une simulation seule.**

## 3. Conception

### 3.1 La géométrie, rappelée

Le champ fait **30 rangées de cellules 3×6 px**, soit **180 lignes écran**
(première ligne `pellet.VP_Y` = 11), sur toute la largeur du viewport :
**160 px = 40 octets par plan et par ligne**. La carte fait 48 octets par
rangée, soit 384 cellules = 1 152 px.

### 3.2 Le buffer

Clone de `mscroll` **amputé de sa moitié verticale** — pas de curseur de ligne,
pas de feed de rangée, pas de problème de coin. Reste le ruban horizontal :

```
ligne k (par plan) :
  [chunk 0][chunk 1] ... [chunk 9]     chunk = ldd #imm / ldx #imm / pshs d,x
                                       8 o de code, 4 o de données = 16 px, 15 cy
buffer : ligne 0 .. ligne 179, jmp de sortie patché
```

- **80 octets de code par ligne et par plan**, comme mscroll (rapport code:
  données de 2:1, incompressible pour cette technique) ;
- **le chunk `c` porte la colonne de carte `c mod 10`** — adressage absolu,
  partagé par le feed et par la rotation ;
- **entrée** par `jmp ligne[0] + h×8`, **sortie** par un `jmp` patché : la
  danse de `vscroll.do`, déjà écrite et déjà validée.

### 3.3 Graver un chunk

C'est la seule chose que `pscroll` sait faire, et elle ne s'exécute qu'au
delta. Un chunk couvre 16 px, une cellule fait 3 px : **6 cellules au plus**
le recouvrent, et sa phase de motif est fixée par sa position de carte
(`16c mod 12 ∈ {0,4,8}`). Le contenu des 4 octets est donc une fonction de
(phase du chunk, ligne 0-5, plan, les 6 bits de gommes vivantes).

Deux façons de l'obtenir, à trancher au démonstrateur :

- **calculée** depuis les tables de motif de la phase 3.1 (1 296 o, déjà
  écrites, déjà prouvées au pixel) — ~50 à 100 cy par chunk, zéro octet de
  plus ;
- **tabulée** : 64 motifs × 6 lignes × 2 plans × 3 phases × 4 o = 9 216 o —
  ~20 cy par chunk, une page à moitié pleine.

Recommandation : **calculée**. Les feeds sont rares (§4), et cela **réutilise
tel quel le travail de la phase 3.1**.

### 3.4 Les trois mécanismes runtime

1. **Blast** (chaque trame) : décomposer `x`, poser `S`, patcher la sortie,
   monter la page du buffer, `jmp`. Coût constant. Deux passes, une par plan.
2. **Feed de colonne** (tous les 16 px de scroll) : la colonne qui entre est
   gravée dans son chunk, sur les 180 lignes et les 2 plans.
3. **Mutation** (quand une gomme disparaît ou repousse) : regraver le ou les
   chunks qui couvrent cette cellule, sur ses **6 lignes** et les 2 plans. Le
   bitfield `C` reste la source de vérité et la collision — **les phases 1 et
   2 du plan sont réutilisées sans une ligne de changement**.

### 3.5 Ce qui disparaît en même temps

La passe ne lit plus les cartes `C`/`T` pendant qu'elle dessine : elle exécute
du code depuis une page montée en fenêtre cartouche. **Toute la contrainte qui
avait façonné la phase 3.2** — « la passe doit vivre en RAM fixe pour lire la
page `$17` en dessinant », d'où la bande résidente `stage4.res` — **tombe**.
La bande résidente redevient disponible.

Et le buffer peignant **chaque octet** de sa bande, il **est** l'effacement du
stage 4 sur ces 180 lignes : la phase 3.4 du plan (« rendre l'effacement à la
passe »), différée depuis le début, est acquise **par construction**.

## 4. Budgets

Tous les chiffres de mise à jour ci-dessous sont **simulés**
(`tools/sim_pscroll_maj.py`, §6.3 et §7) et donnés **en 1 px, les deux phases
comprises** — le cas le plus cher.

| poste | cycles | remarque |
|---|---|---|
| blast, 180 lignes × 2 plans | **~54 000** | 14 400 o à 3,75 cy/o — constant |
| `clearBlast` rendu à la couche | **−21 215** | la bande couvre les lignes 9-178 |
| **net par trame** | **~33 000** | le budget visé par le plan d'origine |
| feed de colonne — câblé, destination fixe | 15 840 cy tous les 16 px | **1 584 cy/trame amortis** (2,9 % du blast) |
| mutation d'une rangée — générique, destination calculée | ~996 cy + ~40 de positionnement | 0 si la cellule était déjà vide (`pellet.test`) |
| Force pod, pic en champ vierge | ~8 000 cy | 0,4 trame, une fois |
| gravure initiale | ~430 000 cy | ~22 trames, au chargement et au checkpoint |

**Cadence attendue.** Le reste de la trame coûte 106 623 cy (mesuré). Avec la
couche : ~139 000 cy ≈ 7 trames vidéo → **~7 img/s**, contre **1,25**
aujourd'hui et 10,4 au stage 1. Et surtout : **plat**, quel que soit l'état du
champ — ce qui compte pour un jeu calé sur les timestamps arcade.

## 5. Mémoire et pages — la contrainte n'en est pas une

`mscroll.LINE_SIZE` = 10 chunks × 8 o = **80 octets par ligne et par plan**.
Le champ demande 180 lignes de contenu ; avec la marge et le `jmp` de
bouclage, `BUFFER_LINES` ≈ 184, soit **14 720 o par buffer** — **une page
par buffer**, et 204 lignes tiennent dans une page si la bande grandit.

| variante | buffers | pages |
|---|---|---|
| 2 px | 2 (un par plan) | **2** |
| **1 px** | 4 (plan × phase) | **4** |

**Pages libres pendant que le stage 4 est chargé — mesurées sur le rapport
d'occupation du build** : `14, 15, 16, 28, 29, 30, 31` (elles n'appartiennent
qu'aux stages 1, 2, 3 et 7, qui sont des **alternatives** : elles sont vides
quand le stage 4 tourne), plus `2, 3, 11` que rien ne charge jamais. **Dix
pages.** Les deux variantes sont finançables, avec de la marge.

Précédent qui fait autorité : le décor du stage 4 paie **déjà** le 1 px en
mémoire — `stage4.tiles.even` et `stage4.tiles.odd` sont deux tilesets
pré-décalés (pages 25 et 24). La couche gommes fait le même choix.

## 6. Le 1 px : conception, cycles, place

### 6.1 Pourquoi le 1 px n'est pas gratuit

`mscroll.do` décompose `x = 16·h + 4·bo + 2·w` : `h` est le chunk d'entrée,
`bo` un offset d'octet sur `S`, et `w` **échange les zones `$A000`/`$C000`**,
ce qui vaut exactement 2 px. Le bit 0 de `camera.x` est **jeté** par le second
`asra` de la décomposition. C'est là, et seulement là, que la résolution
s'arrête à 2 px.

Il n'y a pas de quatrième terme à trouver. En BM16 un octet porte **deux
pixels** (un quartet chacun), et l'appariement pixel → (plan, octet, quartet)
fait qu'un décalage de 1 px déplace les pixels **d'un quartet ET d'un plan à
l'autre** : les octets de la phase impaire ne sont pas une permutation
d'adresses des octets pairs, ce sont d'autres octets. Aucun réglage d'adresse
de départ ne peut les produire — il faut **une seconde donnée**.

### 6.2 La conception : deux jeux de buffers, un par phase

Un second buffer de code par plan, gravé avec le rendu décalé d'1 px. Au
blast, on choisit le buffer sur le bit 0 de `camera.x` ; tout le reste de
`mscroll.do` (h, bo, w, entrée, sortie patchée, cisaillement map-fixe) est
**inchangé**, `w` couvrant alors les 2 px restants.

```
x pair   -> buffers (A0, B0)      x = 16h + 4bo + 2w
x impair -> buffers (A1, B1)      idem, données pré-décalées d'1 px
```

C'est la transposition exacte de ce que fait déjà le décor du stage 4 avec
ses tilesets `even`/`odd` — et c'est aussi la sortie que l'étude mscroll
avait réservée (« le 1 px horizontal, double buffer de phase, réservé en
évolution, décision à l'adaptation R-Type »). La décision arrive ici.

### 6.3 Le coût en cycles — et c'est là qu'est le vrai prix

**L'impact du 1 px n'est pas le blast, c'est qu'il faut tenir DEUX buffers à
jour** : au scroll, et à chaque gomme ajoutée ou retirée. Les deux cas ne se
comportent pas de la même façon.

| poste | surcoût du 1 px | quand |
|---|---|---|
| **blast** | **0** — la bande est peinte une fois, dans l'un ou l'autre | chaque trame |
| choix du buffer | ~15 cy | chaque trame |
| **feed de colonne** | **×2, sur la MÊME trame** | tous les 16 px |
| **mutation d'une cellule** | **×2, sur la MÊME trame** | à chaque gomme mangée ou repoussée |

**Le feed n'est pas étalé par la phase.** J'ai vérifié dans `mscroll.move` :
la fenêtre est `(camera.x+8)>>4`, identique pour les deux phases — les deux
buffers réclament donc la colonne entrante **au même franchissement**, pas
l'un après l'autre. Le pic passe de ~9 000 à **~18 000 cycles**, une trame
sur dix à 1,6 px/trame : **+13 % sur cette trame-là, ~1,3 % amortis** sur un
budget de ~139 000 cy. Si ce pic gênait, mscroll sait déjà étaler un feed sur
la moitié des lignes (les lignes en retard montrent une colonne périmée **au
bord masqué**) — et ici on peut simplement nourrir une phase par trame, la
phase non affichée ayant une trame de battement.

**La mutation, elle, doit être doublée tout de suite** : la gomme disparaît
maintenant, dans les deux phases. Trois choses la rendent abordable, et la
première est décisive.

**Le bitfield dit en ~20 cycles s'il y a quelque chose à faire.** `pellet.test`
— écrite, exportée depuis la phase 2, toujours sans appelant — répond « gomme
vivante » ou « vide » avant qu'on touche au buffer. **Seule une transition
réelle déclenche une copie** : un tir qui repasse dans son propre tunnel, ou
le Force pod qui stationne dans le trou qu'il vient de creuser, ne coûtent que
leurs tests. C'est ce qui écroule le pire cas théorique :

| situation | cellules testées | cellules qui CHANGENT | copies vers les buffers |
|---|---|---|---|
| Force pod entrant dans du champ vierge | 16 | jusqu'à 16 | le pic, une fois |
| Force pod en régime établi (il stationne dans son trou) | 16 | **0 à 4** | ~320 cy de tests, et presque rien d'autre |
| tir traversant un tunnel déjà creusé | 1 | **0** | **aucune** |

Le champ ne se creuse qu'à son bord d'attaque : les amas se recouvrent d'une
trame à l'autre, donc le régime permanent est de l'ordre d'**une à quatre
cellules réellement changées par trame**, pas seize. Le pire cas ne se produit
qu'en entrant dans du champ intact, et il ne se répète pas au même endroit.

**La granularité d'écriture, simulée** (`tools/sim_pscroll_maj.py`, modèle de
coût 6809 explicite et layout BM16 exact). Le layout commande : un octet porte
**2 px adjacents**, l'écran change de plan tous les 2 px, et l'opérande du
buffer fait 2 octets — donc une travée de 8 px d'écran. Résultat net, vrai
quel que soit l'alignement : **une gomme de 3 px touche toujours exactement
2 octets, un par plan** (3 px = 2 px d'un plan + 1 px de l'autre), jamais
plus. Et **jamais de read-modify-write** : le bitfield donne le contenu
complet de l'octet, on le réécrit en entier.

Coût d'une mise à jour sur une rangée de cellules (6 lignes, un plan et
l'autre, pire alignement, données lues en table) :

| granularité | octet par octet | opérande de 2 o | en 1 px (×2) |
|---|---|---|---|
| **une gomme, 3 px** | **186 cy** | 210 cy | **420 cy** |
| 2 gommes, 6 px | **306 cy** | 354 cy | **708 cy** |
| une travée, 8 px | 366 cy | **354 cy** | 708 cy |
| la période du motif, 12 px | 486 cy | **426 cy** | 852 cy |
| le chunk entier, 16 px | 606 cy | **498 cy** | 996 cy |

Le croisement est à 8 px — en dessous l'écriture octet par octet gagne 11 à
14 %, au-delà l'opérande de 2 octets gagne jusqu'à 18 %. **Mais ce n'est pas
là que passe la vraie frontière.** La granularité retenue est la même des deux
côtés — **la bande de 16 px, soit 8 px par plan** — et ce qui sépare les deux
chemins est **la destination** (§6.4).

Ce que ça donne sur les événements réels du jeu, **les deux phases comprises** :

| événement | coût |
|---|---|
| un tir mange une gomme | **420 cy** |
| un amas 2×2 du Force pod (2 rangées) | 1 416 cy |
| Force pod entrant dans du champ **vierge** (4 amas) | **5 664 cy** — le pic |
| Force pod stationnaire (0 à 4 transitions) | ~708 cy |
| tir dans un tunnel déjà creusé | **0** |

Le pic du Force pod est donc à **5 664 cycles**, pas aux 15 000-23 000 que
j'estimais avant de simuler : 0,3 trame vidéo, une fois, à l'entrée dans du
champ intact. La mutation n'est pas un poste.

Les deux autres points, pour borner ce qui reste :

- **on regroupe les cellules voisines.** Un amas 2×2 tient dans 6 px : le
  traiter d'un bloc coûte 708 cy là où deux gommes isolées en coûteraient
  840. Le gain est réel mais modeste — c'est la garde `pellet.test`, pas le
  regroupement, qui fait l'essentiel du travail ;
- **la phase non affichée a une trame de battement.** Si le pic mordait, une
  liste de chunks salis permet de patcher tout de suite le buffer affiché et
  de vider la liste sur l'autre avant qu'il ne passe à l'écran. Même travail
  total, pic divisé par deux.

À retenir : **le poste dominant — le blast, ~54 000 cy — ne bouge pas d'un
cycle.** Le 1 px se paie en deux pages et en deux mises à jour ; il ne se paie
pas dans la boucle qui coûte.

### 6.4 Deux chemins d'écriture, séparés par la DESTINATION

Même granularité, deux algorithmes — et ce qui les distingue n'est ni la
largeur ni le nombre d'octets, mais **le fait que la routine sache ou non où
elle écrit**.

| | **feed de carte** (une colonne entre) | **mutation** (une gomme apparaît ou disparaît) |
|---|---|---|
| destination | **fixe et connue à la génération** : l'emplacement de ruban est l'un des dix, les décalages de ligne ne bougent jamais (pas de scroll vertical) | **à calculer** : cellule → emplacement de chunk, rangée → bloc de six lignes |
| coût de positionnement | nul — `ldu #base`, puis on déroule | ~30 à 50 cy (rangée → offset de ligne par table de 30 entrées, colonne → emplacement) |
| contenu | la carte de build, **toujours vierge** : une colonne qui entre par la borne droite n'a jamais été à l'écran, donc jamais creusée ni semée | **quelconque** : cytron peut faire pousser une gomme là où il n'y en avait pas, l'état local n'est plus celui de la carte |
| implémentation | les **22 routines câblées**, immédiats cuits (§7) | routine **générique**, octets dérivés des tables de motif de la phase 3.1 |
| coût d'une rangée (2 plans, 2 phases) | **528 cy** | ~996 cy + positionnement |

Les deux ne se croisent jamais : **cytron n'écrit pas au-delà de la borne
droite de l'écran, et c'est précisément là que le scroll fait entrer les
colonnes neuves.** Le feed lit donc toujours la carte de build — les 22
combinaisons relevées dessus sont exactement son jeu, ni plus ni moins.

La mutation, elle, doit rester **générique** pour cette même raison : une
gomme semée hors du champ d'origine produit une combinaison locale que la
carte de build ne contient pas. La câbler demanderait de générer les
combinaisons *possibles* (3 alignements × 2⁶ états de cellules ≈ 192 routines,
~30 Ko) au lieu des *présentes* — pour économiser 470 cycles sur un événement
rare. Ça ne vaut pas le coup : **le générique suffit là où le câblé n'apporte
rien.**

### 6.5 La place, et une asymétrie qui joue en notre faveur

Pour une couche **tilemap** générique (le cuirassé du stage 3), le 1 px coûte
**deux fois le buffer de code ET deux fois le tileset** — et il porte une
subtilité : décalée d'1 px, une tuile déborde d'un pixel sur sa voisine, donc
l'opérande impair de la tuile `t` dépend aussi de la tuile `t−1`. Un tileset
pré-décalé ne suffit pas seul : le feed doit y fusionner un quartet venu de
la tuile voisine (~10-20 cy par opérande, au feed uniquement).

**Pour le champ de gommes, rien de tout cela.** Il n'y a pas de tileset : le
contenu d'un chunk est *calculé* depuis les tables de motif de la phase 3.1,
**qui sont déjà indexées par les 12 phases de pixel**. La phase impaire est
donc juste un autre index dans une table qui existe déjà — **zéro octet de
données en plus, zéro fusion de voisin**. Le 1 px ne coûte ici que les deux
pages de buffer supplémentaires.

| | couche tilemap générique | champ de gommes |
|---|---|---|
| buffer de code | ×2 | ×2 (2 pages → 4) |
| données de tuiles | ×2 + fusion au feed | **inchangées** (tables 12 phases) |
| cycles de blast | 0 | 0 |

## 7. Le feed précalculé — ce que la carte réelle impose

**Sans scroll vertical, la gravure d'une colonne est FIGÉE** : le lien
(rangée, ligne) → ligne de buffer ne bouge jamais, et la colonne qui entre
par le bord droit n'a **jamais été visible**, donc jamais creusée — la caméra
ne recule pas et le checkpoint remet le champ à neuf. Son contenu est donc
**exactement celui de la carte de build**. Tout le différentiel de scroll est
connu à la compilation.

J'ai déroulé `level4_ball.bin` (48 o × 30 rangées = 384 cellules × 30) :

| | mesuré |
|---|---|
| profils verticaux de colonne de cellules distincts | **13** sur 384 colonnes |
| colonnes de cellules entièrement vides | **316 / 384** |
| colonnes de chunk (16 px) non vides | **15 / 72** |
| **motifs de chunk distincts** | **12** (11 non vides + le vide) |

Et le champ n'est pas un bloc : il vit en **trois grappes**.

| grappe | chunks | px du niveau | rangées | hauteur utile |
|---|---|---|---|---|
| rideaux d'entrée | 10-11 | 160-191 | 6-21 | 96 lignes |
| rideau isolé | 30 | 480-495 | 18-21 | **24 lignes** |
| la grande salle | 51-62 | 816-1007 | 0-29 | 180 lignes |

Trois conséquences, et la troisième est la plus grosse :

1. **Les routines câblées : 22, partagées entre les plans, 3,4 Ko.** L'unité
   n'est pas la colonne entière (la dérouler coûterait 6,3 pages) mais **une
   rangée de cellules × les 4 octets d'un plan sur la bande de 16 px** : 6
   lignes, 78 octets de code.

   La vue d'un plan sur une bande de 16 px est un **peigne** — 2 px, saut de
   2 px, 2 px… — et **cette combinaison ne mentionne ni le plan ni la phase** :
   le même peigne se retrouve dans les quatre buffers. C'est ce qui partage les
   routines. **Compté, généré et prouvé** par `tools/gen_pscroll.py` sur la
   carte réelle :

   | | mesuré |
   |---|---|
   | vues par (plan 0, phase 0) / (0,1) / (1,0) / (1,1) | 12 / 12 / 12 / 13 |
   | routines si chaque buffer avait les siennes | 49 |
   | partagées entre plans seulement | 41 |
   | partagées entre phases seulement | 39 |
   | **partagées entre les quatre** | **33** (32 non vides) — **−32 %** |

   Code total : 76 o × 33 = **2 508 octets**, plus 1 860 o de tables de colonne
   (62 colonnes non vides × 30 index). **Moins de 4,5 Ko pour toute la
   gravure du niveau.** Et c'est **plus rapide** que la table : les immédiats
   sont cuits dans le code (`ldd #`, 3 cy) au lieu d'être relus (`ldd n,y`,
   6 cy), et il n'y a plus d'arithmétique d'adresse.

   | | table pilotée | **routines câblées** |
   |---|---|---|
   | une rangée (2 plans, 2 phases) | 996 cy | **528 cy** |
   | une colonne entière (30 rangées) | 20 892 cy | **15 840 cy** (−25 %) |
2. **79 % des colonnes n'ont rien à graver.** Avec un drapeau « ce chunk est
   déjà tout fond » par emplacement du ruban, entrer dans du vide coûte un
   test. Sur les 72 colonnes du niveau, **15 gravures** — plus leurs retours
   au vide — au lieu de 72.
3. **La couche ne doit pas tourner partout — mais sa bande ne se règle pas sur
   l'étendue statique.** Hors des grappes il n'y a rien à peindre et
   `clearBlast` (21 215 cy) suffit ; la couche peut donc s'allumer par région,
   sur le modèle de la timeline d'effacement qui existe déjà. En revanche la
   **hauteur** de bande ne peut pas se déduire de la carte de build : cytron
   sème des gommes en cours de partie, y compris là où il n'y en avait pas
   (une cellule vidée et une cellule naturellement vide portent la même valeur
   arcade, `0xFA0`). Ça ne gêne en rien le feed — cytron n'écrit jamais au-delà
   de la borne droite, là où les colonnes entrent — mais ça interdit de rogner
   la bande sur l'étendue du champ d'origine.

En clair, chiffré : dans la salle, une colonne entre tous les 16 px, soit
toutes les 10 trames à la vitesse du stage — **2 089 cy/trame amortis, 3,9 %
du blast**. Et sur le niveau **entier**, les 15 colonnes non vides totalisent
**313 380 cycles** : moins que ce que la passe actuelle brûle en **une seule
trame** (691 537). Le feed cesse d'être un poste.

## 8. Les arbitrages, pour l'auteur

1. **1 px ou 2 px ?** **Recommandation : 1 px.** Il ne coûte aucun cycle de
   blast, deux pages qu'on a, et aucune donnée nouvelle pour les gommes. En
   2 px le champ oscillerait d'1 px contre un décor qui défile à 1 px.
   Ce qu'on accepte en le prenant, et qui est **le seul vrai prix** : toute
   mise à jour se fait **en double** — la colonne qui entre au scroll, et
   chaque gomme mangée ou repoussée (§6.3). Simulé : le feed passe à
   20 892 cy par colonne, soit **2 089 cy/trame amortis (3,9 % du blast)** ;
   une gomme mangée coûte 420 cy et le pic du Force pod 5 664. Les deux sont
   étalables sur une trame si la mesure le réclame.
2. **Hauteur de bande** : 180 lignes est le seul levier du coût. Le champ les
   occupe toutes dans la grande salle ; y a-t-il des salles où la borner ?
3. **Généraliser ou spécialiser ?** Le 1 px décrit au §6 vaut pour mscroll
   lui-même. Soit on l'implémente **dans mscroll** (le cuirassé du stage 3
   en profiterait, au prix du tileset doublé et de la fusion de voisin), soit
   on le garde **dans le clone**, où il est gratuit en données. Mon avis : le
   faire d'abord dans le clone, et remonter dans mscroll le jour où une
   couche tilemap réclame le 1 px.

## 8. Le plan

Chaque phase est livrable et vérifiable seule, comme le plan d'origine.

**A0 — Le générateur et sa preuve. FAIT (22/08).** `tools/gen_pscroll.py`
grave le buffer depuis `level4_ball.bin` et le modèle pixel de la phase 3.1,
recense les 33 combinaisons, émet `src/stages/04/pscroll-rows.asm` (routines
+ tables de colonne), puis **rejoue le placement du blast sur toutes les
positions de caméra du niveau et les deux parités** : **0 divergence sur
28 598 400 pixels**. Le modèle du buffer est prouvé avant la première ligne
de 6809 — la discipline qui avait déjà pris en défaut deux bugs des tables.

**A1 — Le module ASM. ÉCRIT (22/08), non exécuté.**
`engine/graphics/tilemap/pscroll/pscroll.asm` — clone de mscroll amputé de sa
moitié verticale : squelette de buffer, `setCameraX`, `init`, `move` (vitesse
compensée, franchissement de couture, feed des bandes entrantes), `feedBand`,
`engraveColumn`/`engraveEmpty`, `do` (parité → paire de buffers, décomposition
`h`/`bo`/`w`, sortie patchée) et `runBuffer`. **628 octets** de code engine,
**5 008** de données générées — 5 636 en tout. Il assemble proprement
(lwasm, cible objet).

**A2 — Le banc `examples/pscroll`. LES GOMMES DÉFILENT (22/08).**

**Résultat : le champ s'affiche et scrolle, à 16,2 img/s** (81 trames rendues
sur 250 machine, bande pleine de 180 lignes). Le modèle tenait : ~54 000
cycles de blast valent 2,7 trames vidéo, soit 18,5 img/s en théorie pure, et
on mesure 16,2 une fois le feed et la boucle comptés. À comparer aux
**1,25 img/s** de la passe run-blast dans la même salle.

Vérifié à l'écran à deux positions de caméra : au milieu de la grande salle
(920) le champ montre sa vraie structure — l'encoche de gauche, la marche du
haut, les protubérances du bas — et en fin de salle (992) il ne reste que le
rideau de gauche, ce que la carte annonce. Le débord de ruban de ≤ 8 px au
bord droit est visible ici parce que le banc n'a pas de masque ; c'est celui
que le masque du champ recouvre dans le jeu.

**LA COUTURE : REPÉRÉE PAR L'AUTEUR, PUIS SUPPRIMÉE (22/08).** Elle se voyait
à l'écran ; mesurée sur la capture, le motif changeait de phase verticale à
map px ≈ 963 — juste après 960, un multiple de 160, donc bien la coupure du
ruban. Deux défauts distincts se cachaient dessous.

**1. Le piège signé, deux fois.** La comptabilité d'origine faisait
`addb`/`bpl` : sur une valeur de 128 à 185, bit 7 levé, le `bpl` la lisait
négative et rajoutait `BUFFER_LINES` une fois de trop. La suite réelle était
0, 185, 114, 113… au lieu de 0, 185, 184, 183 — l'origine mentait de 70 lignes
dès la deuxième couture, et la valeur lue sur machine (111 à la caméra 920) l'a
confirmé au chiffre près. Même piège dans le modulo du feed. C'est exactement
ce que la campagne mscroll avait déjà écrit : *ne jamais tester le signe d'une
valeur 0..200*. Troisième fois dans ce module.

**2. Le placement mélangeait deux repères.** La ligne d'une bande était
calculée comme `origine ± coutures`, donc elle bougeait avec la caméra — alors
que la position d'une bande gravée doit être fonction **d'elle seule**, sinon
elle cesse d'être valable dès que la caméra avance. La formule juste sépare
les deux :

```
ligne d'une bande   = BIAIS - coutures(bande)     gravée une fois, définitive
entrée du blast     = BIAIS - coutures(caméra)    absorbe le mouvement
```

Les deux termes dérivent alors **dans le même sens**, leur différence vaut 0
ou 1 selon que la bande est avant ou après la coupure, et c'est ce 1 qui annule
le cisaillement du ruban. Avec `BIAIS = 8`, tout reste dans [1..8] : **aucun
modulo, donc aucun piège signé possible** — la correction et sa robustesse
d'un seul coup.

Ce que le « par chance » de l'auteur disait : 160 px = exactement 10 chunks de
16, donc la coupure tombe **toujours** sur une frontière de chunk, jamais
dedans. La compensation ne pouvait être qu'un décalage entier de ligne.

**Vérifié** : à deux positions de caméra (920 et 992) et sur trois bandes
horizontales, le motif ne présente plus que ses **deux** phases normales — la
troisième, signature du cisaillement, a disparu. Cadence après correction :
**16,6 img/s**.

**Le banc a payé son écriture cinq fois.** Quatre bugs francs à moi : ordre
page/adresse inversé dans le squelette, `addd` sur une variable d'un octet,
et **deux fois la même leçon** — une variable de boucle écrasée par un appelé
(`feedBand` puis `init`, tous deux comptant dans `counter2` qu'`engraveColumn`
réutilise). Plus un oubli de branchement : l'IRQ utilisateur doit appeler
`gfxlock.bufferSwap.check`, sans quoi une seule trame est peinte et
`_gfxlock.loop` attend pour toujours. Et surtout une **erreur de conception**
que seule l'exécution pouvait montrer.

**J'avais écrit que le buffer n'avait pas besoin d'être cyclique.** C'est faux.
Le cisaillement se compose de deux termes qui dérivent **ensemble** avec la
caméra : le feed écrit la colonne `n` lignes plus haut (`n` = coutures à gauche
de la colonne, en absolu) et l'entrée du blast porte l'index de couture de la
caméra. Leur **différence** reste petite — c'est ce qui fait tenir l'image —
mais leurs valeurs absolues montent sans fin ; et comme on nourrit des bandes
situées **devant** la caméra, la différence passe à −1 dès que la bande
entrante appartient à la couture suivante. Le banc l'a montré à la première
bande non vide : `engraveColumn` recevait U = $4FF8, soit la ligne −1.

C'est précisément pour cela que le buffer de mscroll est cyclique. **Le cycle
a été remis** (22/08) : `jmp` de rebouclage en fin de buffer, ligne de rangée
prise modulo `BUFFER_LINES`, sortie du blast repliée. La rangée à cheval sur
le bouclage — au plus une par colonne — passe par un chemin lent qui relit les
mêmes octets dans `pscroll.row.data` (émis par le générateur pour ça) et
reboucle ligne à ligne ; le chemin rapide câblé sert tout le reste.

**À trancher avant de le faire tourner** : le blast monte la page du buffer
dans la fenêtre cartouche et y exécute le code ; la **gravure écrit dans cette
même page**, donc le code qui grave ne peut pas vivre dans la fenêtre qu'il
monte. La voie sûre est de rendre les 33 routines et la boucle **résidentes**
(~2 700 o, ce qui tient tout juste dans `stage4.res` une fois l'ancienne passe
retirée), les tables de colonne restant paginées et lues dans un tampon de
30 octets avant le montage. C'est noté en tête du module.

**A3 — Le profil du banc (22/08).** `examples/pscroll/tools/profile_pscroll.py`
attribue les cycles par routine, les frontières venant du `.lwmap` du build.
Mesuré à la caméra 965, 200 trames machine, 65 rendues (16,25 img/s) :

| poste | cy/trame rendue | part |
|---|---|---|
| **le blast** (exécution du buffer) | **54 000** | **88 %** |
| moteur, IRQ, gfxlock, joypad, palette | ~4 200 | 7 % |
| gravure amortie (routines + dispatch + move) | ~700 | 1 % |
| moniteur, divers | ~2 500 | 4 % |
| **total** | **61 397** | 3,07 trames vidéo |

Deux enseignements, et le second commande toute la suite :

1. **Le feed est bien du bruit**, comme la simulation l'annonçait : ~700 cy
   amortis contre les ~990 prédits. Optimiser le dispatch de rangée ou le
   chemin lent de bouclage ne rapporterait rien de mesurable.
2. **Le blast est 88 % de la trame, et il est DÉJÀ à son plancher.** 3,75 cy
   par octet, ce qui est exactement le coût d'un chunk `ldd #/ldx #/pshs d,x`
   (15 cycles pour 4 octets). Il n'y a pas de gras à retirer : le code
   exécuté est du push pur.

**Ce que ça implique pour la phase d'optimisation.** Le seul levier est le
coût par octet du blast, et il n'y a que trois façons de le bouger :

- **la hauteur de bande**, strictement linéaire — 96 lignes au lieu de 180
  donneraient 29 000 cy, soit ~30 img/s ;
- **les chunks de 8 octets** (`pshs d,x,y,u`) : 27 cy pour 8 octets =
  **3,375 cy/o, −10 %** — mais la granularité d'entrée passe à 32 px, ce que
  le débord masqué de ≤ 8 px n'autorise pas en l'état ;
- **le vrai gisement : les registres au lieu des immédiats.** `clearBlast`
  pousse 9 octets à ~1,5 cy/o parce qu'il ne recharge jamais rien. Le motif de
  gommes est périodique horizontalement (3 octets par plan), donc une portion
  UNIFORME de ligne pourrait se pousser en registres seuls — le trou casse la
  périodicité, mais le champ est fait de longues plages pleines et de longues
  plages vides. Un chunk hybride, registres sur les plages uniformes et
  immédiats seulement aux frontières, viserait 1,5 à 2 cy/o là où le champ est
  régulier. C'est un changement de forme du buffer (le feed devrait produire du
  code, pas seulement des immédiats), donc une étude à part entière.

**A4 — Passe d'optimisation : TENTÉE, ANNULÉE (22/08).** Trois pistes de
l'auteur, toutes justes sur le principe :

1. `std ,u` au lieu de `std 1,u` — il suffit de caler U sur l'opérande dès le
   départ. 1 cycle par ligne ;
2. utiliser X pour éviter les rechargements inutiles — les lignes 0 et 1 du
   motif de gomme sont **toujours identiques**, donc la deuxième ligne n'a
   besoin d'aucun `ldd`/`ldx` : 22 cy au lieu de 28 ;
3. graver une **colonne entière** plutôt que des groupes de 6 lignes. Devenu
   possible grâce au biais : une colonne ne peut plus franchir le bouclage,
   donc le test de wrap, le chemin lent ET le recalcul d'adresse par rangée
   (`mul` + deux additions) disparaissent, U se contentant d'avancer.

**Appliquées d'un bloc, elles ont cassé le banc** — le game mode n'était même
plus atteint, la machine restant dans la routine disque du moniteur, alors que
le contrôle `examples/mscroll` bootait sans problème. Tout a été annulé, puis
**repris une par une avec un boot du banc après chacune**. Les quatre étapes
passent :

| étape | contrôle |
|---|---|
| 1. `std ,u` (U calé sur l'opérande) | boote, rendu identique à la référence |
| 2. D/X rechargés seulement s'ils changent | idem |
| 3a. `BUFFER_LINES = BAND + BIAIS` | idem — et corrige un débordement latent : la dernière rangée écrivait jusqu'à la ligne 187 d'un buffer qui en comptait 186 |
| 3b. U qui avance, `rowAddress` supprimée | idem |

**Résultat mesuré** : les postes de gravure — `engraveColumn`, les routines
câblées, `feedBand` — **ont disparu du profil**, passant sous le seuil des
1 000 PC les plus chauds (ils y pesaient 377 + 126 + 126 cy/trame avant). La
cadence passe de 16,25 à **16,50 img/s** ; l'essentiel du gain est invisible
puisqu'il porte sur 1 % de la trame, mais le code est propre et le gras est
parti.

**La leçon de méthode, payée cash** : appliquer trois changements puis tester
coûte le temps de tout défaire ; les appliquer un par un coûte une minute par
aller-retour. Le second est moins cher, toujours.

**A5 — Revue et optimisation du reste du module (22/08).** Profil de départ,
hors blast : `computeStretch` 97 cy/trame, `runBuffer` 44, `do` 39, `move` 21 —
**201 cycles, 0,33 % de la trame**. Le blast en pèse 88 %, et il est à son
plancher. Tout ce qui suit est donc de la qualité de code, sauf le squelette.

| changement | état | gain |
|---|---|---|
| `computeStretch` → **table de paliers** (décision auteur : avancer dans la table comme le HUD dans ses seuils de vie) | **fait, validé** | ~85 cy/trame ; la division par 160 à chaque trame disparaît |
| `buildSkeleton` → **stack blast** | **fait, validé** | l'init passe de ~37 à **21 trames**, mesuré de `main` à la 1re trame rendue (422 615 cy). Le squelette seul : 421 000 → 107 000 |
| variables du module **hors page directe** | **fait** | `dp_extreg` ne réserve que 28 octets et le module en demandait 37 : la 24e variable écrasait la zone temporaire du moteur |
| `runBuffer` : un seul `mul`, sortie dérivée de l'entrée | **annulé** | le rendu changeait ; l'équivalence semble juste sur le papier, la cause reste à trouver. 34 cy en jeu, sur 61 000 — laissé en l'état |
| `do` et `feedBand` : `mod`/`div` par table | **à faire** | ~30 et ~50 cycles, invisibles au profil |

**Le squelette et le checkpoint.** `buildSkeleton` ne sert pas qu'à l'ouverture
du stage : le champ repart à neuf au checkpoint, donc les quatre buffers aussi.
C'est `pscroll.init` qui enchaîne les deux — squelette au stack blast, puis la
gravure des dix colonnes visibles par la routine optimisée — et c'est ce point
d'entrée unique qu'un checkpoint appelle, avec la position de reprise.

**A6 — Cytron et l'« add gum » : la spec et la table (22/08).** Le portage de
cytron se fait **dans le banc** (décision auteur) : c'est là qu'on debuggera la
repousse, et elle valide du même coup le chemin de mutation.

**La spec arcade**, relevée dans les plates Ghidra (`enemy_cytron` : spawner
`0x40696e`, tick `0x4069b4`, draw `0x406a78`). L'étape 5 du tick est la
repousse, et elle confirme mot pour mot ce que l'analyse avait déduit :

> probe the foreground cell at the body's centre ; if it reads exactly
> TILE_EMPTY (0xFA0) overwrite it with the green-ball tile (0x9F6) plus
> attribute 0x0082. **One cell per frame.** […] the exact inverse of
> `erase_green_ball_stage4`. […] a regrown cell is solid again the moment it
> is written […] and Cytron can never grow a ball inside hard terrain.

D'où le contrat de l'« add gum » : **une cellule par trame, seulement si elle
est vide, solide immédiatement**. Le reste du tick (script de mouvement,
`try_foe_fire`, collision, PV depuis la difficulté, mort par script terminé ou
par tir avec récompense `0x86F4` et SFX `0x51`) est hors banc pour l'instant.

**Les ressources sont déjà là** : les 16 images de cytron sont converties dans
`src/enemies/cytron/images/default/`, l'entité est au catalog de
`re.arcade.r-type` (meta-sprite `0x12dd0`, palette `0x2a`, 16 poses,
`frame_duration` 8).

**La table de mutation, écrite et PROUVÉE.** Le feed grave depuis la carte de
build, donc ses 33 combinaisons lui suffisent ; cytron, lui, fait pousser une
gomme **là où il n'y en a jamais eu**, donc un motif absent de la carte peut
apparaître en jeu. La mutation a donc sa propre table, **exhaustive** :

| | |
|---|---|
| index | `((alignement × 64) + motif6) × 24` |
| alignement | `(16m + phase + 2·plan) mod 3` — 3 valeurs |
| motif6 | les 6 cellules qui couvrent le chunk, bit 5 = la plus à gauche |
| taille | 3 × 64 × 6 lignes × 4 o = **4 608 octets** |

*Preuve* : rejouée sur toute la carte réelle contre le modèle pixel direct —
**207 360 octets contrôlés, 0 divergence**. C'est ce qui autorise à écrire le
6809 ensuite.

**`pscroll.setCell` ET LE PILOTE CYTRON : ÉCRITS ET VALIDÉS À L'ÉCRAN.**

`pscroll.setCell` (x = colonne, b = rangée) teste le bit du champ et ne fait
rien s'il est déjà posé — la garde de l'arcade ; sinon il pose la gomme, puis
regrave le ou les chunks touchés (une cellule de 3 px peut être à cheval sur
deux bandes de 16) dans les **quatre buffers** : géométrie lue dans
`chunkbase.tbl`, motif des 6 cellules assemblé bit à bit, 24 octets recopiés
depuis `cell.tbl`. Rend `Z = 1` quand rien n'a changé, ce qui donne au pilote
son compteur de repousses réelles.

Le banc porte maintenant le bitfield en RAM (`level4_ball.bin`, 1 440 o) — le
feed grave depuis la carte de build, la mutation lit et écrit celui-ci.

**La preuve, sur machine.** Cytron rampe le long de la rangée 14, une cellule
par trame. À l'écran, une ligne de gommes traverse tout le champ là où il est
passé, avec le motif exact (période de 3 px, premier sous-pixel transparent).
Et le bitfield le dit au bit près : après 353 trames, partant de la colonne
260, la rangée 14 est pleine **partout sauf le segment 229-259** — celui qu'il
n'a pas encore atteint après avoir fait le tour des 384 colonnes. `260 + 353 ≡
229 (mod 384)`, et `cytron.col` vaut bien 229.

Reste, pour le portage complet de cytron : le script de mouvement bit-packé,
`try_foe_fire`, la collision et les PV, les deux morts — et son sprite, dont
les 16 poses attendent déjà dans `src/enemies/cytron/images/default/`.

**A — Le démonstrateur `examples/pscroll`** (hors du jeu). Ruban horizontal
(cisaillement map-fixe hérité de mscroll), feed de colonne, mutation, **les
deux phases**, sur le vrai champ du stage 4. Oracle au pixel : **la passe
run-blast actuelle sert de référence** — elle est prouvée exacte, c'est ce qui
la rend précieuse avant d'être supprimée. Banc de cycles.
*Acceptation* : image identique à l'oracle **sur les 12 phases de motif et
les deux parités de pixel**, champ intact et champ creusé ; coût mesuré du
blast, du feed et de la mutation. La méthode de contrôle de la campagne
diagonale s'applique telle quelle (`diag_check.py` : écran entier comparé
octet par octet à la source pixel).

**B — L'intégration au stage 4**. La couche remplace `pellet.blast` et prend
l'effacement de sa bande. Les phases 1 et 2 (données, bitfield, primitives,
reset) sont réutilisées telles quelles ; la bande résidente `stage4.res` est
rendue.
*Acceptation* : **mesure sur machine dans la salle, au même point de caméra
(805) et par la même méthode qu'au §2** — attendu ≤ 60 000 cy/trame pour la
couche, ≥ 6 img/s pour le stage. Comparaison de captures avec le rendu
actuel. Le corpus et les sept autres stages inchangés.

**C — Creuser** (la phase 4 du plan d'origine, jamais commencée : `pellet.test`,
`pellet.clear` et `pellet.set` sont exportées et **n'ont aucun appelant**).
Le tir mange une gomme, arrêt franc sur terrain dur, le Force pod efface son
amas, le SFX arcade `0x5E` une fois par trame. **Règle d'écriture : rien ne
part vers les buffers sans être passé par `pellet.test`** — seule une
transition réelle salit un chunk (§6.3). Le bitfield reste la source de
vérité ; les buffers n'en sont qu'un rendu.
*Acceptation* : creuser un tunnel à l'écran et le voir rester ouvert ; mourir
contre une gomme ; **compter les copies de chunks par trame** et vérifier
qu'elles tombent à zéro quand le Force pod stationne dans son trou ; la
cadence ne bouge pas mesurablement en creusant.

**D — Cytron et la repousse** (phase 5), puis **la profondeur par objet**
(phase 6, toujours suspendue à l'arbitrage 0.2 du plan d'origine).

## 9. Points ouverts

- Le coût de gravure initiale (~22 trames, ~430 000 cy, **doublé en 1 px**)
  au **checkpoint** : le champ repart
  à neuf, donc le buffer aussi. À masquer dans la séquence de reprise, ou à
  étaler.
- La granularité du feed : le pic isolé de 9 000 cy tous les 16 px — **18 000
  en 1 px, les deux phases** — tient dans une trame ; s'il gênait, mscroll
  sait déjà l'étaler sur la moitié des lignes (les lignes en retard affichent
  une colonne périmée **au bord masqué**), et les deux phases peuvent être
  nourries en alternance.
- `pscroll` est un nom de travail. Si la couche se généralise (une couche de
  décor mutable persistante n'a rien de spécifique aux gommes), elle a sa
  place dans `engine/graphics/tilemap/` à côté de mscroll, et cette étude
  devient une étude engine.

## 10. La campagne de validation « une gomme à la fois » (23/08/2026)

L'auteur a coupé court à une session de diagnostic qui jugeait le rendu **sur
un champ chargé** : impossible d'y distinguer ce que la repousse écrit de ce
que le feed a déjà peint. Sa consigne — *« valide méthodiquement chaque
routine de dessin, une gomme à la fois, sur un écran vide »* — est devenue
`examples/pscroll/tools/check_gum.py`, et elle a fait tomber **quatre
défauts** dont deux ne concernaient pas la repousse mais le **scroll
lui-même**.

### La méthode

Le banc ne juge plus une capture : il fait la **différence** entre l'écran
d'avant et l'écran d'après **une seule** pose. Ce qui a changé EST ce que
`setCell` a dessiné, quel que soit le fond. Chaque essai compare ces pixels au
modèle de `gen_pellet_tables` (les mêmes `BALL`/`VP_Y` qui ont servi à
engendrer les routines), pose par pose :

- les **seize cas** d'écriture, `(3·colonne − phase) mod 16`, sur seize
  colonnes consécutives ;
- les **deux phases**, en décalant la caméra d'un pixel ;
- le **vertical**, sur les **trente** rangées de la même colonne.

Le calage de l'écran n'est pas supposé : la bordure de toje est symétrique
(16 px et 56 lignes, rendus ×2), donc le pixel BM16 (0,0) est en (32,112) de
la capture — vérifié par la bande peinte, qui occupe exactement 180 lignes.

### Défaut 1 — le champ était peint EN MIROIR VERTICAL

`feedBand` documente que **l'index de ligne du buffer croît vers le HAUT de
l'écran** (le blast descend, S décroissant). Ni le générateur ni le runtime
n'en tenaient compte : les six lignes d'un motif étaient écrites du plus bas
index au plus haut, et les trente rangées dans l'ordre 0→29. Résultat : la
carte s'affichait retournée, rangées ET lignes.

Ça n'avait pas été vu parce que le champ du stage 4 est presque symétrique
verticalement. La mesure, elle, ne s'y trompe pas — corrélation de l'écran
avec la carte, à la meilleure translation :

| modèle | correspondance |
|---|---|
| rangées à l'endroit, lignes à l'endroit | 95,78 % |
| rangées à l'endroit, lignes inversées | 96,25 % |
| rangées inversées, lignes à l'endroit | 98,99 % |
| **rangées inversées, lignes inversées** | **99,70 %** |

Corrigé **dans le générateur** (`DEST` inversé, séquence de rangées émise à
l'envers, `leau` négatif dans les routines d'écriture) : le runtime ne paie
pas un cycle. `setCell` suit la même convention — la rangée `r` est à
`startline + 6·(ROWS−1−r) + 5`, et les routines remontent.

**Ce défaut est celui du feed, pas de la repousse** : tout `pscroll` en
héritait.

### Défaut 2 — la bande descendait d'une ligne

Mesuré `dy = +1` sur les 38 essais, identique pour les deux phases et toutes
les rangées. `pscroll.do` entre le blast à `viewport.ram` et **y peint la
première ligne** : ce paramètre est donc le DÉBUT DE LA DERNIÈRE LIGNE de la
bande, pas l'octet d'après. Le banc passait l'octet d'après. Contrat mesuré,
écrit en commentaire à l'endroit où le projet pose la valeur.

### Défaut 3 — le chunk voisin était à +8 au lieu de −8

96 cellules sur 768 sont à cheval sur deux bandes de 16 px. Les emplacements
du ruban sont rangés **à l'envers** dans la ligne (le chunk `c` peint la
colonne `9−c`), donc la bande suivante de la carte est **8 octets avant**. Le
générateur écrivait `+8` : le troisième pixel de ces cellules atterrissait
deux bandes plus loin. Visible uniquement sur les cas 14 et 15.

### Défaut 4 — écrire hors ruban aliasait ailleurs

Le ruban ne porte que 160 px. Graver une cellule hors fenêtre écrit dans
l'emplacement cyclique d'une **autre** bande : des gommes fantômes
apparaissaient loin du pilote. `setCell` pose désormais le bit du champ
(la carte est la vérité) mais **ne grave que si la bande est dans le
ruban** — le feed la gravera à son entrée. C'est le comportement arcade :
cytron n'écrit jamais au-delà du bord droit.

### Résultat

**36 essais sur 38 exacts au pixel** dès la correction des défauts 1-3, puis
**29 rangées sur 30** au balayage vertical complet. Les seize routines
d'écriture masquée sont donc justes, dans les deux phases, sur toute la
hauteur.

### Séquelle du banc, pas du moteur

`inc $9C05` écrasait le Z que `setCell` venait de poser : le témoin « déjà
pleine » comptait n'importe quoi. Défaut du banc, corrigé — mais il rappelle
que **tout `inc`/`dec` entre un test et son branchement détruit le verdict**.

### Le bouclage de ruban aux 8 px de bord : NORMAL, et hors périmètre

La campagne a relevé que le ruban reboucle sur les pixels de bord quand la
caméra n'est pas alignée sur une bande : 10 chunks de 16 px couvrent
exactement les 160 px de l'écran, sans marge pour le décalage sous-bande, et
`window = (caméra+8)>>4` centre l'erreur au lieu de la supprimer. **Mesure :
au plus 8 px, sur un seul bord à la fois.**

**C'est prévu et ce n'est pas un défaut** (décision auteur, 23/08) : comme
pour mscroll, **8 px à gauche et 8 px à droite sont masqués par un cache noir
posé sur l'image finale de chaque trame**, précisément pour couvrir les
artefacts de scroll. Le cache est plus large que l'artefact — il le recouvre
entièrement. Le cache ne relève pas des routines `pscroll` : il est appliqué
en aval, au compositing de la trame.

Corollaire à retenir pour tout banc : **les 8 px de bord ne se jugent pas**.
`check_gum.py` place ses cibles à l'intérieur, ce qui est déjà le cas.

## 11. La mire, et l'effacement (23/08/2026)

### La mire : un smiley de 32 × 30 cellules

`examples/pscroll/tools/gen_smiley.py` produit un disque de gommes avec deux
yeux et une bouche en creux, que le banc dessine **une rangée par trame** en
appelant `pscroll.setCell` cellule par cellule — 640 gommes par le chemin exact
de la repousse arcade.

Pourquoi un disque et pas un dessin : une cellule fait 3 px sur 6 lignes, et le
pixel BM16 est deux fois plus large que haut — la cellule est donc **carrée à
l'écran**, et le disque doit apparaître **rond**. S'il apparaissait ovale, la
géométrie serait fausse. Les creux, eux, prouvent qu'une cellule vide le reste
au milieu de voisines pleines : un aplat ne dirait rien.

**Résultat : 17 280 sous-pixels comparés au modèle, 0 divergence.**

### L'effacement : les mêmes seize cas

Effacer une gomme, c'est écrire le fond sur ses 3 px : **même géométrie, même
aiguillage `(3·colonne − phase) mod 16`, mêmes masques**. Seule la valeur
change, et elle ne dépend plus de la ligne — l'octet plein ne se recharge donc
qu'une fois, et le `ora` disparaît quand le fond vaut 0.

Le générateur émet les deux jeux depuis **une seule fonction**
(`emettre_cellule`, paramétrée par la valeur du pixel) : les deux chemins ne
peuvent pas diverger. `pscroll.clearCell` partage tout le corps de
`pscroll.setCell` — seuls changent la table de routines et le sens du test de
bit (déjà pleine / déjà vide).

Le masque est ce qui permet d'effacer une gomme **collée à une autre** sans
entamer sa voisine ; le banc l'exige explicitement : après effacement, l'écran
doit redevenir **exactement** celui d'avant la pose.

**Résultat : la mire de 640 gommes s'efface sans laisser un seul pixel allumé.**

### Deux pièges de plus, trouvés par là

**Le blast ne peint pas sa ligne d'entrée.** Il entre à `pscroll.origin` et la
première ligne réellement poussée est `origin+1`. Sans compensation, tout le
champ descend d'une ligne ET la dernière ligne de la rangée 29 tombe hors de la
fenêtre — les deux symptômes disparaissent ensemble. D'où `pscroll.ROW_BIAS =
SEAM_BIAS + 1` : **deux biais, deux rôles** — celui de l'entrée et celui des
rangées. Y toucher d'un seul côté déplace le champ ; des deux côtés ne fait
rien.

**Le blast s'arrête sur une égalité exacte.** `buildSkeleton` écrit le buffer
par blocs de 64 octets (8 × `pshs` de 8) et compare S au début : si la taille
n'est pas un multiple de 64, le `cmps` ne tombe jamais juste, le blast descend
dans le reste de la page et la machine meurt. Ça a d'abord été « corrigé » en
**arrondissant le buffer** au multiple de 4 lignes — 240 octets gâchés par
buffer, 960 sur les quatre. L'auteur a refusé (23/08) : *« tu écris un lot de
moins et tu complètes hors boucle »*. C'est fait — voir plus bas.

### Le banc, désormais

`examples/pscroll` joue au démarrage : mire dessinée → pause → mire effacée.
`tools/check_gum.py` valide **une mutation à la fois sur écran vide**, par
différence d'image, les seize cas d'écriture ET les seize d'effacement, dans
les deux phases et sur les rangées clés. `tools/shot_smiley.py` capture le banc
à un instant précis de son cycle.

## 12. La perf de la mutation, et sa revue (23/08/2026)

### La mesure

`examples/pscroll/tools/profile_gum.py` profile **une rangée de la mire** — 30
mutations dans un tour de boucle, ce qui tient largement dans les ~1 000 PC que
le profileur rend. La mire se rejoue ensuite **au fond du niveau** (caméra 600,
bande 38) sur une zone vide de la carte : c'est là que se juge le coût en
conditions de jeu.

État de départ, par mutation :

| poste | écriture | effacement |
|---|---|---|
| aiguillage (`setCell`/`clearCell`/`mutate`) | 832 | 828 |
| routine de cellule (les 16 câblées) | ~250 | ~250 |

**77 % d'arithmétique pour 23 % d'écriture.** Les routines câblées étaient
saines ; c'est ce qu'il y avait autour qui pesait.

### Les quatre correctifs, un par un, chacun avec son banc

| | ce qui change | aiguillage |
|---|---|---|
| départ | | **828** |
| **A** | la géométrie ne se calcule qu'**une fois** pour les deux phases | **640** |
| **B** | la division par 10 devient une **table** | 645, mais **plat** |
| **C** | l'offset en **deux additions** (deux tables, plus un seul `mul`) | **611** |
| **D** | le champ en **RAM fixe** : plus de page à monter | **599** |

**828 → 599 cycles, −28 %**, et une mutation complète passe de ~1 075 à ~845.

Le détail de chacun :

**A — les deux phases ne diffèrent presque pas.** `n0` vaut `px` puis `px−1` :
le CAS change toujours (c'est `case−1 mod 16`, une soustraction), mais la
bande, la couture, l'emplacement et la ligne ne changent **que si `px` tombe
pile sur un multiple de 16** — une fois sur seize. Tout le bloc était calculé
deux fois pour rien. C'est le gros du gain.

**B — la division par 10 se payait de plus en plus cher.** `chunk mod 10` et
`chunk / 10` se faisaient en retranchant 10 jusqu'à passer dessous : 12 cycles
par dizaine, donc 84 pour la bande 71. La mesure à la caméra 0 le cachait (les
bandes y valent 0 à 3). Mesuré après : **645 cycles à la bande 0 comme à la
bande 38** — le coût ne dépend plus de la position dans le niveau. C'est ça, le
gain de B, pas les 6 cycles du banc à l'origine.

**C — l'offset se sépare.** Il valait `ligne*80 + emplacement + 1` avec
`ligne = BIAIS − couture + 6·(29−rangée) + 5`. Or le terme de **rangée** ne
dépend pas de la bande, le terme de **bande** ne dépend pas de la rangée, et le
biais est une constante d'instruction. Deux tables engendrées avec le reste —
celle des bandes portant déjà l'emplacement **moins** le cisaillement — et
l'offset devient **deux additions**. Plus un seul `mul`.

**D — le champ n'a pas à être paginé.** Il ne fait que 1 440 octets et la
partie de jeu le lit et l'écrit sans arrêt ; le monter à chaque mutation coûtait
un `_SetCartPageA` pour rien. Il vit désormais en RAM fixe dans l'unité (les
tables génériques supprimées y ont fait la place), et le contrat du module le
dit : **le bitfield doit être adressable à l'appel**.

### Ce que la campagne a appris au banc

Deux verdicts « TOUT CONFORME » se sont révélés **vides** : la mire couvrait
toutes les cibles, chaque essai était sauté faute de cellule libre, et le bilan
comptait zéro échec. `check_gum.py` compte désormais les essais sautés et rend
**NON CONCLUANT** dès qu'il y en a un.

Et il ne juge plus que la **bande du champ** (lignes VP_Y..VP_Y+179) : au-dessus,
la ligne d'entrée du blast laisse quelques pixels au bord droit du ruban, qui
clignotent d'une trame à l'autre. Les compter faisait déclarer fausses des
mutations parfaitement justes — 40 essais sur 80, tous à la ligne 10.

Enfin, `TOJE_FAST=1` fait passer la campagne de ~60 minutes à ~3 : mêmes
instructions, mêmes cycles, pas de rendu.

### E — deux bases, zéro `leau` dans les routines de cellule (23/08)

Relevé par l'auteur à la revue : **les routines de cellule n'avaient jamais reçu
l'idiome de la gravure de colonne**. Six lignes espacées de 80 octets se
couvrent avec **deux bases à 240 d'écart** — `u` sur la ligne 1, `x = u−240`
sur la ligne 4 — et des offsets qui ne dépassent jamais ±88, donc tous en
8 bits signés. On paie un octet et un cycle par accès lointain, on économise
**cinq `leau` par plan**.

Le décalage de la base (`u` = ligne 1 et non ligne 0) ne coûte rien : il vit
dans la constante d'addition de `pscroll.geom`.

Compté sur le code émis, ce qui est déterministe :

| | avant | après |
|---|---|---|
| routine d'écriture | 219 cy | **185** |
| routine d'effacement | 203 cy | **169** |

**−34 par appel, −68 par mutation.**

### Le bilan honnête, et une correction

Le poste « routines » rendu par le profileur (247 cy/mutation) était
**sous-compté** : sa liste s'arrête aux ~1 000 PC les plus chauds et le code des
32 routines s'y dilue. Le compte sur le code émis fait foi.

| | aiguillage | 2 × routine | total |
|---|---|---|---|
| départ | 828 | 438 | **1 266** |
| après A-E | 599 | 370 | **969** (écriture) |
| après A-E | 599 | 338 | **937** (effacement) |

**−23 %.** Le poste dominant est désormais `mutate.plans` : poser deux pages et
deux bases coûte 88 cycles par phase, soit 176 des 599. Les quatre pages et les
quatre adresses sont figées après l'init — une table pré-calculée par phase les
ramènerait à deux `ldd`/`std`.

### F — l'entrée de phase, posée à l'init (23/08)

`mutate.plans` relisait `sc.phase` **trois fois** et refaisait l'indexation de
`buf.page`/`buf.address` à chaque fois : 88 cycles par phase, soit 176 des 599
de l'aiguillage — pour aller chercher quatre valeurs qui ne bougent plus depuis
l'init.

`pscroll.buildPhaseTable` (appelée par `pscroll.init`) pose une entrée de six
octets par phase : les deux pages, puis les deux adresses de buffer, **dans
l'ordre où l'interface des routines les attend**. Les deux pages se posent d'un
seul `ldd`/`std` parce qu'elles sont contiguës des deux côtés. L'appelant passe
l'entrée dans X — `sc.phase` et `sc.rout` disparaissent, et la routine du cas
reste dans Y jusqu'au `jmp ,y`.

**599 → 489 cycles.** Bilan depuis le départ, une mutation complète :

| | aiguillage | 2 × routine | total |
|---|---|---|---|
| départ | 828 | 438 | **1 266** |
| après A-F | 489 | 370 | **859** (écriture) |
| après A-F | 489 | 338 | **827** (effacement) |

**−32 %.**


### G — le buffer fait exactement sa taille (23/08)

Le blast écrivait par blocs de 64 octets et s'arrêtait sur une égalité exacte,
donc j'avais **arrondi le buffer** au multiple de 4 lignes. L'auteur a tranché :
c'est de l'espace gâché, on écrit un lot de moins et on complète hors boucle.

Le reste (les chunks que la boucle déroulée ne peut pas couvrir) s'écrit **avant**
la boucle, un par un, et son compteur vit **en mémoire** : les cinq registres
portent le motif, aucun n'est libre — d'où `tst`/`dec` sur une variable plutôt
qu'un `lda`, qui écraserait l'octet d'opcode que porte A.

```asm
        tst   pscroll.blastrem         ; tst et non lda : A porte le motif
        beq   @chunk
@reste  pshs  a,b,x,y,u
        dec   pscroll.blastrem
        bne   @reste
@chunk  pshs  a,b,x,y,u                ; ... x8, puis cmps/bne
```

Le compte est une constante d'assemblage :

```asm
pscroll.BLAST_REM equ pscroll.BUFFER_SIZE/pscroll.CHUNK_SIZE
                      -(pscroll.BUFFER_SIZE/(8*pscroll.CHUNK_SIZE))*8
```

**Impacts, dans l'ordre :**

- `BUFFER_LINES` redevient `BAND_LINES + ROW_BIAS` = **189**, sans arrondi.
  C'est le compte exact : la rangée 29 finit à la ligne `ROW_BIAS + 179` = 188.
- `BUFFER_SIZE` : 15 360 → **15 120 o** (15 123 avec le `jmp` de rebouclage).
  **240 octets rendus par buffer, 960 sur les quatre**, et la marge dans la
  page passe de 1 021 à 1 261 octets.
- L'init est **plus rapide**, pas plus lente : 236 blocs + 2 chunks au lieu de
  240 blocs, soit 240 octets de moins à écrire par buffer. La boucle de reste
  coûte au plus 7 tours d'une vingtaine de cycles, une fois par buffer.
- Le **bouclage cyclique** de `pscroll.do` (`origin + BAND_LINES` comparé à
  `BUFFER_LINES`) n'est toujours jamais franchi : `origin` vaut au plus 8, donc
  188 < 189. Mais le buffer est désormais **exactement juste** — augmenter
  `SEAM_BIAS` ferait boucler pour de bon, et le code du bouclage est là pour ça.
- Validé : banc **80/80 TOUT CONFORME**, et la mire **17 280 sous-pixels,
  0 divergence** — le squelette est bien écrit d'un bout à l'autre.

## 13. Pourquoi 189 lignes et pas 181 (23/08/2026)

Question de l'auteur. Le décompte :

```
180  la bande utile (30 rangées × 6 lignes)
  8  une ligne de BUDGET par couture du niveau  ← le surplus
  1  la ligne d'entrée du blast, jamais peinte
```

Une bande de carte `m` est gravée à `startline = ROW_BIAS − m/10`, où `m/10`
compte les rebouclages du ruban **depuis le début du niveau** : il monte d'une
ligne tous les 160 px, 7 fois pour les 1 152 px du stage 4. Le buffer doit être
assez haut pour que la bande de couture 0 tienne encore ses 180 lignes sous le
budget.

**Ce qui est vivant, lui, tient en 181 lignes** : le ruban ne porte que dix
bandes consécutives, donc `m/10` n'y prend jamais que **deux valeurs
adjacentes**. Le compteur pourrait être pris modulo la hauteur — le buffer est
cyclique, il se termine par un `jmp` vers son début, et les différences
modulaires restent exactes.

**Ce qui l'interdit aujourd'hui** : `engraveColumn` grave une colonne d'un
trait, `leau 6×80` de rangée en rangée. Avec un buffer serré, **une rangée par
colonne tombe à cheval sur le rebouclage** (5 fois sur 6) et les routines
câblées ne savent pas reboucler — elles écrivent six lignes en aveugle depuis
deux bases fixes. Il faut alors le chemin lent, ligne à ligne, avec la table de
données que la conception d'origine avait prévue (`row.data`, 792 o).

**Le calcul du gain, fait avant d'écrire quoi que ce soit :**

| | |
|---|---|
| rendu par le passage au modulo | 8 lignes × 80 o × 4 buffers = **2 560 o** |
| coût | 792 o de table (dans l'unité) + le chemin lent |
| **où atterrissent les 2 560 o** | dans les quatre pages de buffer — **et rien d'autre ne peut y vivre** |

Une page de buffer n'est montée que pendant les opérations de pscroll : la
place qu'on y libère est **morte**. Le gain en octets est donc cosmétique. Le
vrai prix, c'est le **plafond de largeur** : `startline` devient négatif dès que
les coutures dépassent le budget, en silence.

### Les trois conceptions, chiffrées — et le verdict

L'auteur a corrigé une erreur de ma part : la place libérée dans une page de
buffer **n'est pas morte**, le packer v2 sait y couler des objets (arènes,
`<pageset>`). Le critère devient donc franchement la performance, à place
comparable. Et en refaisant le calcul sous cet angle, une variante m'était
apparue que je n'avais pas vue :

| | buffer | slack/page | vitesse |
|---|---|---|---|
| **A — budget** (aujourd'hui) | 15 120 o | **1 264 o** | référence |
| **B — modulo + double appel** | 15 280 o | 1 104 o | plus lente |
| **C — modulo + chemin lent** | 14 480 o | 1 904 o (+2 560 o au total, −792 o de table) | +3 % mutation, +23 % pic de feed |

**B** évite tout chemin lent : la rangée à cheval appelle sa routine **deux
fois**, à `base` puis à `base − BUFFER_SIZE`, et les moitiés hors buffer
tombent dans un scratch pris sur le slack de la page. Mais il faut 5 lignes de
débordement **de chaque côté**, soit dix — quand le budget de A n'en coûte que
huit. B est donc plus grosse ET plus lente : éliminée.

**Le point qui décide** : les huit lignes de budget de A ne sont pas du
gâchis, ce sont **huit lignes qui remplacent les dix lignes de scratch de B**.
Le budget grandit avec le niveau (une ligne par 160 px), le scratch non — le
**croisement est à ~1 600 px de carte**. Le stage 4 en fait 1 152.

**Verdict de l'auteur (23/08) : A**, pas de niveau plus long au programme. A
est ici la plus rapide *et* la plus compacte ; C ne se justifierait que si ses
1 768 o nets manquaient ailleurs, au prix des +23 % de pic de feed.

**Ce qui est fait** — le plafond devient explicite au lieu d'être implicite :

- `SEAM_BIAS` dérive de `pscroll.MAX_SEAMS`, que le projet déclare ;
- deux `ERROR` d'assemblage, parce que les deux se franchissent en silence :
  le buffer qui déborde de sa page, et le budget trop court pour
  `pscroll.MAP_WIDTH`. Vérifié : déclarer une carte de 3 000 px fait échouer
  l'assemblage avec le bon message.

Le budget grandit donc avec le niveau, jusqu'à ~2 900 px où le buffer remplit sa
page. Au-delà, le modulo devient obligatoire.

### Et mscroll ? Non, ce n'est pas la même cause

`mscroll` **prend déjà le modulo** — son curseur cyclique porte l'index de
couture de la caméra et se replie sur `BUFFER_LINES` (`cmpd`/`subd` à chaque
avance). Il peut se le permettre parce qu'il grave **par rangée**, ligne à
ligne (`copyBitmap`) : le rebouclage est un test de curseur, pas un cas
particulier. C'est pscroll qui est prisonnier de ses routines câblées — la
vitesse se paie là.

Sa limite de **2 048 px de large** a une tout autre origine : le stride d'une
rangée de carte est une **puissance de deux** pour qu'une adresse de rangée soit
un décalage et non une multiplication (héritage de vscroll v1, le générateur
padde la largeur), et les données doivent tenir dans une page de 16 Ko.

## 14. Cytron dans le banc (23/08/2026)

Le pilote du banc n'était qu'une trajectoire écrite à la main. Il joue
désormais **le script arcade**, et la source de vérité a corrigé deux points de
la fiche Ghidra.

### Ce que la plate dit, et ce que le code fait

**« la cellule sous le centre du corps »** — non. `run_cytron` (0x40:69B4) lit
un couple `(dx,dy)` dans une table **indexée par la POSE** (0x1000:2D90), l'ajoute
à la position, sonde là, puis restaure. Cette table est un **cercle de rayon
12 px arcade sur seize directions** : cytron sème sa gomme **derrière lui**,
dans l'axe de sa pose. C'est ce qui lui fait laisser une traînée plutôt qu'un
point.

**« 4-entry table »** pour le choix du script — non plus. L'index vaut
`(CL & 0xF0) >> 2`, soit 0 à 60 avec un pas de 4 : **seize variantes**. Le
stage 4 fait naître 38 cytrons et en emploie **neuf distinctes**.

### La géométrie se recoupe exactement

1 tuile arcade = **1 cellule de gomme**, et ce n'est pas une approximation :
8 px arcade × 0,375 = 3 px larges en X, 8 × 0,75 = 6 lignes en Y — la
géométrie d'une cellule, au pixel. Le compte des tuiles le confirme de son
côté : la carte arcade porte 1 618 tuiles `0x9F6`, et le bitfield du stage 4
en porte 1 618.

### L'export, pas la recopie

`re.arcade.r-type` savait décoder le format (`MoveByScript`) mais rien ne
l'appelait. Il a désormais `--extract-movescript` : il part de la table de
variantes, suit chaque commande, collecte les segments atteints et émet le tout
en données assemblables étiquetées par offset ROM. Sortie :
`src/enemies/cytron/movescript.asm`, 1 645 lignes, **rejouable**.

### Ce que le banc porte, et ce qu'il ne porte pas

Porté : le script bit-packé (décodé en unités de **cellule**, la langue du
champ — 1 px arcade = 1/8 de cellule), le décalage de repousse par pose, et la
sonde d'une cellule par trame qui n'écrit que si elle est vide.

Hors banc, faute de joueur et de gestionnaire d'objets : `try_foe_fire`, la
collision, les PV et les deux morts. Une déviation assumée : quand le script se
termine, l'arcade décharge l'objet (0x6A42) — le banc le fait repartir, sinon
la mire s'arrête et ne montre plus rien.

### Vérifié

Caméra figée à 541, cytron lâché à la cellule 200 rangée 15 : après 400 trames
il est à **189,50** (26 segments de `x--`, 3 octets par trame = 0,375 cellule
par tour ✓), pose **8**, et la cellule semée est la **191** — soit 1,5 cellule
**à sa droite** alors qu'il rampe vers la gauche : bien derrière lui. La traînée
mesurée à l'écran couvre les cellules 189 à 202 sur la **rangée 15**. Le banc de
mutation reste à **80/80**.

## 15. Qui détruit les gommes — la cartographie arcade (23/08/2026)

Relevée par Ghidra (MCP `asm-ark`). **Trois routines**, et rien d'autre n'écrit
dans le champ : toute suppression passe par l'une des trois.

| routine | arcade | forme effacée |
|---|---|---|
| `erase_green_ball_stage4` | 0x40:4FB9 | **une cellule** |
| `clear_green_ball_helper_stage4` | 0x40:2736 | **une grappe 2×2** |
| `clear_green_ball_stage4` | 0x40:2702 | **quatre grappes 2×2 aux quatre coins** (±8,±8) — un bloc de 4×4 avec recouvrement |

Les trois ne réécrivent que les cellules qui lisent exactement
`TILE_GREEN_BALL` (0x9F6), et incrémentent `pickup_pending_flag` par cellule
effacée — dont le seul lecteur est l'IRQ, qui joue le SFX 0x5E. **Manger des
gommes fait du bruit, ça ne marque pas de points.**

### Qui appelle quoi

| arme / objet | routine | quand | forme réelle |
|---|---|---|---|
| **Force Pod** — flottant, attaché, éjecté (0x2534, 0x259F, 0x262F) | 4×4 | **chaque trame**, dans ses trois états | un bloc de 4×4 centré sur le pod |
| **Wave Cannon**, allumage (0x3168..0x3180) | 2×2 ×4 | à la naissance du tir | quatre grappes |
| **Wave Cannon**, en vol (0x323B) | 2×2 × CX | chaque trame | **une bande de 2 rangées sur CX+1 colonnes** — CX = 5 à 10 selon le palier de charge (table 0x1000:183E), et le palier décroît d'une trame à l'autre : le tunnel se referme |
| **Counter-Air Laser** (0x4A36..0x4A80, 0x4B65..0x4BAF, 0x4CB4) | 4×4 × 11 | **une trame sur seize** (`anim_phase == 0`) | une grille : colonne de 3, puis 3 latérales, puis une queue de 4 — **176 cellules balayées d'un coup** |
| **Bit Device** (0x2E8E, 0x304F) | 2×2 | par trame | une grappe |
| **Laser réfléchi** (0x4E6B) | 2×2 | par trame | une grappe |
| **Missiles** haut et bas (0x3414, 0x35CC, 0x36E0, 0x3896) | 1 cellule | à l'impact | unitaire |
| **Force Pod, tir simple** (0x3EE4, 0x4F52, 0x4F78) | 1 cellule | à l'impact | unitaire — et il **meurt sur la première gomme** : l'effaceur rend 0, que l'appelant relit comme « mur » |

**Donc : l'ajout est unitaire (cytron), la suppression ne l'est pas.** Le pire
cas est le Counter-Air Laser, 176 cellules dans une seule trame, et le Force Pod
qui efface 16 cellules à **chaque** trame tant qu'il traverse le champ.

### Le test de contournement n'est PAS assez rapide

`pscroll.setCell` rejette une cellule déjà pleine après avoir calculé le px de
carte, la bande, la garde de ruban, le pointeur de rangée et le masque du bit :
**≈ 185 cycles pour ne rien faire**. Compté sur le source, chemin de rejet le
plus court.

Ce que ça donne appliqué à la cartographie :

| cas | cellules | coût de rejet seul |
|---|---|---|
| Force Pod, une trame | 16 | ~3 000 cy |
| Wave Cannon, une trame au palier max | 22 | ~4 100 cy |
| **Counter-Air Laser, sa trame** | **176** | **~32 600 cy — plus d'une trame et demie** |

**Conclusion : la suppression ne peut pas passer par un appel par cellule.** Il
faut une routine de BLOC qui travaille par OCTET du bitfield :

- un bloc de 4×4 cellules, c'est **4 bits de large sur 4 rangées** — donc au
  plus **deux octets par rangée**, soit 4 à 8 lectures-modifications au lieu de
  16 tests ;
- le masque dit d'un coup ce qui change : `change = ancien AND masque`. Si
  `change` est nul, la rangée n'a rien à regraver — **le contournement devient
  un test par RANGÉE, pas par cellule** ;
- et seules les colonnes touchées ont besoin d'une regravure de buffer, ce que
  `change` donne directement.

C'est le même raisonnement que pour le feed : **le champ se parle en octets, pas
en cellules**. Reste à écrire la routine et à la prouver comme les autres.

### La portée de chaque arme — ce qui dimensionne vraiment

Vérifié dans le code, arme par arme :

| arme | efface | portée |
|---|---|---|
| **Force Pod** (le corps) | 4×4 | **infinie** — il n'est jamais détruit, il laboure tant qu'il traverse |
| **Wave Cannon** | bande 2 × (CX+1) | **traverse** : une cellule effacée devient passable, il ne meurt que sur le terrain dur. Son palier décroît d'une trame à l'autre, donc le tunnel se referme derrière lui |
| **Counter-Air Laser** | 11 × 4×4, une trame sur seize | ses seize trames d'animation, puis la queue de fade |
| **Counter-Air, réflexion** | 2×2 | sa propre durée |
| **Bit Device** | 2×2 | **infinie** — satellite permanent |
| **Missile haut / bas** | **1 cellule** | **meurt sur la première gomme** |
| **Tir simple du pod** | **1 cellule** | **meurt sur la première gomme** |
| Rebound laser, ground laser, horizontal laser | **rien** | ils n'effacent pas — le champ les arrête |

**Les deux « meurt sur la première gomme » sont un accident de code**, et le même
dans les deux cas :

```asm
        call  probe_foreground_and_background_tiles
        cmp   AX, 0x9f6                ; une gomme ?
        jnz   skip
        call  erase_green_ball_stage4  ; elle rend AX = 0
skip:   cmp   AX, 0xdfc
        jnc   keep_flying              ; >= seuil : passable
        jmp   explode                  ; < seuil : solide → explose
```

L'effaceur fait `XOR AX,AX` avant de rendre la main : l'appelant relit **0**,
donc « en dessous du seuil de solidité », donc **mur**, et il explose sur la
gomme qu'il vient de manger.

**Trois conséquences pour la conception :**

1. **Le régime unitaire est négligeable.** Missiles et tir simple effacent une
   seule cellule dans toute leur vie : `er.NN` suffit, rien à optimiser.
2. **Trois armes seulement dimensionnent le régime long** — Force Pod, Wave
   Cannon, Counter-Air Laser. C'est sur elles que la routine déroulée se taille.
3. **Il faudra reproduire « meurt sur la première gomme » EXPLICITEMENT** : chez
   nous la mutation rend un `Z` propre, pas un faux « mur ». L'oublier ferait
   traverser missiles et tir simple — un changement de gameplay silencieux,
   exactement ce que le double banc doit attraper.

### Décision : le module calcule le rectangle

Arbitrage auteur (23/08). Les armes passent un départ et une arrivée ; le module
en tire l'escalier exact (un intervalle par rangée), retranche le hors-carte et
le hors-ruban, puis choisit le régime. Les armes ne portent pas de géométrie de
grille.

## 16. `clearRect` — l'effacement en masse (23/08/2026)

### Ce qui est écrit et prouvé

`pscroll.clearRect` prend un **départ**, une **arrivée** et la **taille du bloc**,
et efface la surface balayée. C'est le module qui fait la géométrie : les armes
ne portent pas de grille.

Trois chemins, dont deux spécialisés parce que ce sont ceux du jeu :

- **horizontal** (`r0 == r1`) — le Force Pod et le Wave Cannon : toutes les
  rangées du bloc partagent le même intervalle, aucun parcours de segment ;
- **vertical** (`c0 == c1`) — une seule colonne d'intervalle sur toutes les
  rangées balayées ;
- **oblique** — l'escalier exact, un intervalle par rangée. Le squelette est
  écrit, il n'est pas branché : aucune arme du stage 4 n'en a besoin
  aujourd'hui.

`pscroll.clearRow` borne ensuite sur la carte **et sur le ruban** — une cellule
hors fenêtre n'est pas dans le buffer, l'y effacer poserait un bit que rien
n'affiche, exactement le défaut corrigé sur `setCell`.

**Prouvé sur machine** (`tools/check_rect.py`, cinq cas, chacun sur une mire
fraîche) : la différence à l'écran est **exactement** l'intersection de la
surface balayée et de la mire — ni gomme voisine mangée, ni gomme oubliée dans
le couloir. Le cas qui déborde à gauche de la carte n'efface rien et ne plante
pas.

### Mesuré

| cas | cellules | `clearRect` | mutation | total |
|---|---|---|---|---|
| bloc 4×4 seul | 16 | 655 cy | 1 723 | 148 cy/cellule |
| 4×4 balayé de 6 (l'union d'une trame) | 40 | 2 045 | 13 221 | 381 |
| bande du beam, 2×12 | 24 | 1 494 | 9 870 | 473 |

La géométrie coûte ~50 cycles par cellule ; **tout le reste est la mutation par
cellule**, et c'est elle que le déroulé doit remplacer.

### Le déroulé, branché (23/08)

`gen_pscroll.py` émet `pscroll.zrow` — dix blocs de douze `std`, trois bases
(X, Y, U) pour six lignes, offsets 8 bits, **360 octets** — plus la table
d'entrée par emplacement de ruban et `pscroll.chunkfirst.tbl` (la première
cellule de chaque bande, pour borner sans division).

L'aiguillage fait quatre choses :

1. Il trouve les bandes **entièrement** couvertes par l'intervalle — une bande
   porte six cellules, elle n'est pleine que si le run la couvre toute. Les deux
   extrémités restent par cellule.
2. **Il coupe le run aux coutures.** Le cisaillement décale d'une ligne les
   bandes situées après une couture : deux bandes d'un même run n'y sont plus
   sur les mêmes lignes de buffer, et la séquence déroulée suppose le contraire.
   Le ruban ne portant que dix bandes, un run en traverse au plus une —
   `seamof` donne le groupe, `seamlast` sa dernière bande, et l'emplacement de
   ruban s'en déduit **sans modulo** : `slot(m) = seamlast[couture(m)] − m`.
3. Il efface les bits de carte du groupe **par masques d'octet** — et c'est là
   qu'est le contournement : si aucun bit ne change, on ne regrave rien.
4. Il entre dans `pscroll.zrow` sur la première bande et **patche un `rts`**
   après la dernière, exactement comme `pscroll.do` patche la sortie du blast.

**Prouvé identique** : les cinq cas de `check_rect.py` rendent les mêmes pixels
qu'avec le chemin par cellule — c'est l'A/B qu'il fallait.

### Mesurer : deux instruments faux avant le bon

Trois pièges se sont succédé, et chacun a produit des chiffres crédibles.

**Le champ.** Une cellule déjà vide ne coûte que son rejet. La mire maigrissait
de cas en cas — 9 600 pixels, puis 9 360, puis 9 090 — et redessiner ne la
restaurait pas. La cause n'était pas le banc mais un défaut de `clearRow.zone` :

```
        coma                           ; A = ~masque, la valeur voulue
        andb  ,x+                      ; B = octet & octet — sans effet
        stb   -1,x                     ; la carte est reecrite INCHANGEE
```

La 6809 ne sait pas croiser A et B : le complément doit passer par la mémoire
(`pshs a` / `andb ,s+`). **Les bits de carte des bandes pleines n'étaient jamais
effacés** — les pixels partaient, le bitfield disait toujours « pleine », et
`setCell` refusait de faire repousser. `check_rect` ne pouvait pas le voir : il
compare des PIXELS, et les pixels étaient justes. La mire qui revient à
l'identique est un oracle plus fort, parce qu'elle passe par la carte.

**Les plages de PC.** Le profil sommait les cycles des PC compris entre
`pscroll.setCell` et `pscroll.tbl.bit`. Or les routines d'écriture générées
vivent à `$7750` et `$7E00`, et la séquence déroulée à `$8492` : **on ne
mesurait que l'aiguillage**, et une bande pleine paraissait presque gratuite.
Pire, `profile_top` plafonne à mille lignes et le code déroulé en fait
davantage, donc le total était tronqué — variablement d'une version à l'autre.

**Les trames fixes.** Mesurer `total_cycles` sur un nombre de trames fixe, avec
et sans effacement, donne zéro : le 6809 consomme le même temps qu'il travaille
ou qu'il attende.

**Ce qui marche** : encadrer l'appel. On court jusqu'à l'entrée de `clearRect`,
on lit son adresse de retour sur la pile, on profile jusqu'à elle. `total_cycles`
ne compte alors que l'effacement, sans plage à deviner ni troncature. Et chaque
cas compte en plus les pixels réellement effacés — deux versions ne se comparent
qu'à effacement égal.

### L'aiguillage en lot, mesuré

L'aiguillage recalculait par cellule quatre choses qui ne bougent pas dans un
lot : le pointeur de carte de la rangée, la base de ligne, le px de carte (qui
n'avance que de 3), et la géométrie de bande — alors que la bande ne change
qu'une cellule sur cinq. La queue de `mutate` est devenue `mutate.tail`,
appelable en lot, avec `sc.lastchunk` qui évite le `geom` redondant.

À effacement strictement égal (240, 540, 270 et 603 pixels) :

| cas | avant | après | |
|---|---|---|---|
| bloc 4×4 seul | 942 | **852** | −10 % |
| 4×4 balayé de 6 | 611 | **572** | −6 % |
| bande beam 2×12 | 228 | **222** | −3 % |
| bande large 2×24 | 230 | **219** | −5 % |

**C'est un gain modeste, et il faut le dire** : l'instrument cassé annonçait
−44 % et −76 % sur les deux bandes. La part hoistée ne pesait qu'une fraction de
l'aiguillage, lui-même une fraction du total.

Ce que la mesure fiable montre en revanche, c'est **où est le problème** : le
bloc 4×4 isolé coûte 13 636 cycles, soit **les deux tiers d'une trame** à
19 954 cycles. Les runs longs, eux, tiennent à ~220 cycles par case — le déroulé
y fait son travail.

### Ce que coûtent les extrémités, et ce qu'un masque n'y changerait pas

Le déroulé gagne un facteur 4 à 5 sur les runs longs, mais la bande beam dit où
part le reste, par rangée : ~576 cycles pour les deux bandes pleines déroulées
sur les quatre buffers, et **~1 168 pour les deux seules cellules d'extrémité**.

J'ai d'abord proposé d'y passer une variante MASQUÉE de `zrow`. **C'était faux
par excès**, et la raison est géométrique. Une gomme fait 3 px larges, un octet
en fait 2 : une cellule ne pave jamais des octets.

```
px      0   1 | 2   3 | 4   5 | 6   7 |
octet   |  o0   |  o1   |  o2   |  o3  |   (pairs -> plan A, impairs -> plan B)
cellule |   c0      |   c1      |   c2 |
```

Chaque cellule possède **un octet plein dans un plan et un demi-octet dans
l'autre**, et deux voisines partagent toujours cet octet — d'où les deux passes
`full` (un `sta` sec) et `mask` (`lda`/`anda`/`ora`/`sta`) des routines
générées. **Le read-modify-write est déjà là, une fois par cellule, par
construction.** Le masque n'est donc pas une idée neuve à ajouter aux bords :
c'est le régime normal.

Ce qui coince aux bords est une affaire de granularité. Une bande porte 4 octets
de données par plan, soit 16 px sur les deux, soit **5⅓ cellules** : une
frontière de bande ne tombe sur une frontière de cellule qu'une fois sur trois
(px 16c multiple de 3 ⟺ c multiple de 3), ce que dit `chunkfirst.tbl` — 0, 6,
11, 16. Écraser une bande de bord en bloc mangerait jusqu'à cinq gommes
voisines ; la masquer entière coûterait quatre `lda/anda/sta` par ligne et par
plan, soit ~1 200 cycles pour remplacer les ~1 750 des trois cellules qu'elle
porte. **30 %, pas le facteur douze annoncé.**

Le vrai gras est ailleurs. Une mutation se découpe en **489 cycles d'aiguillage**
(rangée, cellule, bande, slot, tables, montages de page) et **338 d'écriture**
pour les quatre buffers. `clearRect` en amortit déjà une part — 584 mesurés au
lieu de 827 — mais il refait l'essentiel de l'aiguillage à CHAQUE cellule de
bord, alors que ces trois à cinq cellules sont contiguës, sur la même rangée,
dans les mêmes pages, avec les mêmes bases de ligne. Un aiguillage pour le lot
puis N fois la seule routine d'écriture donnerait le même ~30 %, en réutilisant
les routines masquées existantes telles quelles.

### Le run de quatre : les octets partagés partent en entier

Une gomme fait 3 px larges, un octet en fait 2 : deux voisines **partagent
toujours un octet**. Effacées une par une, cet octet se fait masquer deux fois —
une fois par chacune, chaque fois pour préserver la moitié de l'autre — alors
que dans un run il part en entier. Sur quatre cellules, les 24 écritures
masquées d'un plan tombent à 4, et il ne reste qu'un aiguillage au lieu de
quatre.

Seize routines, une par cas `(3c − phase) mod 16`, **deux entrées chacune, une
par plan**. Trois choix de forme, tous imposés par la mesure ou par la place :

- **bouclées sur les six lignes, pas déroulées.** Le déroulé pesait 992
  instructions (~2,4 Ko) et la page du banc était pleine à 129 octets près. La
  base recule de 80 par tour, ce qui a deux vertus : le code n'existe qu'en un
  exemplaire, et les offsets retombent dans −8..+4 — de l'indexé 5 bits, un
  octet et un cycle de moins que les 8 bits du déroulé. Le prix est de 10
  cycles par ligne et par plan, soit ~240 sur un run qui en économise des
  milliers.
- **le montage de page est sorti** dans `pscroll.run.plans` : répété seize
  fois, il pesait plus que les écritures elles-mêmes (472 instructions contre
  264 une fois sorti).
- **les octets pleins voisins partent en `std`** dans les plans sans masque, où
  A reste à zéro d'un tour à l'autre : 264 → 240 instructions, ~560 octets.

`clearRun4` vérifie que les deux bandes du run sont dans le ruban et du même
côté d'une couture (sans quoi le décalage VOISIN de −8 ne veut plus rien dire),
efface les quatre bits, puis appelle `mutate.tail` — **la seule différence avec
une mutation ordinaire est la table de routines**. Sinon il refuse et
l'appelant reprend cellule par cellule.

À effacement strictement égal (240, 540, 270, 603 pixels) :

| cas | avant | après | |
|---|---|---|---|
| **bloc 4×4 seul** | 13 636 | **9 540** | **−30 %** |
| 4×4 balayé de 6 | 22 894 | 23 086 | — |
| bande beam 2×12 | 5 349 | 5 367 | — |
| bande large 2×24 | 10 517 | 10 571 | — |

Le bloc isolé passe des deux tiers d'une trame à moins de la moitié.

### Le run de cinq, et le cas que le banc n'exerçait pas

Les autres cas n'ont pas bougé, et j'ai d'abord cru que le « balayé de six »
faisait des runs de cinq. **Faux** : balayer un bloc de 4 sur 6 cellules donne
une union de DIX cellules par rangée — au-dessus du seuil, donc chemin déroulé.

Le vrai producteur de runs de cinq est le bloc balayé d'**une** cellule, c'est-à-dire
la compensation de frame-drop réelle : 4 + 1. Le banc ne l'exerçait pas ; le cas
a été ajouté aux deux vérificateurs. `emettre_run` était déjà paramétré par la
longueur, et l'aiguillage lit désormais `pscroll.run.n` (la table de routines se
choisit par `run.n − 4`).

| cas | sans run de 5 | avec | |
|---|---|---|---|
| **4×4 balayé de 1** | 15 622 | **10 532** | **−33 %** |
| bloc 4×4 seul | 9 540 | 9 760 | **+2 %** |

Le bloc de quatre paie 220 cycles de plus : l'aiguillage généralisé calcule
`3n − 1` par une multiplication et passe par une table au lieu de constantes.
C'est le prix du second cas, il est assumé — 5 090 cycles gagnés contre 220
perdus.

### Deux pièges rencontrés en chemin

**La rangée voyage dans B.** Poser `sc.plans` dans `setCell`/`clearCell` par un
`ldd` écrasait B **avant** le `stb pscroll.sc.row` de `mutate` : toutes les
mutations tombaient sur la même rangée. La mire se croyait déjà pleine et plus
rien ne s'effaçait. Le store est descendu après la mise à l'abri des registres.

**Un vérificateur peut passer sans rien vérifier.** `check_rect` a affiché
« TOUT CONFORME » sur cinq cas alors que le banc ne démarrait plus et
qu'AUCUN pixel n'était effacé : son modèle dérive les pixels attendus de la
mire, mire absente donne un ensemble vide, l'effacement rend le même, et
l'égalité passe. C'est le mode de panne déjà rencontré sur `check_gum`. Il
compare désormais le champ avant chaque cas à celui du premier, et refuse de
conclure sur un écran vide — un cas peut légitimement n'attendre aucun pixel
(hors carte), mais pas sur un champ différent. Le garde a été vérifié en le
faisant mordre, pas supposé.

**La page du banc, et un garde qui manque au builder.** Le module est une page
de 16 Ko chargée à `$6100` dans la fenêtre `$6000-$9FFF` : seuls **16 128
octets** sont utilisables, mais le builder valide contre 16 384 — la taille de
la page — sans tenir compte de l'adresse de chargement. Il a donc accepté un
direntry de 16 384 octets qui débordait de 252 octets au-delà de `$A000`, et
l'image bootait sur du vide. **Le garde devrait porter sur adresse + taille
contre la fin de la région.**

La place a été faite en passant le **script arcade** de cytron derrière
`BENCH_CYTRON` (l'objet complet vit dans `games/r-type`). Attention : la SONDE
du pilote reste, elle — c'est par elle que `check_gum` injecte ses mutations.

### Le banc de démonstration : le vrai champ, les vraies armes, chaque trame jugée

`examples/pscroll/tools/demo_gommes.py` joue le champ RÉEL du stage 4 qui
défile à la vitesse du jeu ($0030, 0,5 px arcade/trame), traversé par chaque
arme une à la fois, aux vitesses et empreintes relevées dans la ROM. Pendant
les arrêts, chaque trame rendue est comparée au modèle (champ + caméra + motif
de gomme, avec les MÊMES bornes de ruban que le moteur) ; pendant le scroll, à
l'entrée et à la sortie de la phase. La vidéo est assemblée depuis les
screenshots des trames jouées — elle montre exactement ce qui a été validé.

Le banc a payé immédiatement : quatre défauts réels, dont deux du moteur.

1. **`bench.rect` tombait AVANT l'exécution.** Un effacement qui déborde de la
   trame laissait le pilote extérieur croire le travail fini, écrire le rect
   suivant et écraser les variables du rect en vol — 4 des 11 blocs du
   counter-air se perdaient. Le témoin ne tombe plus qu'après le `jsr` ; idem
   pour la sonde. (Au passage : les états « figés » lus pendant le débogage
   étaient des instantanés à mi-course, pas des crashes — `run_frames` rend la
   main au vblank, où qu'en soit le 6809.)
2. **La couture, pour les DEUX phases.** `clearRun` vérifiait que les bandes du
   run étaient du même côté d'une couture — pour la phase 0. La phase 1 écrit
   en px−1 : un run qui commence pile sur un multiple de 16 a sa première
   bande de phase 1 de L'AUTRE CÔTÉ, et la routine déroulée écrivait une ligne
   à côté : 48 px résiduels dans le buffer, qui défilaient avec la carte. Les
   vérificateurs à caméra 0 ne pouvaient pas le voir — leurs coutures étaient
   hors de l'écran. Le refus couvre désormais les deux phases.
3. **La latence du pipeline.** Une mutation décidée au tour T est dessinée par
   le `do` de T+1 dans le tampon arrière, flippé en fin de T+1 : l'écran la
   montre à T+2. Toute validation qui suit une mutation attend deux trames.
4. **`edge16` est un octet** : lu en mot par le modèle Python, la borne de
   ruban devenait infranchissable et le modèle n'effaçait plus rien.

### Le décalage d'une ligne aux coutures — RÉSOLU

Les 48 px résiduels de la démo n'étaient que la queue d'un défaut bien plus
gros : **le plan de gommes s'affichait une ligne trop bas sur les huit derniers
pixels de caméra avant une couture**. Sonde : `tools/probe_couture.py`.

**La cause.** L'index d'une bande vaut `(camera + 8) / 16` — le `+8` centre la
fenêtre de 16 px. Son groupe de couture, donc le `startline` que `feedBand`
grave, change donc quand **`camera + 8`** franchit un multiple de 160. Mais
`move` comparait **`camera.x` nue** aux seuils de `seam.tbl` : `origin` sautait
huit pixels trop tard, et pendant ces huit pixels le blast entrait une ligne à
côté des bandes gravées. Correctif : une variable `pscroll.seamx = camera.x + 8`,
tenue à jour avec la caméra, et c'est elle qu'on compare aux seuils — dans
`move` comme dans `seamFind`.

**Ce qui a permis de le trouver** — l'instrumentation, pas le raisonnement. Un
journal de gravure derrière `PSCROLL_DEBUG` (`dbg.startline`, `dbg.fed`,
`dbg.cam` par bande ; `dbg.entry` et les valeurs vues par `do`) a montré du
premier coup que **le ruban était identique à la caméra fautive et à la caméra
saine** — mêmes bandes, mêmes `startline`, aucune regravure. Le feed était
innocenté, la faute était côté affichage.

**Un piège de lecture, et un faux coupable.** `do` s'exécute AVANT `move` : les
variables relues après la trame ne sont pas celles qui ont peint. C'est en
capturant `h`, `window` et `origin` *à l'instant où `do` les lit* que le
mécanisme est apparu — et il a d'abord désigné le mauvais coupable :

```
@mod    cmpb  #10
        blo   @modok
@modok  beq   >          ; teste les flags du CMPB, pas la nullite de B
```

Un `window` multiple de 10 laisse `b = 0`, mais `Z` porte le `cmpb #10` : le
`beq` n'est pas pris, et `h` vaut **10** au lieu de 0. Ça ressemble à un bug —
c'en est un dans la forme, mais **le résultat est celui qu'il faut** : `h*8 = 80`,
soit une ligne entière, et cette ligne est exactement le débordement de la
rotation (colonne 80 = colonne 0 de la ligne suivante) qui compense le biais
d'une ligne du blast. « Corriger » ce `beq` par un `tstb` casse l'affichage —
essayé, mesuré, annulé. Le commentaire du code le dit désormais.

**Vérifié** : six coutures balayées caméra par caméra (320, 480, 640, 800, 960,
1120), **aucune caméra fautive**. `check_gum` 80/80, `check_rect` 10/10.

### Ce que la chasse a séparé — et les 48 px, toujours ouverts

Deux choses se cachaient derrière « 48 px résiduels », et il a fallu corriger
la première pour voir la seconde.

**Mon modèle sur-effaçait.** `model_clear` bornait le ruban cellule par
cellule ; `pscroll.rect.prep`, lui, borne à la BANDE — il remonte le début à
`chunkfirst[edge16]` et descend la fin à `chunkfirst[edge16+10] − 1`, donc une
cellule *à cheval* sur le bord gauche du ruban est refusée alors qu'un test par
cellule la croit dedans. D'où 39 octets de champ où le modèle se croyait en
avance sur la machine. Le modèle applique désormais la même règle
(`chunkfirst(m) = ceil(16m/3)`).

**Et il reste un vrai résidu, de 48 à 60 px selon le cas**, mesuré CONTRE LA
CARTE DE LA MACHINE (donc indiscutable : `0 manquants, 48 en trop`). Sa forme
est précise et c'est ce qui rend la suite abordable : **quatre lignes sur les
six d'une rangée subsistent, sur quatre cellules**, alors que le bit de carte
est bien effacé. Une routine de run écrit ses six lignes par une boucle sur
`pscroll.run.lines` ; un résidu de deux lignes exactement pointe vers ce
compteur ou vers l'un des quatre buffers non parcouru.

C'est le prochain fil, et il est court : instrumenter `run.plans` pour
enregistrer, par buffer, le nombre d'itérations réellement faites.

Bilan de la passe complète : 41/42 validations conformes, 868 trames, vidéo de
35 s (2× temps réel).

### La matrice sur champ plein — trois défauts en une séance

Décision auteur (23/08) : **plus de mire, plus de scroll**. Le banc remplit
l'écran de gommes (`bench.fill`, qui pose une gomme partout par `setCell` — le
vrai chemin, une rangée par tour), la caméra est figée, et chaque cas s'exécute
seul, avec un remplissage entre deux. Sur un champ plein, tout pixel éteint est
un effacement et rien d'autre : plus de motif à modéliser, plus de cellule
« déjà vide » pour masquer un défaut. Outil : `tools/matrix_runs.py`.

Le contrôle est un ET, à chaque étape : la **carte** machine dit ce que le
modèle dit, ET l'**écran** dit ce que la carte machine dit. Le second attrape
les résidus de buffer.

**Ça a payé immédiatement — trois défauts, chacun masquant le suivant.**

1. **`prep` comparait un registre écrasé.**
   ```
   std   pscroll.rect.n
   lda   #1              ; ecrase A, donc D
   sta   pscroll.rect.m0
   clr   pscroll.rect.m1
   cmpd  #pscroll.CLEAR_UNROLL   ; compare $01xx : jamais < 8
   lblo  pscroll.rect.prepEnd    ; raccourci JAMAIS pris
   ```
   Le raccourci des runs courts n'était donc jamais emprunté.

2. **Conséquence : `dec m1` débordait par le bas.** `m0`/`m1` se calculaient
   pour tout `n` ; pour un intervalle dans la bande 0, `m1` passait de 0 à
   **255**, le test « pas de bande pleine » tombait à l'envers, et le chemin
   des bandes déroulées partait sur des bornes délirantes. Il écrivait **hors
   de la carte** — jusque sur son propre compteur de boucle — et **bouclait à
   l'infini** : le banc se figeait, témoins gelés.

3. **Le raccourci ne nettoyait pas la retenue.** Une fois (1) corrigé, `prep`
   sortait par `lblo` avec le C du `cmpd` — à 1 quand `n < 8` — que l'appelant
   lit comme « rien à faire ». Plus AUCUN run court ne s'effaçait. Le `andcc`
   de sortie n'existait que sur le chemin long ; invisible tant que le
   raccourci n'était jamais pris.

**Ce que la matrice donne maintenant** (144 essais, chaque longueur aux seize
décalages de phase) :

```
longueur 1..7 : ................   toutes conformes
longueur 8    : XXXXXXXXXXXXXXXX
longueur 12   : ..XXXXXXXXXXXXXX
```

Les routines de run et les décompositions sont **justes aux seize cas**. Ce qui
reste est le **chemin des bandes déroulées** (`n ≥ CLEAR_UNROLL`) : la carte est
correcte (`0 octet` d'écart) mais l'écran garde 12 à 18 pixels — c'est la même
famille que les 48 px résiduels de la démo. Le défaut est à la jonction entre
le milieu déroulé et les extrémités, et il se rejoue en une commande.

### Le chemin des bandes déroulées — corrigé

La matrice a désigné le coupable au pixel : longueur 8, tous décalages, la carte
juste et l'écran faux. Le détail disait tout — pour un run de 8 à partir de la
cellule 6, **la cellule 5 (hors du run) perdait deux de ses trois pixels, et la
cellule 10 (dans le run) en gardait deux**.

**La cause : une bande se jugeait en cellules alors qu'elle s'efface en
pixels.** La séquence déroulée vide les seize pixels de la bande ; elle n'est
donc utilisable que si ces seize pixels sont TOUS dans l'intervalle. Or `prep`
demandait « la première cellule entièrement dans la bande est-elle ≥ a ? », ce
qui est un critère plus faible, faux des deux côtés :

- **à gauche**, la bande débordait sur la cellule d'avant, qui perdait deux
  pixels sans que la carte le dise ;
- **à droite**, la queue démarrait à `chunkfirst[m1+1]`, la première cellule
  entièrement dans la bande SUIVANTE — en sautant celle à cheval, qui n'était
  donc effacée par personne.

Le critère est désormais en pixels, et il est exact :

```
m0 = ceil(3a / 16)          première bande entièrement dedans
m1 = (3b + 2 − 15) / 16     dernière bande entièrement dedans
```

et la queue part de `bandlast[m1] + 1`, une nouvelle table donnant la dernière
cellule **entièrement** dans la bande (`floor((16m+13)/3)`), à ne pas confondre
avec `chunkfirst[m+1] − 1`.

**Le prix, et comment il a été repris.** Le critère resserré qualifie moins de
bandes : le coût des runs longs a triplé d'un coup (223 → 728 cycles par case
sur la bande du beam). Les extrémités passent donc elles aussi par les routines
de run — elles font une à cinq cellules, autant les traiter d'un trait — sauf la
longueur 3, qui n'est pas gravée et que la table dense rabattrait sur celle de 2
(une cellule resterait entière : attrapé par la matrice, encore).

| cas | avant correction | après | |
|---|---|---|---|
| bloc 4×4 seul | 610 | 633 | +4 % |
| 4×4 balayé de 1 | 526 | 549 | +4 % |
| 4×4 balayé de 6 | 577 | 808 | +40 % |
| bande beam 2×12 | 223 | **399** | +79 % |
| bande large 2×24 | 220 | **301** | +37 % |

Le surcoût est réel et assumé : **les mesures d'avant portaient sur un
effacement faux**. La bande large en est la preuve directe — elle efface
désormais 615 pixels là où elle en effaçait 603, les douze manquants étant la
cellule que la queue sautait.

**Validation** : 176 essais de matrice (longueurs 1 à 24, seize décalages),
zéro faute ; plus 72 essais sur les rangées de bord. `check_gum` 80/80,
`check_rect` 10/10.

### Ce que la matrice ne peut PAS prouver — et pourquoi ça ne bloque pas

Le banc à champ plein remplit par `setCell`, donc il n'écrit que dans le
**ruban**. Deux conséquences, toutes deux propres au banc :

- **la cellule de bord du ruban** chevauche une bande qui n'y est pas :
  `setCell` n'en peint que la moitié, et le feed grave l'autre depuis les
  données du niveau. Elle « disparaît » dès que la caméra bouge. Le modèle
  exclut donc les deux cellules de bord ;
- **un champ rempli ne survit pas au défilement** : `feedBand` grave une bande
  entrante depuis les données GÉNÉRÉES du niveau, jamais depuis `field.map`.
  Tout remplissage artificiel est donc effacé au fil du scroll.

C'est pour ça que la matrice se joue **caméra figée**, et que ses 328 essais
prouvent les chemins d'effacement et rien d'autre. À chaque essai la carte
machine est comparée au modèle : **zéro octet d'écart, toujours** — y compris
sur les essais où l'écran diverge après un scroll. L'effacement est donc juste ;
ce qui diverge est ce que le feed regrave.

**Et en jeu, ça ne se produit pas** : la caméra n'avance que vers la droite, une
bande n'entre qu'une fois, et elle est gravée AVANT que le joueur puisse
atteindre ce qu'elle contient. Les effacements portent sur ce qui est à
l'écran, donc sur des bandes déjà gravées.

### L'oblique, retiré

Le squelette de l'escalier a été supprimé (23/08) : aucune arme du stage 4 n'en
a besoin — le Force Pod et le Wave Cannon balaient à l'horizontale, les rebonds
à la verticale, et les missiles n'effacent qu'une cellule. Il se réécrira le
jour où une arme le demandera, et la règle est notée sur place : **un intervalle
par rangée, pas une boîte englobante.**

## L'intégration dans r-type — état au 23/08/2026 (EN COURS, ne tourne pas)

**Ce qui est fait et se construit.** `pscroll` remplace `playfield.clearBlast`
ET `pellet.blast` pour le stage 4 : son ruban porte le champ gravé une fois, et
le passage qui le peint pose le fond ET les gommes du même geste, puisque le
creux d'une gomme EST le fond.

- `src/stages/04/pscroll.unit.asm` — l'unité hôte : géométrie dérivée de la
  carte leanscroll, `stage4.init` (pages, adresses, gravure), `stage4.frame`
  (do + move), et `pscroll.grow` qui convertit l'écran en cellule pour cytron ;
- config : arène `pscroll.code` (page $0B) pour les ~14 Ko de code, quatre
  régions `pscroll.buf0..3` ($0E, $0F, $10, $1D) pour le ruban, le direntry
  `stage4.pscroll` à la place de `stage4.pellet` ;
- `stage-main.asm` : pour le stage 4, l'effacement et la timeline ne tournent
  plus — `pscroll.stage4.frame` prend leur place en tête de trame ;
- `cytron` sème par `pscroll.grow` au lieu de `pellet.grow`.

**Le budget, mesuré avant d'écrire** (rapport d'occupation) : pendant le
stage 4 la page 1 porte le commun plus le stage, il y reste ~4,7 Ko — pscroll
n'y tient pas, d'où sa propre page appelée par `paged.call`. Et 23 pages sont
libres pendant ce stage, donc les quatre buffers ne coûtent rien à personne.
`stage4.pellet` libère 1 564 octets résidents, le bitfield en demande 1 440 :
il prend sa place.

### Le découpage en deux, réalisé (23/08, soir)

`paged.call` monte dans la fenêtre CARTOUCHE — celle que pscroll bascule pour
ses buffers : il s'y démontait lui-même. La solution (décision auteur) est de
mettre le code d'édition dans la fenêtre **DONNÉES** (`$A000`), et elle ne
demande **rien** à personne : `engine/system/to8/ram/ram.asm` choisit déjà la
fenêtre d'après l'adresse de destination, donc le loader écrit par la même
fenêtre que celle où le code s'exécutera — l'inversion des demi-pages
(mesurée : offset `$0000` se voit en `$C000`, `$2000` en `$A000`) s'annule
entre l'écriture et la lecture. Ni builder, ni loader, ni arithmétique.

Le module se coupe donc en deux par le drapeau `PSCROLL_PART` :

| part | contenu | où | poids |
|---|---|---|---|
| 0 | `do`, `runBuffer`, **toutes les variables** | résident | ~1,7 Ko |
| 1 | gravure, scroll, ajout, effacement, le bitfield | page réservée, `$A000` | ~11,3 Ko |
| absent | tout d'un tenant — c'est le banc | | |

`do` a besoin de l'écran monté en `$A000` : la page du module n'y est donc pas
à cet instant, et il ne peut lire aucune variable qui y vivrait — d'où les
variables toutes côté résident, exportées vers la part paginée (38 symboles).

**Le banc est le filet de ce découpage** : il compile la version « tout d'un
tenant » et rejoue la matrice — 32 cas, zéro faute après la coupe, identique à
avant.

**Où ça bloque encore.** L'image se construit des deux côtés, mais la scène du
stage 4 ne se charge plus : le PC tourne dans une boucle du moniteur (`$E0C9`,
pas la boucle de lecture `$E3C0`) et la trame ne démarre jamais. Le suspect est
le direntry à destination `$A000` — c'est le premier du jeu à viser la fenêtre
données, et le chemin n'a jamais servi.

**Pourquoi ça ne marchait pas avant — et c'était structurel.** `paged.call` monte une
unité dans la fenêtre **cartouche** (`$0000-$3FFF`). Or c'est exactement la
fenêtre que pscroll bascule pour atteindre ses buffers : au premier
`_SetCartPageA`, **il se démonte lui-même** et le CPU tombe dans les octets du
ruban. Mesuré : `stage=04`, compteur de tours à zéro, PC en `$4F43` — hors de
tout ce que la scène charge.

La machine n'a qu'une fenêtre paginable : la fenêtre données (`$6000-$9FFF`)
est fixée à la page 1, l'écran occupe `$A000`/`$C000`. **Un code qui bascule la
fenêtre cartouche doit donc être RÉSIDENT** — c'est ce que dit l'en-tête de
`pellet.blast`, et je l'ai lu trop vite en croyant que `paged.call` s'en
affranchissait.

Le budget est le vrai obstacle : la partie de pscroll qui doit être résidente
(le module, les routines d'écriture, `zrow`, les 33 routines de gravure et
leurs tables de colonnes) pèse ~11 Ko, et il reste ~4,7 Ko sur la page 1
pendant le stage 4. `mscroll` montre le modèle tenable — 2,6 Ko résidents — mais
il n'embarque pas la gravure d'un niveau entier.

**C'est un arbitrage à rendre** : libérer ~7 Ko de résident, ou réduire pscroll
(les tables de colonnes et les routines de rangée sont les deux gros postes).
Le reste du câblage est en place et se construit.

**Deux outils en sont sortis, eux utilisables tout de suite :**

- `tools/goto_stage.py` — sauter à un stage SANS manette. Le cheat du title
  compte des appuis joypad puis appelle `title.cheat.launch` ; un émulateur
  sans manette ne peut pas y arriver, mais rien n'empêche de poser `tct.pstage`
  et d'appeler la même routine. Piège : la fenêtre cartouche du TO8 est en
  `$0000-$3FFF`, pas en `$A000`.
- **Le toje du plugin qui ne lisait plus l'image : un état, pas un bug.**
  Symptôme : « le contrôleur ne rend pas de donnée », boucle DRQ du moniteur
  (`$E3C0-$E3E9`). J'ai d'abord accusé le format `.fd` — à tort, et deux fois :
  le builder écrit bien face par face, lire face 0 puis face 1 d'une piste est
  l'optimisation de tête, et une autre émulation lit l'image sans broncher.
  La preuve : le harnais `FdBootRepro` du dépôt toje, compilé sur la **1.6.1
  elle-même**, boote notre image (`GOOD`). Le diff `THMFC1` entre notre version
  et la 1.6.1 ne touche rien à la localisation d'un secteur. **C'était
  l'instance du plugin qui portait un état incohérent** — `restart_emulator`
  la remet d'aplomb, et tout lit normalement.
