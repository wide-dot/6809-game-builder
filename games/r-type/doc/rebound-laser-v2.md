# Le laser rebond, tel qu'il est chez nous — état des lieux

*Analyse du code existant, 25/08/2026. Premier volet ; le second est le relevé
arcade sous Ghidra, le troisième le plan d'implémentation.*

Fichier : `src/common/weapons/forcepods/obj_reboundlaser.asm`, 953 lignes,
enveloppé par `reboundlaser.unit.asm` (region `reboundlaser`, page 9 à `$1355`).
C'est la plus grosse des armes du Force Pod, et la seule dont le portage porte
des **coupes assumées** — c'est ce qu'on vient rouvrir.

---

## 1. Comment on y entre

`ForcePodAttachedFire` / `ForcePodDetachedFire` (dans `forcepod.asm`) créent un
objet `ObjID_forcepod_reboundlaser` à la routine 0. Le pod détaché en crée
**plusieurs** selon son palier de puissance (`InstancateForcePodDetachedFire`
avec les directions 0, 1, 3, 4) ; le pod accroché en crée un.

Cet objet n'est **pas** le laser : c'est un **orchestrateur** qui vit une seule
trame, décide ce qu'il y a à lancer, lance, et se supprime.

## 2. La machine à états

Six routines, dispatchées sur `routine,u` :

| # | routine | rôle |
|---|---|---|
| 0 | `Orchestrate` | resynchronise les slots, place le point de tir, lance les lasers, se supprime |
| 1 | `StartLaser` | initialisation différée d'un segment, puis enchaîne immédiatement sur sa routine réelle |
| 2 | `RunHorizontalLaser` | le laser central |
| 3 | `RunDiagonalLaser` | les deux lasers obliques |
| 4 | `RunExplosion` | quatre images, puis mort |
| 5 | `DoubleBufferingFlush` | **un `rts` nu** — le slot survit une trame de plus pour que le double buffer se rattrape |

## 3. Trois lasers, trois slots

`glb.slotsState` porte trois bits : `SLOT_UP`, `SLOT_CENTER`, `SLOT_DOWN`. Une
volée n'est lancée que si **les trois sont libres**, ce qui donne la cadence
observée (~114-118 trames, la durée de vie d'un laser).

Le mot est **reconstruit à chaque appel** en balayant la liste d'objets, il
n'est plus un verrou posé/levé (correctif tracé dans le code) : un segment
disparu autrement que par `Destroy` — mort du joueur, `ManagedObjects_ClearAll`,
pool saturé — laissait sinon son bit collé et le rebond ne repartait jamais.

Avant de lancer, l'orchestrateur :
- décale le point de tir de ±9/11 px selon le côté du pod ;
- **aligne sur la grille de cellules** (÷3 en x, ÷6 en y, +1 pour viser le
  centre de la tuile) via `DIV3u`/`DIV6u`, deux réciproques par `mul` locales ;
- **refuse de naître dans un mur** : `terrainCollision.do` sur l'avant, et sur
  l'arrière si `globals.backgroundSolid`.

## 4. La chaîne : une tête, des enfants, un anneau

Chaque laser est une **chaîne d'objets** : une tête (`parent = 0`) et N enfants.
`InitLaserSegment` recopie direction, slot, position, `bufferBase`, chaîne le
nouveau segment au précédent par `child` (qui squatte `routine_tertiary`), et
numérote par `childId`.

**Les enfants n'ont aucune logique.** `RunHorizontalChildLaser` /
`RunDiagonalChildLaser` font trois choses : vérifier que le parent est toujours
un segment vivant du bon type (sinon mourir), décrémenter leur durée de vie, et
**lire leur position dans l'anneau du parent**, à `bufferIndex − (childId·4 + 6)`
octets. Puis `DisplaySprite`. C'est tout.

L'anneau est écrit par la tête, une entrée par **tick** (pas par trame) :

| anneau | taille | contenu |
|---|---|---|
| `glb.horizontalBuffer` | 32 o | 16 × x |
| `glb.diagonalUpBuffer` | 96 o | 16 × (x à +0, y à +32, imageset à +64) |
| `glb.diagonalDownBuffer` | 96 o | idem |

Aligné par `ALIGN 32` — l'astuce v1 (`equ (*/32)*32`) ne survit pas à une
section relogeable, c'est tracé en écart dans le code.

## 5. Le mouvement et les rebonds

La tête rejoue son déplacement **`gfxlock.frameDrop.count` fois** par trame, en
écrivant l'anneau à chaque tour : la compensation est exacte, et c'est elle qui
donne aux enfants leur échelonnement en ticks plutôt qu'en trames.

- **horizontal** : ±3 px, rebond = inversion du bit 1 de `direction` ;
- **diagonal** : (±3, ±6) selon les huit directions, et le rebond est une
  **cascade de trois sondes** — on essaie le report du preset, puis un second
  report, puis on revient en arrière — ce qui produit les images d'angle
  (`Img_reboundlaser_angle_0..7`) et les huit directions de `ReboundPresets`.

## 6. La collision — le point le plus écarté de la borne

L'en-tête du fichier le dit en toutes lettres :

> `Unlike arcade: only the parent object go through collisions, childs follow the parent`

**Une seule boîte par laser**, celle de la tête : `p = 2`, rayon `5,9` (soit les
12×12 px arcade à l'échelle : 12×0,375 = 4,5 et 12×0,75 = 9 — la conversion est
juste). Les enfants n'apparaissent jamais dans `AABB_list_friend`.

Deux mécanismes s'y greffent :
- `isInCollisionRange` **retire la boîte** quand le laser sort d'une fenêtre
  plus étroite que l'écran, et la marque désactivée par `AABB.rx = 0`. Le code
  dit lui-même « not tested in arcade but we have different behavior in
  collision testing that make this check mandatory » ;
- **le split à l'impact** : quand la tête est touchée (`AABB.p == 0`), elle
  passe en explosion et le **troisième** segment devient une nouvelle tête —
  nouveau `parent = 0`, nouvelle boîte, `bufferIndex` reculé de 8 octets — le
  deuxième segment devenant `isLastChild`. La chaîne se coupe en deux et la
  moitié arrière continue.

## 7. Durée de vie et bornes

`LASER_LIFETIME = 112` trames pour la tête ; chaque enfant vit
`112 + (childId+1)·2` — un échelonnement qui fait disparaître la chaîne par la
queue. `isInLivingArea` tue hors d'une fenêtre autour de l'écran, **dont les
bornes dépendent du palier** : ±64 px / ±120 lignes au niveau fort, ±16 / ±30 au
niveau faible. C'est un corollaire direct de la coupe de longueur.

## 8. Les coupes assumées, et ce qu'elles coûtent

### 8.1 La longueur, divisée par deux ou par quatre

```
        ; laser length (2 or 8) based on forcepod power
        ;jsr   DiagonalLoadObject ; 8 sprites x 3 lasers = 24 sprites, too much left for enemies
        ;jsr   DiagonalLoadObject
        ;jsr   DiagonalLoadObject
        ;jsr   DiagonalLoadObject
```

Quatre appels commentés dans la voie diagonale, quatre dans l'horizontale. On
obtient donc :

| palier | segments par laser (borne) | chez nous |
|---|---|---|
| 2 (faible) | ? à relever | **2** |
| 3 (fort) | **8** | **4** |

La raison écrite est la place dans le pool : 8 × 3 = 24 objets.

### 8.2 Les boîtes des segments enfants

La borne donne des boîtes à certains segments enfants (à relever précisément :
le relevé arcade liste `horizontal_segment_1_arm` … `_8_arm`, dont un
`segment_5_arm_damage` qui se distingue par son nom). Chez nous, aucune.

### 8.3 L'anneau tient huit segments — tout juste

Un passager lit à `bufferIndex − (childId·4 + 6)`. Huit segments, c'est une
tête plus **sept** enfants (`childId` 0..6) : les reculs valent 6, 10, 14, 18,
22, 26, 30 octets, soit 3 à 15 entrées derrière la tête. L'anneau en compte 16.

**Ça passe, avec exactement une entrée de marge.** Le dernier passager lit la
plus ancienne entrée encore valide. Rien à agrandir pour restaurer la longueur
arcade — mais rien non plus au-delà : un neuvième segment lirait une position
*plus récente* que la tête et se collerait devant elle. La borne s'arrête à
huit, l'anneau aussi ; il faut que ça se voie dans le code.

*(Un premier jet de cette analyse annonçait l'inverse — il comptait huit enfants
au lieu de sept. La première `DiagonalLoadObject` crée la TÊTE, pas un enfant :
`stx parent,u` juste après le prouve, et `clr glb.childId` ne vient qu'ensuite.)*

### 8.4 Autres écarts relevés au passage

- `isInCollisionRange` : fenêtre de collision plus étroite que l'écran, ajout v2
  explicite ;
- `DoubleBufferingFlush` : une routine vide, propre au double buffer v2 ;
- le resync de `glb.slotsState` : correctif v2, sans équivalent arcade ;
- l'alignement des anneaux par `ALIGN` : écart v1 tracé.

## 9. Ce que ça coûte aujourd'hui, mesuré

Stage 4, vague active, pod rebond niveau 3, 40 salves, sous toje :

| | |
|---|---|
| segments simultanés | 3,5 en moyenne, **12 au pire** |
| slots libres dans le pool (60) | 51,4 en moyenne, **35 au minimum** |
| part CPU | **sous le seuil de bruit** — aucun PC de l'unité dans les 22 lignes de tête du profileur, toutes déjà sous 1 % |

Le coût n'est donc pas en cycles : il est en **slots d'objets** — et,
plafond moins visible, en **objets graphiques** (`nb_graphical_objects = 64`),
que chaque segment consomme puisqu'il est dessiné.

## 10. Ce que la suite doit trancher

1. le relevé arcade : longueur par palier, quels segments portent une boîte et
   avec quels dégâts, la vraie durée de vie, le comportement de split ;
2. l'architecture : garder N objets (et alors il faut de la place) ou passer au
   **manager** façon `bug`/`outslay` — ici la moitié du chemin est déjà faite
   (l'anneau existe, les enfants n'ont pas de boîte), il ne manquerait que le
   renderer groupé ;
3. l'anneau, lui, n'a pas à bouger : il est dimensionné pour huit segments
   pile — mais la marge nulle mérite d'être écrite dans le code.
