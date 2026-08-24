# Stage 4 — le champ de gommes (Bydo cells)

État : **étude, rien d'implémenté** (21/08/2026). Ce document tient l'analyse
de rendu, l'extraction arcade qui la valide, et la structure de données
retenue. Il sera la référence du chantier quand il démarrera.

Le simulateur qui produit les chiffres de rendu est décrit au §3 ; les
artefacts arcade extraits sont listés au §7. **Le découpage du chantier vit
dans [`plan-gommes-stage4.md`](plan-gommes-stage4.md)** — phases, fichiers à
toucher, critères de validation.

---

## 1. Le problème

Le stage 4 est un champ dense de « gommes » (Bydo cells, *green balls* dans le
code arcade) que le joueur traverse en le creusant, façon Pac-Man. Trois
choses le rendent difficile :

- **la densité** — au pire cadrage, **1 176 gommes visibles simultanément**
  sur les 1 440 cellules du viewport (82 %). Toute solution « à la gomme
  près » est morte d'avance ;
- **la mutabilité** — le champ change en cours de partie, dans les deux sens
  (le joueur creuse, un ennemi fait repousser) ;
- **la transparence** — la gomme a 3 pixels transparents sur 18, tous placés
  de façon à casser l'alignement octet du BM16, ce qui menace de faire payer
  un read-modify-write sur la moitié des lignes.

Aujourd'hui les gommes sont cuites dans les tuiles compilées de la carte.
Mesure sur la vraie tilemap avec les cycles réels de lwasm : **120 597 cycles
par trame** pour la salle, soit **6,04 trames vidéo à 50 Hz**, dont
**108 128 cycles** imputables aux seules tuiles de gomme pure (164 des 185
tuiles dessinées). Et le champ n'est pas destructible.

## 2. La géométrie, mesurée

| grandeur | valeur | d'où elle vient |
|---|---|---|
| cellule de gomme | 3 × 6 px TO8 | = **une tuile arcade 8×8**, à l'échelle du portage |
| bit de collision | 1 cellule | `level4_fc.bin`, 48 o/rangée × 30 rangées |
| gomme | 15 px opaques / 18 | 3 pixels transparents en colonne gauche, lignes 0, 1 et 5 |
| gommes du niveau | 1 618 | extraction arcade (§7) |
| VRAM BM16 | 2 bancs entrelacés par paire de px, stride 40 | vérifié contre une tuile compilée par gfxcomp |

Le point structurant : **4 gommes = 12 px = 1 nibble = exactement une colonne
de tuile = 3 octets par banc**, et le motif est périodique de période 3
octets. Le `PSHS A,B,DP,X,Y,U` de `playfield.clearBlast` pousse 9 octets =
exactement 3 périodes. Tout divise — le « 7×2 ne se traduit pas bien en octet
de 8 bits » qui avait motivé l'étude n'existe pas, il venait d'un comptage
erroné (les gommes sont jointives : un bloc 24×12 en contient 8×2 = 16, pas
7×2).

## 3. L'étude de rendu

Un simulateur émet le flux d'instructions 6809 de chaque stratégie, **l'exécute
contre une VRAM virtuelle et vérifie le rendu pixel par pixel** ; les cycles et
les octets sont comptés par un modèle 6809 explicite. Toutes les stratégies
ci-dessous passent la vérification.

Pire cadrage (caméra px 816, 1 176 gommes visibles) :

| stratégie | cycles |
|---|---|
| aujourd'hui, gommes cuites dans les tuiles (mesuré, lwasm) | **120 597** |
| tuiles de combinaisons, dispatch par nibble | 123 170 |
| run-blast, transparence préservée (décor par-dessus les sprites) | 81 678 |
| run-blast, gommes dessinées en fond | 33 204 |
| **passe fusionnée avec l'effacement** | **38 124 brut − 20 160 d'effacement remplacé = 17 964 net** |

Deux enseignements :

1. **Le masque est le coût, et il est évitable.** L'écart entre 81 678 et
   33 204 — 48 000 cycles — est le seul prix de la transparence. En ordre de
   fond, le creux de la gomme vaut la couleur d'effacement, donc chaque octet
   est entièrement déterminé et il n'y a plus un seul read-modify-write.
   C'est exact et non approché : le **plan de fond arcade du stage 4 est
   intégralement noir** (3072×240, une seule couleur), le creux ne montre
   jamais autre chose.
2. **L'indexation est le piège.** Précompiler « toutes les combinaisons » de
   gommes dans des tuiles coûte 2¹⁶ tuiles pour un bloc 24×12, ou 256 × 2
   plans ≈ 140 Ko pour la tuile 12×12 réelle. Le run-blast n'a besoin
   d'**aucune** combinaison précompilée : il consomme le bitfield en plages.
   ~1,3 Ko de tables suffisent.

### Coût selon l'état du champ

Le creusement réel produit des tunnels, pas un grignotage aléatoire :

| état | gommes visibles | passe fusionnée (net) |
|---|---|---|
| intact | 1 176 | 17 964 |
| 6 tunnels | 1 150 | 18 756 |
| 20 tunnels | 1 005 | 19 680 |
| 50 tunnels | 923 | 20 076 |
| *random 50 % (irréaliste)* | *595* | *31 725* |

**Le coût est plat, 18 000 à 20 100 cycles, quel que soit l'état du champ.**
Pas de dérive de fluidité au fur et à mesure que le joueur creuse — ce qui
compte pour un jeu calé sur les timestamps arcade.

## 4. Ce que dit l'arcade

Extraction Ghidra (base `maincpu`) + données de `re.arcade.r-type`.

### La boucle : creuser / repousser

Deux routines exactement inverses :

| routine | écrit | condition |
|---|---|---|
| `erase_green_ball_stage4` (0x0040_4FB9) | `0x9F6` → `0xFA0`, attribut → 0, `pickup_pending_flag++` | tuile == `0x9F6` |
| `run_cytron` étape 5 (0x0040_6A12) | `0xFA0` → `0x9F6`, attribut → `0x0082` | tuile == `0xFA0` |

Cytron ne « pose » pas des gommes sur du décor : il **fait repousser une gomme
mangée**, une cellule par trame, uniquement là où le tir est passé. Le joueur
creuse, cytron recomble.

### Solidité = seuil d'identifiant

Tous les tests (`run_player_one` point 11, Wave Cannon, tir simple,
counter-air laser) comparent l'identifiant renvoyé par la sonde à **`0xDFC`**
(plan avant) et traitent `id < seuil` comme solide. Et l'extraction confirme
que **`0xFA0` est la seule valeur ≥ `0xDFC` présente dans tout le niveau 4** :
le seuil sépare littéralement « toutes les tuiles dessinées » de « la cellule
vide ». D'où :

- une gomme (`0x9F6`) est **solide** → le vaisseau meurt au contact ;
- une cellule vidée (`0xFA0`) est **franchissable** → le tunnel reste ouvert ;
- il n'existe pas de « terrain sous la gomme » : la gomme **est** la collision.

Contrôle croisé : 2 643 cellules solides comptées dans les identifiants
extraits = exactement les 2 643 bits posés dans `level4_fc.bin`.

### Qui efface, et combien

| agent | effacement | sites d'appel |
|---|---|---|
| **Force pod** (flottant, attaché, éjecté) | amas 2×2 sur quatre coins (x±8, y±8) → **jusqu'à 16 cellules/trame** | 3 |
| **Counter-air laser** | balayage de **11 cellules** en grille, avant ou arrière | 22 |
| **Wave cannon** | `N` amas 2×2 par trame, `N` = 5,5,6,6,7,8,9,10 selon le palier, **décroissant** | inline |
| Missiles haut/bas | 1 cellule par sonde | 4 |
| Tir simple de la Force | 1 cellule, puis il meurt | 4 |

Le Force pod et le counter-air laser sont les vrais outils de creusement, pas
les tirs. Le tir simple ne mange qu'une gomme pour une raison mécanique
amusante : `erase_green_ball_stage4` retourne `AX = 0` (`XOR AX,AX`), et le
test de mur qui suit immédiatement lit ce même `AX` — `0 < 0xDFC`, donc impact
blanc dans la foulée.

### Score : il n'y en a pas

`pickup_pending_flag` (0x2F30) n'a **qu'un seul lecteur**, dans
`irq_main_loop` : « if [0x2F30] set, enqueue SFX 0x5E ». Manger une gomme
déclenche **un son**, pas du score.

### La profondeur : il n'y a aucun bit de priorité

Décodé le 21/08/2026, des deux côtés, et la réponse est négative — le détail
et les preuves sont dans la table de correspondance du skill
([`arcade-to-v2.md`](.claude/skills/enemy-port/arcade-to-v2.md), section
« L'attribut de SpriteRecipe, et la profondeur »).

- **Côté tuile** : l'octet d'attribut vaut `0x80 | banque_de_palette` sur
  **toutes les cellules des huit niveaux** — bit 7 toujours armé, donc pas une
  catégorie par cellule. Pour le niveau 4 c'est `0x81` partout, gomme, terrain
  dur et vide confondus. Et les bits 4-5 du mot d'identifiant sont nuls partout.
- **Côté sprite** : l'octet haut de `recipe[4..5]` est entièrement expliqué par
  la taille (bits 15-14 largeur, 13-12 hauteur, en tuiles de 16×16) et les
  miroirs (bit 11 horizontal — *prouvé* par les tables gauche/droite du cancer
  —, bit 10 vertical). Les bits 9-8 ne sont posés par aucune des 1 134 recettes
  du catalogue.

**Conséquence pour le champ de gommes** : les gommes sont de la tilemap, les
ennemis sont des sprites, et rien dans la donnée ne dit lequel passe devant.
La profondeur découle de la couche, pas d'un drapeau — un objet qui doit
apparaître derrière le champ sans être de la tilemap est **un choix du
portage**, à noter comme écart. La passe de ré-application du §6 est
exactement ce choix, et elle reste le bon outil : elle donne une profondeur par
objet que l'arcade n'exprime pas, pour un coût qui ne se paie que sur les
sprites concernés.

Reste non tranché : l'ordre global entre couche sprite et plan de premier plan.
Il n'est pas dans les données du jeu (§8).

## 5. La structure de données retenue

```
En page (statique, généré au build — jamais écrit) :
  level4_hard.bin    1440 o   T  = terrain dur seul (solide, hors gommes)
  level4_fc.bin      1440 o   C0 = masque solide initial = T | D0

En RAM (copie de travail, restaurée à l'init et au checkpoint) :
  terrain.map        1440 o   C  = masque solide vivant
```

Une seule carte mutable. Les gommes vivantes ne sont jamais stockées :

| grandeur | expression | usage |
|---|---|---|
| gommes à dessiner | `D = C AND NOT T` | la couche de rendu |
| cytron peut faire pousser | `NOT C AND NOT T` | cellule vide |
| un tir mange | `C AND NOT T` posé | effacer le bit de `C` |
| collision | `C` | **`terrainCollision` inchangé** |

`T` a des zéros sur toutes les cellules du champ (une cellule vidée est
franchissable, donc absente du masque solide initial), donc `C AND NOT T`
redonne exactement les gommes vivantes — y compris celles que cytron fait
repousser, et y compris hors de la zone initiale. Vérifié sur la donnée :
1 025 cellules de terrain dur + 1 618 gommes = 2 643 solides.

Format, identique à l'existant : row-major, 48 octets par rangée de cellules
(`lvlMapWidth`), 30 rangées, 1 bit = 1 cellule 3×6, bit 7 = cellule la plus à
gauche (convention de la table `terrainCollision.xMask`).

Quatre primitives, ~25 cycles chacune : `pellet.clear`, `pellet.set`,
`pellet.test`, `pellet.reset` (recopie de `C0`). Les coordonnées existent
déjà : `terrainCollision.checkXaxisRight` calcule en interne la colonne
d'octet et le masque de bit de la cellule touchée — il suffit de les exposer.

### La propriété qui compte

Le champ est **intégralement repeint depuis `C` à chaque trame**. Donc :

- ajouter une gomme et en détruire une sont la même opération à l'inverse
  près : un bit. Ni l'une ni l'autre ne touche la VRAM, ne connaît le scroll,
  ni ne sait quelle tuile est concernée ;
- **ce qui tue est exactement ce qui est affiché.** Comme le contact est
  mortel, un rendu incrémental ou à zones sales risquerait une gomme létale
  pas encore dessinée, ou dessinée mais déjà mangée. Le repeint intégral rend
  ce bug *inexprimable*. C'est la vraie raison de préférer ce design, avant
  les cycles.

## 6. La séquence de trame

```
playfield.clearBlast          ← ne couvre plus les rangées du champ
pellet.blast                  ← efface ET peint, C AND NOT T        ~20 000 net
starfield.draw
stage.frameBlit
BuildSprites
pellet.reapply <liste>        ← gommes par-dessus les sprites
                                 marqués « dans le champ »          ~1 500 / sprite
DrawTiles                     ← quasi vide dans la salle
masque + HUD
```

La couche passe en fond parce que c'est là qu'elle est presque gratuite ; les
rares sprites qui doivent passer **dessous** récupèrent les gommes par-dessus
eux, au prix du masque, sur leur seule boîte. La profondeur redevient **par
objet**, ce qui est le comportement arcade. La passe se saute d'elle-même
quand la boîte du sprite ne recouvre aucune gomme.

Coût mesuré de la ré-application : **1 488 cycles** pour un cytron (12×24 =
4×4 cellules), 1 575 pour un patapata, 5 526 pour un 32×32.

Budget total, pire cadrage :

```
tuiles restantes de la salle       12 469
passe gommes (fond, creusée)       20 076
4 sprites dans le champ             5 952
~80 effacements / pousses           1 500
                                   ------
                                   ~40 000 cycles = 2,0 trames   (contre 6,04)
```

Côté build : `in.png` perd ses gommes (les tuiles pures sortent du tileset —
2 505 octets et surtout 108 128 cycles/trame), le même passage génère `T`, et
la timeline de `gen_clear_timeline.py` est à régénérer puisque la passe gommes
possède désormais ces rangées.

## 7. Artefacts arcade produits

Extracteur `BallField` ajouté à `re.arcade.r-type`
(`--extract-ballfield`, `extractor/BallField.java`) :

| fichier | contenu |
|---|---|
| `out/tiles/levelN_ball.bin` | bitfield packé, gommes authorées (`D0`) |
| `out/tiles/levelN_hard.bin` | bitfield packé, terrain dur seul (`T`) |
| `out/tiles/levelN_f_cellmeta.bin` | 2 o/cellule : octet de flip+id-haut, octet d'attribut |
| `out/tiles/ball-field-report.txt` | comptes par classe + histogramme d'attribut |
| `out/presets/1183e_green-ball-sweep-count.asm` | table de balayage du Wave Cannon |

Extracteur `SpriteAttr` (`--extract-spriteattr`) : recensement de l'attribut
de toutes les recettes de méta-sprite du catalogue (1 134 recettes, 22 valeurs
distinctes) → `out/sprites/sprite-attr-report.txt`. C'est lui qui établit que
les bits 9-8 ne servent jamais, et donc qu'il n'y a pas de bit de priorité.

Packing identique à `Level.collisionMask`, donc directement consommable par le
portage. `TileMap`'s per-level geometry est passée en `static` pour être
partagée sans relancer l'extraction.

Corrections committées dans la base Ghidra le 21/08/2026 :

- `run_cytron` (0x69B4) — le plate décrivait « turning the floor into a
  Bydo-spore wall » ; `0xFA0` n'est pas du sol, c'est la cellule vidée, et
  l'étape 5 est l'inverse exact de l'effaceur ;
- `erase_green_ball_stage4` (0x4FB9) — le plate annonçait un score, le seul
  lecteur du drapeau enfile un SFX ; ajout de la conséquence du `XOR AX,AX` ;
- `probe_foreground_tile` (0x1E6C) — « cell = 2 bytes, stride 0x40 » est faux,
  la tilemap fait **4 octets par cellule** (mot d'identifiant + mot
  d'attribut) et 0x100 par rangée, ce que confirment `tilemap_load_raw` et les
  marches de voisinage ;
- `0x1000_183E` nommé `green_ball_sweep_count_table`.

## 8. Ce qui reste ouvert

1. **L'ordre global couche sprite ↔ plan de premier plan** — il n'existe pas
   dans les données du jeu (§4). Il faudra le lire dans le pilote vidéo M72 ou
   l'observer sous MAME. C'est la seule chose qui manque pour savoir si notre
   passe de ré-application restitue l'arcade ou s'en écarte volontairement.
2. **Le comportement de cytron hors champ** — sa trajectoire (script de
   mouvement en ROM) détermine où il fait repousser. Non extrait.
3. **La cadence de repousse** — une cellule par trame, mais le nombre de
   cytrons vivants et leurs timestamps de wave fixent le rythme réel de
   recomblement face au creusement.
4. **Le portage de cytron lui-même** — 16 images déjà converties, ~50 entrées
   de wave commentées dans `src/stages/04/wave.asm`, spec extraite ici.

## 9. Journal

- **21/08/2026** — étude de rendu (simulateur vérifié), extraction arcade,
  structure retenue, extracteurs `BallField` et `SpriteAttr`, corrections
  Ghidra. Décodage de l'attribut de SpriteRecipe et conclusion sur la
  profondeur (consignée dans la table de correspondance du skill). Aucun code
  de jeu écrit.
