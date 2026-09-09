# Les pièces mobiles du vaisseau : priorité de fond et manager de tranches

Plan du 09/09/2026. Demande de l'auteur : les **gros sprites mobiles** du
stage 3 passent en priorité de fond par rapport aux autres sprites, et, vu
leur taille, ils sont affichés par morceaux par un manager, comme les
gerbes d'alors, avec un découpage de 16 px au plus en largeur et 12 en
hauteur.

**Le périmètre, fixé par l'auteur le 09/09** : triangle qui tombe, petite
capsule, capsule de survie, les trois gerbes des réacteurs de ventre
(gauche, droite, bas), les flammes géantes du réacteur arrière, son
allumage, et le réacteur arrière lui-même. Les tourelles (petites, grosse,
proue, multiples), les réacteurs de ventre, la boule de feu, l'éclat, le
laser et la balle blanche sont de petits sprites accrochés à la coque :
ils restent entiers, à leur rang. (Première lecture erronée, corrigée le
même jour : j'avais commencé par trancher la tourelle multiple.)

## 1. Ce que fait le moteur

`BuildSprites` tient huit rangs, 2 devant et 8 derrière (1 = overlay
fixe, 0 = non enregistré) ; il dessine du rang 8 au rang 1. Il **rejette
en bloc** un sprite qui déborde de la bande, il ne clippe jamais. Le
joueur et les ennemis sont au rang 6, le tir du joueur au 2, les effets
du vaisseau (boule de feu, éclat, flammes géantes, laser) au 4.

Le manager des gerbes (`reactor/flamemgr.asm`) est le modèle : un objet
dont la boîte est garée au centre de l'écran, donc jamais éliminé, et dont
le faux imageset renvoie à une routine à lui que `BuildSprites` appelle
avec sa page montée. La routine parcourt une table résidente de slots
(armés par les réacteurs), calcule l'ancre de chaque gerbe et dessine ses
quatre tranches de 12 lignes une à une, avec le test de bande par tranche
(`_sprite.cull`, `DRS_XYToAddress`, `jsr` sur la routine compilée). Les
tranches gardent le canevas complet et n'en peignent qu'une bande :
elles partagent l'ancre, le dessin ne calcule aucun décalage.

Sa limite structurelle : `BuildSprites` ne monte **qu'une page par
identifiant**, et le manager dessine depuis cette page. Les tranches qu'il
peint doivent donc vivre dans son direntry — les 48 tranches des gerbes
tiennent dans les 16 147 octets de la page 16, pleine.

## 2. La priorité de fond — FAIT

Rang 8 pour les pièces structurelles : petites et grosse tourelles,
tourelles de proue, tourelles multiples, réacteur de queue, réacteurs de
ventre, capsule et petite capsule, triangle. Les effets restent au 4 (ils
passent devant les pièces, ce qui est leur place : les gerbes sortent des
buses) et les tirs à leur rang. Les 27 sous-parties de coque n'ont pas de
sprite, rien à changer.

## 3. L'inventaire des tranches à 16 × 12

Taille du cadre TO8 et tranches par pose, sur les jeux réellement montés :

| jeu d'images | poses | cadre | tranches/pose | tranches |
|---|---|---|---|---|
| small-turret-top-wheel, bottom-wheel | 9 + 9 | 18×24 | 2×2 = 4 | 72 |
| big-turret-wheel | 9 | 12×24 | 1×2 = 2 | 18 |
| front-turret a/c/e (wheel) | 7 + 7 + 6 | 18×36 | 2×3 = 6 | 120 |
| front-turret b (wheel) | 5 | 18×24 | 2×2 = 4 | 20 |
| front-turret d (wheel) | 5 | 18×30 | 2×3 = 6 | 30 |
| multi-turret ×4 | 4 × 4 | 12×24 | 1×2 = 2 | 32 |
| fire-ball, fireball-flash | 22 + 8 | 12×24, 12×18 | 2 | 60 |
| rear-reactor | 1 | 36×24 | 3×2 = 6 | 6 |
| reactor-startup | 4 | 48×48 | 3×4 = 12 | 48 |
| reactor-flame 0/1 | 1 + 1 | 48×24 | 3×2 = 6 | 12 |
| bottom-reactor (6 jeux) | 6 | 12×24, 18×24 | 2 ou 4 | 20 |
| escape-capsule | 1 | 60×24 | 4×2 = 8 | 8 |
| small-escape-capsule, falling-triangle | 1 + 1 | 24×24 | 2×2 = 4 | 8 |
| horizontal-laser | 4 | 18×6 | 2×1 = 2 | 8 |
| reactor-white-bullet | 4 | 6×12 | 1 | 4 |
| flame-wheel (les gerbes, déjà tranchées en 4 × 12 lignes) | 48 | 24×48 | **2×4 = 8** | **384** |

**Le coût d'une tranche** : mesuré sur le gouger coupé en deux, +442
octets pour 23 routines de plus, soit ~19 octets par tranche (le
`LEAU`/`RTS` de la routine et son entrée d'imageset ; les pixels, eux, ne
coûtent pas plus une fois répartis). Par page :

| page | aujourd'hui | tranches en plus | estimation |
|---|---|---|---|
| imgTurret (20) | 7 119 | +63 | ~8,3 Ko |
| imgFront (19, avec le cast 5 432) | 9 677 | +136 | ~12,3 Ko — le cast doit changer de page |
| imgFire (17) | 13 215 | +46 | ~14,1 Ko |
| imgReactor (18) | 11 478 | +~90 | ~13,2 Ko |
| imgFlame (16) | 16 147 | +192 | **~19,8 Ko : ne tient pas** |

**Point tranché (auteur, 09/09) : les gerbes sont dans le périmètre**, en 16 × 12, sur deux pages — voir § 4 bis. Le raisonnement d'origine : les gerbes font 24 px de large : la règle 16 × 12
les recoupe en deux colonnes, 384 tranches au lieu de 192, et leur page
est pleine à 237 octets près. Soit les gerbes gardent leur découpe
actuelle (4 tranches de 24 × 12, une exception à la règle), soit elles
prennent une seconde page. La bande morte que la règle vise est verticale
(la coque monte et descend) ; en largeur le vaisseau ne sort de l'écran
que par la gauche, en défilant. Je recommande l'exception.

## 4. L'architecture proposée

**Un manager résident, pas un par page.** Le manager des gerbes vit dans
sa page d'images parce que `BuildSprites` n'en monte qu'une. Pour dessiner
depuis cinq pages, la routine de dessin doit être en RAM permanente : le
faux imageset lui donne une page quelconque, elle monte elle-même la page
de chaque slot (`_SetCartPageA`), dessine ses tranches, et remonte celle
d'entrée avant de rendre la main. Place : `stage3.res` ($92DB, 2 800
octets, 65 pris par la table des gerbes) ou le main du stage 3 (~870
libres). Le dessin (~350 octets) et la table (~30 slots × 7 octets)
tiennent dans l'un comme dans l'autre.

**Le protocole des pièces.** Une pièce ne pose plus `image_set` et ne
passe plus par `DisplaySprite` : à chaque tick elle *inscrit* un slot —
page, table de tranches de sa pose, x et y écran (ceux qu'elle calcule
déjà pour sa boîte). La table est vidée par le dessin qui la consomme :
pas d'armement, pas de durée de vie, une liste reconstruite chaque trame.
L'ordre d'inscription est l'ordre de peinture (le manager peint, il ne
trie pas) ; à l'intérieur d'une pièce, les tranches du bas d'abord comme
les gerbes.

**Le manager lui-même** : un objet de rang 8, boîte garée au centre,
faux imageset → routine résidente ; il ne fait que rester en vie tant que
le vaisseau est là (le maître du vaisseau le pose et le retire). Les
gerbes restent au leur, rang 4, tel quel.

**Le générateur.** `tools/gen_warship_slices.py` : pour chaque jeu
d'images, découpe chaque pose en tranches ≤ 16 × 12 **sans toucher au
canevas** (le geste de `gen_warship_flames.py` : chaque tranche garde le
canevas et n'en peint que sa fenêtre, l'encodeur rogne et rapporte
l'ancre au centre — même ancre pour toutes), écrit les PNG dans
`images/<jeu>-slices/` et une table asm par jeu : pour chaque pose, les
imagesets de ses tranches, dans l'ordre de peinture. Les entrées
`<images>` du config passent sur les dossiers tranchés ; les tables de
roue (`gen_turret_sets.py`, `gen_warship_frontmulti.py`) désignent des
poses, elles ne changent pas.

## 4 bis. Ce qui est fait (09/09/2026)

- `wsmgr/wsmgr.asm` (résident, `stage3.res`, 495 octets) : 24 slots,
  listes de 8 tranches au plus, page des descripteurs par slot, montage
  de la page de la routine par tranche, `_sprite.cull` par tranche.
- `tools/gen_warship_slices.py` : rear-reactor (6), reactor-startup (14
  sur 4 poses, les fenêtres vides ne sont pas émises), reactor-flame-0/1
  (6 + 6), escape-capsule (8), small-escape-capsule (4), falling-triangle
  (4) → `images/<jeu>-slices/`, listes `react.sl.<jeu>.<pose>` dans
  `reactor/slices.asm`.
- `tools/gen_warship_flames.py` : les gerbes en fenêtres 16 × 12, 76
  tranches pour 12 poses uniques, **un dossier par gerbe**
  (`images/flame-wheel-d|r|l/`) parce que les trois ne tiennent plus dans
  une page (16 778 octets) : la gauche loge dans la page des tourelles
  (`flame.PageIds` donne, par gerbe, l'identifiant dont `Img_Page_Index`
  est la page). Pages : flammes 10 572, tourelles 13 325, réacteur 13 764.
- `reactor/flamemgr.asm` vit dans le cast : il vieillit les slots et
  inscrit chaque gerbe chez wsmgr au tick, avec la caméra du tick. Plus de
  faux imageset, plus de copies des services de couche, plus d'unité dans
  la page des flammes (`flamemgr.unit.asm` supprimé).
- Les pièces : `react.Show` (reactor/obj.asm) inscrit avec la page du
  groupe ; réacteur arrière, flammes géantes et allumage (`rflame.Show`,
  avec la borne des pièces faute de boîte), capsule (`capsule.Show`) et
  détachables n'ont plus d'`image_set` ni de `DisplaySprite`.

**Le test d'apparition en X compte la bordure** (retours auteur du 09/09,
après la première vidéo : les tranches poppaient à 16 px du bord droit ;
puis après un recouvrement pur, qui laissait le retour de ligne dans le
champ). L'écran a une bordure de 8 px de chaque côté : la fenêtre du test
est [−8, 168). Une tranche fait 16 px au plus et la ligne qui déborde à
droite revient à gauche de la suivante : ce qui sort par un bord tombe
dans la bordure de ce bord ou, par le retour de ligne, dans celle de
l'autre, jamais dans le champ. Une tranche apparaît donc dès que huit de
ses pixels sont entrés. Bornes du contenu (imageset), toujours dans la
tranche théorique. En Y le test reste strict, c'est le sol qui l'exige.

**Mesures** (toje, passage du vaisseau, 1 000 rendus) : rtype_bench 7/7 ;
le dessin coûte 2 500 à 3 600 cycles par pièce de 6 à 8 tranches, 1 200
par gerbe quand une partie de ses tranches sort de la bande ; un rendu à
8 pièces inscrites, médiane 9 800 cycles, au pire 25 500. Les 25 captures
du balayage montrent chaque pièce en place : flamme géante derrière le
réacteur arrière, jets coupés net sur le sol, capsule et son laser.

## 5. Les étapes

1. Le générateur et le manager résident, protocole, mesure du coût sous
   toje. **FAIT (09/09)**, d'abord sur la tourelle multiple (hors
   périmètre, remise en sprite entier ensuite). Défaut trouvé au passage :
   la recopie de la liste comptait avec B, que `ldd ,y++` écrase — la
   copie courait jusqu'à un octet nul et recouvrait le code du manager
   (stage 3 figé dans les données de la page du cast). Le compteur est
   sur la pile.
2. Le périmètre entier — réacteur arrière, allumage, flammes géantes,
   gerbes, capsules, triangle. **FAIT (09/09)**, voir § 4 bis.

Ce qui sera mesuré à chaque étape : la taille des pages (occupancy), le
coût par rendu du manager (`object_cost_probe.py`), rtype_bench, et une
vidéo du stage 3 aux réglages habituels.
