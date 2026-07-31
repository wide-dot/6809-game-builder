# Sprites compilés — état des lieux avant portage (juillet 2026)

Statut : **analyse — rien d'implémenté**. Sources : lecture croisée du runtime
v1 (`thomson-to8-game-engine`) et de l'outillage v2 (`6809-game-builder`),
références fichier:ligne vérifiées dans les deux dépôts.

## 1. Verdict en trois phrases

La v2 possède **l'outil** (gfxcomp, le compilateur PNG→code 6809, port du
générateur v1) et **le vocabulaire** (`glb.const.asm` porte déjà l'intégralité
de la structure objet/sprite/caméra v1, 319 lignes d'équates sans une ligne de
code), mais **aucun runtime** : pas une routine de dessin n'existe côté ASM.
Le runtime v1 à porter est bien délimité — 7 fichiers, ~1 400 lignes — et son
contrat avec le code généré est documenté ici. Trois bugs bloquants dans
gfxcomp et un écart de constante entre les deux dépôts sont à régler avant ou
pendant le portage.

## 2. Le runtime v1 à porter

Pack de référence : `engine/graphics/sprite/sprite-background-erase-ext-pack.asm`
(celui de R-Type ; la variante « ext » ne diffère du pack de base que par 4
lignes de crochets pour sprites encodés + 2 stubs).

| Routine | Fichier v1 | Rôle |
|---|---|---|
| `InitDrawSprites` | DrawSpritesExtEnc.asm:13 | init des offsets caméra (obligatoire) |
| `CheckSpritesRefresh` | CheckSpritesRefresh.asm (533 l.) | par objet : choix du mapping frame (miroir/parité), bbox écran, décision erase/draw, détection de recouvrement entre sprites immobiles et mobiles |
| `EraseSprites` | EraseSprites.asm (422 l.) | restaure les fonds (priorités 1→8), libère les cellules (`BgBufferFree` inclus) |
| `UnsetDisplayPriority` | UnsetDisplayPriority.asm (140 l.) | applique les changements de priorité entre erase et draw |
| `DrawSprites` | DrawSpritesExtEnc.asm (282 l.) | alloue les cellules, monte la page du code sprite, appelle les routines compilées (priorités 8→1) |
| `BgBufferAlloc` | BgBufferAlloc.asm (64 l.) | allocateur de cellules de fond (first-fit décroissant, division de bloc) |
| `DisplaySprite` / `DeleteObject` | DisplaySprite.asm, DeleteObject.asm | insertion/retrait dans les listes de priorité (DPS) |

**Ordre d'une frame (R-Type main.asm:216-262), le contrat de timing** :
`CheckSpritesRefresh` (hors gfxlock) → `gfxlock.on` → `EraseSprites` →
blits « sous les sprites » → `UnsetDisplayPriority` → tiles/fonds →
`DrawSprites` → blits « au-dessus » (starfield, HUD) → `gfxlock.off` →
`gfxlock.loop`. Tout ce qui doit être capturé dans les sauvegardes de fond
s'écrit avant `DrawSprites` ; tout ce qui ne doit pas y figurer, après.

## 3. Les contrats (vérifiés des deux côtés)

### 3.1 Code sprite compilé, variante B (backup+draw+erase)

Draw — entrée `Y` = cell_end (retour de `BgBufferAlloc`), `U` =
`glb_screen_location_2` ; le code fait `STS glb_register_s` / `LEAS ,Y` puis
utilise **S comme pointeur d'écriture du buffer de fond** (stack blast,
IRQ actives — d'où la marge), recharge `LDU <glb_screen_location_1` entre les
deux plans, sort `U` = cell_start. Erase — entrée `U` = cell_start
(`rsv_bgdata`), rejoue le miroir exact (plan 1 puis plan 0, LIFO), sort `U` =
cell_end. Identique dans le générateur v1
(`AssemblyGenerator.java:379-498`) et dans gfxcomp v2
(`encoder/bdraw/AssemblyGenerator.java:220-315`). Variante D (overlay) : ni S
ni Y, pas de fond — l'objet doit poser `render_overlay_mask`.

### 3.2 VRAM et adressage

`DRS_XYToAddress` (v1) : écran 160×200 dans un repère 256×256 (X:48-207,
Y:28-227) ; X/2 → parité → `glb_screen_location_2` = $A000 ou $C000 + ligne×40,
`_1` = l'autre demi-banc (±$2000, +1 si impair). Les buffers vidéo sont les
**pages RAM 2 et 3** montées en $A000-$DFFF par gfxlock ; les **cellules de
fond vivent en $4000-$5FFF** (demi-page pilotée par MC6846.PRC bit 0, posée en
absolu par `_gfxlock.on`). La v2 a le même mapping (gfxlock.asm:70-90,
confirmé par wddebug `VideoBufferImage.java:28-39`). Résolution X effective :
2 px par adresse + 1 px par variante pré-décalée (`*1`), aucun décalage
runtime.

### 3.3 Cellules de fond

64 octets/cellule, 128 cellules = 8 Ko par buffer, free-list de 64 entrées
max (en-tête 7 octets : nb_cells, cell_start, cell_end, next). Allocation par
le haut, fusion à 3 blocs à la libération. La cellule n'a **pas d'en-tête** :
le lien est `rsv_bgdata` (adresse basse) + `rsv_prev_erase_nb_cell`.

### 3.4 Index d'images (imageset)

Layout identique v1/v2, et déjà décrit par les équates
`glb.const.asm:74-85` : en-tête image 7 octets (offsets N/X/Y/XY + x_size,
y_size, center_offset), en-tête subset 6 octets (offsets B0/D0/B1/D1 +
x1/y1 signés), mapping frame 7 octets (B : pge/adr draw + pge/adr/nb_cell
erase) ou 3 octets (D). Offsets plafonnés à +127 (+102 en pratique).
`CheckSpritesRefresh` met ces 7 champs en cache dans l'OST pour éviter les
remontages de page — c'est ce cache que Draw/Erase consomment.

### 3.5 OST et DPS

`object_size = 38 + ext_variables_size + 59`. Champs publics consommés :
`id`, `render_flags`, `priority` (1-8, 0=off), `image_set`, `x/y_pos` 16.8,
`xy_pixel`. Bloc réservé : flags, cache du mapping frame, bbox, puis **deux
blocs de 20 octets** (`rsv_buffer_0` à +19, `rsv_buffer_1` à +39 — doivent
rester ≥16, contrainte d'auto-modification) portant l'état par buffer vidéo
(bgdata, prev_*). Les DPS sont des listes doublement chaînées par priorité
(8 niveaux), un jeu par buffer, + une liste « unset » pour les changements de
priorité.

## 4. Ce que la v2 a déjà

- **`glb.const.asm`** : la structure complète (§3.5), les équates d'imageset,
  la caméra, les flags — prêt à l'emploi, cohérent avec ce que gfxcomp émet.
- **gfxlock** : l'API double-buffer complète (`init/on/off/loop/swap`,
  memset, demi-page) validée par les exemples sound/loader-ut.
- **gfxcomp** (`toolbox/graphics/gfxcomp`) : le port Java du générateur v1 —
  4 encodeurs (`draw`, `bdraw`, `rle`, `zx0`), 16 motifs, clustering et
  optimisation combinatoire, imageset, miroirs/pré-décalage. Compile, jar
  produit. Entrée : PNG 8 bits indexé (0 = transparent) + config XML propre.
- **wddebug** : les vues sprites/objets/collisions documentent le format v1
  au binaire près — et militent pour **conserver les noms de symboles v1**
  (`object_list_first`, `rsv_buffer_0`, `Dynamic_Object_RAM`…) afin que le
  debugger fonctionne sans modification.
- **`examples/sound`** : le game mode BM16 double-bufferisé à cloner pour le
  banc — la boucle `_gfxlock.on / [rendu] / _gfxlock.off / _gfxlock.loop`
  est exactement l'emplacement des appels sprites.

## 5. Les écarts à traiter (vérifiés)

| # | Écart | Où | Gravité |
|---|---|---|---|
| 1 | **Marge de cellule : v1 = 16** (12 IRQ + 4 appels sous-routine, `BuildDisk.java:527` + `subd #16` runtime) **vs gfxcomp v2 = 12** (`AssemblyGenerator.java:124-126`) → nb_cell sous-évalué, débordement de cellule possible | outil v2 | **bloquant, silencieux** |
| 2 | main-class du pom gfxcomp erroné (`compiled.MainCommand` au lieu de `gfxcomp.MainCommand`) → CLI inutilisable | gfxcomp/pom.xml:23 | bloquant, trivial |
| 3 | gfxcomp non enregistré dans `Handlers` → inutilisable depuis config.xml | Handlers.java | bloquant pour l'intégration |
| 4 | **Index imageset structurellement vide** : clés `"BN0"` vs lookups `"bdraw_none_shift0"` (`Image.java:107` vs `ImageSet.java:94+`) | gfxcomp | bloquant |
| 5 | `INCLUDE "./engine/constants.asm"` (chemin v1) dans les 4 encodeurs ; v2 = `engine/global/glb.const.asm` via packs | gfxcomp | bloquant, trivial |
| 6 | `gfxlock.frame.count` jamais incrémenté → `frameDrop.count` vaut 0 ; `frameDrop.max`/`frame.gameCount` v1 absents — or les animations et tout le timing gameplay en dépendent | engine v2 | bloquant pour la parité timing |
| 7 | rle/zx0 : plan 1 encodé seulement si plan 0 non vide (`isPlane0Empty` au lieu de `isPlane1Empty`) | gfxcomp | mineur (encodeurs non requis phase 1) |
| 8 | `<memory>` parsé mais ignoré : pipeline figé BM16 TO8 | gfxcomp | accepté (cible = TO8) |
| 9 | ~2 200 lignes dupliquées entre `encoder/draw/` et `encoder/bdraw/` | gfxcomp | dette, pas un bloqueur |
| 10 | v1 : mapping frame D (3 octets) lu comme 7 par `CSR_UpdateMetadata` (lecture de bruit, inoffensive) — à assainir au portage | runtime | mineur |

## 6. Ce que la v2 permet de simplifier au portage

- **Le load-time linker remplace la passe de placement v1.** En v1,
  `BuildDisk` remplissait pages et adresses des mapping frames lors d'un
  placement global (knapsack). En v2, le code sprite est un membre de
  direntry ordinaire : `adr_*` se résout en extern16 et `pge_*` en
  **externPg** au chargement — l'imageset peut référencer les routines par
  symbole et être lié dynamiquement. Le pipeline « projet » v1
  (.properties, knapsack, RAMLoader) n'a pas à être porté pour un banc.
- **Scènes déclaratives** : les pages de sprites sont des régions, l'imageset
  un direntry `loadtimelink`, le tout chargé par une scène — l'outillage de
  la campagne précédente s'applique tel quel.
- Le banc peut vivre **sans object manager** : des OST statiques (comme les
  4 objets statiques de R-Type) + `DisplaySprite` suffisent pour exercer
  draw/erase/refresh/priorités. `UnloadObject_u` sera un stub.

## 7. Plan proposé (à valider)

- **Phase S0 — remise en état de gfxcomp** (écarts 1 à 5, + tests JUnit sur
  l'index imageset et le nb_cell). Livrable : gfxcomp enregistré dans
  `Handlers` (`FilePluginInterface`, comme `asm`), utilisable depuis
  config.xml, sortie validée par assemblage lwasm d'un sprite de test.
- **Phase S1 — gfxlock parité timing** (écart 6) : incrément de
  `frame.count` sous IRQ, `frameDrop.max` et `frame.gameCount` portés de la
  v1 (l'API v1 doit rester identique, tout le timing gameplay en dépend).
  Validé sous toje avec compteurs lus en RAM.
- **Phase S2 — portage du runtime** : les 7 fichiers, en conservant les noms
  de symboles v1 (compat wddebug) et la marge 16. Améliorations limitées à ce
  qui ne change pas les contrats : factorisation B0/B1 sur le modèle
  `CheckSpritesRefresh` si le budget cycles le permet, sinon port à
  l'identique d'abord.
- **Phase S3 — banc `examples/sprites`** : game mode cloné de sound, layout +
  scène déclarative (région gamemode + région page-sprites + imageset
  direntry), quelques sprites en mouvement avec recouvrements, priorités et
  suppression ; résultats en $9C00 comme loader-ut (compteurs, checksums de
  bbox) + validation visuelle toje (screenshot) et wddebug si possible.
- **Phase S4 — docs** : `docs/lang/en/sprites.md` (vide aujourd'hui),
  CLAUDE.md, TODO.

Décisions à valider avant de lancer :
1. Marge de cellule : aligner sur **16** (valeur v1, conservatrice) — outil et
   runtime ensemble.
2. Conserver les **noms de symboles v1** (CamelCase `DrawSprites`,
   `rsv_buffer_0`…) pour la compat wddebug et le diff facile avec la v1,
   quitte à déroger à la convention `module.routine` v2.
3. Porter directement le pack **ext** (crochets sprites encodés inclus, les
   décodeurs RLE/ZX0 restant des stubs `ifndef` tant qu'ils ne sont pas
   portés).
4. Périmètre S2 : port à l'identique d'abord (validation), factorisations
   ensuite — ou factorisation immédiate ?
