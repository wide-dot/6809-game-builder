# La collision du battleship (stage 3) — étude et plan

Relevé le 26/08/2026, avant de brancher quoi que ce soit. Objet : rendre le
vaisseau de fond du stage 3 **solide**, comme en arcade.

## 1. Le moteur, tel qu'il est

`engine/objects/collision/terrainCollision.asm` — la moitié **montée**, une
par stage (`src/stages/NN/collision/collision.asm`). Elle porte le code de
consultation, deux tables précalculées et **les cartes du stage**, désignées
par un couple :

```asm
terrainCollision.maps
        fdb   collisionMapBackground     ; plan 0
        fdb   collisionMapForeground     ; plan 1
```

Une carte est un **champ de bits** : un bit = une tuile de **3 px** de large et
**6 px** de haut, huit tuiles par octet (donc 24 px par octet), `lvlMapWidth`
octets par ligne. Le stride et la borne d'impact sont des **équates que
l'unité du stage pose avant l'INCLUDE** (`lvlMapWidth`, `map_width`) : le
moteur est paramétré à l'assemblage, pas à l'exécution.

L'appelant pose `sensor.x` (monde) / `sensor.y` (écran) et passe l'**identifiant
de plan dans B** : `B=1` avant-plan, `B=0` fond. `loadMap` calcule alors

```
colonne = xOffset[écran_x + scroll_tile_pos_offset24] + scroll_tile_pos
masque  = xMask  [écran_x + scroll_tile_pos_offset24]
ligne   = yOffset[sensor.y]                       ; yOffset equ *-22 -> ligne 11
```

`scroll_tile_pos` / `scroll_tile_pos_offset24` sont maintenus **par le moteur
de scroll de l'avant-plan** (`scroll-map-buffered-even.asm`) : la base de
colonne et le reste sous-tuile de la caméra. C'est ce qui rend la lecture
**exacte** au pixel près sans une seule division.

**Le fond est optionnel** : `globals.backgroundSolid` (posé à 0 par
`stage-main`) commande le second test. Chaque consommateur écrit le même
geste — avant-plan d'abord, fond seulement si le drapeau est armé
(`player_missile.asm`, `forcepod.asm`, `obj_reboundlaser.asm`,
`obj_simplefire.asm`, `groundlaser.unit.asm`).

## 2. Ce que chaque stage en fait

| stage | plan 0 (fond) | plan 1 (avant) | `backgroundSolid` |
|---|---|---|---|
| **1** | la silhouette du BOSS, **décalée** en cours de route | le terrain | **1** |
| **2** | *le même bin que l'avant* (la v1 pointe deux fois `level2_fc`) | le terrain | 0 |
| **3** | `level3_bc.bin` — **jamais testé aujourd'hui** | le terrain | **0** |
| **4** | la carte des GOMMES, **résidente et mutable** | le décor dur | **1** |

Trois usages distincts du même plan 0, et c'est le point à retenir :

- **stage 2** — le fond n'est pas une seconde couche, c'est un alias. Le
  drapeau restant à 0, il n'est de toute façon jamais consulté.
- **stage 4** — le fond est une carte **vivante** (`pscroll.gum.map`,
  résidente) : le décor la mute au fil des gommes. Elle vit dans le **même
  repère** que l'avant-plan et défile avec lui ; rien à corriger dans
  `loadMap`. Le commentaire de son unité dit pourquoi le double test a été
  préféré à une routine d'union : il gère **en prime le cas où les deux plans
  se déplacent l'un par rapport à l'autre** — et cite nommément le suivi du
  boss au stage 1 et le vaisseau de fond au stage 3.
- **stage 1** — le seul qui exerce ce cas. Pendant l'avancée du boss la
  caméra est tenue, donc l'avant-plan ne bouge plus, mais la silhouette du
  boss avance : `main.dobkeratops.computeStep` convertit l'avancée en
  `bgByteOff` (octets de 24 px) + `bgBitShift` (tuiles de 3 px) et `loadMap`
  **décale la lecture du plan 0 vers la droite** de cette quantité. Le décalage
  est ignoré pour l'avant-plan (`bgFlag`), et nul le reste du temps.

## 3. Ce que fait l'arcade

`probe_foreground_and_background_tiles` (`40:1eb5`) sonde les deux tilemaps au
centre de l'objet. Sa plate est explicite sur la différence :

- l'avant-plan **ne défile pas verticalement** — seule `x_foreground_camera`
  entre dans le calcul ;
- **le fond défile sur les deux axes** — `x_background_camera` (`0x2ec9`) ET
  `y_background_camera` (`0x2ecd`) sont repliées dans l'adresse, la seconde
  **avec son reste sous-tuile** (`y_background_camera & 7` ajouté à la base de
  ligne, avant la quantification).

Solidité : identifiant **inférieur** à la sentinelle — `0xDFC` à l'avant,
**`0x7D0` au fond**. Le fond arcade est donc bien solide et le joueur meurt
dessus. La tête du laser de sol suit d'ailleurs explicitement
`scroll_y_bg2_delta`, le delta vertical de cette couche
(cf. [ground-laser-arcade.md](ground-laser-arcade.md)).

## 4. La découverte : `level3_bc.bin` est DÉJÀ la carte du battleship

Le fichier traîne dans l'arbre depuis l'import initial et personne ne le
consulte. Sa silhouette, dessinée bit à bit, est celle du vaisseau — et la
mesure ne laisse aucun doute :

| | boîte englobante |
|---|---|
| `level3_bc.bin` (3 px × 6 px par bit) | x **216..438**, y **12..144** — 222×132 px |
| `map/battleship.png` (l'art de la couche) | x **216..437**, y **12..143** — 222×132 px |

**Même origine, même taille.** La carte n'est donc pas dans le repère du
terrain : elle est dans **celui de la couche mscroll**, exactement comme
l'art. Rien à extraire, rien à convertir — la donnée est là, il n'y manque que
le chemin de lecture.

Ses dimensions : `lvlMapWidth` = 48 octets par ligne (1 152 px, la couche n'en
fait que 640 — le reste est du vide) et 30 lignes (180 px, la couche en fait
384). Le vaisseau tient dans les deux bornes.

## 5. Pourquoi le mécanisme du stage 1 ne suffit pas

Le battleship a **sa propre caméra**, sur **deux axes**, et elle dérive de
l'avant-plan. Mesure faite sur le script de chorégraphie
(`warship/camera-script.asm`, 296 entrées, 9 280 trames = 185 s) contre la
vitesse d'avant-plan constante `stage.SCROLL_VEL` = `$0030` :

```
caméra battleship   x :   0,2 .. 285,0 px      y : -37,5 .. +66,0 px
caméra avant-plan   x :   0   .. 1740,0 px     y : fixe
DÉRIVE (avant-fond) x :   0   .. 1462,5 px  =  0 .. 487 tuiles = 0 .. 61 octets
```

Trois raisons, cumulatives :

1. **le sens** — `bgByteOff`/`bgBitShift` ne décalent que vers la **droite**
   (`adda`, puis `lsrb` du masque). Ici la correction est **négative** : le
   fond retarde sur l'avant-plan de 1 462 px à la fin ;
2. **l'axe manquant** — il n'y a aucun décalage vertical, et la caméra du
   battleship parcourt 103 px en y, soit **17 lignes de collision**. Ignorer
   l'axe y ferait flotter la silhouette de collision à ±11 lignes de son art ;
3. **le fond du problème** — corriger la lecture *de l'avant-plan* par une
   dérive, c'est décrire le fond par rapport à une caméra qui n'est pas la
   sienne. La bonne formulation est celle de l'arcade : **le fond s'indexe par
   SA caméra**, point.

## 6. Le plan

### 6.1 Un second mode d'indexation du plan 0, à l'assemblage

`terrainCollision.asm` lit déjà `lvlMapWidth` et `map_width` de l'unité qui
l'inclut : le paramétrage à l'assemblage est **l'idiome de ce moteur**. On
ajoute donc un mode, sous `IFDEF` — seule l'unité du stage 3 le définit, et
**les unités des stages 1, 2, 4… ne changent pas d'un octet**.

```asm
BG_OWN_CAMERA equ 1        ; posé par src/stages/03/collision/collision.asm
```

Sous ce mode, la lecture du plan 0 devient l'exacte symétrique de celle de
l'avant-plan, avec les registres de SA caméra au lieu de ceux du scroll :

```
colonne = xOffset[écran_x + bgSubX] + bgColBase        ; au lieu de scroll_tile_pos*
ligne   = yOffset[sensor.y + bgSubY] + bgRowBase       ; l'axe que l'avant-plan n'a pas
```

où, entretenus **une fois par trame** depuis `mscroll.camera` :

| registre | valeur | plage |
|---|---|---|
| `bgColBase` | `camera.x / 24` | 0..11 |
| `bgSubX` | `camera.x mod 24` | 0..23 |
| `bgRowBase` | `(camera.y / 6 + PADTOP) × lvlMapWidth` | mot signé |
| `bgSubY` | `camera.y mod 6` | 0..5 |

C'est **exact au pixel** — le reste sous-tuile entre dans l'index *avant* la
quantification des tables, précisément comme l'arcade replie
`y_background_camera & 7`, et comme le scroll d'avant-plan replie déjà
`scroll_tile_pos_offset24`. Coût par consultation : deux `addb`. Coût par
trame : deux petites divisions par une constante.

### 6.2 Les tables s'allongent d'un cheveu

`bgSubX` (0..23) et `bgSubY` (0..5) s'ajoutent à l'index **avant** la table :

- `xOffset`/`xMask` : 168 entrées aujourd'hui (index 8..175), il en faut
  jusqu'à 8+159+23 = **190** → un bloc de 24 en plus par table ;
- `yOffset` : 180 entrées, il en faut 6 de plus.

Soit **+54 octets** dans la seule unité du stage 3. Au passage cela **ferme un
débordement latent** : même à l'avant-plan, un objet au bord droit avec
`scroll_tile_pos_offset24` élevé indexe déjà au-delà de la table
(8+159+23 = 190 > 175) et lit dans `xMask`. Le mode partagé ne change pas,
mais la remarque mérite son propre chantier.

### 6.3 La carte, et la couture verticale

Premier réflexe : rembourrer la carte de quelques lignes vides. **Faux** —
`mscroll` replie sa caméra dans `[0, hauteur[` (« wrap camera position in map,
infinite level loop ») : `camera.y` ne descend jamais sous zéro, et l'excursion
négative du script (−37,5 px) se présente comme **346..383**. La fenêtre de vue
enjambe la couture, et la sonde l'a confirmé en jeu (`camera.y = 373` relevé au
premier passage). Ce n'est pas un cas limite, c'est le cas courant.

On paye donc la couture en **données**, pas en tests :

```
lignes  0..29   le bin, les 180 px du haut de couche où vit le vaisseau
lignes 30..63   le bas de couche, vide (l'art n'y met rien)
lignes 64..93   LA RÉPÉTITION des lignes 0..29 — la couture
```

La ligne consultée vaut `base + 0..30` avec `base = camera.y / 6` dans 0..63 :
l'index reste dans 0..93, la lecture ne sort jamais et **ne teste rien**.
+3 072 octets, aucun binaire à régénérer — le bin est simplement inclus deux
fois.

### 6.4 Le branchement

1. `stage.setup` du stage 3 : `lda #1 / sta globals.backgroundSolid` — le
   drapeau que les cinq consommateurs testent déjà ;
2. par trame, après `mscroll.move` (sous `IFDEF STAGE_MSCROLL`, donc stage 3
   seul) : recalcul des quatre registres depuis `mscroll.camera.x/.y` ;
3. rien d'autre. Les armes, le module et le vaisseau héritent du fond sans
   une ligne de plus : elles font déjà le double test.

### 6.5 Le pont entre les deux repères — ce que l'étude avait manqué

`forcepod.asm` sonde **l'axe X sur le plan de fond** (`clrb` avant
`xAxis.doRight`, sous `backgroundSolid`) : le module longe les surfaces, et
c'est ainsi qu'il s'accroche. Or `checkXaxis` rend un `impact.x` que l'appelant
compare à `sensor.x`, donc **en coordonnées monde** — alors que la lecture du
plan 0 se fait maintenant dans le repère de la couche.

La conversion est exacte et tient en un mot :

```
monde = colonne*24 + tuile*3 + 8 + (glb_camera_x_pos − camera.x)
```

d'où `terrainCollision.bgWorldAdj`, calculé une fois par trame avec les autres
registres, ajouté dans les deux `checkXaxis` sous `IFDEF` **et** sous le test
de plan. Sans lui le module aurait dérivé sur ce stage, et le symptôme aurait
été difficile à rattacher à la cause.

### 6.6 Ce qu'on ne fait pas

- **on ne touche pas au mécanisme du boss** (`bgByteOff`/`bgBitShift`) : il
  marche, il est validé, et le nouveau mode est un `IFDEF` à côté ;
- **on ne régénère pas `level3_bc.bin`** : c'est une extraction arcade, donc la
  vérité ; l'art n'en est qu'une vue ;
- **on ne rend pas la couche destructible** — l'arcade ne l'est pas non plus.

## 7. Ce qui a été vérifié

**Le garde `IFDEF` tient.** Les octets **émis** des unités de collision des
stages 1, 2 et 4 sont identiques au bit près (911, 903 et 932 octets de code et
de tables, comparés entre un build de l'arbre vierge et un build modifié), et
leurs direntries gardent la même taille (4 975 / 2 455 / 2 739). Seul
`stage3.collision` grandit, de 3 895 à 7 091 octets.

**Nuance honnête** : les fichiers objets, eux, diffèrent. Pas le code — les
**identifiants de symboles**, réattribués globalement parce que le moteur
résident a gagné 7 octets et `api.asm` cinq noms. C'est un effet uniforme sur
la cible, pas une régression de stage.

**Les registres suivent la caméra**, mesuré sous toje à quatre instants du
stage 3 (`camera.x/y` lus dans `mscroll`, comparés aux quatre registres) :

```
camera ( 96,373) -> colBase  4 subX  0  rowBase 62 lignes  subY 1   OK
camera (158, 14) -> colBase  6 subX 14  rowBase  2 lignes  subY 2   OK
camera (215, 49) -> colBase  8 subX 23  rowBase  8 lignes  subY 1   OK
camera (271,  9) -> colBase 11 subX  7  rowBase  1 ligne   subY 3   OK
```

Le premier relevé est la couture (`camera.y = 373`) : elle survient dès le
premier passage.

**Le stage est mortel, et pas d'entrée de jeu** : sans invincibilité le
vaisseau survit les 900 premières trames puis perd ses deux vies (~1 000 et
~2 200 trames) — une lecture folle l'aurait tué immédiatement.

## 8. Ce qui reste à l'œil

Le jugement final est visuel, et l'axe **y** est le vrai enjeu — celui que le
stage 1 n'exerce pas :

- le point de contact **suit-il l'art** quand la chorégraphie fait monter et
  descendre la couche ?
- le **module** et le **laser rebond**, qui épousent les surfaces, sont les
  meilleurs révélateurs d'un décalage : ils longent la silhouette.
