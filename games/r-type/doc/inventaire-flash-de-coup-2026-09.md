# Le flash de coup : inventaire des ennemis à plus d'un point de vie (11/09/2026)

Demande de l'auteur : tout ennemi qui encaisse plusieurs coups doit
montrer **une trame blanche** au coup encaissé. L'arcade le fait partout où
elle compte les dégâts : à la création chaque acteur prend une seconde
palette (`get_palette_id 0x55`, dans `[+0x3c]`), et sur le drapeau « touché »
de sa routine de collision il arme `[+0x3d]` (5 ou 6 trames) ; le dessin
échange la palette une trame sur deux tant que le compte court. Chez nous la
palette est globale au stage : **on échange l'image**, une pose blanche
compilée, et le compte à rebours se tient sur la baisse de `AABB.p` (la passe
de collision précède les objets). L'idiome est celui du Tabrok : **une seule
trame de blanc** — à notre cadence, trois éclairs sur douze trames se
collent en une tache (mesure du 03/09/2026) — et **peu d'images blanches**
pour beaucoup de poses (deux pour huit chez le Tabrok, quatre orientations
chez le Gouger, une par forme chez Slither).

PV relevés dans `enemies_properties.asm` et les `*.HP` des pièces du
vaisseau. Sont exclus : les tirs et gerbes (1 PV), les ennemis à 1 PV
(Pata-Pata, Bug, Blaster, Bink, Cancer, Geld, Wick, Outslay, œil du
Dobkeratops), et les invincibles.

## Fait

| ennemi | stage | PV | arcade | chez nous |
|---|---|---:|---|---|
| Tabrok | 1 | 30 | `661a`, 12 trames une sur quatre | `tabrok.hitBlink`, 2 images blanches (vol, sol) pour 8 poses |
| Dobkeratops | 1 | 30 | palette 0x55 | `hitFlash` du monstre |
| Scant | 1 | 30 | 0x55 | `images/hit`, 2 poses |
| P-Staff | 1 | 6 | 0x55 | `pstaff.hitBlink`, `images/hit` |
| Gouger | 2 | 10 | 0x55 | 4 images blanches, une par orientation |
| Brood | 2 | 40 | `[+0x3d]` | `brood.blink`, unité `imgBroodHit` (5 638 o) |
| Zoid | 2 | 4 | `8ecc` recul + flash | objet `zoid_hit`, unité `imgZoidHit` (525 o) |
| Gomander | 2 | 8 | deux acteurs de flash de palette | `blink` du boss, réservé au coup |
| Noyau du vaisseau | 3 | 20 | `de30`, 6 trames une sur deux | `core_open_flash`, 2 tranches (rogné, 11/09) |
| Compiler, ses trois pièces | 4 | 40 | 0x1F trames | `cpl.HIT_FLASH` |
| Slither, corps et tête | 5 | 6 / 14 | `7d22`/`7d45`, 3 trames sur 4 | `fBlink`, `body_hit_round`, `head_hit`, `tail_hit` |

## À faire

| ennemi | stage | PV | arcade | poses à blanchir | note |
|---|---|---:|---|---:|---|
| **Cytron** | 2 | 3 | `6a78` draw_with_hit_blink, 0x55 | 16 (une roue) | le compteur `blink` est déjà tenu, il ne montre rien (V2-DEVIATION notée) : il manque l'image |
| **petite tourelle** du vaisseau | 3 | 2 | `e2aa`, `[+0x3d]=5`, SFX 0x56 | 9 haut + 9 bas (roues) | 17 exemplaires, la plus fréquente à toucher |
| **grosse tourelle** | 3 | 4 | `e157`, idem | 9 (roue) | |
| **tourelle multiple** | 3 | 4 | `dbb5`, idem | 4 × 4 orientations | animation temporelle |
| **tourelle frontale** | 3 | 14 | `d608`, idem | 11 (une roue PARTAGÉE par les cinq variantes depuis le 11/09) | 14 PV : le flash se verra |
| **réacteur arrière** | 3 | 20 | `cc1b`, `[+0x3d]=5` | 1 (le corps, 3 sprites) | |
| **réacteurs de ventre** | 3 | 18 | `d90e`, `[+0x3d]=5` | 6 orientations (3 images + miroirs) | le moignon en feu (10 PV, `da49`) : à vérifier dans l'arcade, le plate ne le dit pas |
| **capsule de survie** | 3 | 20 | `d3c9`, 0x55 | 1 | |
| **petite capsule** et **triangle** | 3 | 10 | `d0ff`, `[+0x3d]=5`, une trame sur deux | 1 + 1 | même tick arcade |

## Sans objet

- **les 27 sous-parties de coque** (12 PV) : pas de sprite, elles sont des
  tuiles de la carte — l'arcade ne flashe pas non plus (`c797`) ;
- **le Shell** (2 PV à l'ouverture, 6 pour l'œil bleu) : l'arcade ne fait
  qu'un SFX 0x56 sur l'œil bleu, pas de palette de flash (`6c37`) ;
- **les ennemis des stages 5 à 8 non portés** (Dop, Bellmite, Bydo…) :
  à inventorier à leur portage.

## Ce que ça coûte

Une pose blanche compilée pèse comme la pose d'origine (même silhouette,
une couleur) ; le dédoublonnage des tranches ne joue pas ici (sprites
entiers). Avec l'idiome « peu d'images blanches » :

| ennemi | images blanches proposées | ordre de grandeur |
|---|---:|---:|
| Cytron | 1 (la pose de repos, comme le Tabrok) | ≈ 400 o |
| petite tourelle | 2 (haut, bas, pose centrale) | ≈ 300 o |
| grosse tourelle | 1 | ≈ 300 o |
| tourelle multiple | 1 par orientation, 4 | ≈ 600 o |
| tourelle frontale | 1 à 2 sur la roue partagée | ≈ 300 o |
| réacteur arrière | 1 | ≈ 800 o |
| réacteurs de ventre | 3 (les images sans miroir) | ≈ 900 o |
| capsule, petite capsule, triangle | 3 | ≈ 900 o |

Soit **≈ 5 Ko** pour le stage 3, dans les pages du cast (`stage3.foes`, 1 035
et 1 772 octets libres en queue des pages 21 et 22, plus les marges des
autres pages du cast à mesurer) ; ≈ 400 o pour le Cytron dans `lib.cytron`.
Le code : le patron `tabrok.hitBlink` (une vingtaine d'octets par objet,
un compteur d'un octet), et une case de plus par ennemi dans l'extension
d'objet quand elle est pleine — les tourelles du vaisseau et le Cytron ont
la leur à regarder.

## Note du 11/09/2026 — la roue partagée des tourelles frontales

L'auteur a vu des doublons sur la planche : 30 images pour 11 silhouettes,
et la mesure montre que chaque silhouette est **à la même place par rapport
à l'ancre** d'une variante à l'autre (seule la hauteur du canevas différait,
24, 30 ou 36 ; l'encodeur rogne et ancre au centre, l'image compilée est la
même). Aucun décalage à gérer à l'exécution : `gen_warship_frontmulti.py`
dédoublonne par (pixels rognés, position relative à l'ancre) dans un jeu
`front-turret-wheel` sur canevas uniforme, et les roues des variantes sont
des tables d'index dans ce jeu. `imgFront` : 9 677 → 3 733 octets (−61 %).
Le flash de coup n'a plus qu'une roue à blanchir. Les autres familles du
jeu n'ont aucun doublon entre dossiers (scan des 652 images du build).

## Décision du 11/09/2026 — une ellipse blanche commune par roue

Pour les familles dont les poses changent trop (les tourelles hors
multiples, et le Cytron), l'image blanche est **une ellipse commune**, la
même pour toutes les poses, à l'ancre du sprite. Ajustée par recherche
exhaustive de l'ellipse qui minimise l'écart moyen avec les poses (pixels
dans l'ellipse hors pose + pixels de la pose hors ellipse), centre au
demi-pixel : planche `images/planche-flash-ellipses-2026-09.png`.

| famille | poses | ellipse (px) | centre depuis l'ancre | couvre la pose | hors pose |
|---|---:|---:|---:|---:|---:|
| petite tourelle haut | 9 | 7 × 13 | +0,5 ; +8,5 | 83 % | 7 % |
| petite tourelle bas | 9 | 7 × 13 | +0,5 ; −6,5 | 85 % | 7 % |
| grosse tourelle | 9 | 12 × 14 | +1,5 ; +4,5 | 83 % | 16 % |
| tourelle frontale (roue partagée) | 11 | 7 × 12 | +1,0 ; +0,5 | 62 % | 12 % |
| Cytron | 16 | 9 × 13 | −1,0 ; +1,0 | 77 % | 17 % |

Validé par l'auteur (« c'est parfait »). Les autres familles gardent la
silhouette blanche d'une pose : tourelle multiple (une par orientation),
réacteur arrière, réacteurs de ventre, capsules, triangle. Cinq ellipses
≈ 1 Ko en tout. Reste à faire : le générateur des PNG blancs (ellipse sur
le canevas de la famille, à l'ancre), leur déclaration dans les pages du
cast, et le patron `hitBlink` dans chaque objet.

## Réalisé le 11/09/2026 — le manager sur le crochet de collision

Décision auteur : pas de substitution d'image dans chaque ennemi, un
**manager** greffé sur `Collision_OnLoose` (moteur résident), le crochet que
la passe de collision appelle quand une boîte encaisse un coup et garde du
potentiel. Il pose un objet **explosion de sous-type `$80`** qui porte la
boîte touchée ; l'unité explosion (`hitflash.*` dans `explosion.asm`)
choisit l'image blanche **par la taille de la boîte** (`hitflash.Sizes`,
générée), la centre sur la boîte relue au dessin, la dessine un rendu devant
tout et se retire. Aucune ligne dans les ennemis, tout ennemi futur couvert ;
une taille inconnue ne dessine rien (les sous-parties de coque, le noyau qui
a son propre flash).

Les images (`tools/gen_hitflash_manager.py`, `images/planche-flash-manager-2026-09.png`) :
toutes des **ellipses**, ajustées aux poses alignées sur le centre de boîte,
**rangées alignées sur l'octet** — la silhouette d'une pose se compilait trois
fois plus lourd (trous, bords irréguliers), 4 117 → 1 550 octets pour les huit.

| clé (rx, ry) | familles | ellipse | centre depuis la boîte | couvre |
|---|---|---:|---:|---:|
| 4, 4 | petites tourelles haut et bas | 7 × 13 | +0,5 ; +0,5 | 88 % |
| 4, 6 | grosse tourelle | 11 × 20 | +1 ; +3,5 | 89 % |
| 4, 8 | tourelle frontale | 7 × 12 | +1 ; +0,5 | 66 % |
| 4, 9 | Cytron | 9 × 13 | −1 ; +1 | 82 % |
| 3, 6 | tourelle multiple, réacteurs de ventre | 7 × 14 | +1 ; +0,5 | 75 % |
| 6, 11 | petite capsule, triangle | 22 × 24 | +1 ; +1,5 | 86 % |
| 14, 11 | réacteur arrière | 36 × 24 | +2,5 ; +1,5 | 83 % |
| 26, 10 | capsule de survie | 60 × 24 | −1 ; +0,5 | 84 % |

Deux clés sont partagées par des familles distinctes : (4, 4) réunit les
petites tourelles haut et bas, dont les boîtes sont excentrées vers le canon
de façon symétrique, si bien qu'une seule ellipse les couvre à 88 % ; (3, 6)
réunit la tourelle multiple et les réacteurs de ventre. Écart consigné : la
tourelle multiple a une ellipse commune et non une silhouette par
orientation, la clé ne connaît pas l'orientation.

Doublons connus, à unifier plus tard : sur d'autres stages la clé (4, 8) est
aussi celle du Dobkeratops, du Zoid et du corps de Slither, qui ont déjà leur
flash — ils recevront en plus l'ellipse 7 × 12 ; retirer leur flash propre
serait la simplification.

Place : `imgHit` 1 550 o (une 4e tranche de l'imageset explosion), unité
explosion 538 → 770 o, moteur résident +25 o (le crochet). L'arène commune
n'avait plus 500 octets de miettes : la queue de la page $0C ($3850-$3FFF,
1 968 o, libre dans tous les états, le lot Cancer s'arrêtant à $3842) lui est
ouverte.

Vérifié sous toje (`tools/hitflash_probe.py`, boucle de jeu par boucle) : au
coup encaissé par un réacteur de ventre, l'objet flash est posé avec la
boîte du réacteur, dessiné au centre de cette boîte dans le rendu de la même
boucle — 104 pixels blancs dans la fenêtre 12 × 16 de la boîte, l'ellipse
7 × 14 entière (`images/flash-de-coup-toje-2026-09.png`). Banc r-type 7/7.

## Révision du 12/09/2026 — remplacement pour les capsules et les réacteurs

Décision auteur : l'ellipse du manager ne vaut que pour **les tourelles à
roue et le Cytron**. Les capsules, le triangle, les réacteurs — et la
tourelle multiple, qui partage la clé (3, 6) des réacteurs de ventre et ne
peut donc pas passer par le manager — dessinent leur **silhouette blanche à
la place de leur sprite**, un rendu, sur la baisse de leur potentiel
(`prevP` d'un octet dans l'extension, l'idiome du Tabrok) :

| pièce | dessin | pose blanche | où |
|---|---|---|---|
| réacteur arrière, capsule, petite capsule, triangle | wsmgr | liste `react.sl.<x>_hit.0`, inscrite par `react.ShowWhite` | page à part `stage3.cast.imgWhite` (3 035 o), wsmgr prend la page par slot |
| réacteurs de ventre | BuildSprites | `breactor.HitSets` par direction | `imgReactor` (+851 o) |
| tourelle multiple | BuildSprites | `multi.Hits` par montage (la pose 0 blanchie) | `imgFire` (+640 o) |

Les silhouettes (`tools/gen_warship_hit.py`, `images/planche-flash-remplacement-2026-09.png`)
ont leurs rangées alignées sur l'octet, comme les ellipses. Le manager ne
garde que quatre clés — (4, 4), (4, 6), (4, 8), (4, 9) — et `imgHit` tombe
à 446 octets. Le moignon en feu des réacteurs de ventre ne flashe pas
(pas de pose blanche de l'épave).

Vérifié sous toje par coups forcés (`tools/hitflash_force_probe.py` : le
potentiel d'une pièce baissé d'un point, une capture avant, puis trame par
trame jusqu'à la pose blanche, et le compte des pixels DEVENUS blancs dans la
fenêtre de la boîte — les gerbes voisines sont blanches par nature) :

| pièce | pose blanche vue | pixels devenus blancs | paire avant/après |
|---|---|---:|---|
| réacteur de ventre | `image_set` = `set_bottom_reactor_bottom_hit_0` | 104 | `images/flash-remplacement-reacteur-toje-2026-09.png` |
| capsule de survie | slot wsmgr = `react.sl.escape_capsule_hit.0` | 170 | `images/flash-remplacement-capsule-toje-2026-09.png` |
| petite capsule | slot wsmgr = `react.sl.small_escape_capsule_hit.0` | 28 | `images/flash-remplacement-petite-capsule-toje-2026-09.png` |

La pose apparaît 7 à 8 trames après le coup forcé : c'est le frame drop de
la scène (un rendu pour 8 trames), pas un retard du mécanisme. Le réacteur
arrière n'était pas à l'écran au moment de la sonde ; il suit le chemin de la
capsule (`react.ShowWhite`). Banc r-type 7/7.

Piège de mesure noté : `run_until_pc` sur l'entrée de `gfxlock.bufferSwap.wait`
revenait ~85 rendus plus tard — pour observer la boucle suivante, avancer par
`run_frames` d'une trame en relisant l'objet.
