# CLAUDE.md — 6809-game-builder

## Contexte

Ce repo est la **v2 (« next generation »)** du game builder wide-dot pour Thomson TO8/MO6,
successeur de [`thomson-to8-game-engine`](../thomson-to8-game-engine) (la « v1 »).
La v1 reste la référence fonctionnelle : elle fait tourner **R-Type niveau 1 complet
(jusqu'au boss Dobkeratops inclus)** sur TO8. L'objectif de la v2 est de reconstruire
proprement la toolchain (plugins Java, load-time linker, formats de média) puis de
re-migrer le runtime ASM de l'engine. **La toolchain v2 est mature ; le runtime de jeu
ne l'est pas encore** — voir l'état des lieux ci-dessous.

Machines cibles : TO8 (principal) et MO6 (déjà largement supporté). Candidats futurs :
MO5, Tandy CoCo 3.

## Build & commandes

- Build toolchain : `mvn clean install` à la racine (multi-module, 17 modules ; JDK 11+,
  CI GitHub Actions sur `master`). Pour le seul builder :
  `mvn -pl toolbox/gamebuilder/core -am package` (jars déposés dans `repo/`).
- Construire un jeu/une démo : `gamebuilder -f <config.xml> [-t <target>] [-v] [-c]`
  (config XML : cible → média (`floppydisk fd640/fd320/fd158`, `rom t2`) → sections →
  `direntry` avec codec `zx0` et `loadtimelink` → sorties `<fd/> <sd/> <sap/> <hfe/>`).
- **Procédure validée sur macOS (07/2026)** : depuis le répertoire du projet/exemple,
  `java -cp "../../repo/*" com.widedot.m6809.gamebuilder.MainCommand -f to8.config.xml`.
  Prérequis : (1) un lien `engine → ../../engine` dans le répertoire du projet (les
  chemins du config.xml sont relatifs au config, `engine/` est gitignoré dans les
  exemples) ; (2) un `lwasm` **>= 4.22** accessible sous le nom **`lwasm.exe`** dans le
  PATH — le nom est codé en dur dans `LwAssembler.java`, et les binaires macOS fournis
  (`toolbox/third-party/bin/macos`, lwtools 4.18) ne comprennent pas les labels locaux
  `@` dans les macros utilisés par l'engine (le binaire Windows est en 4.22). Compiler
  lwtools 4.24 depuis les sources et symlinker en `lwasm.exe` fonctionne.
  Sorties dans `dist/` ; le `<hfe/>` échoue sur macOS (pas de `hxcfe`), l'omettre.
- Exemples de référence : `examples/sound` (le plus complet, TO8 + MO6 : boot, scènes,
  double-buffer, musiques YMM+VGC), `examples/tlsf-ut` (tests unitaires TLSF sur machine),
  `examples/mplus` (bancs de test carte son MPLUS : DAC, MIDI 6850, MEA8000, SN76489, YM2413).
- Assembleur : LWASM (LWTOOLS, binaires dans `toolbox/third-party/bin/<os>/`).
- Debug : `toolbox/debug` (**wddebug**) — GUI ImGui qui s'attache à DCMOTO/Teo en cours
  d'exécution (Windows + macOS) et lit la RAM émulée en direct.
- Conventions : commentaires en anglais (règle `.cursor/rules/wide-dot.mdc`), nommage
  `module.routine` / fichiers `xxx.const.asm` / `xxx.macro.asm` / `xxx.external.asm`,
  packs d'inclusion dans `engine/pack/` et `engine/system/<machine>/pack/`.

## État des lieux (juillet 2026)

### ✅ Fait et mature

| Bloc | Où | Notes |
|---|---|---|
| Builder Java (core/spi/util, plugins, parser LWOBJ16, floppydisk/fd/sap/hfe/sd) | `toolbox/gamebuilder/` | Le plus abouti du repo ; produit des images bootables |
| Load-time linker (relocation intern/extern8/extern16/externPg au chargement) | plugin `direntry` + `loader.file.link` | Remplace le placement statique de la v1 |
| Bootloader + loader + scene loader ASM (~1200 l.) | `engine/system/thomson/bootloader/loader.asm` | Chargement de scènes depuis disquette en cours de jeu, malloc de fichiers, décompression ZX0. Cycle de vie complété le 30/07/2026 : `linkData.unload`, dédup au rechargement, unload implicite sur écrasement de destination, `linkData.count` et `isLoaded`, validés 10/10 par `examples/loader-ut` sous toje. Restent : recouvrement partiel (tailles non suivies), concept « group » du design (`docs/lang/en/dynamic-link-data.md`) — voir l'analyse détaillée plus bas. |
| Allocateur TLSF 16 bits (+ realloc + UT embarqués) | `engine/memory/malloc/` | Nouveauté v2 (la v1 n'avait pas d'allocateur dynamique) |
| ZX0 (compresseur Java + 3 décompresseurs 6809) | `toolbox/gamebuilder/util/zx0`, `engine/compression/zx0/` | |
| Audio VGC (SN76489) + YMM (YM2413) + outils `vgm2vgc`/`vgm2ymm`/`vgm2sfx` | `engine/sound/`, `toolbox/audio/` | Démontré TO8 **et** MO6 (`examples/sound`) — R-Type v1 utilise exactement YMM + soundFX |
| Double buffering `gfxlock` (swap sur IRQ 50 Hz, compteurs frame/frame-drop) | `engine/system/thomson/graphics/buffer/` | Porté de la v1 ; base du timing gameplay |
| IRQ 50 Hz + sync ligne écran, palette, bank switching, modes vidéo | `engine/system/{to8,mo6}/` | Fonctionnel, minimal |
| Contrôleurs : clavier, clavier rapide, joypad, pad Megadrive 6 boutons | `engine/system/{to8,mo6}/controller/` | Équivalent v1 (dont `joypad.kb`) |
| Outils graphiques : `gfxcomp` (sprites/images compilés), `png2bin` (+ buffers `-vs/-vst/-hs`), `png2pal`, `stm2bin`, `leanscroll` | `toolbox/graphics/` | **Substantiels mais sans consommateur runtime** — les outils précèdent l'ASM |
| wddebug | `toolbox/debug/` | Très actif ; ses vues sprites/collisions/objets débuggent les structures v1 en attendant la v2 |

### 🚧 En cours / écrit mais non branché

- **MEA8000** (synthèse vocale) : actif, banc de test dans `examples/mplus`.
- **MUCOM88/YM2608** (`engine/sound/mucom88/`, ~2900 l.) : écrit, non intégré —
  `ym2608.init/detect/reset` et le handler IRQ manquent ; `engine/pack/mub.asm` pointe
  vers de mauvais chemins. Non requis pour R-Type.
- **MPLUS** (carte d'extension son + VHDL) : bancs de test, expérimental. Non requis pour R-Type.
- **Timing** : embryonnaire (`time.ms.wait` seul) ; `docs/lang/fr/timing.md` et
  `examples/timing/` documentent une API `wait.*` **qui n'existe pas**.
- **Math** : RNG seul (`random.asm`). La v1 a en plus sinus, atan2, Mul9x16 (mais R-Type
  niveau 1 n'utilise que le RNG).

### ❌ Absent du runtime ASM (tout reste à migrer depuis la v1)

Aucun code — seulement des équates réservées dans `glb.const.asm` (caméra, sprites,
alphaTiles), des docs vides (`docs/lang/en/{objects,sprites,tilemaps,audio}.md`) et les
vues wddebug orphelines :

- **Object manager** (v1 : `object-management/RunObjects.asm`, `Obj_Run` + macros,
  slots/liste chaînée, montage de page par objet `Obj_Index_Page`/`Obj_Index_Address`)
- **Sprites compilés** — runtime (v1 : `graphics/sprite/sprite-background-erase-ext-pack.asm` :
  `DrawSprites`/`EraseSprites`/`CheckSpritesRefresh`/`BgBufferAlloc`) ; le générateur
  côté outil existe déjà (`gfxcomp`, encoders `draw`/`bdraw` = ND*/NB*)
- **Animation** (v1 : `AnimateSpriteSync.asm`, `moveByScript.asm`)
- **Tilemap + scrolling** (v1 : `horizontal-scroll/scroll-map-buffered-even.asm` —
  scroll 1 px sur tilemap pré-bufferisée pointant des tiles compilées ; la v2 a le
  prototype nouvelle génération `hscroll` côté outil, cf. `png2bin -hs` au HEAD et le
  banc `thomson-to8-game-engine/game-projects/horizontal-band-scroll`)
- **Collisions** (v1 : AABB `collision-list`/`collision-do` + collision terrain
  `terrainCollision` par map de bits)
- **Caméra / AutoScroll** (v1 : `graphics/camera/AutoScroll.asm`, vitesse 8.8 sub-pixel)
- **Waves d'ennemis** (v1 : `ObjectWave-subtype.asm`, spawner temporel)
- **Game modes / transitions de niveau** (v1 : `level-management/LoadGameMode.asm` —
  partiellement remplacé par le scene loader v2, mais le delta-reload entre modes n'y est pas)
- **Fonts/DrawText**, objets engine clés en main (fade palette, raster) — secondaire.
- Côté **builder** : le pipeline « projet de jeu » de la v1 (hiérarchie
  `config.properties` → game-modes → objets, génération des `.glb` d'index
  `ObjID_*`/`Img_*`/`Ani_*`, bin-packing des objets en pages 16 Ko, `INCLUDEGEN`)
  n'a pas d'équivalent v2 : le config.xml actuel décrit des fichiers, pas des objets
  de jeu. À décider : reproduire ce pipeline en plugins SPI, ou faire porter ce rôle
  au load-time linker + conventions.

## Analyse détaillée : loader — cycle de vie incomplet (juillet 2026)

Source : `engine/system/thomson/bootloader/loader.asm`. Le **chemin de chargement**
(scène complète, premier chargement) est terminé et validé sur machine
(`examples/loader-ut`). Tout le **cycle de vie ensuite** est inachevé — c'est la
marche sur laquelle le travail s'était arrêté.

**Ce qui marche** : la table de saut du loader marque 9 entrées `OK` et une seule
`TODO` (`loader.file.linkData.unload`). `scene.load` fait trois passes (load disque
groupé → décompression ZX0 → chargement des link data) puis un **re-link complet de
tous les fichiers chargés**. Ce re-link global est voulu (cf.
`docs/lang/en/dynamic-link-data.md`) : il résout les références en avant — un
symbole non encore chargé se résout silencieusement à 0, puis est corrigé au
prochain `scene.load`. Relocations intern/extern8/extern16/externPg, recherche de
symboles, `getPageID`, fichiers « export-only » (flag fichier vide `$ff00`,
sous-scènes type `$8000`) : complets.

**Résolu le 30/07/2026** (validé 9/9 sous toje via `examples/loader-ut`) :
1. ~~`unload` stub~~ → **implémenté** : `loader.file.linkData.unload` (B=disk id,
   X=file id → B=$00/$FF) libère le buffer de link data (`tlsf.free`), décale les
   slots suivants, décrémente `occupiedSlots`. Routine partagée `linkData.slot.find`.
2. ~~Pas de dédup au rechargement~~ → **implémenté** : `linkData.load` recherche
   d'abord (diskId, fileId) dans l'index ; si présent, libère l'ancien buffer et
   réutilise le slot au lieu d'ajouter un doublon. Plus de fuite, plus de re-link
   fantôme quand on recharge un même fichier au même emplacement.
3. Nouveau : `loader.file.linkData.count` (jump table index 30, D=nb de fichiers
   indexés) pour l'observabilité des tests et diagnostics.
4. **Unload implicite** : enregistrer un fichier *différent* à la destination
   exacte (page+adresse) d'un fichier indexé retire l'entrée périmée
   (`linkData.slot.findByDest` + `linkData.slot.remove` factorisé) — le re-link
   global ne peut plus patcher des offsets périmés sur le nouveau binaire. C'était
   le dernier chemin de corruption du pattern courant (adresses fixes de scène,
   ex. musiques title/level1 d'`examples/sound`).
5. Macro `_loader.file.isLoaded` (`getPageID != $FF`, résultat dans CC).
6. **Layout disque ajusté** : le loader ayant grossi (~4,1 Ko > 16 secteurs), la
   section INDEX est passée du secteur 2 au secteur 4 en face 1
   (`engine/config/storage.xml` fd640+fd320, couplé à `DIR_DEFAULT_SECTOR` dans
   loader.asm) → ~768 octets de marge pour le loader. Les images produites avant
   ce changement ont l'index à l'ancien emplacement (re-builder).

**Ce qui manque encore** :
1. L'unload implicite ne couvre que la destination *exacte* : un chargement qui
   recouvre **partiellement** la mémoire d'un fichier indexé (adresse différente)
   laisse un slot périmé — les tailles ne sont pas suivies dans l'index. Discipline :
   `linkData.unload` explicite dans ce cas (ou ajouter la taille au slot, au prix
   d'un pas d'index ≠ 8).
2. Pas de shrink de l'index à l'unload (optionnel). Le design par **groups**
   (load/unload par group id, paginated groups — `dynamic-link-data.md`) n'existe
   ni côté ASM ni côté builder.

**Défauts annexes** : symbole non résolu = 0 silencieux par défaut (activer
`loader.CHECK_UNRESOLVED_SYMBOLS` piège en `bra *`) ; `linkData.entry.diskId` écrit
mais jamais comparé (collision d'ids entre disquettes) ; boucles extern16 et
symbol.search qui avancent avec `sizeof{}` d'une autre struct (même taille
aujourd'hui, fragile).

**Concept « group » : tranché le 30/07/2026** — spec minimale rédigée dans
`docs/lang/en/groups.md`. Décision clé : un group n'est PAS une nouvelle entité
média/runtime, **c'est un direntry multi-asm** (lwasm concatène les sections, le
codec compresse le flux entier, les link data sont émises fusionnées, le nom du
direntry sert d'alias) ; le cycle de vie par fichier déjà implémenté (isLoaded,
unload, dédup, count) EST le cycle de vie par group. La seule pièce à coder est
**`loader.scene.loadDelta`** (jump table index 33) : converger la RAM vers une
scène cible — passe d'unload des slots absents de la cible, skip des groups déjà
chargés à la même destination, re-link global. C'est l'équivalent v2 du delta-reload
du `RAMLoaderManager` v1 entre game modes. Tests prévus T11–T13 dans loader-ut.
Différés : élément `<group>` builder, paginated groups + outils de découpage,
interfaces/instances, suivi des tailles (recouvrement partiel), shrink d'index.

**Banc de test** : `examples/loader-ut` — game mode UT bootable qui exerce le
loader (zx0 + cdataz, raw, extern16, getPageID, `scene.load` à chaud avec
écrasement, re-link des références en avant, unload implicite T8, dédup T9,
unload explicite + isLoaded + count T10) et écrit ses résultats en `$9C00`
(magic `$CA`, statut final `$0D`/`$E0+n`). **Stress test (30/07/2026)** : T11 =
128 cycles load/unload/re-link de deux variantes sur la même destination
(fixups extern vérifiés dans les données fraîches, flips de symboles dans le gm
ET dans un fichier data stable, unload explicite tous les 16 cycles, le tout
dans le pool de 4 Ko — toute fuite le ferait exploser) ; T12 = croissance de
l'index au-delà de 8 slots (chemin realloc) + mass unload. Validé sous toje :
12/12 pass, index vérifié en mémoire (realloc 8→16, relogement, slots intacts).

**Deux bugs attrapés par le stress test (corrigés le 30/07/2026)** :
1. `loader.dir.load` : quand le répertoire dépasse 1 secteur, le buffer alloué
   n'était jamais écrit dans `map.DK.BUF` → les secteurs 2+ étaient lus sur les
   variables puis le code du loader (`ptsec+256` = $A127+). Bug dormant depuis
   l'origine — aucun projet n'avait de répertoire > 1 secteur (~30 entrées).
2. L'unload implicite par destination évinçait les fichiers export-only les uns
   après les autres (ils partagent tous la pseudo-destination (0,0)) — régression
   introduite avec l'implicite lui-même, qui cassait silencieusement le pattern
   `ym.const`+`sn.const` d'`examples/sound`. Convention actée : les fichiers
   vides ($ff00) sont exempts de l'éviction par destination.

## Reste à faire pour un R-Type minimal (niveau 1 + boss, parité v1)

Ce que le niveau 1 de R-Type v1 consomme réellement (source de vérité :
`thomson-to8-game-engine/game-projects/r-type/game-mode/01/main.asm`) :
gfxlock + frame-drop plafonné, IRQ 50 Hz, palette lean, bank switching, scroll
horizontal 1 px sur tiles compilées, sprites compilés mode background-erase étendu,
AnimateSpriteSync + moveByScript, RunObjects + Obj_Run + ObjectMoveSync + ObjectDp,
ObjectWave, collisions AABB + terrain, joypad/kbd bufferisé sous IRQ, RNG, musique YMM,
SFX YM2413 sous IRQ, LoadGameMode, et ~149 objets de jeu côté projet.

Ordre de migration suggéré (dépendances croissantes) :

1. **Sprites compilés runtime** (`DrawSprites`/`EraseSprites`/`BgBufferAlloc`) — brancher
   sur les sorties de `gfxcomp` ; c'est le contrat le plus fort de la v1 (les PNG
   deviennent du code, pas des données). Valider avec un exemple type `examples/sprites`.
2. **Object manager** (`RunObjects`, slots, montage de page par objet) + `ObjectDp`,
   `ObjectMoveSync`. Le modèle mémoire v1 (résident + objets montés en pages cartouche)
   est structurant : R-Type déporte même sa passe de collision et son end-stage dans
   des objets montés pour libérer le résident.
3. **Animation** (`AnimateSpriteSync`, `moveByScript`).
4. **Scroll horizontal + tilemap** : soit porter `scroll-map-buffered-even/odd` (parité
   v1 garantie), soit finaliser la nouvelle génération `hscroll` (outil déjà au HEAD) —
   décision d'architecture à prendre avant de migrer les maps de R-Type.
5. **Collisions** AABB + terrain (bitmap, tables xOffset/yOffset/xMask, mode boss-follow).
6. **ObjectWave** (spawner temporel) + **caméra/AutoScroll**.
7. **Pipeline builder « jeu »** : équivalent v2 des `.properties` v1 (objets, sprites,
   animations, palettes, acts, index `.glb`, placement en pages) — ou adaptation du
   projet R-Type au format config.xml + linker.
8. **Portage du projet R-Type lui-même** : game-modes 00 (title) + loading + 01,
   les ~60 objets du niveau 1, assets arcade, musiques YMM, SFX.
9. Garder l'API de compensation de frame-drop (`gfxlock.frameDrop.max`,
   `frame.gameCount`) **identique à la v1** : tout le timing gameplay (waves, boss,
   end-stage, timestamps calés sur l'arcade) en dépend.

Non requis pour R-Type minimal : MUCOM88/YM2608, MPLUS, MEA8000, SMPS/PCM/DAC,
fonts engine, Exomizer (ZX0 suffit), parallaxe tilemap (le starfield est un objet projet).

## Dettes / pièges connus

- Lanceurs `bin/unix/6809-gamebuilder-core` : `BASEDIR` résolu un niveau trop haut
  (cherche `bin/repo` au lieu de `repo/`) → ClassNotFound ; utiliser `java -cp "repo/*"`.
- `LwAssembler.java` : nom `lwasm.exe` codé en dur (pas de détection d'OS) ; binaires
  lwtools macOS embarqués obsolètes (4.18 vs 4.22 Windows).
- `engine/pack/mub.asm` : chemins d'INCLUDE invalides (fichiers dans `sound/mucom88/`).
- `engine/system/mo6/graphics/gfx.memset..asm` : double point dans le nom, orphelin.
- `examples/timing/` + `docs/lang/fr/timing.md` : API `wait.*` inexistante.
- `data.asm` et `mub.o` à la racine : artefacts orphelins (table clavier extraite de ROM ;
  objet LWOBJ16 issu de `mub.asm`), à déplacer/supprimer.
- Liens cassés : `readme.md` racine (4 liens doc vides), `docs/lang/en/readme.md`
  (chemins de l'ancien layout), renvoi vers `docs/lang/fr/readme.md` inexistant.
- Hors build Maven : `toolbox/audio/psg`, `toolbox/audio/smps`,
  `toolbox/graphics/tilemap/tmx-animation-lean` (friche).
- `pom.xml` : `maven.compiler.release=11` vs `java.version=23` (incohérence).
- Binaires third-party inégaux selon l'OS : pas de `hxcfe` macOS, pas d'`exomizer` linux-arm.
