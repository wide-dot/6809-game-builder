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

**Depuis le 18/10/2026, le jeu R-Type n'est plus dans ce dépôt** : il vit
dans `wide-dot/r-type` (privé — il porte des données tirées de la borne),
ce moteur y entre en sous-module, comme pour Sonic 2 et Ms. Pac-Man. Les
sections historiques plus bas citent encore `games/r-type` : c'était son
chemin ici, c'est la racine de son dépôt aujourd'hui. Une capacité du moteur
se développe et se valide ici, sur les exemples ; chaque jeu monte ensuite
son sous-module.

## Organisation des sessions (22/08/2026)

**Un clone local par session de travail — jamais deux sessions sur le même
checkout** (décision auteur, après la collision du 22/08 : checkout/stash
d'une session écrasant les fichiers de l'autre). 1 session = 1 clone =
1 branche. `ci/new-clone.sh <dest> [branche]` crée un clone prêt (origin
GitHub, lien `engine`, rappel de build). La synchro entre chantiers passe par
`origin`, jamais par le même arbre.

## Grille de revue avant fusion (09/10/2026)

Toute branche passe cette grille avant sa PR (décision auteur). La revue
reprend chaque point et le dit **fait**, **sans objet** ou **écart justifié** ;
la description de la PR en garde la trace.

1. **La chaîne de build est Java, et elle se déclare dans le `config.xml`.**
   - Toute transformation entre une source commitée et ce que l'assembleur
     consomme est une étape du builder : un handler Java enregistré dans
     `Handlers.java`, un élément déclaré dans le `config.xml`. Jamais un
     script à lancer avant le build.
   - Python reste permis pour l'**authoring** (dessiner une mire, produire un
     corpus de test) et l'**analyse** (sondes et bancs toje) : le script est
     commité à côté de ce qu'il produit, ses sorties sont commitées, le build
     ne l'appelle jamais, et il a un `--check` qui dit si elles sont à jour.
   - Une source de vérité par asset : pas de version « source » et de version
     « convertie » commitées côte à côte.
2. **Une nouvelle capacité ASM vit dans l'engine, pas dans l'exemple.**
   - Elle est rangée au bon niveau (`engine/system/<machine>/`, `thomson/`,
     générique), nommée selon les conventions (`module.routine`,
     `xxx.macro.asm`, `xxx.const.asm`). Un exemple n'écrit pas un registre
     matériel en dur et ne dit pas « pas encore de macro ».
   - Elle est opt-in (macro, routine incluse à la demande, ou `define`) : un
     projet qui ne s'en sert pas ne paie rien, ni octet ni cycle. C'est
     prouvé par `ci/build-corpus.sh` avant et après : images identiques à
     l'octet, ou chaque écart listé et expliqué.
   - Son coût pour qui l'utilise est chiffré : octets, cycles par appel.
   - Un import de la v1 suit la skill `v1-migration` (1:1, manifest,
     `V2-DEVIATION`, cas de migration).
3. **Une capacité ajoutée à un outil existant reprend son vocabulaire.**
   - Une notion déjà nommée ailleurs garde son nom et ses valeurs (un mode
     vidéo s'appelle `videomode`, avec les valeurs de `png2bin`). Un nom
     nouveau doit dire ce que l'option fait, pas comment elle est codée.
   - Le défaut reproduit le comportement d'avant. L'option est déclarée dans
     la spec de `Handlers` (type, doc), le XSD est regénéré (`-x`,
     `docs/schema/gamebuilder.xsd`), une valeur inconnue est une erreur
     nommée.
   - Des tests JUnit l'exercent, sortie comparée octet pour octet à une
     référence.
4. **Un nouvel outil Java** est un module du réacteur Maven, enregistré d'une
   ligne dans `Handlers`, spec déclarée, testé en JUnit, documenté dans
   `docs/lang/en/`. Pas de dépendance nouvelle sans motif écrit.
5. **Un exemple est un banc, propre et rejouable.**
   - Son art est généré (une mire, cf. « Art des exemples »), jamais copié
     d'un jeu.
   - Ses résultats sont des témoins en `$9C00` (convention loader-ut), et un
     script commité dans `ci/toje-bench/` les lit et compare l'écran à sa
     référence : toute affirmation du readme se rejoue. Rien ne vit seulement
     dans un scratchpad.
   - Le corpus le construit (`ci/build-corpus.sh` le trouve seul). Son readme
     dit ce qu'il prouve, comment le construire (une commande, sans étape
     Python) et le résultat daté.
   - Il ne recopie pas un autre exemple quand une capacité de l'engine peut
     porter la différence ; s'il en dérive, il le dit et n'en garde que
     l'écart.
6. **Doc et traçabilité dans le même commit** : le manuel `docs/lang/en/`
   pour toute capacité, l'analyse ou le plan concernés mis à jour, ce
   `CLAUDE.md` si l'état des lieux change. Commentaires de code en anglais.
7. **Avant la PR** : branche à jour de `master`, `mvn clean install` vert,
   corpus identique, bancs toje concernés rejoués.

## Build & commandes

- Build toolchain : `mvn clean install` à la racine (multi-module, 17 modules ; JDK 11+,
  CI GitHub Actions sur `master`). Pour le seul builder :
  `mvn -pl toolbox/gamebuilder/core -am package` (jars déposés dans `repo/`).
- Construire un jeu/une démo : `gamebuilder -f <config.xml> [-t <target>] [-v] [-c]`
  (config XML : cible → média disquette (`floppydisk fd640/fd320/fd158`) → sections →
  fichiers/scènes → sorties `<fd/> <sd/> <sap/> <hfe/>` ; aucun média cartouche
  dans le registre — le portage ROM est au backlog).
- **Convertisseurs** (`vgm2ymm`, `vgm2vgc`, `vgm2sfx`, `pcm`, `png2pal`,
  `phoneme`, `txt2bas`) : des dépendances Maven ordinaires du cœur,
  enregistrées une ligne chacune dans `core/Handlers.java` (le mécanisme
  ServiceLoader/`plugins/` a été supprimé le 31/07 — voir la section revue
  Java). `mvn install` à la racine suffit.
- **Procédure validée sur macOS (07/2026)** : depuis le répertoire du projet/exemple,
  `java -Dbasedir=<racine du repo> -cp "../../repo/*" com.widedot.m6809.gamebuilder.MainCommand -f to8.config.xml`.
  Prérequis : (1) un lien `engine → ../../engine` dans le répertoire du projet (les
  chemins du config.xml sont relatifs au config, `engine/` est gitignoré dans les
  exemples) ; (2) **`-Dbasedir`** pointant sur la racine du repo — le builder y
  trouve l'assembleur (`toolbox/third-party/bin/<os>/`, résolu par
  `ThirdPartyTools`) et, le cas échéant, les plugins de conversion.
  **Aucun `lwasm` à installer et aucun shim `lwasm.exe` : depuis 08/2026 le
  binaire macOS est un lwtools 4.25 universel (x86_64 + arm64) compilé depuis
  les sources versionnées dans `toolbox/third-party/src/asm/`** — voir son
  [readme](toolbox/third-party/src/asm/readme.md). Pour pointer ailleurs :
  `-Dlwasm.path=/chemin` ou la variable d'environnement `LWASM`.
  Sorties dans `dist/`, avec les rapports : `link-report-<cible>.csv` (ce que
  chaque direntry coûte en données de lien), `linked-refs-<cible>.csv` (chaque
  référence résolue au chargement, AVEC sa cause — depuis le 10/08),
  `occupancy-<cible>.html` (l'occupation RAM par scène + le média + l'onglet
  *Parcours* : chaque lecture du loader d'un état au suivant, dessinée sur la
  disquette et chiffrée par un modèle mécanique aux paramètres modifiables —
  depuis le 08/09), `pool-map-<cible>.txt` (le coût de liaison par scène face
  au pool) et `seek-report-<cible>.txt` (le même parcours en texte, aux
  paramètres par défaut).
  Le `<hfe/>` fonctionne sur macOS depuis 08/2026
  (`hxcfe` 2.16.15.2 universel embarqué, sources dans
  `toolbox/third-party/src/floppy/`).
- Les scripts `bin/unix/` et `bin/windows/` ne sont **pas faits pour être lancés depuis
  les sources** : ce sont des zones de staging que les descripteurs `package/` mappent
  vers `/bin` de la distribution, où leur `BASEDIR` (un cran au-dessus du script)
  retombe bien sur la racine avec `repo/` et `plugins/` à côté.
- Exemples de référence : `examples/sound` (le plus complet, TO8 + MO6 : boot, scènes,
  double-buffer, musiques YMM+VGC), `examples/loader-ut` (banc de test du loader, 15/15),
  `examples/sprites` (chaîne sprites compilés, 4 encodeurs), `examples/objects` (banc
  object manager, mouvement, animation, MarkObjGone, 31/31 — sans affichage,
  rejoué contre son `bench.ref` depuis le 18/10/2026),
  `examples/overlay` (banc du pack sprites overlay, 39/39, résultats + checksums
  VRAM en `$9C00` — c'est le banc DIFFÉRENTIEL de BuildSprites, chemin simple
  ET multisprite (t26..t30), et des listes de priorité de DisplaySprite et
  DeleteObject (t31..t39), depuis le 18/10/2026 : rejoué contre sa référence
  commitée `bench.ref` par `ci/toje-bench/bench.py`, voir
  [`benches.md`](docs/lang/en/benches.md) ; `ci/run-benches.sh` rejoue tous
  les bancs décrits par un `bench.json`),
  `examples/tilemap` (banc de TilemapBuffer, 13/13 sur deux cibles — les
  options de sonic-2 sur la seconde : la vue vérifiée cellule par cellule
  contre la carte, puis dessinée, depuis le 18/10/2026),
  `examples/irq` (banc IRQ 50 Hz, gfxlock — le seul double buffer depuis le
  21/10/2026, WaitVBL retiré —, palette, Mul9x16, CalcSine,
  RandomNumber, ClearDataMem, GetImgIdA, TileAnimScript, ReadJoypads — la
  manette de toje tenue par `bench.json` —, paged.call : 19/19 sous toje,
  l'IRQ active, depuis le 18/10/2026),
  `examples/tlsf-ut` (tests unitaires TLSF sur machine),
  `examples/bm4s` (le 320x200 4 couleurs `$41` : `videomode="bm4s"` de
  gfxcomp, `_gfxmode.setBM4S`, banc `ci/toje-bench/bm4s_ut.py`),
  `examples/spritestream` (sprites par flux bm4s et leur mode clip : 42/42
  rejoués contre `bench.ref`, chaque tracé contre un second chemin),
  `examples/mplus` (bancs de test carte son MPLUS : DAC, MIDI 6850, MEA8000, SN76489, YM2413).
- **État de validation au 13/08/2026** : le corpus compte **15 configs et
  63 images** (11 exemples dont collection/stacked-overflow/hscroll/
  tilescroll/objects/sprites, plus `games/r-type` — sorti du moteur le
  18/10/2026 : le corpus ne compte plus que les exemples), construits et empreintés
  en une commande par `ci/build-corpus.sh <out.hashes>` — c'est le banc
  d'identité de toutes les campagnes. Exécution rejouée **sans écran** par la
  lane toje (`ci/toje-bench/` : loader-ut 17/17 + piège T18 avec échanges de
  disquettes, banc r-type 5/5, collection 4/4 ; sondes des autres exemples
  dans les scripts de session). Les images **MO6 ne sont validées qu'au
  build** — pas d'émulateur MO6 ici (toje est TO8 uniquement). Le mplus
  factory test affiche « KO » sur les timers : toje n'émule pas la carte.
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
| Double buffering `gfxlock` (swap sur IRQ 50 Hz, compteurs frame/frame-drop) — le seul double buffer, contrat dans [`gfxlock.md`](docs/lang/en/gfxlock.md) | `engine/graphics/buffer/` (les jeux, import v1) ; `engine/system/thomson/graphics/buffer/` (base v2 : MO6, MPLUS) | Porté de la v1 ; base du timing gameplay |
| IRQ 50 Hz + sync ligne écran, palette, bank switching, modes vidéo | `engine/system/{to8,mo6}/` | Fonctionnel, minimal |
| Contrôleurs : clavier, clavier rapide, joypad, pad Megadrive 6 boutons | `engine/system/{to8,mo6}/controller/` | Équivalent v1 (dont `joypad.kb`) |
| Sprites compilés : `gfxcomp` (PNG → code 6809) **+ le runtime de dessin** | `toolbox/graphics/gfxcomp/`, `engine/graphics/sprite/` | Chaîne complète depuis le 01/08/2026 : `<gfxcomp>` dans le config.xml, index imageset avec page résolue au load-time link, runtime v1 importé 1:1. Les **quatre encodeurs** sont exercés, images compressées comprises (`engine/graphics/codec/zx0_mega.asm` importé, décompresseur rendu relogeable). Banc `examples/sprites` validé sous toje, banc générateur-vs-générateur 11/11. Un set trop gros pour une page est une **collection** (le packer la coule dans les creux d'une arène) et s'indexe par l'élément `<imageset>`, qui grave une page **par image** (comme la v1). Doc : [`sprites.md`](docs/lang/en/sprites.md) |
| Autres outils graphiques : `png2bin` (+ buffers `-vs/-vst/-hs`), `png2pal`, `stm2bin`, `leanscroll` | `toolbox/graphics/` | Substantiels mais sans consommateur runtime |
| wddebug | `toolbox/debug/` | Très actif ; ses vues sprites/collisions/objets débuggent les structures v1 en attendant la v2 |

### 🚧 En cours / écrit mais non branché

- **MEA8000** (synthèse vocale) : actif, banc de test dans `examples/mplus`.
- **MUCOM88/YM2608** (`engine/sound/mucom88/`, ~2900 l.) : écrit, non intégré —
  `ym2608.init/detect/reset` et le handler IRQ manquent ; `engine/pack/mub.asm` pointe
  vers de mauvais chemins. Non requis pour R-Type.
- **MPLUS** (carte d'extension son + VHDL) : bancs de test, expérimental. Non requis pour R-Type.
- **Timing** : embryonnaire (`time.ms.wait` seul). L'ancienne doc d'une API
  `wait.*` jamais écrite (`timing.md`, `examples/timing/`) est supprimée
  (13/08/2026) — concevoir l'API le jour où un consommateur réel arrive.
- **Math** : RNG seul (`random.asm`). La v1 a en plus sinus, atan2, Mul9x16 (mais R-Type
  niveau 1 n'utilise que le RNG).

### ❌ Absent du runtime ASM (tout reste à migrer depuis la v1)

Les sprites compilés sont sortis de cette liste le 01/08/2026 (runtime importé,
banc validé, `docs/lang/en/sprites.md` écrit). Pour le reste : pas de code, seulement
des équates réservées dans `glb.const.asm` (caméra, alphaTiles), des docs vides
(`docs/lang/en/{objects,tilemaps,audio}.md`) et les vues wddebug orphelines :

- ~~**Object manager**~~ : fait le 01/08/2026 (runtime et helpers importés, banc
  `examples/objects` 31/31). Reste le pipeline d'objets côté builder — un game mode
  écrit encore ses tables d'index à la main
- **Animation** (v1 : `AnimateSpriteSync.asm`, `moveByScript.asm`)
- **Tilemap + scrolling** (v1 : `horizontal-scroll/scroll-map-buffered-even.asm` —
  scroll 1 px sur tilemap pré-bufferisée pointant des tiles compilées). **À ne pas
  confondre avec `hscroll`**, qui est fait et validé (`examples/hscroll`) mais répond à
  un autre besoin : une bande de largeur fixe qui boucle, pour un fond répétitif.
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

## Migration engine v1 → v2 (stratégie actée le 31/07/2026)

La v1 (`thomson-to8-game-engine`) reste la **référence opérationnelle** et ne
peut pas être gelée. L'ASM v1 est repris **en 1:1** (iso-syntaxe, mêmes noms
et chemins — le diff contre v1 reste trivial, la resynchronisation mécanique),
tracé fichier par fichier avec son commit v1 dans `engine/v1-manifest.csv`
(dérive détectée par `.claude/skills/v1-migration/drift-check.sh`). Tout écart
volontaire au 1:1 est consigné (manifest + `; V2-DEVIATION:` dans le code).
Le builder migre en **capacité** (idiome v2 : config.xml/scènes/linker). Le
**renommage** (`docs/engine-naming.csv`) et les évolutions non essentielles
sont différés en phase finale, après migration des jeux désignés par l'auteur.
L'engine v2 pré-migration et les exemples pré-migration sont figés dans
`parked/` (référence, ne pas modifier ni builder) ; les exemples migrés
reprennent leur place dans `examples/`. Les parties sans équivalent v1
(bootloader/loader/scènes, TLSF, MO6, MPLUS…) restent v2 telles quelles.
Validation : méthode standard + **double banc** (générateur vs générateur sur
mêmes PNG ; runtime vs runtime sous toje avec checksums comparés).
**Mode opératoire complet : `.claude/skills/v1-migration/SKILL.md`.**
Inventaire de dérive : `docs/lang/fr/migration-inventaire-2026-07.md`.

### Recueil de cas — RÈGLE (02/08/2026)

> **Tout cas de migration v1 → v2 résolu donne lieu à un fichier de
> `docs/lang/en/migration/`, DANS LE COMMIT QUI LE RÉSOUT.** Le code qui en
> porte la trace cite le fichier en commentaire. Un correctif de migration
> sans son cas écrit est incomplet.

Quatre artefacts se partagent la migration, un rôle chacun — n'en créer aucun
cinquième :

| Artefact | Rôle |
|---|---|
| `docs/migration-inventaire.csv` | le reste-à-faire |
| `engine/v1-manifest.csv` | le registre par fichier (commit v1, écarts) |
| `.claude/skills/v1-migration/SKILL.md` | la procédure (import, drift-check, validation) |
| `docs/lang/en/migration/` | **le recueil de cas** — comment un idiome v1 devient v2 |

Le manuel `docs/lang/en/*.md` décrit le modèle v2 pour qui n'a jamais vu la
v1 ; un cas part toujours d'un idiome v1. Critère : si ça s'énonce sans citer
la v1, c'est du manuel.

Fichiers **nommés par le cas, jamais numérotés** — le nom est cité depuis le
code, le manifest et les commits, il doit rester stable. L'ordre de lecture
vit dans `docs/lang/en/migration/README.md` et nulle part ailleurs.

Rédaction **en anglais** (comme `docs/lang/en/`) ; la version française sera
faite en une passe à la fin.

**Avancement (01/08/2026)** : M0/M1 (cadre, inventaire, parking) et M2 (base commune
+ pilote `sound/to8` + arbitrages) clos ; M3 (gfxcomp opérationnel + banc
générateur-vs-générateur) et M4 (runtime sprites 1:1 + banc `examples/sprites`,
images compressées incluses) clos.
29 fichiers v1 importés, 5 écarts tracés (marge d'erase 16→12, trois `setdp`
neutralisés, alignement du décompresseur zx0 supprimé) et 11 fichiers « KEPT-V2 »
sous surveillance drift-check. Le double banc a payé trois fois : il a fait tomber le
parking du lecteur par le moniteur (loader durci), trois défauts silencieux de l'index
imageset, et un centrage horizontal décalé d'un pixel présent depuis le portage.
Reste M4-suite (banc runtime vs runtime « plein », variantes) et M5-suite (renommage,
phase finale).

**Note sur le binaire du loader (01/08/2026)** : rendre le décompresseur indépendant
de son adresse a fait grossir le loader de ~14 octets, donc **les 8 images d'exemples
changent** — c'est le seul écart, confiné aux secteurs du loader (`to8-disk1.fd`, la
seule image sans loader, est inchangée à l'octet près). `loader-ut` revalidé **16/16**
(statut `$0D`) sous toje, échanges de disquettes compris.

## Revue Java & campagne de correction (30/07/2026)

Revue complète en trois passes : `docs/lang/fr/revue-java-2026-07.md` (15 défauts
avec fichier:ligne, dépendances, testabilité, plan par phases). Les 4 phases ont
été exécutées ; à chaque étape les images des 8 configs d'exemples ont été
comparées **octet par octet** avec les précédentes, et `loader-ut` rejoué sous toje.

- **Phase 0** — le build ne mentait plus : `MainCommand` en `Callable<Integer>`,
  erreurs d'écriture propagées, JUnit + surefire, 22 tests sur les fonctions pures
  (SAP, checksum fd640, cascade Attribute). Un build cassé sort désormais en
  exit ≠ 0. *Effet de bord assumé à l'époque : les configs déclarant `<hfe/>`
  échouaient sur macOS faute de `hxcfe` — elles échouaient déjà, en silence.
  Levé en 08/2026 : le binaire macOS est embarqué.*
- **Phase 1** — bugs de format : garde-fou 16 Ko réactivé (il lisait la mauvaise
  clé de defaults et n'a **jamais** servi), SAP format 2 invalide (`*` au lieu de
  `+`), détection des drives SAP décalée, `FdUtil.getIndex` dérivé de la géométrie
  déclarée, fenêtre zx0 découplée de `maxsize`, bornes explicites (piste 7 bits,
  255 secteurs), et reproductibilité par target (`LinkSymbols` remis à zéro comme
  `FileIds` : `-t fd` et `-t sd,fd` donnent enfin la même image).
- **Phase 3** — hygiène : `openipa` (appli Next.js vendorisée de 8,8 Mo) sortie
  des resources et ses deux manifestes JS retirés — c'était l'origine du gros des
  alertes Dependabot ; jar phoneme 7,2 Mo → 815 Ko. Versions toutes figées,
  logback 1.5.19, `dependabot.yml` (retiré le 22/10/2026 : les versions
  figées ne bougent qu'au besoin ; restent les alertes de vulnérabilité et
  les « Dependabot security updates »), jython déplacé vers son seul consommateur,
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

**Scènes/régions déclaratives — phase A réalisée (31/07/2026)** : plan complet
dans `docs/lang/fr/scenes-declaratives-2026-07.md`. Nouveaux éléments
`<layout>`/`<region>` (carte mémoire du target, portée par le contexte) et
`<scene>`/`<load>` (la table asm est **générée** — `SceneGenerator` +
`ScenePlugin` — puis passe par le pipeline direntry standard ; les types de
blocs %01/%10 sont choisis par le générateur, jamais authorés). Une région =
une destination fixe partagée par toutes les scènes qui la ciblent, flag
`permanent` pour le contenu à chargement unique. Contrôles actifs dès la
génération : référence inconnue, région inconnue ou chargée deux fois,
destination région+brute. **Phase C faite dans la foulée** (migrer avant de
vérifier donne de la matière réelle aux contrôles) : **15 des 17 tables du
corpus sont déclaratives** — loader-ut (10, dont le stress et la disquette 1),
sound TO8+MO6 (4), tlsf-ut TO8+MO6 (2), mplus-pcm (1, premier usage de la
destination brute). Les 8 images restent **identiques octet pour octet**, y
compris après reconstruction complète avec `gen/` effacé ; loader-ut rejoué
sous toje **16/16** (statut $0D), sound TO8 vérifié en RAM avec changement de
scène à chaud. Les 15 tables manuscrites sont supprimées.

**Limite découverte à la migration** : mon relevé initial affirmait que le type
de bloc `%10` ne servait qu'à des lots export-only à (0,0) — c'est faux. Les
deux configs `mplus-test` empilent 9 fichiers **avec données** (jusqu'à 6 Ko) à
une destination réelle. Cet empilage runtime n'est pas exposé par la syntaxe
(les destinations dérivent avec les tailles, ce qui casserait l'unload
implicite) : ces 2 scènes restent manuscrites. La distinction utile n'est pas
« empilage interdit » mais « empilage = chargement unique » — elles sont
chargées une seule fois au boot, jamais échangées. Trois options au §12 du plan,
recommandation : un `<stack region>` gardé par l'attribut `permanent`, en
phase B.

Phases restantes : B (vérifications tailles/chevauchements/permanent + décision
empilage), D (docs).

Reste ouvert côté builder : phases B et D ci-dessus, migration de storage.xml
vers le même loader, tri alphabétique des ids de symboles, packaging en zip.
**Suivi d'avancement : `TODO.md` à la racine.**

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

## Analyse détaillée : loader (récit de juillet 2026 — lire l'encart d'abord)

> **État courant (13/08/2026).** Cette section est le journal du travail de
> juillet ; trois de ses mécanismes ont changé depuis et son « ce qui
> manque » est traité. L'**unload implicite décrit plus bas a été REMPLACÉ** :
> charger sur les octets d'un fichier encore indexé (destination exacte OU
> recouvrement partiel, étendues relues du répertoire en cache) **fige** avec
> `log.scene.LOAD_OVERLAP` — la scène qui finit déclare ce qu'elle lâche
> (`scene.unload`, table de scène gardée en cache). L'exemption des fichiers
> vides est devenue « ils n'occupent aucun octet ». La **marche de placement
> des blocs %10/%11 a été retirée** (phase 8) : le runtime ne place plus
> rien, les blocs séquentiels ne portent que de l'export-only. Le banc est à
> **17/17 + T18** (le piège provoqué et lu). Le modèle à jour :
> [`groups.md`](docs/lang/en/groups.md) et
> [`scenes.md`](docs/lang/en/scenes.md) ; les différés restants (suivi des
> tailles, paginated groups, unloadAll) sont au TODO.

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

## R-Type : le jeu de référence du moteur (jusqu'au 18/10/2026)

Le portage de R-Type a servi de banc à toute la migration v1 → v2 : sprites,
objets, animation, scroll, collisions, waves, pipeline « jeu » (pagesets,
tilemaps, frontière résident/stage), puis le jeu entier. Le jeu vit
désormais dans son dépôt privé `wide-dot/r-type` ; le récit détaillé de
cette section (« Reste à faire pour un R-Type minimal ») y est conservé,
`doc/journal-claude-moteur.md`.

## Le loader relit ses secteurs partagés : corrigé (07/09/2026)

Le builder écrit les fichiers bout à bout : le dernier secteur partiel d'un
fichier est le premier du suivant, et les link data d'une scène se serrent
sur deux ou trois secteurs. Le loader relisait chaque fois le même secteur
dans `ptsec`, et une relecture immédiate coûte **un tour de disque entier**
(200 ms, huit secteurs). Mesuré sous toje sur r-type : un secteur sur six
perdait un tour, 27 s sur les 37 de l'amorçage, 12 s sur les 44 du passage
au stage 1. Corrigé par `ptsec.key` dans `ldsec` (12 cycles par secteur
plein) ; `loader.dir.load` invalide la clé. Amorçage → title : 37,7 s →
10,5 s ; loader-ut : 25 s → 7 s de banc. L'étude complète — géométrie,
entrelacement, budget par créneau, où passe le temps, et le hook de barre
de chargement à venir — est dans
[`etude-chargement-2026-09.md`](docs/lang/fr/etude-chargement-2026-09.md),
avec ses sondes dans `tools/loading/` du dépôt `wide-dot/r-type`.

## DKCONT coupe le moteur à chaque appel ; l'inertie de toje (07/09/2026)

L'épilogue de DKCONT (`$E080–$E091`) coupe le moteur (`$E0B9`, CMD2 = $40)
à la fin de CHAQUE lecture de secteur, et l'appel suivant le rallume dans
sa boucle READY (`$E45A`). Vrai sur machine. Le trou de 0,4 s toutes les
2 s vu sous toje vient de son modèle d'inertie (teo-wd) : la remise en
marche rejoue 0,38 s d'inertie quand la dernière mise en marche date de
plus de 2 s — comparée à la mise en marche, pas à l'arrêt. **Les temps
disque mesurés sous toje portent ~20 % d'artefact probable**, et le pas
de tête n'y est pas modélisé (STEP instantané) : le skew ne s'y règle
pas. Étude §8–§9 ; à trancher sur machine avec deux images (entrelacement
2 et 1).

## L'entrelacement est généré, et surchargeable par cible (07/09/2026)

Les tables de lecture du loader (`sclist`) et des secteurs de boot
(`blist`), et le décalage de skew par piste, sont **générés** dans
`gen/directories/locations.asm` depuis l'`Interleave` du storage
(`_loader.interleave.sclist`, `_loader.interleave.skew`,
`loader.interleave.SKEW_MASK`) : une seule source, celle qui écrit
l'image. `<floppydisk softskip="1">` (ou `softskew`, `hardskip`) surcharge
le storage pour une cible — c'est ainsi que se fabriquent les deux images
de l'essai machine (entrelacement 2 et 1). Tous les disques d'une cible
doivent partager le même entrelacement, le builder refuse sinon.

## Le tampon de répertoire et l'index de lien : deux blocs du tas, dimensionnés par le builder (08/09/2026)

Le tampon de répertoire est alloué UNE fois dans le pool, à la taille du
plus gros répertoire de la cible (`loader.dir.buffer.SECTORS`, généré) ;
`loader.dir.unload` (table de saut 45) le rend, personne ne le fait par
défaut. L'index de lien est alloué une fois à `loader.file.linkData.SLOTS`
entrées : le plus grand nombre de fichiers porteurs de link data qu'un
état déclaré indexe à la fois, compté par le builder sur les compositions
à l'émission des répertoires (macro `_loader.file.linkData.SLOTS` de
`gen/directories/locations.asm`, un `<define>` du même nom l'emporte —
loader-ut charge à la main et déclare 32). Un slot de plus qu'annoncé =
piège `log.scene.INDEX_FULL`. Le loader n'inclut plus `tlsf-realloc.asm`
ni `memcpy.asm` : 4 817 → 4 264 octets, pool 3 375 → 3 928 ; r-type
indexe 24 fichiers à la pointe (stage 1). L'étape intermédiaire du 07/09
(tampon à la taille exacte, redimensionné sur place, répertoire 0 scindé
en 0 + 10) reste dans l'étude §11 ; la scission du répertoire 0 est
conservée. Bilan de place complet : `docs/lang/fr/bilan-loader-8ko-2026-09.md`.
Même jour : `tlsf.SL_BITS` sous `IFNDEF` (défaut 4), le loader à 2 (quatre
classes de taille par puissance de deux, matrice 378 → ~116 octets) ;
`examples/tlsf-ut` joue les deux finesses (`fd`, `fd-sl2`). Loader r-type
3 996 octets, pool 4 196. Piège toje rencontré : la stabilisation de 1 200
trames de `boot_floppy` pouvait figer un transfert de secteur plus tard
(loader-ut, artefact d'émulation) — `loader_ut.py` amorce avec `settle=1`.
Décision auteur : le loader reste générique, pas de `define` par capacité
de la cible ; l'erreur « I/O Error » est rendue LISIBLE (mode 40 colonnes,
page 0, palette 1/7 forcée blanc sur rouge, écran effacé — le registre
d'adresse du EF9369 compte des octets, entrée n à 2n) et l'erreur de
lecture d'un fichier y passe au lieu d'un reset (bilan §9). Loader 4 044.

## Second lecteur, invite de disquette, .sd à deux lecteurs (09/10/2026)

Le loader cherche une disquette sur le lecteur mémorisé (octet 1 de la
table des emplacements = DK.DRV, réécrit à chaque succès), puis sur l'autre,
puis demande. Un second lecteur « non prêt » (`DK.STA $10`, 1,18 s mesurées
dans la ROM `$E45A`) n'est plus sondé avant une invite. L'invite écrit
`DISK n` sous la barre du loader (`loader.loadbar.text.set`, table de saut
51 ; barre masquée = largeur 0), sans toucher mode, page ni palette, écrite
pour la taille (police 3x5, seulement les chiffres des disquettes de la
cible, `loader.dir.physicalDisks`) ; sinon le texte moniteur. Touche : KTEST
(PA0 du PIA système), IRQ masquées. La convergence groupe ses passes par
répertoire (celui en mémoire d'abord, tables triées par le builder) et lâche
sans lire le disque une scène sans données de lien. `<sd drive="1">` met une
disquette dans les unités 2/3 du même .sd. Loader : +281 octets sur sonic
(4 148 → 4 429). Manuel : `config.md`, *Several disks*. Bancs : loader-ut
un lecteur et `--two-drives` (toje `feature/second-drive`), r-type 7/7.

## La barre de chargement : le loader compte, l'engine dessine (07/09/2026)

`loader.progress.hook.set` (table de saut 42) installe un hook appelé à
chaque unité : un secteur lu, 512 octets décompressés. Le total vient du
répertoire : l'entrée d'une scène porte un second bloc (`dir.entry.units`,
bit 5 de `bitfld`) où le builder écrit ce que son chargement comptera,
lu avant la première lecture (depuis le 08/09 ; la mesure par le loader,
`file.measure`/`scene.measure`, est retirée). L'effet de référence,
`engine/graphics/loadbar/loadbar.asm`, est assemblé DANS le loader après
son code et s'installe par `loader.loadbar.set` (table de saut 48, X =
`loadbar.PARAMS` octets : page vidéo, adresse x+40·y, largeur en pixels, hauteur,
octet de pixels, puis la pulsation — entrée de palette, période en unités
ou 0, nombre de teintes, puis les teintes elles-mêmes, copiées avec le
reste — 8 au plus — parce que l'unité qui les apporte peut être celle que
le chargement recouvre ; une écriture de palette par pas) —
depuis le 08/09 ; il fallait avant le recopier dans un `<reserved>` du
layout, parce qu'il tourne pendant que le chargement recouvre l'unité qui
l'apportait. Budget d'un hook : 2 000 cycles, un tour de disque au-delà.
Étude §10. `INDEX` est passé au secteur 5 le 07/09 (loader > 18 secteurs).

## L'état résident se déclare : `loader.composition.set` (07/09/2026)

`composition.load` converge la RAM depuis `composition.current`, et seule
`composition.load` le pose. Un état amené par `scene.load` — l'amorçage :
scène par défaut, fondu, splash, puis le moteur — laisse l'état courant
nul, et la première convergence croit la RAM vide : elle recharge tout ce
que la cible nomme. Sur r-type, `scenes.boot` était chargée DEUX fois
(13 s sur les 34 du boot au title), depuis la séparation boot/title du
01/09, sans rapport avec le splash. Nouvelle entrée de la table de saut,
index 39, `loader.composition.set` (X = la table, 0 = rien) : elle ne
charge rien, elle déclare. `boot.entry` de r-type l'appelle avec
`compositions.boot` avant de demander le title. Règle : **qui amène un état
par `scene.load` le déclare avant la première convergence.**

## gfxlock : une section par boucle principale (22/10/2026)

**Règle de l'auteur.** Une seule section `_gfxlock.on` / `_gfxlock.off` par
boucle principale, et TOUTE écriture à l'écran (clear, texte, masque, image
appelée en direct, `$E7E5`, demi-page de `$E7C3`) est déplacée dedans —
jamais une section ouverte autour de la routine qui écrit. Avant le swap, la
fenêtre données montre encore le tampon affiché : une écriture hors section
clignote (vécu sur Sonic 2, texte d'intro et level select). Deux façons :
section ouverte avant `RunObjects` (title, menu), ou requête de l'objet
exécutée par le game mode dans la section (`paged.call`, niveau). Au
démarrage, `gfxlock.status` à -1 avant l'IRQ, les deux tampons dessinés selon
`gfxlock.backBuffer.status`, puis `_gfxlock.init` ; la bordure par
`gfxlock.screenBorder.color` seulement (`$E7DD` est en écriture seule).
Contrat complet : [`gfxlock.md`](docs/lang/en/gfxlock.md).

## Page directe : contrat DP (01/08/2026)

Deux pages en jeu — `$60` (moniteur, registres disque) et `$9F` (globales
engine). Le loader démarre sur la première et bascule sur la seconde juste
avant de lancer le game mode ; à l'inverse, ses points d'entrée appelés *depuis*
un game mode reposent DP sur `$60` le temps de parler au moniteur. **Ces deux
bascules manquaient et se masquaient mutuellement** : sans la première, un game
mode lisait ses globales dans la page moniteur (un chargement de scène écrit
`$60DC`, l'offset de `glb_camera_x_offset`) ; en corrigeant la première seule,
le loader se bloque à sa première invite.
Le contrat complet — les deux pages, la passation dans les deux sens, le code
qui tourne sur les deux, et la méthode de choix des octets — est dans
[`direct-page.md`](docs/lang/en/direct-page.md) ; cette section n'est qu'un
renvoi et l'historique du correctif. Pas de cas de migration dédié : la v1
n'avait pas de passation, le contrat v2 se lit directement dans le manuel.

## Symboles inter-fichiers : exporter coûte au chargement (01/08/2026)

Le loader résout **chaque référence par une recherche linéaire** sur les exports
de tous les fichiers chargés : le coût de liaison d'une scène est de l'ordre de
`références × exports`. Règle : **n'exporter que ce qui franchit une frontière
de direntry** ; ce que le builder place, le builder peut l'adresser en dur
(sections `*.static`). Ne pas activer `undefextern`.

Le modèle, les trois mécanismes (`.static`, cuisson des interns, élagage des
exports) et **toutes les mesures** vivent dans
[`symbols.md`](docs/lang/en/symbols.md) — cette section n'en est qu'un renvoi,
ne pas y redupliquer les chiffres. Le raisonnement qui y a mené :
[`analyse-exports-tables-2026-08.md`](docs/lang/fr/analyse-exports-tables-2026-08.md).
Côté migration : [`what-to-export.md`](docs/lang/en/migration/what-to-export.md).

Deux corrections du support multi-sections faites au passage (01/08) : base de
section perdue par les interns inter-sections, et `code` mis en tête du binaire
quel que soit l'ordre d'écriture de lwasm — cette dernière est ce qui rend
tenable l'entrée d'unité à l'offset zéro, cf.
[`unit-entry-point.md`](docs/lang/en/migration/unit-entry-point.md).
Piège de lecture des rapports, désormais sans objet sur macOS (hxcfe embarqué
depuis 08/2026) : les configs `<hfe/>` avortaient sur hxcfe **avant** la ligne
de rapport d'élagage, tout en élaguant quand même.

## Art des exemples : tout est généré (01/08/2026)

Aucun exemple n'embarque d'art authoré. Chaque image est produite par un script
commité à côté d'elle (`examples/*/tools/gen_*.py`) et conçue comme une **mire**,
pas comme un dessin : périodicité choisie pour que le raccord d'un défilement se
vérifie, asymétrie choisie pour qu'un miroir ou un décalage d'un pixel donne une
image visiblement fausse plutôt que plausible. Les sprites de test de
`examples/sprites` (`glyph`, `marker`) et la bande de `examples/hscroll`
remplacent des copies venues de R-Type et de `horizontal-band-scroll`.

## Piège vidéo : le mode n'est pas posé par défaut (01/08/2026)

Un game mode qui dessine **doit** appeler `_gfxmode.setBM16` : la machine démarre
en 320x200 deux couleurs et lit les données BM16 comme telles. Les témoins
mémoire restent justes pendant ce temps — seul le jugement porté *à l'écran* est
faussé, d'où le temps perdu. À vérifier en premier quand un rendu paraît haché
en colonnes.
Cas de migration (la v1 écrivait `$E7DC` en direct) :
[`video-mode.md`](docs/lang/en/migration/video-mode.md).

## Modèle mémoire : pages, fenêtres, places (02/09/2026)

Une place se déclare par **deux nombres et rien d'autre** : `page` (dans quelle
RAM elle vit, absolument) et `address` (à quelle adresse elle s'exécute, telle
que le code l'utilise). La fenêtre par laquelle le loader y écrit **se déduit**
de l'adresse, les fenêtres de la machine occupant des plages CPU disjointes ;
la position dans la page — le référentiel où se font tous les contrôles — est
**calculée**, `adresse modulo la taille de page`, et n'est écrite par personne.

Les fenêtres sont déclarées par la machine (`engine/config/machine.xml`).
Trois des quatre du TO8 sont de l'arithmétique pure ; la vidéo porte deux
lignes parce qu'elle montre 8 Ko d'une page de 16 **et numérote ses moitiés à
l'envers** (bit à 1 = première moitié) — d'où l'attribut `slice`, écrit dans
l'ordre de la page, le builder posant le bit. Si `$6000` tombe au milieu d'une
page, c'est seulement que la fenêtre vidéo de 8 Ko décale la suite hors de la
grille de 16 Ko : `$6000 mod $4000 = $2000`. Ce que les émulateurs appellent
« ordre non linéaire » est cela et rien d'autre.

Conséquences à connaître :

- **une place peut dépasser la fin de sa page et reprendre à son début** — les
  neuf écrans de r-type le font, chargés en `$7C00` ; les contrôles comparent
  les deux morceaux et le rapport les dessine ;
- **dépasser sa FENÊTRE est une erreur dure** (un fichier cartouche de 8 Ko en
  `$3000` écrirait dans l'écran) ;
- **les espaces de chargement ne se déclarent pas** : ce sont les fenêtres de
  la machine moins celle d'où le loader s'exécute. Charger dans la sienne est
  refusé ;
- **le loader est une place**, tas compris (`<reserved name="loader">`), et
  les deux `<define>` que son binaire utilise sont vérifiés contre elle.

Modèle et syntaxe : [`memory.md`](docs/lang/en/memory.md) (manuel),
[`modele-memoire-2026-09.md`](docs/lang/fr/modele-memoire-2026-09.md)
(concepts) et [`plan-modele-memoire-2026-09.md`](docs/lang/fr/plan-modele-memoire-2026-09.md)
(le journal des six phases, avec les écarts).

## Disposition disque : répertoires colocalisés (08/09/2026)

Un répertoire déclaré `colocate="true"` est écrit dans sa section **juste
avant ce qu'il liste** (secteurs réservés au curseur, contenu écrit derrière
dans l'ordre de lecture du loader — table, données des fichiers, puis leurs
liens — répertoire écrit en dernier). Avec les tables de scènes et les
données de lien dans la même section, charger un stage est une marche avant
de la tête. r-type n'a plus qu'une section `DATA` (piste 1) : le modèle
passe de 90 à 64 s de disque sur la chaîne title → stage 8, le temps de
déplacement d'un stage de ~3 s à ~0,7 s ; amorçage → title mesuré sous toje
à la trame 952 contre 1100. Contrainte : la table des emplacements
(`gen/directories/locations.asm`) est réécrite à l'émission de chaque
répertoire, le `<data>` du loader doit venir APRÈS les répertoires (sinon
`ERROR` à l'assemblage, nommant le répertoire). Modèle et mesures :
`docs/lang/fr/etude-chargement-2026-09.md` §12, manuel `config.md`.

## mscroll : la couture corrigée (05/10/2026)

Trois défauts trouvés en portant mscroll en 1 bpp, corrigés et validés à
l'octet par `examples/mscroll/tools/diag_check.py` (8 trajets scriptés +
150 aléatoires, coutures franchies dans les deux sens) : `h` valait 10 au
lieu de 0 quand la fenêtre est un multiple de 10 (bande une ligne trop
bas) ; le biais de curseur de la couture (`1 − ceil(fenêtre/10)`, avec un
cisaillement relatif à la caméra, et `mscroll.feedLine` pour la rangée que
le glissement du biais découvre) ; et le tileset de l'exemple chargé en
`$0000` au lieu de `$2000`. Le banc d'origine ne franchissait aucune
couture (carte de 256 px). Étude §10 de
[`etude-mscroll-2026-08.md`](docs/lang/fr/etude-mscroll-2026-08.md).
`common.mscroll` de R-Type : 2 677 octets, sous les arènes de stage.

## mscroll1 : le scroll multidirectionnel en 1 bpp (05/10/2026)

`engine/graphics/tilemap/mscroll1/` est le fork 1 bpp de mscroll (mode
`$24`, un plan, pas de 8 px, carte à deux niveaux layout → chunk 128×128 →
bloc 16×16, colonnes 16 bits, init par le feed), pour le clone Sonic 2
mono (`wide-dot/sonic-2-mono`, privé). Démonstrateur `examples/mscroll1` :
`tools/check.py` (écran relu et comparé à l'octet, `--random N` pour une
marche aléatoire), `tools/fps.py`, `tools/profile.py`. Plein écran
320×200 : 25 i/s caméra arrêtée, ~16 i/s à 6 px + 3 lignes par trame.
**Deux défauts du mécanisme de couture hérités de mscroll y sont
corrigés** (biais du curseur `−ceil(window/10)` et cisaillement relatif ;
la rangée découverte quand le biais bouge) — corrigés aussi dans le BM16,
section suivante. `mscroll1.mask` (après le blast et les sprites)
noircit les deux seules zones fausses : l'octet de recouvrement à droite
(le slot à cheval sur le retour de ligne quand x mod 16 ≥ 8) et la ligne
du haut (le trou du début du ruban) — image exacte de 312 × 199 px. Piège
de sonde : lire les tampons en tête de boucle (ailleurs le tampon arrière
est à moitié dessiné) et rendre la page data après lecture. Étude et
mesures : [`etude-mscroll1-2026-10.md`](docs/lang/fr/etude-mscroll1-2026-10.md).

## Rangement fichier par fichier (15/10/2026, la règle depuis le 16/10)

Une arène rangée d'un bloc démarre chaque zone après le plus haut contenu
avec lequel UN de ses fichiers partage un état : une arène dont les
fichiers vivent dans plusieurs états laisse à personne la place que les
autres états occupent (Hidden Palace 1 de sonic-2 : 32 Ko libres, 383
octets refusés). Dès que le layout déclare ses `<composition>`, le packer
range tous les fichiers de toutes les arènes en un seul tri, les plus
partagés d'abord (nombre d'états qui les chargent) puis les plus gros,
chacun dans le premier trou des zones de SON arène libre des fichiers avec
lesquels IL partage un état ; une collection qu'aucun trou ne tient entière
s'y découpe. L'ordre compte : par taille seule, les fichiers communs à tous
les états passaient après les gros fichiers d'un acte et trouaient les
pages hautes de tous (plus grand bloc libre de sonic-2 : 16 → 9 Ko) ;
arène après arène, un gros fichier d'une arène rangée tard ne trouvait plus
de place. Pas de réglage (décision auteur, 16/10) : r-type sort identique
à l'octet, sans `<composition>` le rangement par arène reste (rien n'y dit
qui peut partager des octets), la passe de découverte aussi. Code :
`ArenaPacker.packFiles`, tests `ArenaPackerFileTest`, manuel `scenes.md`.

## Sprites par flux bm4s : `<spritestream>` (27/10/2026, branche locale)

Un gestionnaire de sprites qui stocke des données au lieu de code : chaque
image bm4s (PNG indexé, 0 transparent, 1-4 les couleurs) devient un flux de
segments de ligne masqués (masque + donnée par octet écran, ~3 octets par
octet dessiné contre ~6 en compilé), tiré à l'exécution par des **walkers
générés** pour tout le jeu de formes : les deux facings depuis un seul flux
(table d'inversion de 256 octets), la sauvegarde des octets masqués fusionnée
au dessin (pile S, un walker de restauration par tampon, dernier dessiné
premier rendu). Module `toolbox/graphics/spritestream` (élément
`<spritestream>` : `<sprite>` → enregistrements + flux, en pièces d'une
collection ; `genwalker` → walkers et tables, mis en place par la taille
exacte de chaque instruction autour des tables alignées) ; runtime
`engine/graphics/sprite/stream/spritestream.asm` (+ `.const.asm`), une copie
par moitié de la demi-page vidéo `$4000-$5FFF` (le gfxlock y monte celle du
tampon dessiné : chaque moitié porte sa pile de sauvegarde). Manuel
[`spritestream.md`](docs/lang/en/spritestream.md).

**Validé** contre le prototype mesuré du jeu consommateur (flux et routines
identiques à l'octet, 96 images d'une mire en JUnit ; sous toje dans l'arbre
du jeu : chaque image dans ses 8 tracés exacte et restaurée, 2 096 trames
réelles en double tampon, mêmes cycles au cycle près — la restauration perd
seulement un `jmp`, −4).

**Clipping : le mode clip des walkers** (option A de l'étude du jeu, choisie
par l'auteur), opt-in par `clip="true"` sur `<spritestream genwalker>`,
`spritestream.drawClip` dans le runtime : une table de saut de clip par
facing dont les entrées sont des handlers (enregistrement entier → sa
routine, caché → sauté, coupé → boucle serrée octet par octet, sauvé au fil
du tracé, un enregistrement de restauration par rangée). Mêmes flux avec ou
sans. Coût : walkers +260 octets, runtime +1 063 ; mesuré sur le jeu,
+412 cycles par trame en moyenne sur 5 743 trames réelles découpées comme
l'original, sous le temps de l'Apple sur les trois découpes réelles du
personnage debout. JUnit `ClipTest` (un modèle du chemin coupé lisant les
tables générées, contre le décodeur, chaque fenêtre de colonnes) ; banc
`examples/spritestream` (42/42, `ci/toje-bench/bench.py`, chaque tracé
contre un second chemin). Branche locale `feat/bm4s-sprite-stream`, PR à
décider par l'auteur.

## Fidélité arcade de R-Type

Section sortie le 18/10/2026 avec le jeu : `wide-dot/r-type`,
`doc/journal-claude-moteur.md` (le banc trace contre trace, les boss, le
second tour). Le savoir sur la borne va dans `wide-dot/re.arcade.r-type`,
`referentiel/`.

## Dettes / pièges connus

- `engine/pack/mub.asm` : chemins d'INCLUDE invalides (fichiers dans `sound/mucom88/`).
  (Les orphelins de cette liste — `data.asm`/`mub.o` racine, `gfx.memset..asm`,
  `examples/timing` + `timing.md` — sont supprimés le 13/08/2026, phase 9 ;
  le besoin d'une API de timing reste tracé dans l'état des lieux plus haut.)
- Liens cassés : `readme.md` racine (4 liens doc vides), renvoi vers
  `docs/lang/fr/readme.md` inexistant. (`docs/lang/en/readme.md` corrigé le
  01/08/2026 : ses cibles pointaient encore sur l'ancien layout `docs/`.)
- Binaires third-party inégaux selon l'OS : pas d'`exomizer` linux-arm, pas de
  `hxcfe` linux (les configs déclarant `<hfe/>` y sortent en erreur explicite).
  hxcfe : macOS en 2.16.15.2 (universel, reconstruit depuis les sources
  versionnées dans `toolbox/third-party/src/floppy/`), Windows et linux-arm sur
  binaire amont.
  lwtools : macOS en 4.25 (universel) et Linux x86_64 en 4.25 (09/08/2026),
  tous deux reconstruits depuis les sources versionnées ; Windows en 4.22,
  Linux-arm encore en 4.18 — procédure dans
  `toolbox/third-party/src/asm/readme.md`.
