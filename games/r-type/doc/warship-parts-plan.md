# Le vaisseau du stage 3 : ses 68 pièces — étude et plan de campagne

Relevé le 27/08/2026. La couche battleship défile et elle est solide ; il lui
manque **tout ce qui vit dessus**. Cette étude cadre la campagne et découpe le
travail en tranches livrables.

## 1. Ce qui existe déjà — plus que prévu

| pièce | où | état |
|---|---|---|
| la couche mscroll + sa chorégraphie | `warship/pilot.asm`, `camera-script.asm` | **fait** |
| la collision de fond (silhouette) | `03/collision/` + `BG_OWN_CAMERA` | **fait** |
| l'art des 39 éléments | `src/enemies/warship-elements/images/` | **converti** (16 poses par tourelle) |
| le script de spawn, converti en v2 | `re.arcade.r-type/out/warship/warship-spawn-script.asm` | **exporté**, squelette en attente d'ObjIDs |
| les index de score | `enemies_properties.asm` | **posés** (`warship_*_scoreIdx`) |
| `setDirectionTo`, `loadFirePreset`, `createFoeFire` | `src/common/lib/` | **résidents** |

Autrement dit : ni extraction, ni conversion d'art, ni outil à écrire. Il
manque **le code des objets** et leur câblage.

La place non plus n'est pas un souci ici, contrairement au stage 2 :
**l'arène `stage3.foes` (7 pages, 112 Ko) est entièrement vide.**

## 2. Le mécanisme arcade — `warship_scrolling_spawner` (`40:c61f`)

Un unique script de **68 entrées de 10 octets** (`1000:6ce0`), parcouru par un
curseur, déclenché au **seuil de défilement du vaisseau** :

```
seuil (mot)  | x (mot) | dy (mot signé) | tick (mot) | priorité (mot)
```

Le spawner compare le seuil à `-warship.X`, c'est-à-dire à la **distance
parcourue par la couche** — chez nous `mscroll.camera.x`, qui va de 0 à 285.
Les seuils convertis couvrent **6 à 240** : ils tombent tous dans la course.

L'enfant naît à `x` (toujours 266-282, soit le bord droit du cadre) et à
`parent.Y + dy`. Composition :

| famille | nb | tick arcade |
|---|---|---|
| **sous-parties de coque** | **27** | `C656..C78E` (une vignette chacune) |
| petite tourelle HAUT | 10 | `E26A` |
| petite tourelle BAS | 7 | `E277` |
| grosse tourelle | 5 | `E129` |
| tourelles de proue | 6 | `D596..D5D7` |
| tourelles multiples | 4 | `DB63..DB8A` |
| réacteurs de ventre | 4 | `D8B7..D8DE` |
| réacteur arrière, capsules, triangle, cœur | 6 | `CBEF`, `D39E`, `CFE9`, `D095`, `DCC0` |

## 3. La découverte qui simplifie tout : les sous-parties n'ont pas de sprite

`warship_part_install` (`40:c797`) le dit sans détour :

> *The sub-part has NO per-frame sprite paint. Its visible presence on screen
> comes from the warship's BG tilemap.*

Les 27 sous-parties de coque sont des **boîtes de collision et de dégâts** qui
chevauchent la couche — 12 PV chacune, aucun dessin. Chez nous la couche est
déjà peinte par `mscroll` : **il n'y a rien à dessiner, seulement à toucher.**

Leur seul rendu propre arrive à la mort : une épave blittée dans la tilemap
(`c846 → c8d6 → c8e8`) — la grille de tuiles de la queue de la recette,
`{aabb, x_off, y_off, lignes, colonnes}` puis lignes × colonnes mots de
tuile en colonnes, écrite à la CELLULE de l'ancre de la pièce. La coque est
détruite zone par zone au fil des attaques, et le reste jusqu'au
rechargement de la tilemap (checkpoint). **Fait le 10/09/2026** sans
chirurgie de couche : voir la tranche 3 au § 8.

## 4. Les tourelles autonomes — le patron que la v2 sait déjà faire

`tick_warship_small_turret_standalone` (`40:e2aa`), 17 instances :

- **suit la couche** — applique le delta de scroll du vaisseau (`0x2ed4`/`0x2ed6`) ;
- **vise le joueur** : `set_direction_to(max_dir=0x20)`, décalé à droite d'un
  bit → **roue à 16 directions**, qui indexe sa table de poses ;
- **tire** par `load_fire_preset(0x10)` — le préréglage 1, et `loadFirePreset`
  est **déjà résident** en v2, même sémantique (id dans les bits 4-7 de B) ;
- **12 × 24 de boîte**, posée **au-dessus** de l'ancre pour la variante HAUT
  (`y −14..−2`), en dessous pour la BAS (`+2..+14`) ;
- **2 PV**, éclat de coup 5 trames, mort → explosion `small_x2` + score
  index 1.

La grosse tourelle (`40:e157`, 5 instances) est le même patron : boîte plus
large (`y −12..+4`), **4 PV**, score index 2, une seule orientation.

Tout cela se traduit sans invention : `setDirectionTo` et `loadFirePreset`
existent, la roue à 16 directions est celle du wick et du gouger.

### Un choix v2 : la position vit dans le repère de la COUCHE

L'arcade pousse à chaque trame le delta de scroll dans la position de chaque
tourelle. On peut faire mieux et plus juste : **ranger la position en
coordonnées de couche** et dériver l'écran par `map − camera` à l'affichage.
Le résultat est identique, la compensation de frame-drop est gratuite (elle
est déjà dans la caméra), et rien ne dérive à l'accumulation. C'est le geste
que le plan de collision de fond vient d'adopter, pour la même raison.

## 5. Le découpage en tranches

| # | tranche | contenu | dépend de |
|---|---|---|---|
| **1** | **le spawner + les tourelles autonomes** | le parcours du script, `ObjID_warship_turret` (HAUT/BAS) et `ObjID_warship_bigturret` — 22 des 40 externes | — |
| 2 | les 27 sous-parties | boîtes de collision, 12 PV, explosion à la mort ; **sans** l'épave | 1 |
| 3 | l'épave dans la tilemap | `c8e8` — **FAIT le 10/09/2026** : un patch de la carte mscroll, appliqué à la mort, défait au checkpoint (`bship/patch.asm`) | 2 |
| 4 | tourelles de proue et multiples | 10 objets, patrons voisins | 1 |
| 5 | réacteurs, capsules, triangle | 10 objets, comportements propres | 1 |
| 6 | le cœur et la fin de séquence | `DCC0`, le fondu vers le stage 4 — **FAIT le 09/09/2026** (`core/obj.asm`, `doc/analyse-boss-stage3-2026-09.md` § 9 ; l'« effacement de coque » était une lecture fausse, cf. § 8) | 2, 5 |

La tranche 1 est la fondation : **le spawner sert tout le reste**, et les
tourelles sont l'élément que l'on voit et que l'on tire en premier. Les
entrées dont le tick n'est pas encore porté sont simplement **ignorées** par le
parcours, ce qui rend chaque tranche indépendamment livrable.

## 6. Tranche 1 — livrée le 27/08/2026

Le spawner et les 22 tourelles autonomes tournent. Ce que la mise en œuvre a
appris :

- **le parcours vit AVEC ses données.** Le mettre dans le pilote a fait
  déborder l'unité du stage sur le bloc du banc en page résidente ; il est
  donc dans le direntry du script, que l'appelant monte d'un `_SetCartPageA`.
  `LoadObject_x` ne touche pas la fenêtre cartouche — c'est ce qui permet de
  revenir dans le parcours après l'allocation.
- **l'export convertit l'abscisse comme un delta.** Les trois champs
  convertis par l'extracteur ne sont pas de même nature : le seuil et l'écart
  en y sont des **distances** (le rapport suffit, l'export est juste), mais
  l'abscisse est une **position** — il lui faut le décalage d'origine,
  `(x − 320) × 0,375 + 8`. L'export donne 269 là où le jeu attend 157, et les
  tourelles naissaient 109 px au-delà du bord droit, donc culées à la
  naissance : rien à l'écran, aucune erreur. La correction est affine et
  exacte (`x_export − 112`), appliquée dans le générateur — **à remonter à
  l'extracteur** (`re.arcade.r-type`).
- **le rendu est propre** : le moteur est en mode overlay, les sprites
  n'effacent pas leur fond et le blast de la couche fait l'effacement. Rien à
  ajouter pour composer par-dessus le vaisseau.

## 7. Tranche 2 — livrée le 27/08/2026

Les 27 sous-parties de coque. Ce sont bien de pures boîtes : l'objet ne
dessine rien et son `Live` se termine sur un `rts`, pas sur `DisplaySprite`.

- **le compte était de 27, pas 28.** La 28ᵉ entrée à priorité `0x6000` du
  script est le CŒUR (`DCC0`), pas une sous-partie ; le pré-commentaire des
  vignettes le dit (« 27 WARSHIP PART INSTALLER THUNKS »).
- **les boîtes sortent de la ROM, pas d'une recopie.** `gen_warship_parts.py`
  suit les deux indirections — vignette → recette → boîte — dans le dump
  arcade et convertit par la formule de la table. Chaque ligne produite cite
  son adresse de recette et de boîte, et le générateur vérifie que tout tient
  dans un octet.
- **l'explosion de coup n'est pas décorative** : sans sprite, elle est le
  SEUL retour visuel quand le joueur touche la coque. C'est pour cela que
  l'arcade la tire à chaque dégât encaissé, et on la porte telle quelle.
- **la collision est testée à chaque trame**, là où l'arcade alterne une
  trame sur deux : chez nous la boîte est inscrite dans une liste que le
  moteur confronte, il n'y a pas de sondage par objet à amortir — alterner
  reviendrait à inscrire et retirer la boîte, plus cher et moins juste.

## 8. Ce qui reste à trancher, le moment venu

- **l'épave** (tranche 3) — **FAIT le 10/09/2026**, par la voie arcade : un
  PATCH de la carte mscroll. La chaîne : `re.arcade --extract-warship` écrit
  `out/warship/warship-wreck.csv` (la cellule de chaque grille) et
  `level3_b_wrecked.png` (le fond du stage 3 avec les 27 épaves en place) ;
  `tools/gen_warship_wreck.py` le convertit comme la coque
  (`arcade_to_mscroll.py --out`, mêmes forces) en
  `map/battleship-wrecked.png` + `battleship-wrecks.csv` ; l'élément
  `<mscroll patches=… patchimage=…>` ajoute les tuiles d'épave au jeu (94,
  251 dans le jeu, 3 Ko par plan) et génère `bship/battleship.patches.asm` :
  par pièce, les cellules à réécrire (offset, id d'origine, id d'épave).
  Runtime : la pièce survit 26 trames sous son explosion puis DEMANDE son
  patch (`bship.patch.request`) ; la boucle de stage l'applique après
  `mscroll.move` (`bship/patch.asm` : carte réécrite, colonnes visibles
  re-nourries par `mscroll.feedTile`) ; `stage.setup` défait tout patch
  appliqué AVANT `mscroll.setup` au retour au checkpoint (la carte n'est pas
  rechargée). Coût par trame : zéro.
  **La voie sprite, essayée le même jour et refusée** : l'épave dessinée en
  sprite de fond chez `wsmgr` (deux fichiers d'images, 13,5 Ko) coûtait
  1 700 cycles par épave et par rendu, mesurés sous toje sur un stage sans
  aucune attente — neuf épaves faisaient passer la période de rendu de 8,3 à
  9,1 trames (`prof-wreck`, deux boots déterministes, même scène).
  La CELLULE arcade : ancre = (camera + pos_x − 320, camera_y + 383 − pos_y),
  caméra (128, 0) à la naissance du maître — trouvée en comptant, pour chaque
  décalage de 8 px, les cases d'épave identiques à la coque qu'elles
  remplacent (100 contre 52) ; les 27 ancres tombent alors à (+4, +3) dans
  leur cellule. Et `wsmgr.Reset` remet à zéro l'état RÉSIDENT des managers
  (wsmgr, table des gerbes) au premier tour du pilote : sans lui,
  `wsmgr.live` restait à 1 sans objet et plus aucune pièce mobile ne
  s'affichait après une mort.
  **Les réacteurs de ventre** (10/09/2026, même jour) : en arcade chaque
  réacteur mort fait naître une sous-partie de coque de plus (`c9a0`..`c9c4`,
  nommée par son installateur `d8b7`..`d8de`, à x − 12, y + 28/52/36/36), 12 PV,
  dont la mort blitte l'épave de la zone au-dessus du réacteur (`cb26`), et
  laisse un moignon en feu (`da49`) qui explose quand la pièce tombe. Porté :
  la pièce seule, rangs 27 à 30 de `part.Object` (`part.REACTOR0`,
  `part.ReactorDy` dans `boxes.asm`, le rang du réacteur dans les bits 4-5 de
  son sous-type, `react.VARIANT`), née dans `breactor.Boom` ; ses épaves sont
  les patches 27 à 30 (l'export re.arcade les ajoute derrière les 27).
  **Le moignon en feu** (même jour, en sprite, décision auteur) : le réacteur
  mort ne s'efface pas, il passe en état `breactor.Stub` — l'image
  `bottom-reactor-bottom-wreckage` à sa place, 10 PV neufs dans la même boîte
  (`da9e`), une bouffée toutes les 128 trames à une phase tirée au sort
  (`da61`), et il explose quand sa pièce d'épave tombe ou sous les dix coups.
  La bouffée est la zone 3 du manager de gerbes (`small-puffs`, chaîne
  `0x7fc4`, quatre pas de cinq trames) : armée avec une vie de quatre pas
  (`flamemgr.LIFE_PUFF`), sa chaîne est calée en queue des dix du manager,
  ses tranches dans la page `imgFlame`. Elle vieillit d'**un pas par rendu**,
  pas du frame-drop (décision auteur) : vieillie du drop, à 8 trames par
  rendu elle passait par les vies 20, 12, 4 et la pose 2 n'était jamais
  dessinée. Vérifié sous toje : vies 20, 15, 10, 5, une par rendu. Le signal de la pièce est le bit
  27 + rang du bitmap des patches, lu par le moignon — aucun lien entre
  objets. **Mesure** (toje, 400 trames, même scène, trois boots) : quatre
  réacteurs vivants 47 rendus (169 800 cycles par rendu) ; les quatre morts
  sans moignon 50 rendus (159 600) ; quatre moignons 47 rendus (169 800).
  Un moignon coûte ce que coûtait le réacteur vivant, 2 500 cycles par
  rendu ; la scène ne s'alourdit pas quand les réacteurs meurent, elle ne
  s'allège plus. Piège vécu : le compteur de bouffée logé en `ext+20`
  tombait sur la réserve du moteur de sprites (`ext_variables_size` = 20),
  réécrite à chaque rendu — une bouffée par rendu, 33 000 cycles.
  Conséquence : 263 tuiles dans le jeu mscroll, au-delà du format
  court — les deux tilesets passent en PLEINE PAGE ($1B et $1C à $0000, page
  27 était vide), la carte reste en $1D. Piège vu : au-delà de 256 tuiles le
  fichier de 16 Ko posé à $2000 était « unplaced » dans le rapport et le
  build sortait quand même en 0.
- **le signal de mort du parent** : chaque pièce lit `parent.[+0x3e]` pour
  mourir avec le vaisseau. Il faudra un drapeau partagé, et le pilote est le
  porteur naturel.
- **les sons** : aucun dans ce portage, comme partout ailleurs.

## Le manager des gerbes (28/08/2026)

Les gerbes des reacteurs de ventre ne sont plus des objets. Trois raisons se
sont cumulees :

1. **Le rejet en bloc.** `BuildSprites` ne clippe jamais : une gerbe de 48
   lignes disparait entierement des que son bas sort de la bande, alors que sa
   buse est encore visible. Quand le vaisseau descend, c'est pres d'une seconde
   de jet manquant sur 44 px de bande morte.
2. **Le cout de trancher.** La parade est de couper en quatre tranches de 12
   lignes (bande morte ramenee a 8 px), mais quatre reacteurs qui tirent
   ensemble auraient fait **seize objets d'un coup**.
3. **La page.** `Img_Page_Index` ne donne qu'UNE page d'images par identifiant,
   et les trente poses des trois gerbes en occupaient trois.

La sortie est le patron `outslay.Render`, deja au depot : **un objet unique qui
gare sa boite au centre de l'ecran** — donc jamais elimine — **et peint
lui-meme**, tranche par tranche, ce qui tient dans la bande. Ce qui l'a rendu
possible est la **deduplication** : la chaine arcade ne designe que quatre
poses uniques sur ses dix pas. Les trois gerbes tranchees pesent **11,9 Ko**,
une page — au lieu de 36 Ko sur trois.

Deux details ont fait tout le travail :

- **Les quatre tranches gardent le canevas de 48 lignes** et n'en peignent que
  douze. L'encodeur rogne les bords transparents mais rapporte les bornes au
  centre du *canevas* (`Image.java : x1_offset = x_Min - (width-1)/2`) : les
  tranches partagent donc l'ancre tout en portant chacune la boite de ses
  douze lignes. Le dessin se fait aux memes coordonnees, sans un calcul, et le
  test de bande reste par tranche.
- **Le code du manager vit avec son art.** BuildSprites monte la page d'images
  de l'objet avant d'appeler sa routine de dessin : le dessin et ce qu'il
  dessine partagent la page. Le cast n'y entre jamais — il **arme des slots**
  dans une table **residente** (`reactor/flameslots.asm`), lue par la page des
  flammes. D'ou les copies locales des trois services de couche.

Bilan : trois direntries et trois identifiants deviennent **un et un**, seize
objets simultanes deviennent **zero**, et la gerbe suit le vaisseau jusqu'au
bas de l'ecran.
