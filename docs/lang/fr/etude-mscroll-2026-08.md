# Étude — mscroll : scroll multidirectionnel par buffer de code (BM16)

> 2026-08-20 — étude et plan d'implémentation, demandés par l'auteur.
> Révisée le même jour après trois arbitrages de l'auteur : **mode ruban avec
> couture** (pas de copies doublées), **tuiles 8×16** (le format vscroll), et
> **base de départ = clone du vscroll v1 intact**, modifié en deux temps.
> Références : `engine/graphics/tilemap/vscroll/` et `hscroll/` (v1
> `thomson-to8-game-engine`, hscroll aussi présent en v2),
> `thomson-to8-game-engine/etude-hscroll-bandeau.md` (l'étude hscroll : la
> décomposition §3.2 et le mode ruban §3.5 sont repris tels quels),
> `engine/graphics/tilemap/horizontal-scroll/scroll-map-buffered-even.asm`
> (le rendu tilemap actuel, qui devient la **seconde couche**),
> `games/r-type/src/stages/stage-main.asm` (le masque playfield existant).

## TL;DR

**mscroll** rend une bande d'écran défilant **dans les deux axes** sur une
tilemap plus grande que l'écran, par la technique éprouvée du **buffer de code
cyclique + stack blast** : la bande entière est repeinte chaque trame (coût
constant), et seul ce qui *entre* est réécrit dans le code (feed différentiel).
Architecture = **le vscroll v1, cloné intact, plus deux modifications** :

1. le déplacement horizontal du hscroll **en mode ruban** — entrée dans le
   code au chunk `h`, offset fin de S, échange RAMA/RAMB — avec la **couture
   assumée** (cisaillement d'1 ligne à la colonne de bouclage, comme hscroll
   v1, décision auteur) ;
2. la **mise à jour horizontale par tuiles** : la colonne qui entre est
   patchée dans les opérandes de toutes les lignes du buffer — le symétrique
   du feed de rangées déjà présent, **sans dupliquer sa machinerie** (mêmes
   buffers, mêmes variables, même flux d'update ; le coin n'est pas alimenté
   deux fois).

Cas d'usage visé : la **couche battleship du stage 3 de R-Type** (le cuirassé
bouge par rapport à la caméra, donc par rapport à l'écran, dans les deux
axes). Le rendu tilemap actuel (`DrawTiles`) reste la **seconde couche**,
peinte par-dessus pour le premier plan arcade (sol et plafond) — il saute les
tuiles vides, le cuirassé apparaît au travers. Les artefacts de bord (≤ 8 px à
gauche et à droite) sont couverts par le **masque playfield existant**
(`adr_playfield_mask_ND0`, peint en dernier chaque trame) — aucun mécanisme de
masquage nouveau.

Tuiles : **8×16, le format vscroll existant** — une colonne de tuile = 2
octets de plan = **exactement un opérande**, alignement parfait des feeds, et
le layout de tileset `-vst` de png2bin se réutilise. Le cuirassé n'a pas de
motif répétitif : la grille 8×16 ne coûte rien de plus que la 12×12 sur cet
art (constat auteur). Le premier plan `DrawTiles` garde ses tuiles 12×12
compilées : chaque couche a sa grille.

Gfx du démonstrateur : **le cuirassé lui-même** —
`games/r-type/src/stages/03/map/images/original/level3_b.png` (3072×240,
plan arrière arcade), réduit à l'échelle TO8 par la recette du pipeline
existant (×3/8 en x, ×3/4 en y → 1152×180, le vaisseau ~260×170).

Résolution : **2 px horizontal** (comme hscroll), **1 px vertical** (gratuit,
la granularité est la ligne). Le 1 px horizontal (double buffer de phase) est
réservé en évolution, décision à l'adaptation R-Type.

Budget : le blast domine tout (~300 cy/ligne), les feeds sont du bruit
(quelques k/trame, aucun pic notable — le ruban n'a **pas** de repatch de
`jmp`). La **hauteur de bande est LE levier** : ~29 k cycles pour 96 lignes
(tenable à 25 fps), ~54 k pour 180 lignes (16,7 fps). Mémoire : 80 o de code
par ligne et par plan → **une page par plan jusqu'à ~195 lignes de buffer**,
soit 2 pages en tout même en pleine hauteur.

---

## 1. Besoin

- **Stage 3 R-Type** : le cuirassé géant est un décor mobile — la caméra du
  niveau scrolle horizontalement, le vaisseau a son propre mouvement ; la
  position de sa couche à l'écran varie donc **en x et en y**
  (`caméra_couche = caméra_monde − position_vaisseau`). Aucun des scrolls
  existants ne couvre ça : vscroll est vertical pur, hscroll est un bandeau
  bouclant sans contenu nouveau, le tilemap scroll (`DrawTiles`) est
  horizontal pur et « pas le top niveau perf ».
- **Composition en couches** actée : mscroll (fond, repeint tout sa bande) →
  `DrawTiles` (premier plan sol/plafond, tuiles vides sautées) → sprites →
  masque. Le full redraw de la couche mscroll ouvre au passage l'optimisation
  « sprites sans effacement » pour les objets entièrement dans la bande
  (cf. §3.6) — c'est un dividende mesuré par le banc, pas un prérequis.
- **Bandes de masquage** : exigence explicite — 8 px à gauche et à droite,
  même principe que le masque actuel de R-Type. La conception doit garantir
  que tous les artefacts horizontaux tiennent dans ces 8 px.
- **Mise au point hors R-Type** : un démonstrateur `examples/mscroll`
  autonome, avec l'art du cuirassé, oracle et banc de cycles. L'adaptation
  R-Type est hors périmètre de cette étude.

## 2. Ce qu'on réutilise (et ce qu'on écarte)

| Source | Repris | Écarté |
|---|---|---|
| `vscroll.asm` | **tout, cloné intact comme point de départ** : buffer de lignes cyclique, curseur, feed différentiel des rangées (`copyBitmap`), point de sortie patché avec sauvegarde/restauration, compensation frame-drop 8.8, cache de rangée de map, tuiles 8×16 layout `-vst`, rendu en passes successives par plan (RAMA puis RAMB) | le format d'ids 12 bits (remplacé par des ids 16 bits prémultipliés, cf. §7), le tileset à taille figée 512, le bouclage infini de map (remplacé par un clamp) |
| `hscroll.asm` + étude §3.2/§3.5 | décomposition `x = 16·h + 4·b + 2·w` (h = chunk d'entrée, b = offset de S, w = échange RAMA/RAMB), **mode ruban avec couture** (une seule copie de code, cisaillement d'1 ligne au bouclage — assumé, comme en v1), ligne de garde + refill couleur de garde, spill borné à ±8 px | le mode « sans couture » du §3.6 de l'étude (copies doublées + `jmp` par ligne) : mémoire ×2 et repatch permanent pour supprimer un artefact que l'auteur accepte — reste une évolution possible si la couture gêne sur l'art réel |
| R-Type v2 `stage-main.asm` | le **masque playfield** compilé, peint en dernier chaque trame par-dessus les bandes d'artefacts — déjà payé dans le budget trame du jeu | rien à créer côté engine |
| `scroll-map-buffered-even` | inchangé, devient la seconde couche | — |

Point de contraste important : les tuiles mscroll sont des **données**
(bitmaps planaires patchés dans les opérandes), pas des routines compilées
gfxcomp. Les deux couches coexistent avec leurs deux formats de tuiles.

## 3. Conception

### 3.1 Structure du buffer

Deux buffers de code (un par plan RAMA/RAMB), `BUFFER_LINES` lignes chacun
(hauteur de bande + marge + 1 ligne de garde). Chaque ligne couvre
**160 px = 40 octets de plan = 10 chunks de 16 px**, en **une seule copie**
(mode ruban) :

```
ligne k (par plan) :
  [chunk 0][chunk 1] ... [chunk 9]        chunk = ldd #imm / ldx #imm /
                                                  pshs d,x
                                          (8 o de code, 4 o de données
                                           = 16 px écran, 15 cy)
buffer : ligne 0 .. ligne N-1, jmp @loop  (bouclage vertical, comme vscroll)
```

- **Chunks de 4 octets partout** : n'importe quelle ligne peut être la ligne
  d'entrée (le curseur vertical tourne), donc toutes portent la granularité
  d'entrée de 16 px. C'est aussi ce qu'impose le masquage 8 px : l'offset fin
  `b` reste dans [−2..+1] octet (spill ≤ 8 px). Vscroll utilisait des chunks
  de 8 octets (`pshs d,x,y,u`, 3,375 cy/o) ; le passage à 4 octets coûte
  ~+11 % de blast (3,75 cy/o) — c'est le prix de la rotation horizontale.
- **Entrée** : `jmp` du driver vers `ligne[curseur] + h×8`. **Sortie** : un
  `jmp @ret` de 3 octets patché (avec sauvegarde/restauration, la danse de
  `vscroll.do`) à la position qui clôt exactement `hauteur×40 − 4h` octets
  écrits. Les `4h` octets manquants sont le **trou du ruban** : il tombe
  dans la **ligne de garde** (une ligne de buffer au-dessus du contenu,
  couleur unie), refill après chaque passe par la boucle `pshu` de
  `hscroll.runBuffer`. Aucun `jmp` par ligne, aucun repatch : la rotation
  est entièrement portée par le point d'entrée et l'offset de S.
- **La couture** : à la colonne écran `(10−h)×16` environ, le contenu passe
  d'une ligne de buffer à sa voisine — cisaillement vertical d'1 px qui se
  déplace avec le scroll. C'est l'artefact structurel du ruban (étude
  hscroll §3.5.b), **assumé** — sur hscroll v1 l'art est édité en
  conséquence ; ici l'art du cuirassé jugera, le banc E5 fournit les
  captures.

Assignation des colonnes : la colonne de map de 16 px `m` (= 2 tuiles) vit
dans le chunk `m mod 10` — formule absolue, partagée par les deux feeds et la
rotation (`h = (x/16) mod 10` au signe de couture près, conventions exactes
tranchées à l'implémentation comme pour hscroll).

### 3.2 Décomposition de la position

```
x : entier, fenêtre de 160 px dans la map, pas visuel de 2 px
    x = 16·h' + 4·b + 2·w    h = h' mod 10
                             b ∈ [−2..+1] octet sur S     (pas de 4 px)
                             w ∈ {0,1} échange RAMA/RAMB  (pas de 2 px)
y : entier, pas de 1 px = le curseur de ligne (modulo BUFFER_LINES)
```

`mscroll.move` intègre deux vitesses 8.8 signées (x et y) compensées par
`gfxlock.frameDrop.count`, et **clampe** la caméra dans la map
(`x ∈ [0, map_w−160]`, `y ∈ [0, map_h−H]`) — pas de bouclage de map.

### 3.3 Les mécanismes runtime

1. **Blast** (`mscroll.do`, chaque trame rendue) : décompose x, calcule S de
   départ (fin de bande + b, zones échangées si w=1, comme hscroll), patche
   la sortie, monte la page du buffer en espace cartouche, `sts`/`lds`/
   `jmp ligne[curseur]+h×8`, refill du trou à la couleur de garde, restaure.
   Coût constant ∝ hauteur. Deux passes, une par plan — comme `vscroll.do`.
2. **Feed rangée** (vertical — **c'est le `updategfx` de vscroll, inchangé
   dans son principe**) : la ligne de buffer qui entre reçoit sa rangée de
   map — 20 opérandes = 20 tuiles par plan, `ldd` id / `ldd d,y` / `std`
   opérande, cache de la rangée d'ids, ligne de tuile par `anda #$0f`.
3. **Feed colonne** (horizontal, au franchissement de 8 px — la largeur de
   tuile) : la colonne de tuile qui entre s'écrit dans son opérande — **une
   tuile 8×16 = exactement un opérande par ligne par plan**, offset trivial
   (`chunk (c>>1) mod 10`, opérande `c & 1`), boucle sur les
   `BUFFER_LINES` lignes. **Aucune machinerie nouvelle** : mêmes buffers,
   mêmes pages, même table de tileset, même cache d'ids que le feed rangée —
   seule la direction de parcours change (une colonne de map au lieu d'une
   rangée).
4. **Coin (diagonale)** : les deux feeds lisent la map (source de vérité) ;
   pour ne pas écrire le coin deux fois, le feed colonne **saute les lignes
   que le feed rangée vient de couvrir** dans la même passe d'update (test
   d'intervalle sur le curseur — le « sans doublon » de la consigne).

### 3.4 Coûts de feed — pas de pic

Le ruban n'a **aucun repatch de phase** (c'était le poste à pics du design à
copies doublées, abandonné). Restent, aux vitesses cibles (≤ 2 px/trame) :

- feed colonne : ~190 lignes × 2 plans × ~15 cy ≈ **5,7 k tous les 8 px**
  (H = 180 ; moitié moins à H = 96) → 1,4-2,8 k/trame amortis, et le pic
  isolé tient dans une trame sans drop ;
- feed rangée : ~0,6 k par ligne entrante (les deux plans) ;
- driver ~0,5 k.

Si un lissage devenait quand même utile (vitesses hautes), le feed colonne
peut s'étaler sur les lignes (une moitié du buffer par trame) — les lignes
non encore patchées affichent une colonne périmée de 8 px **au bord masqué**.

### 3.5 Mémoire, pages, initialisation

- Ligne = 10 chunks × 8 o = **80 octets/plan** → **~195 lignes de buffer par
  page de 16 Ko** (le `jmp @loop` en plus). Une bande pleine hauteur
  (180 + garde + marge) tient donc dans **une page par plan, 2 pages en
  tout**. Si un jour un buffer dépasse : le rendu étant déjà en passes par
  plan, une page de plus n'est qu'une passe de plus du driver — pas de
  trampoline (remarque auteur, 20/08).
- Marge verticale : `BUFFER_LINES = H + garde + marge de feed` (vscroll
  prend 8 lignes de marge pour 200).
- **Initialisation** : au choix du moment M1, les buffers de départ viennent
  de `png2bin -vs` comme en v1 (vscroll intact) ; dès que le feed rangée
  couvre l'init (M3), les buffers peuvent devenir un **squelette généré au
  runtime** rempli par le feed — plus aucun binaire de buffer sur disquette.
  Décision différée à M3, les deux voies restant ouvertes.
- Tuiles : **8×16, données planaires ligne-de-tuile-major** — le layout
  `-vst` existant. Tuile = 32 o/plan (64 au total) ; 256 tuiles =
  8,2 Ko/plan → une page par plan, partageable.
- Map : ids **16 bits prémultipliés** par le pas de ligne du tileset (le
  builder précalcule, philosophie « valeurs en dur » de la v1) — lecture
  `ldd ,x` + indexation directe, pas de dépaquetage 12 bits.

### 3.6 Artefacts et masquage

- **Horizontal** : l'offset `b` décale toute l'écriture de ±8 px — confiné
  aux colonnes écran extrêmes de la bande, couvert par les **bandes de
  masquage de 8 px** : fenêtre visible = colonnes 8..151 (144 px, la largeur
  playfield R-Type), masque peint en dernier chaque trame — dans R-Type
  c'est l'`adr_playfield_mask_ND0` existant, dans le démonstrateur un
  équivalent généré.
- **La couture du ruban** : cisaillement vertical d'1 px à la colonne de
  bouclage, mobile avec le scroll — assumé (cf. §3.1).
- **Vertical** : le trou du ruban (≤ 36 o) tombe dans la ligne de garde,
  refillée couleur de garde chaque passe ; spill S de ±2 octets aux
  extrémités du blast + les 12 octets d'une IRQ sous S (contrainte héritée) :
  placer la bande de sorte que la ligne au-dessus soit repeinte ou
  tolérante, laisser `$9FF4-$9FFF`/`$BFF4-$BFFF` libres si la bande touche
  le haut d'écran.
- **2 px horizontal** : assumé en v1 du module (le vertical est à 1 px). Le
  passage à 1 px = deuxième jeu de buffers pré-décalés d'1 px (phase
  paire/impaire) alimentés en parallèle — mémoire buffers ×2, feed ×2,
  blast inchangé. Décision différée à l'adaptation R-Type.

### 3.7 Composition avec l'existant

Ordre de trame cible (celui du stage R-Type, inchangé dans sa structure) :

```
EraseSprites → mscroll.do (blast bande) → DrawTiles (premier plan)
             → DrawSprites → masque playfield → HUD
```

- Les sprites **background-erase restent corrects partout sans
  modification** : l'erase restaure un fond périmé, le blast repeint
  par-dessus dans la bande — inutile mais inoffensif. L'optimisation
  (sauter erase + sauvegarde de fond pour les objets entièrement dans la
  bande, via les bits `rsv_render_flags`) est un dividende à récolter
  ensuite, mesuré par le banc.
- `DrawTiles` doit repeindre **à chaque trame rendue** tant que la couche
  mscroll bouge (aujourd'hui il ne peint que si `glb_camera_move` — au
  stage 3 la caméra bouge en continu, sinon forcer le drapeau).
- gfxlock inchangé : blast entre `_gfxlock.on/off`, destinations fixes de la
  fenêtre `$A000-$DFFF` (c'est la page derrière qui alterne).
- Contrainte IRQ cartouche héritée : le blast s'exécute depuis la fenêtre
  cartouche, l'IRQ musique la remonte et la restaure — même situation que
  vscroll, couverte par la discipline `irq-bridge.md`.

## 4. Budgets

Trame TO8 ≈ 20 000 cycles à 50 Hz ; budget 25 fps = 2 trames ≈ 40 k.

**Blast** (10 chunks × 15 cy ≈ 150 cy/ligne/plan → ~300 cy/ligne) :

| Hauteur de bande | Blast/trame rendue | En trames 50 Hz |
|---|---|---|
| 48 lignes | ~15 k | 0,75 |
| 96 lignes | ~29 k | 1,5 |
| 128 lignes | ~39 k | 2,0 |
| 180 lignes (playfield entier) | ~54 k | 2,7 |

**Feeds** (§3.4) : ~3-6 k/trame en régime diagonal, sans pic — dominés par
le blast dans tous les cas.

**Lecture** : une bande ≤ ~112-128 lignes laisse la place du premier plan,
des sprites et de la logique dans un budget 25 fps ; le playfield entier
impose 16,7 fps. Le cuirassé du stage 3 est une bande, pas le playfield
entier — c'est précisément ce que le banc du démonstrateur doit chiffrer
(48/96/180) avant tout engagement.

**Mémoire** (bande pleine hauteur, 2 px, 256 tuiles) : buffers 2 pages,
tuiles 2 pages (partageables), map ~2 o/tuile — à mettre en regard des
8 pages de tuiles compilées even/odd d'un stage actuel.

## 5. Tooling

- **Tuiles : l'option `-vst` existante de png2bin fait déjà le travail**
  (tuiles 8×16, blocs par plan ligne-de-tuile-major). Seule retouche
  éventuelle : lever la contrainte de hauteur de tileset en multiples figés
  (256/512/1024/2048) héritée de vscroll — paramétrisation légère, pas de
  nouvelle classe. Sortie consommée par `INCLUDEBIN` dans des direntries
  data ordinaires.
- **Buffers de départ (M1)** : `png2bin -vs` existant, comme en v1.
- **Map + tileset du cuirassé** : script python du démonstrateur —
  réduction de `level3_b.png` à l'échelle TO8 (recette du pipeline stage 3 :
  ×3/8, ×3/4, palette du stage), découpe en 8×16, déduplication, émission du
  strip de tileset (1 tuile par ligne, format d'entrée `-vst`) et de la map
  binaire (ids 16 bits prémultipliés). Pas de nouvel élément builder pour
  l'exemple ; l'adaptation R-Type décidera si un générateur dédié se
  justifie.

## 6. Démonstrateur `examples/mscroll`

Même patron que `examples/hscroll`/`tilescroll` : config `to8.config.xml`,
résultats en `$9C00` (magic `$CA`, statut `$0D`/`$E0+n`), validation toje
sans écran. **L'art est le cuirassé du stage 3** (décision auteur — un cas
réel plutôt qu'une mire) ; la map l'entoure de vide pour que la fenêtre
scrolle dans les deux axes, et une bordure de tuiles repères (asymétriques,
générées) encadre la zone pour rendre visibles miroirs, décalages et erreurs
de feed que le vaisseau seul ne trahirait pas.

- **Oracle embarqué** : un rendu naïf de la même fenêtre (copie directe
  tuile → VRAM, lent, hors budget — il ne sert qu'aux points de contrôle).
  À chaque checkpoint du chemin scripté (scroll arrêté), checksum de la
  fenêtre visible (colonnes 8..151) du rendu mscroll vs celui de l'oracle —
  un octet de verdict par checkpoint. La couture du ruban n'existe qu'aux
  positions x non multiples de 160 px de fenêtre... elle existe dès que
  h ≠ 0 : les checkpoints de comparaison stricte se prennent à h = 0, et
  des checkpoints « couture » séparés vérifient que le cisaillement est
  exactement d'1 ligne à la colonne attendue (et rien d'autre).
- **Chemin scripté** : segments →, ←, ↓, ↑, diagonales, inversions,
  vitesses avec frame-drop simulé, butées de clamp — ~10 checkpoints.
- **Composition** : un segment avec `DrawTiles` par-dessus (chaîne
  `<gfxcomp grid>`/`<tilemap>` de tilescroll), un sprite background-erase
  qui traverse la bande, et le masque 8 px peint en dernier.
- **Banc** : segment en course libre, profil toje (`profile_top`,
  flamegraph) → la table de cycles réelle par hauteur de bande (48/96/180),
  et les captures d'écran de la couture pour jugement de l'auteur.

## 7. Plan d'implémentation

Module : `engine/graphics/tilemap/mscroll/mscroll.asm` + `mscroll.macro.asm`
(mono-instance, variables globales, commentaires en anglais, macros
`_mscroll.*`). **Cloné du vscroll v1** (provenance notée en en-tête — c'est
un fork v2 qui diverge, pas une migration 1:1 : pas d'entrée manifest).
Manuel `docs/lang/en/mscroll.md` à la fin.

Chemin en trois marches (consigne auteur : vscroll intact d'abord, puis la
modif hscroll avec couture, puis le feed horizontal) :

> **M1 FAIT (20/08/2026), validé sous toje** : le cuirassé défile
> verticalement dans les deux sens, wrap de map compris ; une ligne
> alimentée relue en mémoire est **identique octet pour octet** à la rangée
> de map attendue, et la capture d'écran égale le rendu TO8-vrai de la map
> (palette stage 3 passée par png2pal — les ombres olive sortent en vert
> niveau 1, c'est la vérité machine du jeu actuel, pas un défaut du scroll).
> Deux pièges réels trouvés et corrigés :
> 1. le `jmp` de bouclage du buffer objet s'assemblait en mode **direct**
>    (lwasm, cible $0000) et sautait en `$9F00` une fois DP posé sur la page
>    engine — `jmp >` forcé étendu ;
> 2. le tileset doit être **paddé à la taille déclarée PAR bloc-ligne**
>    (contrat v1 : « image de 256/512/1024/2048 tuiles exactement ») — un
>    padding en fin de fichier seul désaligne la LUT d'adresses d'un facteur
>    nb_tuiles_réelles/nb_déclaré. Vérifié au passage : la fenêtre data
>    $A000-$DFFF présente bien les deux moitiés de 8 Ko d'une page
>    **inversées**, ce que le swap du format tileset compense.
> Reste noté pour M2 : la phase +1 entre caméra et affichage une fois le
> scroll engagé (le curseur pointe la ligne pré-alimentée), qui crée une
> couture transitoire d'1 px entre les lignes du buffer de départ et les
> lignes alimentées, jusqu'au premier cycle complet du buffer — comportement
> v1 conservé tel quel à ce stade, à trancher quand `mscroll.do` sera
> réécrit.

> **vscroll migré 1:1 le même jour (20/08)** : l'état M1 étant exactement le
> vscroll v1, les fichiers v1 sont importés tels quels dans
> `engine/graphics/tilemap/vscroll/` (manifest, zéro écart) et le
> démonstrateur M1 devient `examples/vscroll` — dont l'image est **octet
> pour octet identique** à celle validée sous toje en M1 (le renommage ne
> change aucun octet) : la migration est validée par identité.

> **M2 FAIT (20/08/2026), validé sous toje** : chunks de 16 px
> (`ldd#/ldx#/pshs d,x`, +11 % de blast assumé), décomposition
> `x = 16h + 4bo + 2w`, entrée ET sortie patchée décalées de h chunks —
> le mécanisme de sortie de vscroll couvrant exactement `hauteur` lignes,
> **ni trou ni ligne de garde** (hscroll en avait besoin parce que sa sortie
> était figée au build). Mesuré au pixel par corrélation VRAM et captures :
> rotation **160/160 pixels exacte** (rangée de map retrouvée entière),
> **chaque +2 px de caméra = −2 px d'écran, linéaire sur toutes les phases**
> (flip w, pas bo, pas h : 2→4→6→8→16→32), signe conforme à la convention
> caméra qu'attend M3 ; couture et débordements confinés aux colonnes de
> bord (≤ 8 px, les bandes de masquage) ; **feed vertical octet-parfait en
> diagonale** (ligne alimentée relue = rangée de map exacte) ; wrap des deux
> axes. Trois pièges de mise au point : le postbyte `pshs d,x` est `$16`
> (pas `$06` = `pshs d` seul — générateur python) ; **une ligne vide termine
> la portée des labels locaux `@` sous lwasm** (d'où le style v1 « lignes
> `;` jamais vides » et son `@exit` en tête de routine — sortie passée en
> label global) ; et deux artefacts de MESURE sous toje : une page vidéo se
> relit périmée si on ne laisse pas ~2 blasts s'écouler (le blast pleine
> hauteur prend ~3 trames), et une rangée témoin périodique (damier 2 px)
> est invariante par l'échange de plans — choisir une rangée apériodique.
> `mscroll.viewport.ram` est devenu une vraie variable (c'était l'opérande
> auto-modifié du `lds` de `vscroll.do`, disparu avec la réécriture).

> **M3 FAIT (20/08/2026), validé sous toje.** Le feed colonne existe
> (`mscroll.feedColumn` : cache d'ids par rangée de tuiles construit en une
> passe map, puis écriture de 2 opérandes × 201 lignes × 2 plans par
> franchissement de 16 px — le ruban n'a qu'une copie de code, rien n'est
> écrit deux fois). La map est passée au format M3 : **ids
> 16 bits prémultipliés, row-major, stride en puissance de deux**
> (`_mscroll.setMapRowShift` — l'adresse d'une rangée est un décalage, pas
> une multiplication ; le générateur padde la largeur), `camera.x` est un
> **entier 16 bits en pixels** avec son accumulateur de fraction 8.8
> (miroir exact de l'axe vertical), clampé par `_mscroll.setMapWidth`.
> Limites v1 du module : map ≤ 2048 px de large, ≤ 4080 px de haut, données
> dans une page de 16 Ko. Le cache de rangées est invalidé à chaque
> déplacement de fenêtre (son contenu appartient à l'ancienne fenêtre), et
> `updateTileCache` charge désormais la tranche de la fenêtre **tournée**
> (index de cache = colonne mod 20 = le slot du buffer), ce qui laisse
> `copyBitmap` linéaire.
>
> **Les conventions, tranchées à la mesure** (VRAM corrélée contre la map,
> méthode hscroll) — le démonstrateur roule sur la map 512×640 avec le
> vaisseau entier :
> 1. la disposition des slots est INVERSÉE (le chunk c du code porte la
>    colonne 9−c, héritage de l'ordre d'exécution v1 : le premier chunk
>    écrit les 16 px de droite) → **h = (−window) mod 10**. La « validation
>    de direction » de M2 ne pouvait pas le voir : sur une bande qui boucle,
>    les deux signes sont indistinguables — c'est la map 2D qui l'a révélé ;
> 2. les termes fins ont le signe OPPOSÉ à hscroll (sa convention était
>    « contenu vers la droite », mscroll veut une caméra) : `bo` est négué à
>    la décomposition, et la phase w=1 est **le miroir** de la variante
>    hscroll — échange de zones avec **−1 octet côté plan 0** (l'échange
>    seul décale plan 0 de −2 px et plan 1 de +2 px ; reculer la destination
>    du plan 0 d'un octet lui rend +4 px : les deux plans à +2 px). La
>    variante « +1 de l'autre côté » désaligne les plans de ±4 px (brouillage
>    mesuré, pas un décalage) ;
> 3. résultat : **D(x) = x, pixel-exact à toutes les phases** (bo, w,
>    franchissements h/fenêtre), 143-160/160 par ligne VRAM (le reliquat =
>    la couture, contenu de la rangée voisine sur le chunk du wrap), dans
>    les deux sens (aller 0→352 et retour 352→0 par le chemin gauche du
>    feed, 160/160 aux deux butées de clamp), en diagonale libre avec les
>    deux feeds entrelacés.
>
> **M3-opt FAIT (20/08/2026), validé sous toje** — les points 2 et 3 de
> l'analyse cycles, avec la liberté d'organisation des données accordée par
> l'auteur :
> - **tileset TILE-MAJOR** : les 16 lignes d'une tuile sont des mots
>   consécutifs (32 octets/tuile/plan, 512 tuiles max par page) et la map
>   porte des ids **prémultipliés par 32** — l'adresse d'une ligne de tuile
>   est `base + id + ligne*2`, la source d'une colonne se lit en `ldd ,y++`.
>   Le feed rangée (`copyBitmap`) garde son `ldd d,y` : la LUT de lignes
>   devient `$A000 + ligne*2` (`_mscroll.setTileLut`), aucun coût ;
> - **feed par tuile de 8 px, cadencé sur les masques** : en allant à
>   droite une tuile est alimentée quand elle passe SOUS le masque droit
>   (edge+18), à gauche sous le masque gauche (edge−1) — toujours complète
>   un pas de 8 px avant qu'un de ses pixels en sorte. `feedTile` rassemble
>   les ids une fois (page map montée une fois, adresses au pas du stride),
>   puis chaque passe de plan tourne buffer en fenêtre cartouche et tileset
>   en fenêtre data montés UNE fois — la boucle interne tombe à **37 cy par
>   ligne et par plan** (mesuré 117 avant) ;
> - résultat mesuré (courbes avant/après, mêmes 10 s de diagonale) : **plus
>   aucune boucle à 6 trames** — un pas de feed coûte +1 trame au lieu de
>   +2 pour un franchissement — min 9,8 → 10,8 fps ; la moyenne reste
>   ~11,8 à 200 lignes (la quantification gfxlock absorbe pareil : le pas
>   de ~16 k dépasse encore la marge de ~9 k de la boucle de 4 trames). Aux
>   hauteurs réalistes la marge grandit et le pas de 8 px s'y absorbe en
>   entier — cadence lisse — là où un pas de 16 px basculerait encore ;
>   l'arbitrage 8 px/16 px est un choix d'ordonnancement de 5 lignes dans
>   move, à refaire à l'intégration selon la hauteur retenue.
>
> **Bug sérieux trouvé par cette campagne** (il expliquait aussi des gels
> d'émulateur imputés à tort à l'outillage) : la marche descendante du feed
> comparait sa borne de bouclage en NON SIGNÉ (`bhs`) — le buffer étant
> chargé à l'adresse $0000, `u` passe sous zéro au wrap, se relit $FFxx,
> le wrap n'est jamais pris et **la queue de la marche arrose $FFxx puis
> les registres d'E/S $E7xx** (d'où IRQ morte et machine figée). La v1
> garde toutes ses marches par des comparaisons SIGNÉES (`bge`) précisément
> pour ça — un opcode corrige. Règle retenue : toute marche de pointeur
> descendante dans une page montée à $0000 se borne en signé.
>
> Mesure de coût en passant : un saut de caméra de 10 colonnes (une
> téléportation de test) coûte ~350 k cycles de feed — la boucle de
> franchissements les absorbe correctement mais fige ~17 trames : la borne
> pratique de vitesse est de l'ordre d'un franchissement par trame (~35 k
> le franchissement à 201 lignes de buffer, hauteur pleine — à bancher
> proprement en M4). **Premier relevé de cadence (20/08,
> `examples/mscroll/tools/fps_curve.py` + `fps_plot.py` de la lane toje,
> 10 s émulées en diagonale 1 px/trame, bande 200 lignes)** : 11,8 fps de
> moyenne — le détail vaut mieux que la moyenne : la boucle de base fait
> **4 trames** (12,5 fps : blast ~2,8 + feeds + IRQ, quantifié par gfxlock)
> et chaque franchissement de fenêtre 16 px coûte **une boucle de 6 trames**
> — mesuré : 103 boucles de 4 et 14 boucles de 6 sur 225 trames, soit
> exactement les 14 franchissements attendus à cette vitesse ; après la
> butée x (feed y seul) la cadence remonte à 12,55 fps. Confirme le modèle
> du §4 : à bande ~96 lignes la boucle de base passerait sous 2 trames →
> 25 fps, à chiffrer au banc M4.
>
> **Profil cycles (profiler toje, 160 trames machine en diagonale 1 px/t,
> H=200)** : blast ~56 k par trame rendue (~308 cy/ligne, 154 par plan —
> ~70 % du travail) ; **feedColumn ~50 k par franchissement de 16 px**
> (boucle interne mesurée à 117 cy/ligne/plan — au-dessus de l'estimation,
> le par-ligne recharge tables et page tileset) ; feed rangée ~0,9 k/ligne
> entrante ; palette/IRQ négligeables en régime (`PalUpdateNow` est gardé
> par `PalRefresh`, ~10 cy au repos) ; **attente gfxlock ~10 % du total**
> (travail ~3,6 trames quantifié à 4). Axes d'optimisation identifiés pour
> M4+ : (1) hauteur de bande, linéaire, sans rival ; (2) feedColumn
> réordonné par rangée de tuiles — ids et adresses source fixes par passe
> externe, avance de `nbx2` par ligne interne au lieu de
> lsla+tables+montage : ~65-70 cy/ligne visés, le franchissement passe de
> ~50 k à ~30 k ; (3) le pré-feed étalé du §3.4 (colonne de marge) qui
> supprime les boucles à 6 trames — le plus rentable en ressenti (cadence
> stable) ; (4) rien à gratter dans le blast sans casser le contrat
> 16 px/bandes 8 px (le calibre 32 px et ses ±11 % restent l'échange
> documenté).
> L'artefact de bord attendu est confirmé à l'image : au
> bord d'attaque, ≤ 8 px du slot pas encore entré — dans la bande de
> masquage, par construction. Reste M4 : masque 8 px, DrawTiles par-dessus,
> banc de cycles (48/96/180) et captures de couture pour jugement.

| Étape | Contenu | Critère d'acceptation |
|---|---|---|
| **M1 — clone vscroll intact** | `mscroll.asm` = vscroll v1 renommé (ids 12 bits et tileset 512 conservés tels quels à ce stade) ; démonstrateur en **scroll vertical seul** sur l'art du cuirassé : gen tileset/map/buffers (`-vst`/`-vs`), config, game mode | le cuirassé défile verticalement sous toje, rendu conforme au PNG source, aller-retour sans glitch — c'est la préservation du comportement vscroll qui est testée |
| **M2 — ruban horizontal** | chunks 10×(`ldd/ldx/pshs d,x`), décomposition h/b/w, entrée `ligne[curseur]+h×8`, sortie patchée recalée, ligne de garde + refill, clamp de map | pas de 2 px exacts toutes phases (méthode hscroll : correspondance pixel entre pas consécutifs), couture conforme (1 ligne, à la colonne attendue), vertical toujours vert |
| **M3 — feed colonne** | update horizontal par tuiles (1 opérande/ligne/plan), déclenchement au franchissement de 8 px, anti-doublon du coin, clamp ; passage des ids en 16 bits prémultipliés et levée du tileset figé ; option : init par feed (suppression des buffers `-vs`) | chemin scripté complet vert (checkpoints oracle à h=0, checkpoints couture), map ≫ 160 px traversée aller-retour en diagonale |
| **M4 — composition + banc** | masque 8 px, `DrawTiles` par-dessus, sprite erase traversant ; mesures profiler | UT complet vert sous la lane toje ; table de cycles réelle (48/96/180) et captures de couture reportées ici |

Hors périmètre (différé, décisions à l'adaptation R-Type stage 3) : 1 px
horizontal (buffers de phase ×2), mode sans couture si l'art du cuirassé
rend le cisaillement gênant, générateur de map builder, collision terrain
contre la couche mobile, multi-instance, optimisation « sprites sans erase
dans la bande ».

## 8. Points ouverts

- Conventions exactes de signe b/w, sens de la couture et position du trou :
  à trancher à l'implémentation, pixel-perfect sous toje — comme pour
  hscroll (§7 de son étude, même méthode).
- Vitesse maximale garantie par axe (le feed boucle sur les franchissements
  multiples ; la borne réelle sort du banc M4).
- Init par feed vs buffers `-vs` : trancher à M3 (l'init par feed supprime
  un format de média mais ajoute ~20 rangées de feed au chargement).
- Tuile 8×16 actée (format vscroll, alignement parfait) ; grilles
  indépendantes entre couches (mscroll 8×16, `DrawTiles` 12×12). L'art du
  cuirassé n'a pas de motif répétitif (constat auteur) : le passage en
  8×16 ne gonfle pas le tileset — à vérifier au comptage réel du gen script
  (M1).

## 9. Campagne diagonale : deux bugs, un fix v1 latent, et la couture supprimée (20/08/2026)

L'auteur a signalé des décalages d'écriture de tuiles en diagonale (jamais
en horizontal pur ni en vertical pur). La campagne a remplacé le cuirassé
par une mire générée, trouvé et corrigé deux bugs à moi, un troisième
probablement latent en v1, puis — décision auteur — supprimé la couture du
ruban par une compensation ancrée à la map.

**Bug 1 — l'ancre du tile-feed (le bug signalé).** Dans `feedTile.plane`,
la garde `deca / bpl / lda #200` du wrap de cursor (prévue pour cursor=0)
déclenchait pour **tout cursor ∈ [129..200]** (bit 7 levé après le dec) :
le feed s'ancrait ligne 200 au lieu de cursor−1, décalant toute la colonne
de (201−cursor) px — une valeur qui dérive avec le temps, d'où des colonnes
décalées différemment selon le moment de leur feed. Invisible hors
diagonale : sans mouvement y le cursor ne bouge pas, et le row-feed ne
repasse jamais recouvrir les colonnes fausses. Fix : `bne / lda #201 /
deca`. Leçon 6809 (deuxième fois dans ce module après le `bhs`/`bge` du
wrap descendant) : **tout compare/branch sur une valeur 0..200 est à un bit
du piège signé** — écrire le cas 0 explicitement plutôt qu'un test de signe.

**Bug 2 — le buffer de départ.** Le générateur émettait 200 lignes + une
ligne vide (la marge du jmp de sortie), ancrées un pixel à côté de
l'appariement runtime, et la ligne vide traversait l'écran pendant le
premier cycle de buffer. Fix cohérent : `<mscroll output="start">` émet les
**201 lignes** (y 0..200), `_mscroll.setCameraPos` ancre
`cursor = (−y0) mod 201`, et les unités buffer ne gardent que le jmp de
bouclage.

**Fix 3 — les montées (probablement latent en v1).** Le row-feed montant
écrivait un cran trop bas (`@goUp` de `computeBufferWAddress`, code octet
pour octet identique au v1) : toute rangée nourrie en remontant était à
−1 px. `addd #1` tracé `V2-DEVIATION` ; l'auteur confirme n'avoir jamais
contrôlé le vscroll v1 à l'octet — à vérifier un jour avec la même méthode.

**La couture, mesurée puis supprimée.** L'entrée en milieu de ligne fait
emprunter à chaque rangée écran ses 4h premiers octets à la ligne de buffer
suivante : mesuré à x=96 (h=4), les colonnes à droite de la coupure
affichaient +1 px, uniformément, contenu frais compris — un artefact
d'échantillonnage, pas de fraîcheur. Constat clé (de l'auteur) : **la
coupure est fixe dans la MAP** — toujours sur les multiples de 160 px
(h est verrouillé à la fenêtre ; la mesure la plaçait à map x=160 pile).
D'où la compensation « cisaillement map-fixe », sans jamais rien re-nourrir :
- toute écriture d'une colonne située après n coutures la pose **n lignes
  plus haut** (feedTile décale le départ de sa collecte ; le générateur
  cisaille le buffer de départ) ;
- côté row-feed, les entrées du cache des colonnes au-delà de la prochaine
  couture (slots 0..n−1, contigus par construction) sont **cuites à
  id×32−2** au rechargement : le pointeur de ligne unique de `copyBitmap`
  écrit alors une ligne plus haut sans coûter un cycle par ligne. Le seul
  rattrapage est la ligne où ce décalage franchit une frontière de tuile
  (tileset.line 0 → ligne 15 de la tuile du dessus) : une passe de
  réécriture des n slots, **1 ligne sur 16**, depuis un second cache de
  40 octets (la rangée au-dessus, rechargé avec l'autre) ;
- quand la caméra franchit elle-même un multiple de 160, `cursor ± 1`
  absorbe le décalage global — pure comptabilité, au moment précis où h=0
  et où la frontière est cachée sous le masque de bord.
Coût mesuré : 12,50 fps sur le chemin vertical contre 12,55 avant — nul.
Les franchissements gardent leurs 2 feeds par 16 px (+ ~100 cycles de
calcul de tranche par feed).

**La mire refaite pour l'humain.** `gen_mire.py` produit par défaut un
motif **lisible** : règles blanches horizontales toutes les 16 lignes
(continues sur toute la largeur — une couture d'un pixel y fait une marche
visible), règles verticales cyan, hachures 45°, patchwork sourd. L'ancien
motif auto-descriptif (chaque octet nomme sa tuile) reste disponible en
`--coded` pour le forensique. Le générateur écrit aussi `mire.pix` (la
source pixel brute) : `diag_check.py` calcule l'écran attendu depuis ce
fichier — le contrôle marche pour n'importe quel motif, et son modèle est
redevenu **uniforme** (aucun terme de couture).

**Validation** : les quatre diagonales (bas-droite, bas-gauche,
haut-droite à demi-vitesse $0080, haut-gauche), chacune jusqu'à sa butée,
écran entier comparé octet par octet à la source : **0 défaut sur
4 × 8 000 contrôles**, et capture d'écran propre à h=4 (l'ancien pire cas).

**Note d'exemple (débordement de la ligne du haut)** : avec h≠0 la ligne
partielle de sortie pousse jusqu'à 36 octets AVANT le début de zone —
plan A dans le trou $BF40-$BFFF (inoffensif), plan B sous $A000 dans la
page résidente, où l'engine ne réserve que 12 octets (`glb_ram_end`). Le
choix appartient au projet via les réglages du viewport (ligne de départ,
hauteur) ; le banc pleine hauteur assume d'écraser des globales inutilisées
ici — le commentaire de `main.asm` détaille.

> **Mesure fps après compensation (20/08, mire, rebond aux butées pour
> garder les feeds actifs sur les 10 s)** : 11,0 fps de moyenne en
> diagonale 1 px/trame en régime de franchissement PERMANENT — la
> référence 11,8 d'avant mélangeait ~70 % de franchissements et ~30 % de
> vertical clampé, la comparaison honnête est par boucle : **50 boucles de
> 4 trames, 59 de 5, zéro de 6** — et les 59 boucles à 5 correspondent
> une pour une aux ~60 feeds de colonne du trajet (487 px / 8). Profil
> identique à l'état M3-opt d'avant compensation ; le vertical à la butée
> reste à 12,50 (12,55 avant). Le surcoût du cisaillement est invisible
> sous la quantification gfxlock.
