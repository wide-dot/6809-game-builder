# Bit devices : l'arcade contre notre portage — analyse d'écart (03/09/2026)

Demande : analyser le code arcade des bit devices (les deux petites boules
au-dessus et au-dessous du vaisseau), le comparer à notre version, et répondre
en particulier à deux questions : tirent-elles avec le counter-air laser, et
tuent-elles les gommes du stage 4 ? Analyse seule, rien n'est implémenté.

Sources arcade (Ghidra, maincpu) : `create_bit_device_top` (0x402CE5),
`run_bit_devices` (0x402D50, variante basse inlinée à 0x402EA6),
`collision_to_top_and_bottom_bit_devices` (0x40F49B), les dispatchers
`do_collision_with_player_and_weapons_v1..v4` (0x40F694..0x40F7F1),
`clear_green_ball_helper_stage4` (0x402736),
`create_counter_air_reflection_bit_top/bottom` (0x404CD3/0x404CF8),
`run_counter_air_reflection` (0x404E0F), les tables de tir du pod
(ROM 0x1B80..0x1C40) et les tables d'orbite (0x15DE), de vitesse (0x16DE) et
de boîte (0x17EE). Côté portage : `src/common/weapons/bitdevice/obj.asm`,
`src/common/lib/weaponcollide.asm`, `src/common/flow/checkpoint.unit.asm`,
`src/common/weapons/forcepods/forcepod.asm` et `obj_counterairlaser.asm`.

Unités : les mesures arcade sont en pixels arcade et en trames à 60 Hz. La
grille de tuiles arcade (8×8) coïncide avec la nôtre (3×6) : un pixel arcade
vaut 0,375 des nôtres en X et 0,75 en Y.

## 1. Ce que fait l'arcade

### 1.1 Activation et perte

Deux enregistrements fixes (0x120 haut, 0x140 bas), toujours présents,
dormants tant que `bit_device_count` ne l'autorise pas : **le haut s'arme dès
un bit ramassé, le bas dès deux**. À l'armement, l'anneau de positions est
semé avec la position du vaisseau (y + 0x10 en haut, y − 0x10 en bas), une
palette est réservée et le tick s'installe. Quand le compteur retombe à
zéro (mort du joueur) le tick libère la palette et repasse à la porte
dormante. Rien d'autre ne tue un bit : il n'a pas de points de vie, aucune
collision ne le consomme.

### 1.2 Le mouvement : un suiveur élastique, pas une copie

À chaque trame, pour chaque bit vivant :

1. **Balancier** (`swing`, octet +0x11) : +5 par trame tant que le joueur vient
   de changer de direction (`direction_change_flag`), plafonné à 0xE0 ;
   −1 par trame sinon, plancher 0. Remis à zéro quand le compteur de spin
   (+0x13, un pas toutes les 8 trames) boucle après 7.
2. **Cible d'orbite** = position du vaisseau + un décalage lu dans une table
   indexée par **la direction tenue** (4 bits) et **le palier du balancier**
   (`swing >> 6`, 0..3) ; en Y s'ajoute +0x20 (haut) ou −0x20 (bas). Le
   décalage pointe **dans la direction tenue** et grandit avec le palier :
   16 px en X et 14 en Y au palier 0, 32 et 30 au palier 1, et ainsi de suite.
   Direction relâchée : décalage nul, le bit revient au-dessus du vaisseau.
3. La cible est poussée dans un anneau de 16 entrées ; le bit lit l'entrée de
   queue, **une trame derrière la tête** (les deux curseurs avancent
   ensemble) : le retard de l'anneau est d'une trame, il n'explique pas
   l'élasticité.
4. **Poursuite** : une vitesse `v` est lue dans une table de 32 entrées
   indexée par `swing >> 3` quand une direction est tenue (4 px/trame au
   repos, jusqu'à 15 px/trame au balancier maximal). Sur chaque axe, si la
   cible est au-delà de `pos + v` le bit avance de `v`, si elle est en deçà de
   `pos − v` il recule de `v`, sinon il ne bouge pas (bande morte de ±v : il
   ne tremble jamais autour de la cible). C'est cette poursuite à vitesse
   bornée qui fait « traîner » le bit derrière le vaisseau et qui le fait
   déborder dans la direction tenue.
5. **Animation** : 12 images, une de plus toutes les 4 trames (un tour en 48
   trames), tables distinctes haut/bas.
6. **Boîte** : demi-largeurs 12/12 (24×24 px) pour les deux bits.
7. **Gommes du stage 4** : appel de `clear_green_ball_helper_stage4` à chaque
   trame (voir §1.5).

### 1.3 Contact avec les ennemis

`collision_to_force_pod` (0x40F493) **tombe** dans
`collision_to_top_and_bottom_bit_devices` (adresses contiguës) : dans les
dispatchers v1, v2 et v3 un ennemi est « touché par le pod » s'il recouvre le
pod OU l'un des bits. Le dispatcher v4 (compiler, bellmite et leurs
satellites) appelle les bits **directement, sans le pod** : ces ennemis sont
immunisés au contact du pod mais pas à celui des bits.

Dégâts : dans v2/v3/v4, **1 point toutes les 16 trames globales**
(`[0x2EB6] & 0x0F == 0`), une seule incrémentation même si pod et bits
touchent ensemble ; dans v1 (obstacles en un coup) le contact tue sans
porte. Le bit n'est jamais consommé.

### 1.4 Les tirs ennemis ne voient pas les bits

Les projectiles ennemis (`run_foe_fire`, `run_newt_fire`, `run_scant_beam`,
les scies, les tirs du cuirassé…) appellent `collision_to_player_one`
directement. **Aucun ne teste les bits** : un bit n'arrête pas une balle, ne
protège le vaisseau que par les ennemis qu'il tue au contact. Il n'y a donc
rien à « perdre » côté bits sur un tir ennemi.

### 1.5 Les gommes du stage 4 : oui, les bits les effacent

`run_bit_devices` appelle `clear_green_ball_helper_stage4` **à chaque trame,
pour chaque bit** : sonde de la tuile d'avant-plan sous (x − 4, y + 4), puis
un amas 2×2 (la cellule, sa voisine de droite, la rangée du dessous et sa
voisine de gauche) ; chaque cellule qui porte la tuile gomme (0x9F6) est
réécrite vide (0xFA0) et **`pickup_pending_flag` est incrémenté** — c'est le
crédit de bonus du stage 4. Garde : x ≥ 0x140 (le bit doit être dans la bande
visible). Le pod flottant fait la même chose avec un amas plus large
(`clear_green_ball_stage4` : quatre appels aux coins ±8).

Réponse à la question posée : **en arcade les bits tuent les gommes**, en
continu, exactement comme le pod, et le crédit de bonus suit.

### 1.6 Le counter-air laser : des reflets partent des bits

Les tables de tir du pod (`force_pod_weapon_dynamic_call`, blocs de 24 octets
indexés par palier de pod et type de laser) désignent, pour le type
counter-air (6) aux paliers 2 et 3, pod **accroché** :

| Slot d'arme | Routine | Ancrage |
|---|---|---|
| 1 (palier 3) | `create_counter_air_laser_a` | tête, pod ± 0x50 |
| 2 | `create_counter_air_reflection_bit_top` | **bit du haut** |
| 3 | `create_counter_air_reflection_bit_bottom` | **bit du bas** |
| 4 (palier 2) | `create_counter_air_reflection_up_right` | coin du pod (x − 0x10, y + 8) |

Le reflet ancré à un bit n'existe que si l'enregistrement du bit exécute
`run_bit_devices` : **pas de bit, pas de reflet**, sans autre garde. Un
reflet (`run_counter_air_reflection`) : dégâts 2 (la tête en fait 5),
`step_x` +8 (négatif si le pod est accroché derrière), clignotement sur 2
images, boîte partagée 0x26DC, **efface les gommes à chaque trame** et sonde
le décor ; il meurt hors écran, dégâts épuisés ou décor rencontré, puis une
queue de fondu de 5 trames ; SFX « tir simple » si le pod n'est pas au
palier 3.

Réponse : **oui, avec le counter-air laser chaque bit vivant tire un reflet
à chaque salve**, en plus des reflets aux coins du pod.

## 2. Ce que fait notre portage

- **Ramassage** (`InitOptionBox`/`LiveOptionBox`/`Collect`) : le bonus touché
  arme le slot statique haut puis bas (`bitdevTopOST`/`bitdevBotOST`), le
  compteur `globals.bitdevice` monte ; à deux bits la boîte du bonus est
  réarmée et le bonus ignoré. Même règle d'activation que l'arcade (haut à
  1, bas à 2), y compris au rejeu de checkpoint
  (`checkpoint.armament.restore`).
- **Perte** : à la mort `checkpoint.armament.lose` remet le bloc armement à
  zéro et le rechargement repasse les slots en `Dormant`. Comme l'arcade.
- **Mouvement** (`ActiveTick`) : le bit recopie la position du vaisseau
  **avec deux trames de retard**, compensée du déplacement caméra, et un
  décalage vertical fixe de ±25 px (l'équivalent de l'arcade : 0x20 arcade
  = 24 des nôtres). Pas de décalage horizontal, pas de balancier, pas de
  poursuite : le bit est rigidement collé au vaisseau, à deux trames près.
  C'est le modèle v1, repris tel quel.
- **Animation** : 6 images de 7×12 px, `duration` 4 (un tour en 24 trames),
  sens inversé pour le bas.
- **Boîte** : demi-largeurs 3/6 (6×12 px, la taille du sprite). L'arcade
  ferait 4,5/9 dans nos unités : la nôtre est moitié moins large.
- **Contact ennemi** : `WeaponContactTick`, une passe résidente par trame sur
  les listes `ennemy` et `target` : pod OU bit haut OU bit bas, 1 point
  toutes les 16 trames compensées pour les ennemis à p ≥ 2, contact immédiat
  pour les p = 1 (l'équivalent v1). Fidèle à l'arcade, dispatcher v4 compris
  (la porte est la même). Le slot n'est dans aucune liste : jamais consommé,
  jamais visé — comme l'arcade.
- **Gommes** : `stage.gum.hook` est appelé par le tir simple, le beam, le pod
  (`ForcePodGumSweep`, rectangle balayé 4×4 cellules depuis la position de
  la trame d'avant) et le counter-air (`CounterAirGumSweep`). **Les bits ne
  l'appellent pas.**
- **Counter-air** : `ForcePodAttachedFire` crée un seul objet
  `ObjID_forcepod_counterairlaser` (verrou de cadence 20 trames), qui met au
  monde son second faisceau. **Aucun reflet**, ni aux coins du pod ni aux
  bits.

## 3. Tableau d'écarts

| Point | Arcade | Portage | Écart |
|---|---|---|---|
| Activation haut/bas | à 1 puis 2 bits, slots fixes | idem | aucun |
| Perte à la mort | compteur à 0, slot dormant | idem | aucun |
| Position de repos | vaisseau ± 0x20 (24 px chez nous) | ± 25 px | négligeable |
| Décalage selon la direction tenue | 16→64 px arcade (6→24 chez nous) en X, 14→62 (10→46) en Y, par paliers | aucun | **majeur, visuel** |
| Balancier au changement de direction | accumulateur +5/−1, paliers, reset au spin | aucun | **majeur, visuel** |
| Poursuite | vitesse bornée 4→15 px/trame avec bande morte | copie rigide à 2 trames | **majeur, visuel** |
| Animation | 12 images, 1 toutes les 4 trames (48) | 6 images, 1 toutes les 4 (24) | mineur (deux fois plus vite) |
| Boîte | 24×24 px arcade (9×18 chez nous) | 6×12 px | moyen : le bit touche moins loin |
| Dégât de contact | 1/16 trames (v2-v4), immédiat (v1) | idem, par p de l'ennemi | aucun |
| Ennemis v4 (compiler, bellmite) | bits seuls, sans le pod | pod ET bits | mineur (le pod touche en plus) |
| Tirs ennemis | ignorent les bits | idem | aucun |
| Gommes stage 4 | effacées à chaque trame, crédit bonus | rien | **fonctionnel** |
| Counter-air | un reflet par bit vivant et par salve, dégâts 2, efface les gommes | aucun reflet (ni pod ni bits) | **fonctionnel** (le counter-air lui-même n'est pas fini) |

## 4. Réponses courtes

- **Tirent-elles avec le counter-air ?** Oui : chaque salve du counter-air
  crée un reflet à la position de chaque bit vivant, à 8 px/trame vers
  l'avant du pod, dégâts 2, qui efface aussi les gommes. Notre counter-air ne
  fait aucun reflet, aux bits pas plus qu'au pod.
- **Tuent-elles les gommes du stage 4 ?** Oui, en continu, avec le crédit de
  bonus, par la même routine que le pod flottant. Chez nous non : le crochet
  gommes n'est appelé que par le tir simple, le beam, le pod et le
  counter-air.
- **Protègent-elles des tirs ?** Non, ni en arcade ni chez nous. Elles tuent
  au contact les ennemis qu'elles touchent, c'est tout.

## 5. Ce que ça coûterait — pistes, sans implémenter

1. **Gommes** (petit, sûr) : dans `ActiveTick`, l'idiome de
   `ForcePodGumSweep` avec l'entrée +6 du crochet (rectangle balayé entre la
   position de la trame d'avant et la courante), bloc $33 (3×3 cellules pour
   les 24 px arcade, le pod prend $44 pour 32) et une `gum_prev_x` par slot
   (deux variables d'unité, ou `ext_variables`). Hors stage 4 le crochet est
   `stage.gum.none`, coût d'un `jsr` par bit. Le crédit de bonus suit
   automatiquement si le crochet le porte déjà pour le pod.
2. **Boîte** : passer de (3,6) à (4,9) est une constante ; à faire avec le
   point 1, puisque la portée de contact et la portée d'effacement vont
   ensemble.
3. **Mouvement arcade** (moyen, visuel) : le balancier tient en quatre
   octets d'état par bit et deux tables de 2×4 entrées (une par direction
   tenue, quatre paliers) plus la table de vitesse ; la poursuite à bande
   morte est deux comparaisons par axe. La compensation de trames est le
   vrai sujet : la poursuite doit avancer de `v × frameDrop` et le balancier
   de `frameDrop` pas, sinon le bit deviendra mou à bas régime. La position
   du joueur tenue à deux trames n'a plus lieu d'être. À décider par toi :
   c'est le seul écart que le joueur voit en permanence.
4. **Reflets du counter-air** : dépend du chantier counter-air (deux têtes,
   reflets aux coins, sonde décor, fondu), pas des bits ; le jour où les
   reflets existent, l'ancrage aux bits est une lecture de `x_pos/y_pos`
   des deux slots quand leur routine est `ActiveTick`.
5. **Ennemis v4** : rien à faire tant qu'aucun ennemi du portage ne demande
   l'immunité au pod ; à noter pour compiler et bellmite (stages 4-5).

## 6. Réalisé (03/09/2026) : gommes et boîte

Décision auteur : les points 1 et 2 du §5, rien d'autre.

- `BitGumSweep` dans `bitdevice/obj.asm`, appelé par `ActiveTick` : l'entrée
  +6 du crochet (rectangle balayé), bloc $33, coin haut-gauche = centre −
  (4, 9). Le départ du balayage est le `x_pos` de la trame d'avant, lu dans Y
  en entrée de tick avant d'être écrasé — `ext_variables` est plein (20
  octets, `offsety` finit à +18), pas de variable de plus. `ActiveInit`
  amorce `x_pos` avec celui du vaisseau pour que le premier balayage ne
  parte pas de zéro (rejeu de checkpoint compris).
- Boîte du bit actif : (3, 6) → (4, 9), les 12/12 arcade dans nos unités.
  La boîte du bonus flottant reste (3, 6).

`rtype_bench` 7/7 (chaîne stages 1→3). L'effacement des gommes par les bits
n'est pas vérifié sur machine au stage 4 : à l'auteur.
