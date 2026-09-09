# Le boss du stage 3 : le noyau du vaisseau — analyse arcade en vue du portage

Relevé du 09/09/2026, depuis la base Ghidra `maincpu` (asm-ark), le
catalogue de `re.arcade.r-type` et le code déjà porté du vaisseau
(`src/enemies/warship-elements/`, `src/stages/03/warship/`). Les adresses sont
en segment `0x40` (code) et `0x1000` (données). Les constantes converties
suivent la table du skill `enemy-port` (X × 0,375, Y × 0,75 avec l'axe
arcade vers le HAUT, comptes de trames gardés tels quels).

## 1. Ce qu'est le boss

Le stage 3 n'a pas de boss séparé : c'est le **noyau** (`create_warship_core`,
`40:dcc0`), une pièce du vaisseau comme les autres, semée par le script de
spawn du pilote (entrée 41 : seuil 412 → 155 en `mscroll.camera.x`, x 720 →
270, dy 24 → −18, priorité `0x6000`). Le maître (`tick_warship_master`,
`40:c4bc`, déjà porté par `warship/pilot.asm`) ne sait qu'une chose de lui :
le drapeau `[+0x3e]` que le noyau lève en mourant, et qui déclenche la fin du
stage. Aujourd'hui l'entrée 41 du script porte l'identifiant 0 (« pas encore
porté ») et la fin du stage est un combat de substitution : caméra au bout +
délai (`main.asm`, protocole endlevel).

Deux corrections au passage : `tools/objid-arcade.csv` nommait « warship-core »
la routine `0xc46e`, qui est le MAÎTRE (porté) ; le noyau est `0xdcc0`.

## 2. Le cycle d'états

Un seul objet, un compteur `[+0x10]`, un mot `[+0x20]` qui porte à la fois la
dérive en X et un drapeau de branche (bit 15). Toutes les phases ajoutent le
mouvement propre du vaisseau (`[0x2ed4]/[0x2ed6]`) : le noyau est ANCRÉ À LA
COUCHE, comme les autres pièces (`layer.evenX` / `layer.followY`), plus une
dérive de ±1 px arcade par trame dans les phases d'ouverture/fermeture.

| # | routine | durée (trames) | image | boîte | dégâts | sortie |
|---|---|---|---|---|---|---|
| 0 | `dce6` fermé | **1536** (25,6 s) | `core_anim`, 4 poses, `compteur & 0x18` (une pose par 8 trames) | aucune | invulnérable | `[+0x20]=+1`, 36 → 1 |
| 1 | `dd25` s'ouvre | 36 | `core_anim` (fermé) | `81ca` | ABSORBÉS | 63 → 2 (ou 2 bis si bit 15) |
| 2 | `dd8a` ouverture | 63 | `core_opening` poses 0→7, une par 8 trames (`(−compteur) & 0x38`) | `81ca` | ABSORBÉS | 128 (64 en difficile ou 2e boucle) → 3, flash à 0 |
| 3 | `ddf4` **OUVERT** | **64 ou 128** | `core_open`, fixe ; flash de coup 6 trames (palette `0x55`, une trame sur deux) | `81d2` (élargie à gauche) | **COMPTÉS**, armes seules (`v3_skip_player`) | mort si `[+0x1f] ≥ 20` ; sinon 63 → 2 ter |
| 2 ter | `df44` fermeture | 63 | `core_opening` poses 7→0 (`compteur & 0x38`) | `81ca` | absorbés | → `df85` : `[+0x20]=−1` (bit 15 levé), 36 → 1 |
| 1' | `dd25` recule | 36 | fermé, dérive **−1** px | `81ca` | absorbés | bit 15 → 2 bis |
| 2 bis | `df95` pompe et **tire** | 63 | `core_anim` (fermé) | `81ca` | absorbés | feu toutes les 8 trames (4 en difficile) ; → `[+0x20]=+1`, 36 → 1 |

Cycle après la dormance : 36 + 63 + (64..128) + 63 + 36 + 63 = **325 à 389
trames**, dont 64 à 128 vulnérables. Le noyau glisse de 36 px arcade vers la
droite en s'ouvrant (13,5 px TO8) et revient de 36 en se fermant.

« Dégâts absorbés » : la collision est faite (`do_collision_v2`, boîte
`81ca`), le tir touche et disparaît, mais `damage_taken` est sauvé et
restauré autour de l'appel — le noyau encaisse sans compter. Seule la phase 3
compte, et elle ignore le joueur (`f7e4`, armes seulement).

PV : `[+0x2f] = 0x14` posé à la création, jamais réécrit (le plate de `ddf4`
parle de `0x0a` posé par la phase 2 bis — rien dans le code). **20 points de
dégâts**, à traduire avec le modèle inversé (`AABB.p` descend) et la table
d'absorption de `doc/arcade-combat-reference.md`.

Difficulté : `[0x2f2d]` (drapeau difficile) et `[0x3e] ≥ 2` (2e boucle)
raccourcissent la phase 3 à 64 trames et doublent la cadence de feu.
Politique v1 : difficulté fixe, prendre 128 trames et le masque 7.

Écart de plate relevé : `dd25` annonce un SFX `0x52` à sa transition ; le
code (`dd72..dd89`) n'en joue aucun.

## 3. Les boîtes de collision

Format arcade `x_min, x_max, y_min, y_max` (mots signés, autour de l'ancre).

| table | arcade | TO8 (×0,375 / ×0,75) | usage |
|---|---|---|---|
| `1000:81ca` | −12..+12, −12..+12 (24 × 24) | ±4,5 × ±9 → 9 × 18 | phases 1, 2, 2 bis, 2 ter |
| `1000:81d2` | −32..+12, −12..+12 (44 × 24) | −12..+4,5 × ±9 | phase 3 (l'ouverture dépasse à gauche) |
| `1000:81f2` | ±4 × ±4 | ±1,5 × ±3 | le feu du noyau, contre le joueur |

## 4. Le feu du noyau (`e00f` / `e060`)

Un projectile par déclenchement, en phase 2 bis seulement, huit environ par
cycle.

- naissance : `noyau.x − 10, noyau.y + 16` arcade → (−4, −12) TO8 (l'axe Y
  arcade monte : +16 est 12 px AU-DESSUS de l'ancre à l'écran) ; SFX `0x5d` ;
- vitesse X : `±(0x80..0x17f)` en 8.8, signe au hasard → 0,5 à 1,5 px/trame
  arcade, 0,19 à 0,56 TO8 ;
- vitesse Y : `0x280..0x47f` → 2,5 à 4,5 px/trame, **décrémentée de 1/16 par
  trame** ; quand elle passe sous zéro le tick `e0d9` continue avec la vitesse
  négative : avec l'axe arcade vers le haut c'est une **fontaine** — le feu
  monte, ralentit, retombe. Le plate dit « vers le bas » ; à vérifier sous
  MAME avant d'écrire, le plate se trompe parfois d'axe ;
- image : `core-fire`, 4 variantes choisies par l'IDENTITÉ du slot objet
  (`BP & 0xc0`), tuiles `0xde`/`0xdf` avec deux attributs — exportées ce jour
  (6 × 12 TO8) ;
- fin : tuile solide (fg `< 0xdfc` ou bg `< 0x7d0`) → SFX `0x50` + petite
  explosion (`e7ae`) ; hors champ → silence ; touche le joueur → une fois.

## 5. La mort

Phase 3, `damage ≥ 20` (`de61`) :

1. `parent.[+0x3e] = 1` — le maître, à sa trame suivante, **efface 256 cases
   du plan arrière** (`0xd000:9d02`, pas de 4) puis entre dans son fondu ;
2. score : `update_current_stage_score(0x871c)` = index **13 → 10 000 points**
   (le plate y voit un « événement de fin de stage » ; c'est la table des
   récompenses, `0x86E8 + 13×4`) ;
3. SFX `0x53` ;
4. le noyau lui-même efface les mêmes 256 cases (`de86..de9e`, le même
   code que le maître en `c544`) ;
5. il pose l'enfant **cascade** (`dec9`, priorité `0xef00`) à sa position
   (+4 en Y), table d'offsets `1000:80ce`, vie 320 trames ; puis se
   transforme en petite explosion (`e7b6`).

La cascade (`dec9`) : une explosion toutes les 4 trames (`compteur & 3 == 0`),
`small_x3` (`e7b6`) ou, une chance sur quatre, la grosse grise-brune (`e817`),
SFX `0x52`/`0x53` au sort, aux offsets de la table qui BOUCLE jusqu'à la fin
de vie. Vingt-trois offsets arcade `(dx, dy)`, étendue −40..+192 × −72..+64
(le noyau est à l'extrémité gauche de la gerbe, qui s'étale vers la droite,
sur la coque) :

```
(-16,0) (8,-2) (16,4) (28,-4) (64,16) (80,-48) (152,48) (32,-16) (128,24)
(-32,-64) (56,48) (120,-8) (-40,-24) (64,-64) (32,16) (112,-48) (104,64)
(0,-32) (144,4) (0,-72) (192,24) (88,32) (32,-40)
```

En TO8 (`dx × 0,375`, `−dy × 0,75`) : (−6,0) (3,2) (6,−3) (10,3) (24,−12)
(30,36) (57,−36) (12,12) (48,−18) (−12,48) (21,−36) (45,6) (−15,18) (24,48)
(12,−12) (42,36) (39,−48) (0,24) (54,−3) (0,54) (72,−18) (33,−24) (12,30).

C'est exactement le patron du module commun `src/common/fx/bosscascade/`
(Gomander, Bellmite, Compiler, Bydo : même acteur borne) : une table
`{dx, dy, subtype}` générée par un `tools/gen_<boss>_death.py` avec le hasard
pré-tiré, `bosscascade.PERIOD = 4`, 80 entrées pour 320 trames.

Le maître ensuite (`c55d` → `c57d` → `c5e8`) : 384 trames de fondu (scroll
verrouillé, la coque part vers le haut à −64 ; à 320 trames restantes le
jingle et le drapeau de fin de niveau `[0x2fc1]` ; à 272 le noir de palette),
puis 448 trames de noir, puis l'init du stage 4. Chez nous cette séquence
existe déjà (`ObjID_endstage`, protocole du stage 1) — le portage remplace le
déclencheur « caméra au bout + délai » par « noyau mort ».

## 6. Les images

| jeu | arcade | TO8 | état |
|---|---|---|---|
| `core_anim` | 4 poses, 2 sprites 32 × 32 côte à côte, palette `0x39` | 24 × 24, ancre (−12, −12) | converti (déjà dans `images/`) |
| `core_opening` | 8 poses | 24 × 24 | converti |
| `core_open` | 1 pose | 24 × 24 | converti |
| `core-fire` | 4 variantes de 16 × 16, palette `0x02` | 6 × 12, ancre (−3, −6) | **exporté et converti ce jour** (entrée `core-fire` ajoutée à `data/catalog.yaml`, `--export-catalog`) |

Le flash de coup est un échange de palette (`0x39` → `0x55`) : pas de palette
par objet en v2. Les pièces du vaisseau n'en ont pas non plus (`reactor/obj.asm`
: « pas de clignotement de coup ») — à décider : rien, ou une pose alternative.

Les sons : `0x52`/`0x53` = `explosion.sfx.turret`/`.big` de nos explosions,
`0x50` = `.small` ; `0x5d` (lancement du feu) n'a pas d'équivalent v2 — une
décision d'auteur, comme pour tout son nouveau.

## 7. Le plan de portage proposé

1. **L'objet `core`** dans `warship-elements/core/` sur le patron des
   pièces (capsule/réacteur : `layer.evenX`, `followY`, boîte, `react.Show`
   si l'auteur le classe parmi les gros sprites mobiles — il fait 24 × 24,
   comme la petite capsule et le triangle, et il glisse). États 0..2 bis
   comme au § 2 ; PV 20 ; score index 13 (`warship_core_scoreIdx`, 10 000).
2. **Le feu** : un enfant `corefire` (vitesse 8.8 sur les deux axes,
   décélération 1/16, collision terrain par `terrainCollision`, boîte 3 × 6),
   4 images ; cadence 8 trames pendant la phase 2 bis.
3. **La mort** : `tools/gen_core_death.py` → table `bosscascade` (période 4,
   320 trames) ; le noyau pose l'enfant `ObjID_bosscascade` et meurt.
4. **La coque** : effacer 256 cases du plan (le carré `0x9d02` — sa position
   sur notre carte est à établir depuis `TileMap.java` : base du plan
   arrière et largeur 64) via la chirurgie de couche `mscroll` déjà prévue
   pour l'épave des sous-parties (tranche 3 du plan des pièces).
5. **La fin du stage** : `main.endstage` armé par la mort du noyau au lieu
   du délai, séquence existante.
6. **Câblage** : ObjID (noyau, feu), les cinq tables d'index, l'EXPORT du
   cast, `enemies_properties.asm` (score, boîte, dégâts), l'entrée 41 du
   script de spawn (`gen_warship_spawn.py`), pages d'images (le noyau et
   son feu vont dans `imgReactor`, page 18, 13 764 octets : 12 + 1 poses de
   24 × 24 et 4 de 6 × 12 y tiennent).

## 8. À vérifier avant d'écrire

- le sens du feu (fontaine vers le haut d'après l'axe, « vers le bas »
  d'après le plate) — MAME ;
- la position du carré de 256 cases effacé à la mort (`0x9d02`) sur la
  carte du vaisseau, et ce qu'il représente (la chambre du noyau ?) ;
- le sens du `[0x3e] ≥ 2` (2e boucle) — sans effet chez nous (difficulté
  fixe) ;
- si le noyau doit passer par le manager de tranches (`wsmgr`) ou rester un
  sprite entier : décision auteur.

## 9. Réalisé le 09/09/2026 — l'implantation

- `src/enemies/warship-elements/core/obj.asm` : le noyau (`core.*`, sept
  états, le cycle du § 2, PV 20, 10 000 points, dégâts absorbés hors phase
  ouverte par une boîte invincible) et son feu (`corefire.*`, fontaine
  8.8 avec gravité 12/256 par trame, décor et joueur, quatre variantes par
  compteur). Groupe `boss.Object`, bit 0 du sous-type (`boss.CORE`,
  `boss.FIRE`), `ObjID_warship_boss` = 45 (les assets bship glissent à
  46-50).
- Dessin par le manager de tranches (`core/slices.asm`, 52 tranches pour
  13 poses de 24 × 24), page `stage3.cast.imgCore` (12 952 octets, la
  sixième de l'arène) qui porte aussi le feu. Le flash de coup est un
  clignotement (pas de palette par objet).
- La mort : `bosscascade` commun avec la table générée par
  `tools/gen_core_death.py` (40 entrées, période 8, 320 trames, 9 grosses
  pré-tirées), direntry `stage3.cascade` sur le slot commun 29 ;
  `globals.bossDefeated` arme la fin de stage existante.
- Câblage : index (cinq tables), cast, `enemies_properties.asm`, entrée
  41 du script de spawn (`gen_warship_spawn.py`), `families.equ`,
  `to8.config.xml`.
- Vérifié sous toje : naissance au seuil, dormance 1512 trames de jeu,
  puis le cycle glisse (36) → ouverture (63) → ouvert (128) → fermeture
  (63) → recul (36) → pompe (63, 3 à 7 feux en vol) en boucle jusqu'à la
  fin du script ; mort forcée en phase ouverte → +10 000, cascade de
  320 trames, passation au stage 4. rtype_bench 7/7.
- **Non porté, à décider** : l'effacement des 256 cases de coque à la
  mort ; la collision joueur/noyau qui n'existe pas en phase ouverte dans
  l'arcade (ici la liste ennemie touche le joueur dans toutes les
  phases) ; le son de lancement du feu.
