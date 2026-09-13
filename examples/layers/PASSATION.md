# Passation — démo layers $26, swarm 16 sprites, CSR two-phase (résolu)

Date : 10/09/2026. Branche : `feature/new-graphic-mode-1`. Rien n'est commité
(plusieurs répertoires entiers sont untracked : `examples/layers/`,
`engine/graphics/sprite/background-erase-mode-1bpp/`,
`toolbox/.../gfxcomp/encoder/onebpp/`).

## 1. Contexte : ce qui marche

Démo `examples/layers` : donjon vertical qui scrolle sur **RAMB** (vert,
`vscroll.planes = 2`, bitmask 1=A/2=B/3=les deux, défaut 3 = BM16 inchangé),
sprites rouges sur **RAMA** (devant, $26 donne priorité à RAMA), 25 → 20 fps
selon le nombre de sprites. Palette GR-first (`$f000` rend vert, `$0f00`
rouge — les vieux commentaires "expect" avaient faux, corrigés dans main.asm).

- Sprites 1px fluides via **8 variantes pré-shiftées** par sprite
  (`tools/mk_shifts.py` → `knight/ghost/dragon_s0..s7.png`, 24 entrées
  `clear1` dans `to8.config.xml`). Variante `s = (X-x1_0)&7`,
  colonne `(X-x1_s)>>3`, `x1_s = x1_0+s` exact (même canvas). Zéro changement
  moteur/toolchain pour ça.
- Encodeur **`clear1`** (Java `ClearGenerator` + `CLEAR1BPP equ 1` dans main.asm
  avant l'INCLUDE du pack) : draw ORA sans backup, erase `CLR` par octet
  d'encre, `nb_cell = 0`. Flag build uniquement (pas de bit libre dans
  `render_flags`), BM16/bdraw1 byte-identiques quand désactivé.
- X bounds [888,1144], Y [40,180]. 16 objets, tous `id=1` → `ObjectRunSwarm`.
- Témoins `$9C00` : +0 `$CA` run, +1 compteur dessinés (attendu `$10`=16),
  +4 sanity imageset (`$01`), +5 frame counter, +6 tête free-cell,
  +9 scroll LSB.
- État stable courant (3e session) : **16 sprites, 14 fps, zéro morsure,
  bitmap de cellules sales, déplacements 1 px, 15,9 fps** ; film `/tmp/layers_defer.avi` ; détecteur
  `tools/bites.py <avi>` (les pistes à longue « chute » sont des fusions).
  Avant la two-phase : 20 fps avec morsures, film `/tmp/layers_16.mp4`. Mémoires Engram : #139 (bitmask vscroll),
  #140 (bug render_flags), #141 (pré-shift), #142 (clear1).

## 2. Le problème d'origine : flicker par "bites" d'overlap

Analyse lossless (AVI ZLIB + composantes connexes, jamais le mp4 H.265 qui
bave le rouge) : un dragon perd sa moitié gauche en **une itération**
(`c24→c25`), reste mordu ~10 itérations. Mécanisme prouvé par lecture du
code : `CheckSpritesRefresh` parcourt les priorités **de 8 (fond) vers 1
(devant)** en une seule passe, et chaque sous-recherche anti-collision ne
voit que les entrées **déjà ajoutées** aux listes erase/draw. Un objet de
fond rate donc l'erase d'un objet de devant traité plus tard → pas de
refresh → morsure persistante (puis heal au prochain mouvement). v1/BM16 a
la même structure mono-passe (bug latent, masqué par moins d'overlaps).
Fichiers vidéo : `/tmp/layers_16.avi`, `/tmp/dbg16/`, `/tmp/clear_dbg/`.

## 3. RÉSOLU (10/09/2026, 2e session) : le hang CSR two-phase, puis les morsures

Deux défauts dans `background-erase-mode-1bpp/CheckSpritesRefresh.asm`, trouvés
par lecture puis confirmés sur machine :

1. **Le hang** : `CSR_CheckDrawMini` (chemin phase 0) faisait `stx
   CSR_CheckDrawFull+1` puis `ldx #$FFFF` — ce `ldx` n'était patché par
   personne (le `stx` patche le chemin FULL). X = `$FFFF` littéral, puis
   `ldu buf_priority_next_obj,x` = `ldu 3,x` lisait `$0002` → U ordure
   constante (`$4153`) → cycle sur pointeur garbage dès le premier objet.
   Fix : les deux instructions supprimées, X est intact à toutes les
   entrées de phase 0 (aucune sous-recherche ne le clobbe en phase 0).
2. **Les listes « gelées » ne l'étaient pas** : phase 1 réécrivait
   `Tbl_Sub_Object_Erase/Draw` depuis le début, DANS le buffer que ses
   sous-recherches lisent ; un upgrade inséré décale le curseur qui écrase
   des entrées phase 0 non encore réémises → entrée perdue. Fix : deux
   tables dédiées `Tbl_Sub_Object_Erase_P0`/`Draw_P0` (160 o), phase 0 y
   écrit, phase 1 reconstruit les tables normales et lit les `_P0`.

Et un bug DÉMO, pas moteur, qui expliquait les « disparitions » :
`ObjectRunSwarm` clampait Y avec `bge`/`ble` (signés) alors que ymax=180
= −76 signé → 8 objets (lanes verticales) faisaient du ping-pong y=40↔180
à chaque itération. Corrigé en `bhs`/`bls`. (Vu au dump du pool : `pxy0=(x,180)`
contre `xy=(x,40)`.) Attention : `x` 16 bits reste signé, correct.

**Validation** : `/tmp/layers_2phase_b.avi` (10 s, 499 trames), détecteur
de morsures `tools/bites.py` (composantes rouges suivies, chute d'aire
< 75 % du max pendant ≥ 3 trames) : baseline `/tmp/layers_16.avi` = 9
événements (dont les morsures réelles c24→c25) ; nouveau film = 2
candidats, tous deux des artefacts de fusion (deux chevaliers superposés
puis séparés, intacts à la trame 116+). **Zéro morsure.** 16/16 dessinés
(`$9C01=$10`), pas de fuite (`$9C06` stable).

**Coût** : 143 itérations / 500 trames ≈ **14 fps** (20 avant). Profil
toje (100 trames) : CSR ≈ 440 k cycles = **15 k/itération** (0,75 trame),
vscroll.do 270 k, RunObjects 123 k, DRS 86 k, ERS 66 k. Dans CSR, les
sous-recherches de phase 1 pèsent ~9 k : chaque objet INCHANGÉ (8 sur 16,
les gated) balaie les deux listes gelées entières (16+16 entrées × ~40
cycles). C'est le O(n²) v1, doublé parce que les listes sont désormais
complètes (avant : seulement les entrées « derrière »). À 32 sprites :
~40 k = 2 trames. Note : à 1 px/itération TOUS les objets non gated
changent de variante pré-shiftée → E=1 D=1 partout, listes pleines.

## 4. FAIT (10/09/2026, 3e session) : bitmap de cellules sales + bug des boîtes X

`CheckSpritesRefresh.asm` (1bpp) n'a plus de listes erase/draw : une **grille
de 40 colonnes × 13 lignes de 16 px** (80 o, un mot par colonne, bit 15 =
ligne 0, masque de lignes = `From[r1] AND To[r2]`, tables de 13 mots), effacée
par blast `pshu` à chaque appel.

- **Phase 0** : drapeaux directs + marques. Objet effacé ET redessiné →
  UNE marque « union prev ∪ cur » (`CSR_dirty.markUnion`) ; objet qui
  apparaît → boîte cur ; objet effacé sans redessin (hors champ, caché,
  sans frame, priorité changée dans la trame) → boîte prev. Pas de hide
  en phase 0 (phase 1 le prendrait pour caché).
- **Phase 1** : objet inchangé à l'écran → `CSR_dirty.testCur` ; touché →
  erase+draw et marque sa boîte pour les suivants (chaîne partielle, ordre
  du parcours, comme v1). Les objets changés ne re-marquent pas.
- Coût linéaire : ~270 cycles par opération de boîte (locate ~120 +
  colonnes × 36). Mesuré : 5,4 k/itération à 16 sprites.

**Bug préexistant trouvé par la trace** (la bitmap ne marquait rien) :
`CSR_CheckPosition` divisait `left_px`/`right_px` par 8 avec `lsra / rora`
au lieu de `lsra / rorb` — B n'était jamais décalé, `rsv_x1/x2_pixel`
recevaient l'octet bas en PIXELS (ex. 92 pour la colonne 119). Invisible au
dessin (DRS lit `x_pixel`), fatal à toute détection de recouvrement : c'est
la vraie cause des morsures de la baseline (§2), les sous-recherches v1
comparaient des unités fausses. Quatre séquences corrigées (`rorb`).

**Démo** : la moitié gated bouge tous les **4** ticks (`obj_gate = 3`) pour
qu'un objet soit « inchangé » au sens CSR (comparaison PAR TAMPON, donc
contre l'itération k−2 : à 2 ticks personne ne l'était jamais et le
chemin d'upgrade ne tournait pas). Le clamp Y en non signé (§3) reste.

**Validation** : `/tmp/layers_bitmap2.avi` (10 s) → `tools/bites.py` = 15
événements, TOUS des fusions (sprites superposés puis séparés intacts,
vérifiés à l'image : trames 212-233, 205-233, 270-312). Avant le `rorb`,
le même film montrait un fantôme réduit à son contour 2 itérations sur 4
(période du gate). Trace d'une itération : 8 `testCur`, upgrades effectifs,
bitmap peuplée. 16/16 dessinés.

**Budget mesuré par breakpoints, UNE itération, en cycles (16 sprites)** :

| Étape | Cycles |
|---|---|
| RunObjects | 4,6 k |
| CheckSpritesRefresh | 19,9 k (géométrie phase 0 ~11 k, bitmap 5,4 k, drapeaux ~3,5 k) |
| attente swap | 0 |
| vscroll.do | **26,7 k** (blast d'un plan entier) |
| vscroll.move | 2,9 k |
| EraseSprites | 7,4 k |
| DrawSprites | 12,3 k |
| fin de boucle | 0,6 k |
| **Total** | **~74 k = 3,7 trames → 14 fps, CPU saturé, zéro idle** |

Piège de mesure : le flamegraph toje sous-estime de moitié (la commutation
de pile `lds` d'IrqManager casse son attribution) ; les breakpoints +
`dump_trace_ring count=1` (total_cycles) font foi.

Leviers restants, par ordre de gain : (1) `vscroll.do` 27 k — 36 % du
budget, indépendant des sprites ; (2) géométrie CSR 690 cycles/objet
(`CheckPosition` 220 : la boîte X en 16 bits pourrait devenir 2 additions
d'octets si les offsets d'image étaient pré-divisés par 8 par gfxcomp) ;
(3) DRS 770/sprite, ERS 460/sprite. À 32 sprites le budget projeté est
~110 k = 5,5 trames (9 fps) ; passer sous 3 trames (16,7 fps) demande
~−15 k, sous 2 trames (25 fps) ~−35 k.

## 4b. FAIT (10/09/2026, 3e session) : les déplacements 1 px — ancre gfxcomp

Symptôme signalé par l'auteur : déplacements horizontaux « par bloc ». Mesuré
sur film (bord gauche des composantes) : sauts de 8 px toutes les 8
itérations. En machine, `obj_x`, `obj_s`, `image_set` cyclaient bien (dump
`dec2.py`) et les 24 PNG sont bien décalés d'1 px. Cause dans **gfxcomp** :

1. `Image.prepareMono` rognait la boîte 1bpp au **pixel** d'encre
   (`monoX0 = x_Min`) et `BitPack.pack` empaquetait depuis ce pixel : les 8
   variantes donnaient les mêmes octets, le décalage était perdu.
2. Plus profond : le code 1bpp dessinait la boîte rognée **à `x_pixel`/
   `y_pixel`** alors que `x1_offset`/`y1_offset` sont relatifs au centre du
   canvas — boîtes CSR décalées d'une constante par sprite, différente
   selon sa taille et son rognage. Recouvrements approximatifs.

Correctif (`Image.java`, `onebpp/{Draw,Bdraw,Clear}Generator.java`,
`CACHE_VERSION` 2 → 3) : le code généré est **ancré sur l'octet et la ligne
de référence du canvas** (centre : octet `((w-1)/2)/8`, ligne `(h-1)/2` ;
top-left : 0,0) via un offset `monoOrigin = (monoY0-refRow)*40 +
(monoX0/8-refByte)` ajouté à chaque `o,U` (peut être négatif, ex. `-241,U`) ;
la boîte empaquetée part de l'octet aligné avant l'encre (`monoX0 = x_Min &
~7`, `monoRowBytes` jusqu'au dernier pixel d'encre) ; `x1_offset = x_Min -
refByte*8`, `y1_offset = y_Min - refRow`. Conséquences : l'encre garde son
bit dans l'octet, `x1_offset(s) = x1_offset(0) + s` pour huit variantes d'un
même canvas, et les boîtes CSR sont **exactes** (`x_pixel*8 + x1_offset` =
pixel d'encre gauche). La sémantique runtime devient : `x_pixel` = colonne
octet du centre du canvas, `y_pixel` = ligne du centre (avant : coin haut
gauche de la boîte rognée). Test `OneBppTest.preShiftedVariantsKeepTheirBitAndShareTheAnchor`
(32 tests verts).

Piège : le **BuildCache gfxcomp** (`.builder-cache/`, clé sans version du
jar) a resservi les anciennes sorties après le premier repackage (« 72
hits ») — d'où le bump de `CACHE_VERSION`. Après une modif Java : `mvn -pl
toolbox/graphics/gfxcomp -am package` (le `-am` est obligatoire hors
réacteur), `cp target/gfxcomp-0.0.1.jar repo/`, et vérifier la ligne
`cache gfxcomp : … misses` du build.

Validation : `/tmp/layers_anchor.avi` — trajectoires x à 1 px par
itération (gated : 1 px / 4 itérations), 12 événements détecteur tous des
fusions (trames 28-49, 444-465, 470-498 vérifiées), 142 it/500 trames =
14,2 fps.

## 4c. FAIT (10/09/2026, 3e session) : passe d'optimisation fps

Mesures par breakpoints, une itération, 16 sprites (cycles) :

| Étape | avant | après |
|---|---|---|
| RunObjects | 4,6 k | 4,6 k |
| CheckSpritesRefresh | 19,9 k | **15,4 k** |
| vscroll.do | 26,7 k | 26,7 k |
| vscroll.move | 2,9 k | 2,9 k |
| EraseSprites | 7,4 k | **6,5 k** |
| DrawSprites | 12,3 k | **9,7 k** |
| **fps** (500 trames, turbo) | 14,2 | **15,9** |

Ce qui a été fait :

1. **gfxcomp `RowCode`** (draw1/clear1, `CACHE_VERSION` 4) : U marche
   ligne par ligne (`LEAU origin,U` puis `LEAU 40,U`), offsets 0..15 (5 bits,
   +0 cycle) au lieu de 16 bits (+4) ; paires d'octets en D
   (`LDD/ORA/ORB/STD` = 16 cycles pour 2 octets contre 2×14) ; le `ANDA #~v`
   avant `ORA #v` était redondant (AND ~v puis OR v = OR v) ; effacement par
   `STD` de zéros (`LDD #0` une fois). Test `OneBppTest` adapté (32 verts).
2. **CSR une seule passe + liste différée** : les objets inchangés à
   l'écran sont poussés dans `CSR_defer` pendant l'unique parcours (qui pose
   les drapeaux finaux, le hide et les marques pour tout le reste) ; la
   phase 1 ne parcourt QUE cette liste (test bitmap, upgrade + markCur,
   drapeaux, hide). Plus de second parcours complet ni de `CSR_phase`.
3. **Boîte X en octets** : `x1 = x_pixel + floor(x1_offset/8)`, `x2 =
   x_pixel + floor((x1_offset+x_size)/8)` (asra/rorb ×3), bornes comparées
   en octets — exact puisque le code est ancré (§4b). Remplace le calcul 16
   bits avec pile. **Troisième bug de géométrie trouvé là** : le port 1bpp
   lisait `image_subset_x1_offset` avec Y = `image_set` (la v1 recharge
   `rsv_image_subset` avant), soit `x_size` au lieu de `x1_offset` : boîtes
   décalées de +18 px depuis l'origine du port. Corrigé (Y rechargé).

Validation : `/tmp/layers_defer.avi`, 4 événements détecteur, tous des
fusions (trames 128-149 vérifiées), 159 it/500 trames.

Ce qui reste, par gain : (1) **`vscroll.do` 26,7 k = 42 % du budget**,
plancher du blast 6809 (3,4 cycles/octet) pour 200 lignes — le seul levier
est le viewport (144 lignes = −7,5 k, soit ~18 fps ; 100 lignes = −13 k) ;
(2) géométrie CSR ~9 k (page switch `Img_Page_Index` + métadonnées + boîtes,
~560/objet) ; (3) `CSR_dirty.locate` ~120/op, XOR des tables From (−15) et
inline (−30) ; (4) DRS ~600/sprite dont ~330 hors code compilé (snapshot
prev, XYToAddress avec MUL). 25 fps (40 k) est hors de portée avec un
scroll plein écran ; 20 fps (50 k) demande le viewport réduit + (2)-(4).

## 5. Théories écartées AVANT la résolution du hang (historique, ne pas refaire)
1. `render_flags` garbage → objets auto-supprimés (8/32). **Vrai bug, fixé**
   par wipe (Engram #140). Non lié au hang actuel.
2. Objet `object_size`/base pool : vérifié lwmap (`$75`=117,
   `Dynamic_Object_RAM=$943B`), pool intact en RAM.
3. `IFNDEF/ENDC` déséquilibrés : comptés (Draw 2/2, Erase 6/6) ✓.
4. Adresses perso fausses (`$61CA` vs `$62CA`, `$67D1` vs `$67D8`) : comprises,
   re-vérifiées via lwmap à chaque fois.
5. `object_size`/`nb_dynamic` : 17 slots, pool `$943B–$9C00` ✓, game mode
   ~4 Ko à `$6100` → pas de collision.
6. Watchpoint DPS `$6ED1` : aucun écrivain post-load en 2M instructions
   (l'enregistrement DisplaySprite n'y écrit jamais → autre zone ou jamais).
7. Wipe complet des 117 o du slot (base+ext+rsvd, pour `buf_priority` $FF →
   fausse ChangePriority) : appliqué, **hang inchangé** → pas la cause.
8. Dump RAM 512 Ko + scan : pool trouvé (CPU `$9xxx` ↔ fichier bank1,
   offset = CPU − `$4000`), DPS à pointeurs `$94xx` **introuvable**
   (seules les chaînes next du pool matchent) → enregistrement DPS jamais
   visible.
9. `main.lst` : `IFNDEF`/`ENDC` et `lbeq` correctement encodés (les `0000`
   du listing sont des fixups normaux du link, idem code d'origine).

## 6. Anciennes pistes (§5 d'origine — la 2 a suffi : lecture du code)

1. **Lire `UnsetDisplayPriority.asm` en entier** (jamais lu) : qui
   écrit/efface les tables DPS, et avec quels symboles (`n` vs
   `DPS_buffer_0` — soupçon de **double jeu de tables** : DisplaySprite
   enregistre via `ldy #DPS_buffer_0` (l.51) mais manipule aussi des labels
   `n` ; si `n` ≠ `DPS_buffer_0`, CSR et enregistrement divergent).
2. **Bisect** : neutraliser la two-phase (revenir au walk unique + mini
   désactivée) → si ça repart, réintroduire par morceaux (driver seul avec
   phase 0 = walk complet SANS mini/gate, listes ignorées) pour isoler
   l'instruction qui boucle.
3. **Sectionnement du link** : `.obj` = 32 Ko (debug inclus), offsets lwmap
   > taille fichier chargé (ex. CSR `$1430`=5168 > 4096 pour 16 sect) →
   comprendre le layout réel (sections ? `locations.asm`,
   `gen/directories/disk0/entries.asm`) au lieu de supposer base+$offset
   partout. Ça expliquerait `$6ED1`-code-mais-lwmap-table.
4. **DPS jamais enregistrés** : bp à `mainLoop`, step dans RunObjects frame 1,
   vérifier que `DisplaySprite` écrit bien des `$94xx` à `$6ED1`
   (watchpoint armé APRÈS l'entrée mainLoop, pas avant le load).
5. Une fois le hang levé : re-mesurer fps (attendu ~19), re-filmer 10 s,
   refaire l'analyse composantes (scripts dans `/tmp`, voir §6) pour
   confirmer la fin des morsures.

## 7. Commandes et repères

```bash
# build jeu (froid obligatoire : rm -rf dist gen, le incrémental donne des
# "Undefined symbol" fantômes sur entries.asm périmé)
java -Dbasedir=/home/robin/github/wide-dot/6809-game-builder -cp "/home/robin/github/wide-dot/6809-game-builder/repo/*" com.widedot.m6809.gamebuilder.MainCommand -f to8.config.xml
#bucket: workdir examples/layers. Après modif Java : mvn -q -pl toolbox/graphics/gfxcomp -am package -DskipTests PUIS cp target/gfxcomp-0.0.1.jar repo/ (sinon NPE encoder inconnu). Tests : mvn -q -pl toolbox/graphics/gfxcomp -am test (31 tests, tous verts le 10/09 02:52).
```

```bash
# analyse lossless : extraire l'AVI (jamais le mp4) puis composantes/trajectoires
ffmpeg -y -v error -i /tmp/layers_16.avi -vf "fps=5" /tmp/dbg16/f%02d.png
```

- TOJE MCP : `toje_boot_disk` (settle 600 pour jeu qui tourne, 100 pour
  mid-load), `toje_run_frames` (fast=true sauf capture vidéo),
  `toje_read_memory` (hex, len ≤ 4096), `toje_load_symbols` (dir avec
  `.lwmap`), `toje_set_breakpoint` (one-shot, page=null),
  `toje_set_watchpoint` (persistant, avec culprit PC),
  `toje_disassemble`, `toje_machine_state`, `toje_step`,
  `toje_arm_video_capture` + `toje_run_frames` SANS fast + `stop` + `encode`.
- Géométries : AVI 704×464 (jeu ×2.2, offset y 12) ; screenshots 704×624
  (jeu ×2, offset (32,112)).
- Fichiers modifiés (tracked) : `docs/lang/en/sprites.md`,
  `engine/.../background-erase-mode/EraseSprites.asm`,
  `engine/.../tilemap/vscroll/vscroll.asm` + `.macro.asm`,
  `toolbox/.../gfxcomp/Image.java`. Tout le reste du chantier est untracked
  (voir `git status`). Mémoire Engram à jour (#139–#142).
