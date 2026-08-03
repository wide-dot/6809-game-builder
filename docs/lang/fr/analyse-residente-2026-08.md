---
date: 2026-08-04
sujet: la page résidente de R-Type — ce qu'elle contient, ce qu'on peut en sortir,
       et ce qu'il faut pour retrouver le pool d'objets de la v1
---

# La page résidente : inventaire, marges, et le chemin vers 50 objets

## Le constat qui commande tout le reste

**Nous ne sommes pas plus gros que la v1. Nous sommes moins bien déclarés.**

| | v1 | v2 (04/08/2026) |
|---|---:|---:|
| Code + tables résidents | 9 426 | 9 670 |
| OST hors pool | 468 | 117 |
| **Pool d'objets** | **5 850** (50 slots) | **1 872** (16 slots) |
| Variables inter-main + page directe | 380 | 380 |
| **Total page `$6100-$9FFF`** | **16 124** | **12 039 + 4 073 déclarés inutilisés** |

Le contenu v2 tient dans 244 octets de plus que celui de la v1 — pour un moteur
qui porte en plus `fade` en résident et un décompresseur zx0, et qui n'a pas
encore le boss, `WeaponContactTick`, les quatre palettes ni `LoadAct`. Autrement
dit : **le pool est petit parce que les budgets ont été déclarés larges, pas
parce que le code a grossi.**

Les 4 073 octets déclarés-mais-vides, au 04/08 :

| zone | déclaré | occupé | dormant |
|---|---:|---:|---:|
| `common` | 9 984 | 8 131 | 1 853 |
| `stage` | 2 224 | 1 539 | 685 |
| trou `$9875-$9BFF` | 907 | 0 | 907 |
| `bench.wit` | 644 | 16 | 628 |

Le cas de `bench.wit` mérite une ligne : la zone n'a jamais eu besoin de
644 octets, elle a été déclarée jusqu'à `$9E84` parce que rien d'autre ne
réclamait la place. Seize octets de témoins sont réellement écrits.

## Ce que la v1 met dans son main

Reconstruit depuis `generated-code/level01/FD/main.lwmap` — 15 744 octets de
`$6100` à `$9E80`, soit la page entière moins les variables inter-main.

| bloc | octets |
|---|---:|
| **Pool d'objets** (`Dynamic_Object_RAM`, 50 × 117) | **5 850** |
| Chaîne sprites (CSR, Erase, Draw, DPS, BgBuffer, DeleteObject) | 2 600 |
| Cellules d'effacement de fond (×2) | 912 |
| Init de niveau + boucle + états + fondu + boss | 1 073 |
| Gestionnaire d'objets, wave, `Obj_Run`, `RunPgSubRoutine` | 692 |
| OST hors pool (fade, forcepod, 2 bitdevices) | 468 |
| `AnimateSpriteSync` + `moveByScript` | 480 |
| Scroll | 449 |
| Les 5 tables d'index d'objets | 385 |
| `tryFoeFire` + `setDirectionTo` | 372 |
| Buffers de priorité d'affichage (×2) | 332 |
| Tables sous-objets erase/draw | 256 |
| IRQ, palette, joypad, gfxlock, banking, RNG, score, WeaponContactTick | 1 034 |
| Traînée du joueur, table rotonde, variables starfield, 4 palettes | 353 |

**Plus de la moitié du main v1 est de la RAM, pas du code.** « Le main est
serré » veut dire « les tables sont serrées ».

Trois gestes de la v1 qui se lisent dans cette carte :

1. **Tout ce qui peut être un objet monté l'est** — 55 `ObjID_` en page
   cartouche. Y compris `fade`, que nous avons rendu résident.
2. **`gfxlock.on/off/loop` sont enveloppés en routines locales** (`main.asm:386`,
   95 octets) et appelés par `jsr`. Nous expansons les macros à chaque site.
3. **`obj_mainext` en dernier recours**, et il ne contient presque rien —
   `Collision_Do` seul, `WeaponContactTick` étant resté résident. Quand ils l'ont
   créé, tout le reste était déjà sorti.

## Notre moteur, octet par octet

Mesuré sur `gen/common/build/engine.lst`, 8 131 octets. Les vingt premiers postes :

| octets | fichier | nature |
|---:|---|---|
| 1 568 | `EraseSprites.asm` | dont **912 de listes de cellules** (RAM) |
| 1 072 | `CheckSpritesRefresh.asm` | code |
| 498 | `DrawSpritesExtEnc.asm` | code |
| 466 | `scroll-map-buffered-even.asm` | code + état du scroll |
| 415 | `RunObjects.asm` | code + pile d'objets (32 o) |
| 411 | `DisplaySprite.asm` | dont **204 de buffers de priorité** (RAM) |
| 279 | `fade.asm` | **objet monté en v1** |
| 276 | `setDirectionTo.asm` | code |
| 276 | `moveByScript.asm` | code |
| 223 | `UnsetDisplayPriority.asm` | code |
| 206 | `Irq.asm` | code |
| 204 | `DeleteObject.asm` | code |
| 182 | `AnimateSpriteSync.asm` | code |
| 162 | `PalUpdateNow.asm` | code + `Pal_buffer` (32 o) |
| 161 | `AnimateSprite.asm` | code |
| 126 + 30 + 44 | décompresseur **zx0** | code, **jamais exécuté ici** |
| 128 | tables sous-objets erase/draw | RAM |
| 109 + 75 | `collision-do` + expansions `_Collision_Do` | **c'est le mainext de la v1** |
| 100 | `ClearInterlacedDataMemory.asm` | appelé à l'init et au checkpoint |
| 88 | `projectile.asm` (`tryFoeFire`) | code |

Environ **1 324 octets du moteur sont des tables de RAM** (cellules 912,
buffers de priorité 204, sous-objets 128, pile d'objets 32, `Pal_buffer` 32,
tampon joypad 16). Elles sont incompressibles et doivent rester en page 1 :
elles sont lues par du code résident à chaque trame.

## Ce qu'on peut sortir, et ce qu'on ne peut pas

### Sortable

| quoi | octets | pourquoi c'est sûr |
|---|---:|---|
| **`fade`** en objet monté — *fait le 04/08* | 279 | la v1 le monte (`object.fade=…`). Il a un OST, un index de routine, et l'explosion vient de montrer que la page `$14` accueille très bien ce genre d'unité |
| **La passe de collision** (`Collision_Do` + expansions) | 184 | calcul pur, page-neutre — c'est exactement ce que la v1 met dans `obj_mainext`. Seule la boucle l'appelle |
| **`ClearInterlacedDataMemory`** | 100 | appelé deux fois : ouverture de stage et checkpoint. Un `paged.call` suffit |
| **Décompresseur zx0** | 200 | aucune image de R-Type n'est encodée `rle`/`zx0` — que du `bdraw`/`draw`. `DrawSpritesExtEnc` garde ses deux `jsr`, donc il faut un talon, pas une suppression |
| **`gfxlock` en routines** | 151 (dans `stage`) | trois enveloppes de 95 o + un `jsr` par site remplacent 276 o d'expansions. Placées dans le moteur plutôt que dans le stage, elles sortent en plus **huit variables de l'interface** — mais coûtent alors 92 o à `common` |

**Total sortable : 763 octets de `common`**, plus 151 de `stage`.

### Non sortable — et pourquoi (vérifié, pas supposé)

- **`setDirectionTo` (276)** — tentant, puisque `createFoeFire` qui l'appelle
  est déjà dans une page montée. Mais la v1 a **cinq** sites d'appel dans
  **quatre pages différentes** : `player_missile`, `commonmissile`, `scant`,
  `blaster`, plus `createFoeFire`. Il reste résident.
- **`tryFoeFire` (88), `moveXPos/YPos8.8` (56), `AwardScore` (80)** — appelés
  par des objets montés, à chaque trame pour les deux premiers.
- **Toute la chaîne sprites (≈ 4 400)** — appelée par la boucle *et* par les
  objets, et elle porte les tables de RAM.
- **`AnimateSprite`/`AnimateSpriteSync`/`moveByScript` (619)** — appelés depuis
  les pages montées.
- **Le scroll (466)** — appelable en `paged.call` en théorie (une fois par
  trame), mais la v1 le garde résident et il touche l'état partagé du double
  tampon. À ne considérer qu'en dernier recours.

## Le chemin vers 50 objets

Cible : la géométrie v1, `nb_dynamic_objects = 50` et
`nb_graphical_objects = 64`.

Le second n'est pas gratuit : il dimensionne les tables sous-objets
(2 × 64 × 2 = 256, contre 128 aujourd'hui) et les listes « unset » des buffers
de priorité (idem). **+256 octets au moteur** — une dépense, pas une économie,
mais 50 objets dont seulement 32 peuvent être dessinés n'aurait pas de sens.

L'échelle, dans l'ordre où je la monterais :

| # | geste | rend |
|---|---|---:|
| 0 | *(fait le 04/08)* rééquilibrer `common`/`stage` et reprendre le trou de 176 o | — |
| 1 | Resserrer les budgets déclarés sur le contenu + une marge **énoncée** | 2 538 |
| 2 | Reprendre le trou `$9875-$9BFF` | 907 |
| 3 | Ramener `bench.wit` à ses 16 octets réels | 628 |
| 4 | `fade` en objet monté — **fait le 04/08** | 279 |
| 5 | La passe de collision en unité montée (le `mainext` de la v1) | 184 |
| 6 | Talon zx0 | 200 |
| 7 | `ClearInterlacedDataMemory` en `paged.call` | 100 |
| 8 | `gfxlock` en routines | 151 |
| | **disponible** | **4 987** |
| | à retrancher : `nb_graphical_objects` 32 → 64 | −256 |
| | **net pour le pool** | **4 731** |

Le pool passerait de 1 872 à **6 603 octets, soit 56 slots** — au-dessus des 50
de la v1, avec ~750 octets de marge.

Cette marge n'est pas du luxe : il reste à porter le HUD, les messages,
`endstage`, le boss et ses maths (`CalcSine`, `Mul9x16`), `WeaponContactTick`,
et surtout **trois OST hors pool** (force pod + deux bit devices) qui coûteront
**351 octets** de plus dans `objects.static`. La v1 portait tout cela dans ses
9 426 octets ; nous en sommes à 9 670 sans rien de tout ça.

## Ce qu'il ne faut pas faire

- **Réduire `object_rsvd_size` (59 o/objet).** Ce sont les 19 octets d'état de
  rendu partagés plus 2 × 20 par tampon d'écran — le double buffering. Les
  toucher, c'est réécrire le moteur de sprites. La v1 paie les mêmes 117 octets
  par objet.
- **Sortir le pool de la page 1.** Un OST est adressé par `U` depuis du code qui
  tourne en page cartouche montée ; seule la RAM `$6000-$9FFF` est visible en
  permanence.
- **Compter sur `$4000-$5FFF`.** Les 8 Ko y sont déjà entièrement découpés en
  128 cellules de 64 octets par l'allocateur de fonds de sprites.

## Méthode

Les chiffres v1 viennent de `main.lwmap` (1 208 symboles triés par adresse), les
chiffres v2 de `engine.lst` et `stage01-main.lst` (octets émis attribués au
fichier `INCLUDE` d'origine) et de `dist/ram-map-fd.txt`. Aucun n'est estimé ;
les seules extrapolations sont marquées comme telles (le coût de
`nb_graphical_objects`, calculé depuis les `fill` de `DisplaySprite.asm` et
`CheckSpritesRefresh.asm`).
