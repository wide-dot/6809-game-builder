# La scie du Dobkeratops en manager — conception (02/09/2026)

## Ce que fait la scie aujourd'hui (v1, `saw.asm`, un objet OST par scie)

- Le monstre crache une **chaîne** tous les 128 pas (`anim_frame+1 & $7F == $30`)
  depuis sa bouche (x − 6, y + 9). La tête est un objet ; elle engendre un
  **esclave tous les 4 pas** pendant 32 pas : neuf scies par chaîne.
- Tout le monde avance à gauche de **1,5 px par pas** (`XVEL = −$0180`).
- Au **32ᵉ pas** de sa vie, la tête lit la hauteur du joueur et fixe
  `y_vel_step` = −12, 0 ou +12 (1/256 px par pas²). Puis à chaque pas
  `y_vel += step`, `y += y_vel` : une **parabole**.
- Chaque esclave, au 32ᵉ pas de **sa** vie, recopie le `y_vel_step` de la
  tête : il rejoue la même parabole, décalée de 4 pas × 1,5 px = **6 px**
  derrière le précédent. La chaîne suit exactement la trajectoire de la tête.
- Rotation : quatre images, `frame += 2 mod 8` **une fois par rendu** pour
  chaque scie ; l'esclave naît avec la phase du précédent + 2.
- Collision : boîte (3, 6), `p = −128` (intuable), **une boîte pour deux
  scies** (`saw.instanceParity`), liste `ennemy_unkillable`.
- Mort : `x + 8 < caméra`. Rien d'autre ne la tue ; le boss vaincu n'arrête
  que les nouvelles chaînes (le monstre ne tire plus).
- Deux chaînes peuvent être en vol en même temps (période 128 pas, durée de
  vie ≈ 115 pas) : jusqu'à **18 objets OST** sur les 60 du pool, chacun avec
  son dispatch, sa boucle de mouvement × frameDrop et son `DisplaySprite`.

## Ce que devient la scie : `sawmgr`, sur le patron de `tailmgr`

**Un objet maître unique** (un slot OST, spawné par la wave au boss `$1B40`
comme le tailmgr), qui possède l'état de **la chaîne** sur sa page, se
dessine seul via le faux imageset (BuildSprites appelle `sawmgr.DrawAll`
avec la page montée) et fait ses collisions par balayage, sans boîte stockée.

### La trajectoire pilotée par la tête — le gain

Chaque maillon rejoue la trajectoire de la tête avec 4·i pas de retard. Le
manager n'intègre donc **que la tête**, une fois par pas, avec exactement
l'arithmétique v1 (mêmes arrondis, même parabole), et range sa position dans
un **anneau de 64 entrées** (x, y en 16 bits, 4 octets, 256 octets par
chaîne). Le maillon i se lit à l'entrée `(âge − 4·i) & 63` : **zéro
arithmétique par maillon**, et la chaîne est sur le chemin de la tête par
construction. Un maillon existe dès que `âge ≥ 4·i` (naissance échelonnée
comme v1), jusqu'à ce que son x + 8 passe sous la caméra.

État par chaîne : origine (x, y), âge (pas), `y_vel_step` (fixé au 32ᵉ pas),
`y_vel`, position courante de la tête, image de tête, anneau. **Une seule
chaîne** (arbitrage 2 ci-dessous) : une demande pendant un vol serait
ignorée, le cas n'arrive pas.

### La rotation (arbitrage 1)

- **La tête avance d'une image par trame affichée** (par rendu, pas par pas
  machine : à 4 pas par rendu et quatre images, une avance par pas machine
  ramènerait la même image à chaque rendu — la scie semblerait figée).
- **Le maillon i montre l'image `(tête + i) & 3`** : chaque image de la
  chaîne diffère d'un cran de la précédente, quelle que soit la cadence.

### Le dessin

Comme `TailDrawAll` : par maillon, coordonnées écran depuis l'anneau, choix
ND0/ND1 par la parité de x XOR le centre (`imgset.center`), `_sprite.cull`
sur le **vrai descripteur** de l'image (les huit `set_dobkeratops_saw_N`
existent, `shifts="0,1"` conservés) — le containment est exact, y compris
quand la parabole sort par le bas de l'écran, ce que la scie v1 laissait au
moteur.

### La collision

Idiome du tailmgr : balayer les listes `player` et `friend` avec la boîte
(3, 6) centrée sur le maillon ; un contact `clr AABB.p` de l'adversaire (la
scie est intuable, elle ne perd jamais). **Une boîte pour deux, les maillons
impairs, testée à chaque trame** — comme v1 (arbitrage 3), sans table
résidente ni liens à entretenir.

### Le spawn — boîte aux lettres résidente

Le monstre garde sa cadence et son `CreateSawChain`, qui n'alloue plus
d'OST : il écrit (x − 6, y + 9) et lève un drapeau dans
`stage1.sawmgr.res` (5 octets, arène `stage1.res`, l'idiome de
`eyemgr-res`). Le maître consomme la demande dans son Run. Le monstre et le
manager n'ont pas la même page : une boîte aux lettres évite l'appel paginé.

### Le cycle de vie

Init (spawn du maître, et rejeu de checkpoint : l'état de page n'est pas
rechargé) remet tout à zéro. Run : consomme la boîte aux lettres, avance les
chaîne de `frameDrop` pas, calcule les positions écran, balaie les
collisions, met à jour la boîte du maître. Quand `bossDefeated` et plus
aucune chaîne en vol : `DeleteObject` (jamais un flag à la main — le slot
fuirait, cf. tailmgr).

### Ce qui disparaît

`stage1.dobkeratopssaw` (l'objet et son unité) ; `ObjID_dobkeratops_saw`
n'est cité par aucune wave, seulement par `CreateSawChain`. Les images et
leurs descripteurs passent dans l'unité `stage1.sawmgr` (`stage1.foes`,
même page d'accueil que la scie aujourd'hui).

## Coût, estimé

Aujourd'hui, par rendu et par scie : dispatch objet, boucle de mouvement
× frameDrop (deux additions 24 bits), `UpdateFrame`, `UpdateHitBox`,
`DisplaySprite` — de l'ordre de 500 cycles, soit **~9 000 cycles pour 18
scies**, plus 18 slots OST occupés.

Manager : par pas, une intégration de tête par chaîne (~60 cycles) ; par
rendu, 18 lectures d'anneau + cull + adresse écran (~80 cycles chacune) et
9 balayages de collision. De l'ordre de **2 000 cycles**, les blits étant
les mêmes des deux côtés. Et zéro OST hors le maître.

## Validation

`rtype_bench` 7/7 ; sonde toje au boss comptant chaînes et maillons vivants
et vérifiant image(i) = image(tête) + i ; vidéo du combat contre le boss
(`boss_clip.py`) pour le rendu.

## Arbitrages (auteur, 02/09/2026)

1. « Frame réelle » = **trame affichée** : une image de tête par rendu.
2. **Une seule chaîne.** L'arcade n'en montre jamais deux, et le code le
   garantit : le monstre tire depuis 1516 et ne glisse que vers la gauche,
   donc le trajet le plus long est la chaîne droite depuis l'arrêt — 122 px
   à 1,5 px par pas = 81 pas, plus 32 pour le dernier maillon = 113 pas,
   sous la période de 128. Une demande pendant un vol serait ignorée ; elle
   n'arrive pas (marge 15 pas).
3. **Collision comme v1** : une boîte pour deux, les maillons impairs (la
   tête n'en portait pas), testée à chaque trame.

## Réalisé (02/09/2026)

`sawmgr.asm` / `sawmgr.unit.asm` (3 262 o en $16, à la place de la scie),
`sawmgr-res.unit.asm` (5 o résidents). Vérifié sous toje au boss, point
d'arrêt sur `sm.DrawAll` : neuf maillons visibles à 6 px d'écart,
image(i) = tête + i sur 8/8 rendus, tête + 1 par rendu sur 7/7, mort maillon
par maillon depuis la tête ; `rtype_bench` 7/7 ; vidéo du combat.
