# Les boîtes qui s'enroulent : pourquoi un tir sorti par la gauche tue à droite (03/09/2026)

Étude seulement — rien n'est implémenté. Deux symptômes rapportés par l'auteur :

- un tir dont la boîte passe d'un côté de l'écran tue les ennemis de l'autre
  côté ;
- un ennemi à grande boîte voit sa boîte s'enrouler de la même façon.

Les deux ont une seule cause, et elle n'est pas dans les objets : **la
collision travaille sur un octet, modulo 256, alors que les positions qu'elle
projette sont des décalages signés sur seize bits.** Tout ce qui vit hors du
champ, à gauche comme à droite, réapparaît de l'autre côté dans l'espace des
boîtes.

## 1. Le noyau : une arithmétique modulo 256

`Collision_Do` (`engine/collision/collision-do.asm:30-49`), pour chaque paire
de boîtes U et X, sur l'axe x :

```
        lda   AABB.rx,u
        adda  AABB.rx,x        ; A = R = rx_u + rx_x
        asla
        sta   @rx              ; seuil = 2R
        asra
        adda  AABB.cx,u
        suba  AABB.cx,x        ; A = (cx_u - cx_x) + R
        cmpa  #0
@rx     equ *-1
        bhi   @continue        ; non signé : au-dessus de 2R, pas de contact
```

Le test est `0 ≤ (cx_u − cx_x) + R ≤ 2R`, soit `|cx_u − cx_x| ≤ R` — mais
**tout est calculé sur huit bits**. Deux centres distants de 250 pixels ont un
écart qui vaut 6 après le modulo, et se touchent dès que R ≥ 6. Le même axe y
suit, avec `cy` et `ry`.

C'est un choix de vitesse assumé : 34 cycles par axe et par paire, sans
branchement de signe, dans une boucle en O(n·m). Il est aussi hérité tel quel
de la v1 (manifest, `collision-do.asm` 1:1).

Le test existe en **trois exemplaires**, à tenir ensemble le jour où l'un
change :

| Copie | Où | Sert à |
|---|---|---|
| `Collision_Do` | `engine/collision/collision-do.asm:30` | la passe générale, six paires de listes |
| `wctk_overlap` | `src/common/lib/weaponcollide.asm:146` | le contact du pod et des bits |
| `gl.hitEnemies` | `src/common/weapons/forcepods/obj_groundlaser.asm:538` | le laser de sol, hors liste |

## 2. La projection : un octet bas de décalage signé

Chaque objet écrit lui-même son centre, à chaque tick, par l'idiome :

```
        ldd   x_pos,u
        subd  glb_camera_x_pos
        stb   AABB_0+AABB.cx,u         ; l'OCTET BAS d'un decalage signe 16 bits
        ldb   y_pos+1,u
        stb   AABB_0+AABB.cy,u
```

84 sites pour `cx`, 76 pour `cy` (`grep AABB.c[xy] src/`). **Aucun ne borne**,
à une exception près, traitée au §5.

Ce que vaut `cx` selon la position vraie `d = x − caméra` :

| d (pixels) | cx | ce que le noyau croit |
|---|---|---|
| 48 à 207 | 48 à 207 | à l'écran — juste |
| 0 à 47 | 0 à 47 | bande gauche, hors champ — juste |
| 208 à 255 | 208 à 255 | bande droite, hors champ — juste |
| **−1 à −64** | **255 à 192** | **à droite, jusqu'à 16 px DANS l'écran** |
| **256 à 303** | **0 à 47** | **à gauche, juste hors champ** |

Deux objets à `d = −20` et `d = 236` ont le même `cx` (236) : rien, dans la
boîte, ne les distingue. C'est là que le noyau ne peut plus rien faire — la
correction est nécessairement à la projection ou dans la structure.

## 3. Qui vit hors champ en restant armé

Le bug n'existe que si un objet armé (potentiel non nul, dans une liste)
franchit les bornes 0 ou 255 de `d`. Relevé des règles de sortie, mesurées
dans le code :

### Côté joueur

| Objet | Sortie gauche | Sortie droite | Verdict |
|---|---|---|---|
| tir de base (`weapon/obj.asm:206`) | `cmpd #156 / bhs` non signé : un d négatif est ≥ 156, donc mort | d ≥ 156 | **sûr** ; et `cx` calé à 0 quand le segment balayé naît à gauche (`:217-219`, « s'enrouler jamais ») |
| tir simple du pod (`obj_simplefire.asm:101-104`) | **commentée** (`;cmpd #-9 / ;blt Delete`), déjà dans la v1 | d ≥ 153 | ses cinq presets tirent à droite ou en vertical (`x_vel ≥ 0`, `:174-185`) : il ne va jamais à gauche. Sûr en x |
| counter-air (`obj_counterairlaser.asm:264-268`) | `bmi @delete` dès d < 0, avec `RemoveAABB` | d ≥ 156 | **sûr** |
| **laser reflex, tête** (`obj_reboundlaser.asm:661-699`) | zone de vie **d ≥ −64** (long), −16 (court) | d < 208 / 160 | **fautif** : armé jusqu'à 64 px hors champ à gauche |
| missile (`player_missile.asm:286-291`) | d ≤ 0 → mort | d ≥ 156 | **sûr** en x |
| laser de sol (`obj_groundlaser.asm:336-338`) | d ≥ −8 | d < 166 | **marginal** : 8 px, cx 248..255 |

### Côté ennemis

- naissance : `d = 155` (`pata-pata/obj.asm:26`, `144+8+3`) ; les positions
  préréglées (`presets/18dd0_preset-xy.asm`) ne dépassent pas 155 non plus ;
- sortie gauche, six ennemis du stage 1 (tabrok, shell, scant, cancer,
  p-staff, bink) : `addd #5 / bmi` — ils vivent jusqu'à `d = −5`, donc
  `cx = 251..255` pendant cinq pixels ;
- les autres : `cmpd #159` ou `#layer.XGONE` (255) en seize bits.

Cinq pixels de marge à gauche, c'est **une adjacence réelle** : un ennemi à
`d = −3` touche bien un tir à `d = 2`. Le modulo ne ment que si quelque chose
d'armé se trouve *aussi* vers `cx ≈ 250` de l'autre côté, c'est-à-dire à
`d ≈ 250`, 43 px au-delà du bord droit. Rien n'y naît (155), mais un objet
qui *part* vers la droite peut y passer.

## 4. Les deux cas rapportés, démontés

### Le tir qui tue de l'autre côté : le laser reflex tiré vers l'arrière

Le pod accroché **derrière** le vaisseau lance le laser reflex vers la gauche
(`InitiateHorizontalLaser`, direction `LASER_LEFT` d'après la position du pod,
`obj_reboundlaser.asm:345-350`). La tête sort par le bord gauche et **reste
armée jusqu'à `d = −64`** — la zone de vie « 20 px arcade × 3,75 » du long
laser.

Pendant ces 64 pixels, `cx` décrit **255 → 192**. Or l'écran s'arrête à 207 :
de `d = −48` à `d = −64`, la boîte fantôme parcourt **les seize derniers
pixels de l'écran, de droite à gauche**, et y tue tout ce qu'elle croise. Un
ennemi qui entre à `d = 200` se fait faucher par un tir qui est à 250 pixels
de lui, et qui a quitté l'écran depuis dix trames.

Le laser court (niveau 2) vit jusqu'à −16 seulement : `cx ∈ [240, 255]`, tout
entier hors champ à droite, où rien d'armé ne se tient. Le symptôme est donc
propre au **niveau 3**.

### La grande boîte qui s'enroule : un ennemi qui part à droite, un tir né à gauche

Le tir de base cale son `cx` à 0 quand son segment balayé naît au bord gauche
(`weapon/obj.asm:217-219`) : c'est le bon geste, mais il place la boîte à
`cx = 0`, et `0` est aussi ce que vaut `cx` d'un objet à `d = 256`.

Un ennemi qui **sort par la droite** — un tabrok qui décolle, un cancer qui
s'en va — passe par `d = 245..255` puis `256+`. À `d = 250` avec `rx = 9`
(bink, cancer, brood, compiler : les plus larges du jeu), sa boîte s'étend de
241 à 259, et 259 s'enroule en 3. Un tir de base né à `cx = 0` avec
`rx = 3` : écart 6 après modulo, R = 12, contact. Le tir part du bord gauche
et frappe un ennemi 43 px au-delà du bord droit.

C'est bien « la boîte de l'ennemi qui s'enroule », et c'est la grande boîte
qui rend le contact possible : avec `rx = 3`, il faudrait `d ≥ 250`.

## 5. Ce que la borne fait, et ce que la v1 avait

La borne ne connaît pas ce problème. Son noyau `collision_test` (`0x40:F578`,
plaque Ghidra) compare des **mots de seize bits** : le centre de l'ennemi, un
AABB cible en `Xmin/Xmax/Ymin/Ymax`, quatre rayons signés. Aucun modulo.

La v1 avait exactement notre noyau (manifest 1:1) et **déjà** la sortie
gauche du tir simple commentée (`thomson-to8-game-engine/.../obj_simplefire.asm:98-99`).
Le bug était donc latent ; il n'y avait rien pour le déclencher tant que rien
d'armé ne partait à gauche. Le garde-fou « s'enrouler jamais » du tir de base
date du **31/08/2026** (`d94d06d43`, boîtes balayées) : c'est la première
rencontre du bug dans la v2, traitée localement.

## 6. L'axe vertical : même mécanisme, cas marginal

`cy` est l'octet bas de `y_pos`, qui est déjà en coordonnées écran (naissance
par preset sur un octet, `[28, 227]` visible). Seuls les objets qui **montent
au-dessus de zéro** s'enroulent : le tir vertical du pod vit jusqu'à
`y = −6` (`obj_simplefire.asm:107`), soit `cy = 250..255`, la bande du bas.
Face à un ennemi au ras du sol avec `ry = 18` (tabrok, brood) le contact est
à quelques pixels près — possible, jamais observé. À garder à l'esprit si un
tir vers le haut tue un jour un ennemi au sol.

## 7. Les options, avec leur prix

Le noyau seul ne peut pas trancher (§2) : deux positions distantes de 256
pixels lui arrivent identiques. Trois familles de correction.

### A. Ciblée — la zone de vie du laser reflex

Ramener la zone de vie gauche du long laser de −64 à −8, ou désarmer la tête
(`AABB.p = 0`, ou `RemoveAABB`) dès que `d < 0`. Une dizaine de lignes dans
`obj_reboundlaser.asm`. Règle le symptôme rapporté, et lui seul. Ne touche
pas au cas de la grande boîte.

Coût : nul. Portée : un objet.

### B. Générale — borner la projection

Généraliser le geste du tir de base : à la projection, `d < 0 → cx = 0`,
`d > 255 → cx = 255`. Un objet hors champ garde une boîte **du bon côté**, à
distance de tout ce qui est à l'écran ; les adjacences vraies (l'ennemi à
`d = −3` contre le tir à `d = 2`) restent des contacts.

```
        ldd   x_pos,u
        subd  glb_camera_x_pos
        tsta                           ; octet haut du decalage
        beq   >                        ; 0..255 : tel quel
        bmi   @neg
        ldb   #255                     ; au-dela de 255 : cale a droite
        bra   >
@neg    clrb                           ; negatif : cale a gauche
!       stb   AABB_0+AABB.cx,u
```

Cinq instructions de plus par objet et par tick, une dizaine de cycles ; à
soixante objets, moins d'un demi pour cent d'une trame. Le noyau et ses deux
copies ne changent pas.

Coût : un macro `_AABB.setCx` et **84 sites** à réécrire — mais l'idiome est
identique partout, c'est un remplacement mécanique. Même chose pour `cy` si
l'on veut fermer le §6 (76 sites, ou seulement les tirs verticaux).

### C. Exacte — des centres sur seize bits

Faire comme la borne : `cx`/`cy` sur deux octets, noyau en `cmpd`. Plus de
modulo nulle part, plus de règle à retenir.

Coût : la structure `AABB` passe de 9 à 11 octets, ce qui **décale toutes les
variables d'extension** de tous les objets ; 160 sites ; les trois copies du
noyau ; et une dizaine de cycles de plus par paire dans une boucle en O(n·m).
Le plus propre, et le plus cher.

### Décision (auteur, 03/09/2026) : B, et B seulement

Un chantier d'uniformisation par macro, traité progressivement. Les macros
`_AABB.setCx` / `_AABB.setCy` vivent dans `engine/collision/macros.asm`
(V2-DEVIATION tracée au manifest) ; la règle est écrite en cas de migration
dans `docs/lang/en/migration/aabb-screen-projection.md`. Premiers sites
convertis, pour prendre la main avant de scaler : le tir simple
(`weapon/obj.asm`, trois sites) et le beam (`beam/beam.asm`, trois sites) —
les segments balayés y sont désormais calculés en 16 bits de bout en bout,
le calage n'intervenant qu'au dernier geste. Le reste des sites
(`grep 'stb.*AABB\.c[xy]' src/`) est le reste-à-faire.

## 8. Ce qui reste à relever avant d'implémenter B

- les objets qui **sortent par la droite** au-delà de 255 en restant armés
  (tabrok au décollage, cancer, les couches du warship jusqu'à `XGONE = 255`) :
  ce sont eux que le calage à 255 concerne ;
- le **guidage du missile** (`PlayerMissile_Seek`, `player_missile.asm:446`)
  lit les `cx`/`cy` des ennemis sur un octet pour choisir sa cible : il peut
  viser un fantôme. Même correction, même macro ;
- le gestionnaire de balles (`_shared/bullets/mgr.asm`) et ses propres
  projections.
