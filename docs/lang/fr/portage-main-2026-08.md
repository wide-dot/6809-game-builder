---
date: 2026-08-05
sujet: Portage du main R-Type v1 → v2 — inventaire ligne à ligne et état vérifié
---

# Le main v1 contre le nôtre — ce qui est porté, ce qui diverge, ce qui manque

Ce document existe parce que le portage du main a été fait **par morceaux et sans
tenir de compte**, ce qui a produit des divergences invisibles jusqu'à ce qu'un
essai les révèle une par une. Il tient la liste, avec un état par ligne.

Source de vérité : `game-projects/r-type/game-mode/01/main.asm` du dépôt v1, et
les objets qu'il appelle. Rien ici n'est déduit : chaque ligne a été relue dans
la source.

## Convention d'état

| marque | sens |
|---|---|
| ✅ | porté, et **vérifié à l'exécution** |
| 🟡 | porté, **non vérifié** à l'exécution |
| ⚠️ | porté **avec divergence** — la divergence est nommée |
| ❌ | **absent** de notre portage, sans raison valable |
| ⛔ | absent parce que l'objet dont il dépend n'est pas porté |

## 1. `Level01_Start` — l'init (v1 : 242 o)

| # | v1 | v2 | état |
|---|---|---|---|
| 1 | `clr globals.nextGameMode` | — | ❌ |
| 2 | `jsr InitGlobals` | idem | 🟡 |
| 3 | `jsr InitDrawSprites` | idem, plus loin, mais **avant** le checkpoint comme en v1 | ✅ |
| 4 | clear `shellEraseTable` | — | ⛔ rotonde |
| 5 | `clr globals.difficulty` | idem | 🟡 |
| 6 | `jsr InitStack` | idem, plus loin, mais avant le checkpoint | ✅ |
| 7 | `jsr LoadAct` | chargement de scène v2 (`game.stage.switch`) | ✅ équivalent v2 |
| 8 | `jsr InitJoypads` | `joypad.init` | 🟡 |
| 9 | `jsr InitRNG` | idem, plus loin, mais avant le checkpoint | ✅ |
| 10 | `_terrainCollision.init ObjID_collision` | dans `stage.setup` | 🟡 |
| 11 | `_Obj_RunB ObjID_endstage,#endstage.INIT` | — | ⛔ endstage |
| 12 | `Pal_black` → `Pal_current`, `PalUpdateNow` | idem | ✅ |
| 13 | `moveByScript.register` | idem | 🟡 |
| 14 | `globals.score` + **`globals.stageScoreBase`** (24 bits) | score seul | ❌ base de score |
| 15 | `globals.lives` = 2, `globals.backgroundSolid` = 1 | idem | ✅ |
| 16 | `_Obj_Run ObjID_LevelInit` | `stage.openingSequence`, **après IrqOn** | ⚠️ à confirmer |
| 17 | `_Obj_Run ObjID_LevelWave` | `stage.setup` — le corps de l'objet, en ligne | ✅ |
| 18 | `_Obj_RunB ObjID_starfield,#starfield.INIT` | `paged.call starfield.init` | 🟡 |
| 19 | `gfxlock.bufferSwap.do` | idem | 🟡 |
| 20 | `RunObjects` | idem | 🟡 |
| 21 | `InitScroll` | idem | 🟡 |
| 22 | **`_Obj_Run ObjID_checkpoint`** | `paged.call checkpoint.load`, routine unique | ✅ **fermé le 05/08, cf. §5** |
| 23 | musique YMM | idem | ✅ |
| 24 | `IrqInit`, `Irq_user_routine`, `IrqSync`, `_gfxlock.init`, `frameDrop.max`=8, `IrqOn` | idem | ✅ |
| 25 | `LoadObject_x` + `ObjID_initlevel1` | `stage.openingSequence` | ✅ |
| 26 | amorçage `forcepodOST`, `bitdevTopOST`, `bitdevBotOST` en Dormant | emplacements réservés, non amorcés | ⛔ |

**Ajouts v2 sans contrepartie v1** : la remise à zéro des OST statiques (la v1
l'obtient de son binaire, cf. `reserved-ram-is-not-zeroed.md`), et l'horloge de
niveau `gfxlock.frame.gameCount` remise à zéro (le moteur v2 est résident).

## 2. `mainloop.routine.running` (v1 : 206 o)

Relevé fait le 2026-08-04, appel par appel. Manquent, tous ⛔ :
`_Obj_RunU ObjID_forcepod`, `_Obj_RunU ObjID_bitdevice` ×2,
`_Obj_RunB ObjID_endstage,#endstage.BLIT`, `_Obj_Run ObjID_shellEraser`,
`_Obj_RunB ObjID_endstage,#endstage.TICK`.

Le reste est dans le même ordre que la v1. 🟡

## 3. `mainloop.routine.dead` (v1 : 75 o)

Porté à l'identique. 🟡

## 4. `UserIRQ` (v1 : 24 o)

Porté ; l'ordre `bufferSwap → PalUpdateNow → joypad` a été rétabli le
2026-08-04 après avoir été inversé. ✅

## 5. La divergence de fond : le checkpoint

**La v1 n'a qu'une routine.** `objects/checkpoint/checkpoint.asm` porte
`checkpoint.load`, appelée par `Level01_Start` **et** par
`mainloop.routine.checkpoint`. Elle fait :

```asm
        (choisit le point de reprise selon scroll_tile_pos)
        jsr   ObjectDp_Clear / ManagedObjects_ClearAll / InitStack
        jsr   DisplaySprite_ClearAll / EraseSprites_ClearAll / Collision_ClearLists
        ldx   #$FFFF
        jsr   ClearDataMem
        _SwitchScreenBuffer
        ldx   #$FFFF
        jsr   ClearDataMem
        (rejeu du defilement jusqu'a la position)
```

Notre portage en a fait **deux moitiés divergentes** :

- l'init appelle quatre fois `ClearInterlacedEven/OddDataMemory` avec `$0000`,
  puis un `preScroll` **que nous avons écrit** ;
- le rechargement appelle `stage.checkpointLoad`, qui appelle ce même
  `preScroll`.

Trois écarts en découlent, tous vérifiés dans la source :

1. **la v1 efface avec `$FFFF`**, pas `$0000` — c'est ainsi qu'elle pose le ciel
   en nibble `$F`. `preScroll` a été écrit pour peindre ce que la bonne valeur
   d'effacement donne gratuitement ;
2. **les routines « entrelacées » n'existent pas dans le moteur v1.**
   `engine/ram/` n'a que `ClearCartMemory`, `ClearDataMemory` et
   `ClearDataMemoryRAMx`. La v1 traite les deux tampons par
   `_SwitchScreenBuffer` entre deux `ClearDataMem` ;
3. **`ClearDataMem` manquait de l'arbre v2** — importé le 2026-08-04 seulement,
   après qu'un essai a montré le décor visible derrière READY.

### Fermé le 2026-08-05

`checkpoint.load` est porté en entier dans `src/common/flow/checkpoint.unit.asm`,
sans paramètre, appelé des deux endroits comme la v1. `preScroll`, les quatre
appels entrelacés, l'unité `clear` et sa région ont disparu ; les gestes que
l'init dupliquait (`ObjectDp_Clear`, `player1+id`, le fondu d'entrée,
`ObjectWave_Init`, la remise à zéro de l'horloge) sont rendus à la routine.

**Un quatrième écart, invisible en lecture, a été trouvé au pas-à-pas.** Porter
`_SwitchScreenBuffer` tel quel ne suffit pas : c'est un toggle RELATIF
(`eor #1 / or #2`) qui ne rend 2 ou 3 que si le registre porte déjà 2 ou 3. En
v1 c'était acquis — `gfxlock.bufferSwap.do` écrivait `$E7E5` à chaque trame, et
`LoadAct` laissait `$E7E5=3` (son propre commentaire le dit). En v2
`bufferSwap.do` n'écrit que la page AFFICHÉE (`$E7DD`), la fenêtre données est
montée en absolu par `_gfxlock.on`, et `game.stage.switch` laisse la page du
LOADER en place. Le toggle donnait donc 7 puis 6 : on effaçait deux pages
étrangères, et le pré-scroll partait dans du `$FF`, écran noir. Correctif :
`_ram.data.set #2` en ancrage absolu avant le premier effacement — la leçon
déjà écrite dans `_gfxlock.on` pour le PRC.

Cas de migration : `checkpoint-is-one-routine.md`,
`relative-toggles-on-shared-registers.md`.

## 6. Routines du moteur non importées, relevé du 2026-08-04

| routine | v1 | état v2 |
|---|---|---|
| `ClearDataMem` | `engine/ram/ClearDataMemory.asm` | importé le 04/08, dans l'unité checkpoint |
| `ClearDataMemRAMx` | `engine/ram/ClearDataMemoryRAMx.asm` | ❌ non importé |
| `ClearCartMemory` | `engine/ram/ClearCartMemory.asm` | ❌ non importé |
| `InitFadeOut` / `FadeOut` | `engine/graphics/fade/pixel-fade.asm` | importé, non câblé (objet endstage) |
| `bm4.drawChunks` | `engine/graphics/codec/bm4.drawChunbks.asm` | importé, câblé (messages) |

## 6bis. Ce qui manque encore au main — liste arrêtée le 2026-08-05

**Portables tout de suite** (rien ne les bloque) :

| # | manquant | v1 | pourquoi ça compte |
|---|---|---|---|
| 1 | `clr globals.nextGameMode` | init, 1re ligne | la variable de sortie de niveau ; non remise à zéro, un stage hérite de la sortie du précédent |
| 2 | `globals.stageScoreBase` (24 bits) | init | base de score au début du stage — le score de fin de stage s'en déduit |
| 3 | `ClearDataMemRAMx` | `engine/ram/` | effacement d'une page données autre que la courante |
| 4 | `ClearCartMemory` | `engine/ram/` | effacement de la fenêtre cartouche |

**Correction du 2026-08-05** : `_Obj_Run ObjID_LevelWave` figurait ici à tort.
L'objet v1 `LevelWave` n'a pas de comportement — son corps entier fait six
instructions, exécutées une fois à l'init : `ldd #Level_data / std
object_wave_data / std object_wave_data_start / _GetCartPageA / sta
object_wave_data_page / rts`. Le déclarer objet était le moyen v1 de faire
PLACER ses données dans une page et d'en apprendre le numéro au vol. Nous
faisons exactement ces cinq écritures dans `stage.setup`, la page venant d'une
équate de pageset au lieu de `_GetCartPageA`. C'est porté, pas absent — et
c'est pour ça que la vague marche déjà. Même cas que
`main-private-object.md`.

**Bloqués par un objet non porté** (⛔ — à reprendre avec l'objet) :

| # | manquant | dépend de |
|---|---|---|
| 6 | clear `shellEraseTable` (init **et** checkpoint) | objet rotonde |
| 7 | `_Obj_RunB ObjID_endstage,#endstage.INIT` (init, et au replay du checkpoint) | objet endstage / boss |
| 8 | amorçage Dormant de `forcepodOST` (init **et** checkpoint) | objet force pod — les deux bit devices sont FAITS depuis le 05/08 |
| 9 | `_Obj_RunU ObjID_forcepod`, `_Obj_RunU ObjID_bitdevice` ×2 dans la boucle | force pod ; les OST des bit devices existent et sont amorcés, il reste à les faire tourner |
| 10 | `_Obj_RunB ObjID_endstage,#endstage.BLIT` et `#endstage.TICK` | endstage |
| 11 | `_Obj_Run ObjID_shellEraser` | rotonde |
| 12 | `InitFadeOut` / `FadeOut` (importés, non câblés) | endstage |

**Non applicable** : `LoadAct` (code généré v1, remplacé par le loader de scène),
`IFDEF DEBUG_START_LAST_CHECKPOINT` (aide de développement v1).

## 6ter. Les objets v1 encore à porter — relevé du 2026-08-05

Critère objectif : présence de l'objet dans les `.properties` **actifs** des sept
game modes v1 (01 à 08). 73 objets distincts au total.

### Communs — déclarés par les SEPT game modes

| objet | état v2 |
|---|---|
| `animation`, `fade`, `Player1`, `Weapon`, `beamcharge`, `beamp`, `foefire`, `collision`, `Mask`, `hud`, `LevelInit` | ✅ portés |
| `pow`, `pow_optionbox` | ✅ **portés et câblés le 05/08** |
| `bitdevice` | ✅ **porté et câblé le 05/08** |
| `forcepod` + `forcepod_reboundlaser` + `forcepod_counterairlaser` | importés 1:1, **non câblés** — 2 260 lignes, 27 fichiers d'images |
| `LevelWave` | ✅ porté — son corps est dans `stage.setup` (cf. correction §6bis) |

Quasi-communs (5 ou 6 modes sur 7), même nature : `createFoeFire` et
`loadFirePreset` ✅ portés ; `bossmusic` en bouchon ;
`forcepod_simplefire` / `_straightup` / `_straightdown` accompagnent le force
pod ; `p1explosion` est le nom que les stages ≥ 03 donnent à `explosion` ✅.

### Spécifiques — un à quatre game modes

Cast des niveaux et machinerie de stage : `patapata`, `bug`, `bink`, `scant`,
`pstaff`, `cancer`, `blaster`, `shell`, `tabrok`, la famille `dobkeratops`
(6 objets), `shellEraser`, `tabrokcanon`, `scantfire`, `commonmissile(flame)`,
`fadetotunnel`, `endstage`, `mainext`, `starfield`, `initlevel1`, `messages`,
`checkpoint`, `soundFX`, `ymm01`, `emitter_flash`, `engineflames`.

Parmi eux, sont ✅ portés : `patapata`, `explosion`, `initlevel1`,
`engineflames`, `messages`, `emitter_flash`, `starfield`, `checkpoint`,
`soundFX`, `ymm01`. Les autres sont en bouchon dans l'index d'objets — leur
identifiant existe, leur code non.

## 7. Ce qui reste à vérifier À L'EXÉCUTION

Tout ce qui porte 🟡 ci-dessus n'a **jamais été éprouvé** autrement que par « le
jeu démarre ». En particulier : l'ordre des appels de l'init, `InitGlobals`,
`moveByScript.register`, et le retour d'écran après le message READY — symptôme
ouvert au 2026-08-04.

## Méthode, pour ne pas refaire les mêmes erreurs

Trois règles nées des erreurs de cette session :

1. **Porter une routine depuis son PREMIER octet**, jamais depuis son milieu.
   `ClearDataMem` a été perdu parce que le portage du checkpoint a commencé à
   `_Obj_Mount ObjID_messages`.
2. **Lire la source avant de théoriser.** Le décor visible derrière READY a été
   attribué à un décalage d'index de palette — une construction — alors que la
   v1 efface simplement l'écran deux lignes plus haut.
3. **Ne déplacer du code qu'après avoir vérifié appel par appel** qu'aucune
   appelée ne commute la fenêtre cartouche sans la rendre. Deux déplacements ont
   dû être annulés faute de cette vérification.
4. **Un macro v1 importé porte une précondition non écrite.** `_SwitchScreenBuffer`
   suppose que le registre porte déjà une page écran ; en v1 une routine de trame
   le garantissait, en v2 personne. Avant d'importer un `lire / modifier / écrire`
   sur un registre matériel, chercher QUI garantissait la valeur d'entrée.
5. **Quand la lecture ne suffit plus, passer au pas-à-pas.** L'écran noir de ce
   correctif n'était visible dans aucune source : il a fallu poser un point
   d'arrêt sur `checkpoint.load`, lire `$E7E5` et constater la page 4.
