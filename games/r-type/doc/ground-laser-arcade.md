# Le laser de sol de la borne — relevé Ghidra

*26/08/2026. La dernière arme du Force Pod qui nous manque : le laser JAUNE,
celui qui rampe le long du décor. Source : base `maincpu`, sous-système
`ground_laser` (15 membres) via asm-ark, plus le décodage de la table de
routage des armes.*

Pendant : [le relevé du laser rebond](rebound-laser-arcade.md), dont ce
document reprend la méthode.

---

## 1. Ce que le routage dit, avant même de lire une instruction

La borne route chaque slot d'arme par la même table que le rebond
(`weapon_object_routines_table`) : **une recette de 24 octets par slot**,
soit 3 paliers × 4 types d'arme, indexée `(palier−1)·8 + type`. Le type est un
octet de couleur, pas un index : **0 = rebond**, **2 = sol**, **4 = sol
aussi**, **6 = counter-air**.

Décodée pour le type 2, elle donne deux chaînes :

| | slots | palier 2 | palier 3 |
|---|---|---|---|
| chaîne A | 2, 4, 6, 8, 10, 12 | **3 cellules** | **6 cellules** |
| chaîne B | 18, 20, 22, 24, 26, … | **3 cellules** | **6 cellules** |

Le palier ne change pas seulement la longueur : la tête est armée par une
routine différente selon le palier (`arm_ground_laser_right_a` à 2,
`_right_b` à 3), et **la seule différence entre les deux est le potentiel de
dégâts** — 2 contre 4.

> Les plates de la base appellent cet octet `standby_frames`. C'est une
> mauvaise lecture : `check_ground_laser_explosion` le teste comme des PV, et
> le counter-air y met 5 en le nommant `damage_potential`. C'est le potentiel.

**Deux chaînes de six, pas trois de huit** — le laser de sol est plus court
que le rebond mais il est double, et surtout il ne vole pas droit.

## 2. Deux faisceaux, deux mains

Chaque chaîne naît au Force Pod et part **verticalement** :

| | direction de départ | rotation | comportement |
|---|---|---|---|
| chaîne A | **0 = HAUT** | 0 | tourne dans le sens horaire au contact |
| chaîne B | **4 = BAS** | 2 | tourne dans le sens anti-horaire |

C'est un **suiveur de mur**, la technique classique du labyrinthe : l'un garde
la main droite sur la paroi, l'autre la main gauche. Le premier monte, touche
le plafond, tourne à droite et le longe ; le second descend, touche le sol,
tourne à gauche et le longe. Les deux progressent vers la droite en épousant
le relief. C'est exactement l'image qu'on a du laser jaune.

`create_ground_laser` ajoute **4 à la rotation quand le pod est amarré à
l'arrière** — ce qui inverse le sens de rotation des deux faisceaux, donc la
main avec laquelle ils tiennent la paroi.

## 3. La marche

Quatre directions cardinales seulement, **pas de 8 px**, table à `ES:0x2114` :

| direction | 0 | 2 | 4 | 6 |
|---|---|---|---|---|
| (Δx, Δy) | (0, −8) | (−8, 0) | (0, +8) | (+8, 0) |
| | HAUT | GAUCHE | BAS | DROITE |

Par trame, la tête :

1. **suit la caméra** — `pos_x += scroll_amount`, `pos_y += scroll_y_bg2_delta` ;
2. **avance d'un pas** dans sa direction courante ;
3. **sonde le décor** au nouveau centre, sur les deux plans
   (`probe_foreground_and_background_tiles`, sentinelles `0xDFC` au premier
   plan et `0x7D0` au fond — **un identifiant de tuile INFÉRIEUR à la
   sentinelle est solide**) ;
4. **si c'est solide** : elle recule du pas qu'elle vient de faire, puis
   `direction += dir_advance[rotation]` masqué par `0x6`. La table à `0x2124`
   donne **+6 pour la rotation 0** (horaire : haut→droite→bas→gauche) et
   **+2 pour la rotation 2** (anti-horaire) ;
5. **dans les deux cas** elle fait une **sonde de coin** : la table
   `[rotation][direction]` à `0x212C` — 4×4 entrées de 6 octets, `(Δx, Δy,
   direction candidate)` — désigne un point à tester. **Si ce point est
   LIBRE, la direction candidate est adoptée.**

C'est l'étape 5 qui fait toute la différence entre « rebondir sur un mur » et
« épouser une surface » : elle laisse le faisceau tourner *vers* le vide quand
la paroi se dérobe, au lieu d'attendre de la percuter. Sans elle le faisceau
décollerait à chaque angle rentrant.

## 4. La chaîne : une file de deux, par cellule

Les suiveurs n'ont **aucune logique de marche**. Chaque cellule porte une file
de deux positions et, à chaque trame :

```
pos      = file[0]
file[0]  = file[1]
file[1]  = position COURANTE de la cellule qui la précède   ([BP−0x1C])
```

`[BP−0x1C]` est le `+0x04` du slot précédent : les slots d'une chaîne sont
consécutifs, de 0x20 octets, exactement comme pour le rebond.

Chaque cellule est donc **deux trames derrière** celle qui la précède. Le pas
valant 8 px, l'espacement est de 16 px — et le sprite fait 16×16 (l'offset de
centrage de la recette vaut (−8, −8)). **Les cellules se touchent exactement.**

C'est un vrai serpent : contrairement au rebond, où chaque segment rejoue la
trajectoire de la tête depuis un anneau commun, ici l'information se propage
de proche en proche. Le résultat est le même tant que la chaîne est intacte,
mais le mécanisme est plus simple et il n'a pas de longueur maximale imposée
par la taille d'un anneau.

## 5. Le rendu

Deux jeux de quatre images de 6 octets :

| base | pour qui | sprites |
|---|---|---|
| `0x218C` | **la tête** | 0x08F4 / 0x08F5, avec deux variantes miroir |
| `0x21A4` | **les suiveurs** | 0x08F6 / 0x08F7, idem |

> La plate de la base les nomme « wall-stick » et « free ». C'est faux : le
> chemin de propagation aboutit à `0x218C` qu'il ait touché ou non, et le
> chemin de veille à `0x21A4`. La distinction est tête / suiveur.

L'image est choisie par `global_counter & 6` — quatre pas, une image toutes
les deux trames — et **le cycle est inversé** (`NEG`) quand le bit de parité
à `+0x1D` est posé, ce qui donne aux deux faisceaux un scintillement décalé.

## 6. Vie, collision, mort

- **Vie** : 112 trames (`0x70`), posées à la naissance de la tête. Même durée
  que le rebond.
- **Naissance refusée** : la tête sonde le décor à son centre dès le premier
  tour ; si c'est solide, elle se décharge immédiatement.
- **Grille** : le centre est calé sur une grille de 8 px (`AND 0xFFF8`) puis
  décalé de +2.
- **Collision** : **seule la tête porte une boîte**, extents `12,12,12,12`
  (`0x21D4`), reconstruite chaque trame. Les suiveurs n'en ont aucune —
  comme le rebond avant qu'on lui rende ses boîtes de milieu de chaîne.
- **Mort de la tête** : potentiel épuisé → explosion de 4 trames (recette
  `0x21BC`, compte à rebours 0x18 → 0), puis déchargement.
- **Intégrité de chaîne** : chaque suiveur lit **le gestionnaire du slot
  précédent**. S'il vaut l'explosion, il explose aussi ; s'il vaut le tick
  normal, il continue ; sinon il se décharge. **L'explosion se propage donc
  vers l'arrière**, cellule par cellule — la chaîne se désintègre depuis la
  tête.
- **Déchargement** : rend le slot de palette et **rebranche le slot sur son
  entrée de veille de tir simple** — le slot n'est jamais libéré, il retourne
  au repos, comme pour le rebond.

## 7. Ce que ça donne à notre échelle — et une bonne surprise

Les facteurs de conversion du projet sont `x·0,375` et `y·0,75`. Donc :

| arcade | v2 |
|---|---|
| pas de 8 px | **(3, 6) px** |
| sprite 16×16 | 6×12 px |
| espacement 16 px | 6 px en x, 12 px en y |
| boîte 12×12 | rayons (5, 9) — les mêmes que le rebond |
| vie 112 trames | 112 trames |

**Le pas de 8 px de la borne tombe exactement sur notre cellule de terrain
3×6.** La marche du faisceau devient « une cellule de la carte de collision
par pas », sans reste ni arrondi — et notre `terrainCollision` teste déjà deux
plans, ce que la sonde arcade fait aussi. Les deux mécanismes se recouvrent
mieux que pour n'importe quelle arme portée jusqu'ici.

## 8. Ce qui reste à établir

- **Le type 4.** La table route les types 2 ET 4 vers les mêmes routines de
  laser de sol. Reste à savoir ce que la borne écrit dans
  `player_one_laser_type` au ramassage — s'il existe vraiment deux bonus qui
  donnent le jaune, ou si le 4 est une case morte.
- **Le biais de +2** dans le calage sur la grille de 8 px : un demi-quelque
  chose, à comprendre avant de le recopier.
- **Le bit de parité à `+0x1D`** : qui le pose, et selon quoi.
- **Les cellules 2 à 6 posent-elles un potentiel ?** Les plates n'en parlent
  pas et seule la tête est testée ; à vérifier dans le listing des `_slotN`.
- Hors de portée du moteur, comme pour les autres armes : le slot de palette
  `0x3D` et le SFX `0x3C`.

## 9. Tableau des écarts prévisibles

| # | la borne | chez nous | nature |
|---|---|---|---|
| 1 | 2 chaînes × 3 ou 6 cellules | rien — le type 1 retombe sur le rebond | **à porter** |
| 2 | suiveur de mur à 4 directions, pas de 8 px | — | pas de 8 px = 1 cellule 3×6, direct |
| 3 | file de 2 par cellule, lue chez la précédente | l'anneau du rebond fait autrement | **mécanisme plus simple à reprendre tel quel** |
| 4 | une seule boîte, sur la tête | — | à trancher : on a appris à en mettre plusieurs |
| 5 | explosion propagée vers l'arrière | — | à porter |
| 6 | 12 slots dédiés (2 chaînes × 6) | pool commun de 60 | le renderer groupé du rebond s'applique |
| 7 | palette par objet, SFX | absents | moteur |
