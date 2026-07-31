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
- **Plugins de conversion** (`vgm2ymm`, `vgm2vgc`, `vgm2sfx`, `pcm`, `png2pal`,
  `phoneme`, `txt2bas`) : ce sont des modules Maven séparés dont le jar est déposé
  dans **`plugins/<nom>/`** (pas dans `target/`) et chargé au runtime par
  ServiceLoader. Un `mvn package` **à la racine** les produit tous les 7 ; un build
  ciblé (`-pl toolbox/gamebuilder/core -am`) ne les inclut pas, d'où des
  « Unknown Plugin: vgm2ymm » sur les projets qui les utilisent.
- **Procédure validée sur macOS (07/2026)** : depuis le répertoire du projet/exemple,
  `java -Dbasedir=<racine du repo> -cp "../../repo/*" com.widedot.m6809.gamebuilder.MainCommand -f to8.config.xml`.
  Prérequis : (1) un lien `engine → ../../engine` dans le répertoire du projet (les
  chemins du config.xml sont relatifs au config, `engine/` est gitignoré dans les
  exemples) ; (2) un `lwasm` **>= 4.22** accessible sous le nom **`lwasm.exe`** dans le
  PATH — le nom est codé en dur dans `LwAssembler.java`, et les binaires macOS fournis
  (`toolbox/third-party/bin/macos`, lwtools 4.18) ne comprennent pas les labels locaux
  `@` dans les macros utilisés par l'engine (le binaire Windows est en 4.22). Compiler
  lwtools 4.24 depuis les sources et symlinker en `lwasm.exe` fonctionne ; (3)
  **`-Dbasedir`** pointant sur la racine du repo dès qu'un plugin de conversion est
  utilisé : le builder cherche les plugins dans `${basedir}/plugins`, et sans cette
  propriété il les cherche dans le répertoire courant.
  Sorties dans `dist/` ; le `<hfe/>` échoue sur macOS (pas de `hxcfe`), l'omettre.
- Les scripts `bin/unix/` et `bin/windows/` ne sont **pas faits pour être lancés depuis
  les sources** : ce sont des zones de staging que les descripteurs `package/` mappent
  vers `/bin` de la distribution, où leur `BASEDIR` (un cran au-dessus du script)
  retombe bien sur la racine avec `repo/` et `plugins/` à côté.
- Exemples de référence : `examples/sound` (le plus complet, TO8 + MO6 : boot, scènes,
  double-buffer, musiques YMM+VGC), `examples/loader-ut` (banc de test du loader, 15/15),
  `examples/tlsf-ut` (tests unitaires TLSF sur machine),
  `examples/mplus` (bancs de test carte son MPLUS : DAC, MIDI 6850, MEA8000, SN76489, YM2413).
- **État de validation au 30/07/2026** : les **8 configs** des exemples buildent
  (`mplus/to8-mplus-test`, `mplus/to8-mplus-pcm`, `mplus/mo6-mplus-test`, `sound/to8`,
  `sound/mo6`, `tlsf-ut/to8`, `tlsf-ut/mo6`, `loader-ut/to8`). Exécution vérifiée sous
  toje pour toutes les images **TO8** (sound : changement de scène à chaud + données
  musicales correctes en RAM ; mplus factory test : affiche son écran, les tests timer
  sortent « KO » car toje n'émule pas la carte MPLUS ; mplus pcm : boucle principale ;
  tlsf-ut et loader-ut : verts). Les images **MO6 ne sont validées qu'au build** — pas
  d'émulateur MO6 disponible ici (toje est TO8 uniquement).
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
| Bootloader + loader + scene loader ASM (~1200 l.) | `engine/system/thomson/bootloader/loader.asm` | Chargement de scènes depuis disquette en cours de jeu, malloc de fichiers, décompression ZX0. Cycle de vie complété le 30/07/2026 : `linkData.unload`, dédup au rechargement, unload implicite sur écrasement de destination, `linkData.count` et `isLoaded`. Multi-disquette validé (liens croisés dans les deux sens). Validé **15/15** par `examples/loader-ut` sous toje, qui a fait remonter 4 bugs dont 2 dormants depuis l'origine. Restent : recouvrement partiel (tailles non suivies), identité de fichier ambiguë entre disquettes pour `getPageID`/`externPg` — voir l'analyse détaillée plus bas. |
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

## Revue Java & campagne de correction (30/07/2026)

Revue complète en trois passes : `docs/lang/fr/revue-java-2026-07.md` (15 défauts
avec fichier:ligne, dépendances, testabilité, plan par phases). Les 4 phases ont
été exécutées ; à chaque étape les images des 8 configs d'exemples ont été
comparées **octet par octet** avec les précédentes, et `loader-ut` rejoué sous toje.

- **Phase 0** — le build ne mentait plus : `MainCommand` en `Callable<Integer>`,
  erreurs d'écriture propagées, JUnit + surefire, 22 tests sur les fonctions pures
  (SAP, checksum fd640, cascade Attribute). Un build cassé sort désormais en
  exit ≠ 0. *Effet de bord assumé : les configs déclarant `<hfe/>` échouent sur
  macOS faute de `hxcfe` — elles échouaient déjà, en silence.*
- **Phase 1** — bugs de format : garde-fou 16 Ko réactivé (il lisait la mauvaise
  clé de defaults et n'a **jamais** servi), SAP format 2 invalide (`*` au lieu de
  `+`), détection des drives SAP décalée, `FdUtil.getIndex` dérivé de la géométrie
  déclarée, fenêtre zx0 découplée de `maxsize`, bornes explicites (piste 7 bits,
  255 secteurs), et reproductibilité par target (`LinkSymbols` remis à zéro comme
  `FileIds` : `-t fd` et `-t sd,fd` donnent enfin la même image).
- **Phase 3** — hygiène : `openipa` (appli Next.js vendorisée de 8,8 Mo) sortie
  des resources et ses deux manifestes JS retirés — c'était l'origine du gros des
  alertes Dependabot ; jar phoneme 7,2 Mo → 815 Ko. Versions toutes figées,
  logback 1.5.19, `dependabot.yml`, jython déplacé vers son seul consommateur,
  3 modules morts supprimés avec `libtiled`, `pluginManagement` racine, et
  `mvn clean` qui nettoie enfin `repo/` et `plugins/` (des jars périmés s'y
  empilaient et cassaient le classpath).
- **Phase 2** — verrous d'évolution : source unique du calcul de taille d'entrée
  avec assertion croisée (ids réservés == blocs émis), `evalReloc()` factorisée
  dans `LwObject` (4 émetteurs, ~70 lignes en moins, et 4 bugs corrigés dont une
  relocation 8 bits appliquée en 16 bits), unicité des exports vérifiée au build,
  et surtout **rebasage des offsets multi-section et multi-objet** : un direntry
  peut enfin contenir plusieurs membres porteurs de link data. C'est le
  déverrouillage concret du modèle « group » (validé par T16).

**`BuildContext` (31/07/2026)** : l'état de build n'est plus statique. Un objet
`spi/BuildContext` porte le chemin racine, les settings, la table de symboles de
link, l'allocateur d'ids et les defaults/defines *scopés* (`child()` pour un
conteneur imbriqué, `publish()` au retour). Les 4 interfaces SPI passent de
`(node, path, defaults, defines)` à `(node, ctx)` — 39 fichiers touchés, dont les
7 plugins de conversion. `Settings` devient une instance dans `spi/configuration`,
`LinkSymbols` et `FileIds` deviennent des instances. Seul reste statique le
*registre* de plugins (`Plugins`), chargé une fois par JVM et jamais muté : ce
n'est pas de l'état de build. Effet mesuré : **deux configurations traitées dans
une seule JVM produisent désormais des images identiques à des builds isolés**,
ce qui était impossible avant (les ids de symboles fuyaient d'une config à
l'autre). Ça débloque aussi la parallélisation de lwasm et les tests
d'intégration. Images des 8 configs inchangées octet pour octet, loader-ut 16/16.

**Mécanisme de plugins supprimé (31/07/2026)** : le builder chargeait ses
fonctionnalités par `ServiceLoader` + `URLClassLoader`, avec 47 classes de
fabriques et 16 fichiers `META-INF/services` — une architecture d'extension
dynamique alors que **tout est dans le même dépôt et le même réacteur Maven**,
et que le SPI n'a jamais été publié (un tiers devait déjà cloner et builder le
projet). Ce que ça coûtait : des pannes silencieuses (une faute de frappe dans un
fichier de service ou un jar non reconstruit donnait « Unknown Plugin » très loin
de la cause — vécu deux fois cette session), et une liste `SHARED_PACKAGES` en dur
dans le cœur où traînait `com.caoccao.javet`, un moteur JS qu'aucun pom ne déclare.

Remplacé par `core/Handlers.java` : **une ligne par fonctionnalité**, vérifiée par
le compilateur (`MEDIA.put("directory", DirectoryPlugin::run)`). Les convertisseurs
deviennent des dépendances Maven normales du cœur et exposent un `getObject`
statique. Bilan : **−2 400 lignes**, 89 fichiers supprimés, et `-Dbasedir` n'est
plus nécessaire. Ajouter une fonctionnalité = écrire la classe + une ligne
d'enregistrement.

Si le chargement dynamique redevenait un objectif, le registre est précisément le
point d'ancrage où brancher un loader — il faudrait d'abord publier le SPI et le
versionner, ce qui n'a jamais été fait.

**Contrat d'attributs (31/07/2026)** — analyses préalables dans
`docs/lang/fr/analyse-config-2026-07.md` (XML vs YAML : XML conservé, la douleur
était dans le décodage) et `analyse-dsl-2026-07.md` (DSL externe décliné, critères
de réévaluation écrits). Réalisé en trois couches :
1. **Loader StAX** (`config/XmlLoader`) remplaçant XMLConfiguration : mêmes arbres
   (prouvé bit à bit sur les images), positions fichier:ligne conservées
   (`SourceMap` dans le contexte), xml:space=preserve hérité, DTD/entités refusées,
   plus d'interpolation `${}` surprise.
2. **Specs déclarées** (`spi/schema/ElementSpec`) : les 24 éléments du format sont
   déclarés sur leur enregistrement dans `Handlers` (types STRING/INT/BOOL, requis,
   doc). `config/Validator` passe sur l'arbre entier avant exécution : attribut
   inconnu rejeté avec position et candidats, types vérifiés, clés de `<default>`
   validées contre les specs. L'API `Attribute` à clé dérivée rend la divergence de
   namespace inexprimable ; `Values.parseInt` accepte `$`/`0x`/décimal (fini le
   piège octal de `Integer.decode`). Première exécution sur le corpus réel : un
   attribut mort (`page="true"` sur `<label>`, jamais lu) détecté et purgé.
3. **XSD généré** (`config/SchemaGenerator`, option `-x`, fichier commité dans
   `docs/schema/gamebuilder.xsd`) : validation + autocomplétion éditeur depuis la
   même source de vérité (attributs stricts et typés, contenu permissif — les
   règles par conteneur restent au build).

Reste ouvert, par ordre de valeur : scènes/régions déclaratives (générer les
tables de scène, vérifier les régions — cf. groups.md ; plan détaillé et
syntaxe : `docs/lang/fr/scenes-declaratives-2026-07.md`), migration de
storage.xml vers le même loader, tri alphabétique des ids de symboles,
packaging en zip. **Suivi d'avancement : `TODO.md` à la racine.**

**Packer VGC porté en Java (31/07/2026)** : `vgmpacker` (LZ4 + parser VGM) tournait
sous un interpréteur **Jython 2.7 embarqué**, soit 47 Mo de dépendance et un runtime
Python 2 mort depuis 2020, pour ~2000 lignes de Python. Porté en trois classes dans
`toolbox/audio/vgm2vgc/.../pack/` (`VgmStream`, `Lz4Enc`, `VgmPacker`), validé **bit
à bit** : les `.vgc` régénérés sont identiques à ceux produits par la chaîne Python,
et chaque module a été comparé séparément à son original exécuté sous Jython
(12 fichiers VGM pour le parser, 72 combinaisons entrées×réglages pour LZ4).
`repo/` passe de 74 Mo à 21 Mo. Le mode huffman du packer d'origine n'est pas porté
(jamais activé par cette chaîne, et le player 6809 n'a pas le décodeur correspondant) :
il lève une erreur explicite.

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
l'index au-delà de 8 slots (chemin realloc) + mass unload ; T13 = répertoire
INDEX de 3 secteurs (589 octets, la dernière entrée chargée et vérifiée) ; T14 =
churn : 16 cycles de +22 fichiers export-only (chaîne de realloc 8→16→24→32 au
premier passage) puis mass unload des 22. Le tout dans un pool volontairement
réduit à $0E00 (3,5 Ko) ; T15 = **multi-disquette** : bascule vers la disquette 1
(prompt « Insert disk 1 » vérifié à l'écran, montage à chaud sous toje), chargement
d'un fichier depuis la disquette 1, liens croisés vérifiés **dans les deux sens**
(export du game mode disquette 0 patché dans les données disquette 1, export
disquette 1 résolu dans le game mode disquette 0), liens des fichiers disquette 0
préservés, puis retour à la disquette 0. Validé sous toje : **15/15 pass**, index
vérifié en mémoire (totalSlots=32, cohabitation de [disk 0][file 0] et
[disk 1][file 0], dernière entrée du répertoire indexée).

**Quatre bugs attrapés par le stress test (corrigés le 30/07/2026)** :
1. `loader.dir.load` : quand le répertoire dépasse 1 secteur, le buffer alloué
   n'était jamais écrit dans `map.DK.BUF` → les secteurs 2+ étaient lus sur les
   variables puis le code du loader (`ptsec+256` = $A127+). Bug dormant depuis
   l'origine — aucun projet n'avait de répertoire > 1 secteur (~30 entrées).
2. L'unload implicite par destination évinçait les fichiers export-only les uns
   après les autres (ils partagent tous la pseudo-destination (0,0)) — régression
   introduite avec l'implicite lui-même, qui cassait silencieusement le pattern
   `ym.const`+`sn.const` d'`examples/sound`. Convention actée : les fichiers
   vides ($ff00) sont exempts de l'éviction par destination.
3. `loader.dir.load` gardait l'index de secteur dans B à travers sa boucle de
   retry, mais le prompt « Insert disk » appelle le moniteur (PUTC/KTST) qui
   détruit B : la sauvegarde auto-modifiante stockait $30 (dernier caractère du
   message). La première lecture de répertoire multi-secteurs après un changement
   de disquette partait alors sur un index d'entrelacement aberrant → erreur d'E/S
   fatale. Il fallait **à la fois** un prompt de changement de disquette **et** un
   répertoire > 1 secteur pour le déclencher. Corrigé : B rechargé depuis
   `DIR_DEFAULT_SECTOR`.
4. `linkData.symbol.search` excluait « le fichier en cours de résolution » en ne
   comparant que le fileId. La numérotation des fichiers repart à 0 sur chaque
   disquette : un fichier de même numéro sur une autre disquette était donc
   ignoré et **tous ses symboles exportés devenaient invisibles** — les liens
   inter-disquettes se résolvaient silencieusement à 0. Corrigé par l'ajout de
   `linkData.currentDisk` (identité = [diskId][fileId]).

5. **Ids de fichiers globaux** (corrigé dans la foulée) : `getPageID` — donc
   `isLoaded` et les relocations `externPg` — ne compare que le fileId, et le
   format des link data n'a pas de place pour qualifier le disque. Plutôt que de
   changer le format, la numérotation est devenue **globale à un target** côté
   builder (`spi/globals/FileIds`, remise à zéro par target dans `Target.java`) :
   chaque répertoire continue la numérotation du précédent et enregistre l'id de
   sa première entrée dans son en-tête (`dir.header.baseId`, en-tête 5 → 7 octets).
   `loader.dir.getFile` soustrait cette base pour retrouver l'index local — le
   file id reste un simple index, au prix d'un `subd` (~7 cycles). Un fichier est
   désormais identifié par son id seul, sans ambiguïté entre disquettes.

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
