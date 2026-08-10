# TODO — suivi d'avancement

Fichier de travail : on coche ici, le détail vit dans `CLAUDE.md` et `docs/`.

Méthode standard pour tout changement builder/loader : images des 8 configs
d'exemples comparées **octet par octet** avec la référence, `loader-ut` rejoué
sous toje (16/16), tests JUnit verts, CI master verte. Le replay toje se fait
désormais **sans écran** en une commande : `ci/toje-bench/` (boot, montages à
chaud, lecture des témoins, dump du bloc de log au blocage).

## À corriger — trouvé par la lane toje headless (09/08, détail : `ci/toje-bench/readme.md`)

Trois régressions dormantes, bissectées contre un état connu-bon (loader-ut à
`ff633bc` rejoue 16/16 `$0D` sous le harnais). Toutes antérieures à la campagne
« modèle cible » — ses phases sont hors de cause (contrôle par image).

- [x] **loader-ut T12/T14** (10/08) : les 24 exports de lest sont consommés
      par des sommes de contrôle dans le gm — les fichiers regagnent bloc de
      lien et slots d'index.
- [x] **Recouvrement fantôme de `findOverlap`** (10/08) : garde diskId — un
      slot d'un autre disque est ignoré, son étendue étant illisible depuis
      le répertoire en cache. T18 réparé au passage (recharger le même
      fichier prend la dédup : la provocation charge désormais bb sur cc via
      `scenes.trap`). **loader-ut 17/17 + `$0D` + T18 `$8301`, vérifié sous
      la lane toje.** Changement du binaire du loader : les images bootables
      changent toutes.
- [x] **r-type : gel YM à l'échange** (10/08) : `ymm.stop` dans les deux
      `stage.handOver` (relancer `ymm.obj.play` sur un flux en cours
      désynchronisait l'anneau). Témoins du banc relogés en `$8766` (bloc
      réservé pris au 46e objet du pool — deux collisions successives ont
      montré qu'il n'y a pas un octet libre ailleurs : la traînée du joueur
      écrasait +13, la pile S écrase +148) ; layout mis au vrai (globals
      $94, pile $9ED4/$1C — le débordement missile est déclaré).
- [x] **r-type : t1 invérifiable par construction** (10/08) — `bench.spawns`
      ne compte que les bouchons, et le cast du stage 1 est entièrement
      porté (la wave est VIVANTE : cinq patapata à l'écran, capture à
      l'appui). t1 re-spécifié sur la progression de la wave ; t2 garde la
      preuve du chemin de spawn (bouchon du stage 2).
- [x] **ymm : le second morceau partait en vrille** (10/08) — le
      décompresseur streaming est une coroutine et `ymm.decompress` ne
      remettait pas `@flip` (la parité registre/valeur) à zéro : un morceau
      interrompu en pleine trame (échange de stage) la laissait quelconque,
      et le morceau suivant se dépliait décalé d'un octet — plus un wait vu
      en phase, écritures YM sans fin (même famille que le bourrage de
      tampon perdu à l'import v1, l'avertissement d'à côté). `clr @flip` à
      l'init. Les images ymm changent (sound TO8/MO6, mplus-test TO8/MO6,
      r-type), les 10 autres configs sont identiques à l'octet.
- [x] **ymm : relance après interruption** (10/08, décision auteur : une
      lecture fait table rase) — `ymm.buffer.reset` remplit l'anneau de
      $39 à chaque obj.play/restart : un consommateur qui déborde dans le
      non-produit s'arrête net au lieu de boucler. + `clr @flip` à l'init
      du décompresseur. La signature YM a disparu des blocages ; images
      ymm changées (sound, mplus-test, r-type), 10 configs identiques.
- [x] **r-type : le 5/5 est ATTEINT** (10/08) — « la marche `$39CA` » était un
      faux diagnostic : `$6154-$6156` n'est pas un slot `rsv_prev_*` mais la
      boîte aux lettres soundFX (`curSound`/`newSound`, moteur $6100+$53/$55,
      `$FF00` = NO_SOUND), et `$39CA` le test d'entrée IDLE de
      `soundFX.playIRQ` (page 8, unité à $398A) — la signature IRQ d'une
      machine vivante échantillonnée, pas une boucle. La relance YMM,
      elle, était déjà GUÉRIE par `clr @flip` + `buffer.reset` (vérifié
      octet par octet contre un décodage ZX0 hors machine : production et
      consommation conformes à la référence). Les deux vrais bloqueurs,
      pris sur le fait au watchpoint sous toje :
      1. **Bouchon auto-supprimant invoqué à cru** : au stage 2, l'index
         mappe `ObjID_shellEraser` (appelé CHAQUE TRAME sans OST) sur
         `stage.placeholder`, qui fait `UnloadObject_u` — un slot fantôme
         par trame, la pile de slots déborde sous $6628 et laboure le
         moteur jusqu'au code de `terrainCollision.do` (gel caméra=16,
         le fil principal finit par exécuter l'OST joueur en page directe).
         Corrigé : `stage.placeholder.raw` (rts) pour les invocations sans
         OST. Règle écrite dans stage-main.
      2. **Pile S de 28 octets** : la chaîne de mort d'un objet
         (RemoveAABB→Delete→Unload) sous IRQ plongeait sous $9ED4 et
         écrasait `player_pos_ring_buffer_ptr` (premier octet sous le
         plancher) ; la traînée désalignée (wrap par égalité stricte)
         labourait la page directe puis la fenêtre — gel au 2e passage du
         stage 1 (cam=198, Init du joueur rejoué, liste AABB player
         auto-bouclée, `Collision_Do` infini). Corrigé : pool 45 → 44
         objets, les trois ancres (layout, GLOBALS_BASE, GLOBAL_VARIABLES)
         descendues ensemble de 117, pile portée à 145 octets
         ($9E5F-$9EF0). **`rtype_bench.py` : R-TYPE BENCH 5/5 PASS.**
      Seules les images r-type changent (stage-main + layout résident) ;
      loader intact, exemples byte-identiques par construction.

## En cours

- [ ] **Migration engine v1 → v2 + sprites compilés** — stratégie actée le
      31/07/2026 : import ASM v1 **en 1:1** (la v1 reste la référence
      opérationnelle, pas de gel — traçage par commit), builder migré en
      **capacité**, renommage différé en phase finale. Mode opératoire :
      [`.claude/skills/v1-migration/SKILL.md`](.claude/skills/v1-migration/SKILL.md) ;
      état des lieux sprites :
      [`docs/lang/fr/sprites-etat-2026-07.md`](docs/lang/fr/sprites-etat-2026-07.md)
  - [x] M0 — mode opératoire (skill v1-migration : import + manifest,
        politique d'écarts tracés, drift-check.sh, double banc)
  - [x] M1 — inventaire de dérive (478 v1 / 131 v2 / 30 homonymes tous
        divergents — [`migration-inventaire-2026-07.md`](docs/lang/fr/migration-inventaire-2026-07.md)) ;
        partition actée ; engine + exemples v2 parqués dans `parked/`
  - [x] M2 (pilote) — base commune : 14 fichiers v1 importés 1:1 (manifest),
        gm title sound/to8 réécrit en dialecte v1, **validé de bout en bout
        sous toje le 31/07** : title joue (ymm+vgc), swap à chaud vers
        level1 vérifié dans les DEUX pages (p6:$0400=ymm level1,
        p7:$0A80=vgc level1, fenêtres cart forcées via $E7E6). Quatre
        causes racines corrigées : (1) setdp interdit en cible obj →
        neutralisé (V2-DEVIATION) ; (2) fichiers v1 sans SECTION → include
        DANS la section du gm ; (3) les players v2 conservés résolvent
        `irq.on`/`irq.off` au link, symbole absent = 0 silencieux =
        jsr $0000 → pont d'export zéro octet dans le gm (`irq.off equ
        IrqOff` + EXPORT) ; (4) **le swap chargeait à vide : le handler
        timer par défaut du moniteur parque le lecteur (reset contrôleur,
        DK.OPC:=1) → DKCONT « réussit » sans lire** → durcissement loader
        (ldsec réassert OPC=2 avant chaque DKCONT) + armement IRQ tôt dans
        le gm, rallumage final après les obj.play (ils coupent via
        irq.off). Revalidation complète post-changement loader : 8 configs
        rebuil­dées, loader-ut **16/16** ($0D), tlsf-ut vert, mplus test+pcm
        conformes, JUnit 57/57, snapshots REF rafraîchis. Leçons dans la
        skill : le prompt « Insert disk » est infranchissable au clavier
        sous toje (scan IRQ masqué) → bypass PC $ACD5→$ACD7 ;
        CHECK_UNRESOLVED_SYMBOLS incompatible avec les références en avant
        (title importe les sons level1) — ne l'activer que sur des bancs
        sans forward refs.
  - [x] M2 (suite) — arbitrages rendus le 31/07 (détail dans la skill) :
        (1) tlsf.ut basculé sur `RandomNumber.asm` v1 (identique modulo
        labels, prouvé par diff) et `engine/math/random.asm` v2 supprimé —
        8 images inchangées octet pour octet ; (2) **mplus reste
        intégralement en dialecte v2** : banc pour matériel v2-only (carte
        MPLUS), gm partagé TO8/MO6, features gfxlock v2-spécifiques
        (halfPage/memset) absentes du gfxlock v1 — la base v2
        (irq/glb.init/palette/gfxlock/packs) reste vivante pour MO6 et
        mplus, la dérive du côté v1 est déjà surveillée par les lignes
        d'import du manifest ; (3) homonymes son/zx0 (players ymm/vgc,
        sn76489, ym2413, packs, 3 décompresseurs zx0) : **KEPT-V2** —
        formes v2-natives (EXPORT/link, ports dynamiques, intégration
        loader) ; 11 lignes ajoutées au manifest avec leur commit v1
        courant pour que drift-check alerte quand la v1 bouge (résync
        manuel à évaluer).
  - [x] M3 — gfxcomp opérationnel + banc générateur vs générateur (01/08).
        Corrigé : main-class du pom, **index imageset structurellement vide**
        (clés `BN0` côté Image vs `bdraw_none_shift0` côté lookups → source
        unique `Image.variantKey`, forme v1 `NB0` conservée), erreurs avalées
        (PNG manquant = NPE plus loin ; CLI en `Callable<Integer>` comme le
        builder), un générateur d'index par `<imageset>` (les multiples se
        écrasaient). `<gfxcomp>` enregistré dans `Handlers` comme FilePlugin
        de `<lwasm>` : il compile les PNG, écrit un `EXTERNAL` par `pge_*`
        (résolus au load-time link — la v1 les plaçait au build) et exporte
        `set_/idx_/adr_*`. Banc `toolbox/graphics/gfxcomp/bench/run.sh`
        (harnais qui pilote les encodeurs v1 hors projet de jeu) : **7/7**,
        code v1 et v2 **binairement identiques** quand la recherche est
        exhaustive ; au-delà les DEUX générateurs tirent au sort
        (`new Random()` non graîné — la v1 diffère d'elle-même : 543 vs 544
        octets sur shell_3), donc le critère devient « aussi bon que le
        meilleur tirage v1 + 1 % ». Écart 5 (INCLUDE v1) résolu par M2 : le
        chemin `engine/constants.asm` existe désormais à l'identique.
        Nouvel exemple `examples/sprites` (PNG → code compilé → direntry →
        scène) validé sous toje : $CA 01 01.
  - [x] M4 (runtime) — sprites 1:1 : les 7 fichiers du pack
        `background-erase-ext` + `RunObjects.asm` importés (manifest, 2 écarts
        tracés : marge d'erase 16→12, setdp neutralisé). **Le banc
        `examples/sprites` dessine** sous toje (01/08) : $CA 01 01 01 01,
        compteur de frames qui avance, tête de liste de cellules libres STABLE
        (allocation/libération équilibrées, pas de fuite), sprite visible à
        l'écran. Trois défauts du port v2 de l'index imageset corrigés au
        passage : adresses émises en `fcb` (tronquées à 8 bits — la v1
        découpait la valeur elle-même) → `fdb` ; page par image inventée
        (`pge_*`) → **le vrai contrat v2 est `<direntry>$PAGE`** (externPg,
        une seule page par unité compilée) ; bits fenêtre cartouche absents
        (la v1 écrivait `page+$60`) → opérande d'addition de la relocation.
        Pièges consignés dans la skill (point d'entrée en offset 0, `fill` RAM
        v1 → équates, coordonnées écran décalées, DisplaySprite par frame).
  - [x] M4 (index) — le banc compare aussi **l'index imageset**, le contrat
        que le runtime lit (`bench/checkindex.py`) : géométrie identique des
        deux côtés, `nb_cell` conforme à l'écart de marge tracé (12 vs 16).
        Il a immédiatement attrapé un **bug de portage** : le centrage
        horizontal utilisait `x_Min-(width/2)` là où la v1 fait
        `x_Min-((width-1)/2)` — un pixel de décalage sur tous les sprites, et
        une incohérence interne (le calcul vertical, lui, était correct).
        Corrigé, banc **11/11**.
  - [x] M4 (reproductibilité) — le `Random` de gfxcomp est graîné par une
        constante unique (01/08) : au-delà d'une certaine taille de nœud la
        recherche d'ordre est aléatoire et la v1 ne se reproduit pas
        elle-même (542 puis 544 octets sur le même sprite). Sans grain, une
        image disque changeait à chaque build — inacceptable maintenant que
        les destinations RAM sont placées à la main contre des budgets
        calculés une fois, et incompatible avec la comparaison binaire qui
        sert de méthode de validation au dépôt. Graine **unique** et non
        dérivée du nom : le code d'un sprite ne dépend que de ses pixels,
        renommer une image ne change pas sa taille. Vérifié : 3 builds
        complets d'`examples/sprites` donnent la même image au bit près ;
        8 configs inchangées, banc 11/11, runtime toujours vert sous toje.
        `maxTries` ne remplace pas le grain (mesures dans sprites.md).
  - [x] M4 (audit du portage) — relecture méthodique de gfxcomp face au
        générateur v1 (01/08). Corrigé : **table `center_offset` divergente**
        (v2 rendait v1+1 pour `width%8` ∈ {0,1,4,6} — 615 des 758 sprites de
        R-Type, dont nos deux sprites de banc ; le runtime s'en sert pour
        choisir la variante décalée ET pour calculer l'adresse écran, donc
        sprite à un pixel près ou invisible) ; garde de cache dégénérée des
        encodeurs rle/zx0 (2e build dans le même répertoire = données vides) ;
        erreur avalée dans l'encodeur `draw` (le garde-fou des 16 Ko
        n'arrêtait plus le build) ; contrôles d'entrée v1 rétablis (indice de
        couleur > 16, image > 160x200) ; `alpha` redevenu champ d'instance ;
        import parasite. **`shift` refuse désormais de compiler** : le
        pré-décalage est appliqué sur le PNG source par une AffineTransform
        qui élargit l'image d'un pixel alors que la largeur est déjà capturée
        — chaque ligne dérivait. Mieux vaut refuser que sortir un sprite
        corrompu ; le portage de la version v1 reste à faire.
        `checkindex.py` compare maintenant `center_offset` (c'est son absence
        qui avait laissé vivre l'écart).
  - [x] M5b — animation : `AnimateSprite.asm` + `constants-animation.equ` +
        `WaitVBL.asm` importés 1:1 (manifest). Le banc `examples/sprites`
        anime maintenant son objet entre deux imagesets et le vérifie sous
        toje ($9C08=01 : les deux frames atteintes), tête de liste de
        cellules stable sur 600 trames malgré l'alternance 3 cellules /
        1 cellule. Format de table documenté dans sprites.md ; comme pour les
        sprites, `Ani_Page_Index`/`Ani_Asd_Index` sont écrites à la main en
        attendant le pipeline « jeu » du builder.
  - [ ] M6 — migration `vgc-demo` (sujet choisi le 01/08 : même pack sprites
        que v2, ses deux musiques ont déjà leur player, 2 objets, pas de
        scroll ni collision ; c'est une des démos vitrines du readme).
        **Remis en état côté v1** (il lui manquait `builder.parallel`, devenu
        obligatoire — commit local dans le repo v1) : il construit et tourne
        sous toje, ce qui donne la référence exécutable du banc runtime vs
        runtime. Reste à faire côté v2 : générateur de tables d'animation
        dans le builder (`<animation>`), palette depuis PNG (png2pal existe),
        images plein écran ZX0, portage des deux objets et de leur dispatch
        `routine,u`.
  - [x] M4 (pré-décalage) — l'historique a montré que le portage fidèle avait
        existé (`ed5f496`, 11/10/2022) et qu'il avait été emporté une semaine
        plus tard par le refactor « generic img transformer », qui rangeait
        miroir et décalage sous une interface unique typée sur BufferedImage.
        Le miroir y tenait, le décalage non. Corrigé en séparant les deux
        espaces dans le typage (`ImageTransform` / `PlaneTransform`) : un
        transform d'écran ne compile plus sur une image source. Corps repris
        du commit d'origine. Banc étendu aux variantes décalées : **19/19,
        toutes byte-identiques** (shell_0 NB1 = 883 octets des deux côtés).
        Invariant « une variante décalée déclare la géométrie de la non
        décalée » verrouillé par test — c'est lui qui protège le x1/y1 partagé
        du groupe de miroir.
  - [x] M4 (couverture du banc) — les quatre miroirs (N/X/Y/XY) et les deux
        encodeurs ajoutés au banc : **30/30 byte-identiques**. Tous les
        chemins de gfxcomp que le portage R-Type utilise sont désormais
        comparés à la v1, aucun ne diverge.
  - [x] M6 (palette) — `<png2pal>` a maintenant ses deux chemins, validés avec
        l'auteur : **FilePlugin** dans un `<lwasm>` (table liée, symbole
        exporté) et **ObjectPlugin** en contenu de direntry (32 octets
        chargeables, remplaçables par région). Ils coexistent parce que
        `Pal_current` n'est qu'un pointeur. Le mode `obj` est retiré du chemin
        objet : il y écrivait du texte assembleur sur la disquette, une
        combinaison que rien n'utilisait et que personne n'aurait vue.
        `examples/sprites` tourne avec la vraie palette de ses sprites, écran
        nettoyé (`ClearInterlacedDataMemory` importé) — le sprite s'affiche
        enfin avec ses couleurs. Piège consigné : la palette doit rester
        adressable, `PalUpdateNow` s'exécutant sous IRQ.
  - [x] M7 (décompresseur relogeable) — l'alignement de page du décompresseur
        zx0 est remplacé par un DP dérivé du **compteur de programme**
        (`leay zx0_code,pcr / tfr y,d / tfr a,dp`). L'ancien `zx0_dp equ */256`
        n'avait aucun sens en unité relogeable — c'est ce qui interdisait aux
        sprites compressés d'atteindre ce décodeur. **241 octets récupérés**
        (435 → 194). Ce qui doit partager une page n'est pas la routine mais
        les quelques octets auto-modifiés qu'elle lit en DP : bornés par
        `zx0_dp_first`/`zx0_dp_last`, 16 octets au lieu de 179. Contrôle
        `ERROR` de lwasm quand ils sont à cheval — actif en absolu, lwasm
        refusant l'expression sur une section relogeable (« Conditions must be
        constant on pass 1 »). Effet de bord traité : le pool de loader-ut
        suivait le loader en mémoire, donc son sommet avait bougé de 241
        octets ; il est rendu à son adresse historique ($BE50) et T14
        repasse. Validé : loader-ut **16/16** ($0D), sound TO8 avec swap à
        chaud, banc sprites, JUnit 53.
  - [x] M7 (suite) — **contrôle de page côté builder** fait. Capacité
        générique plutôt que cas particulier zx0 : une unité déclare une plage
        à ne pas couper en nommant deux symboles `<tag>.pagespan.first` et
        `.last`, `LwObject` les extrait en les rebasant (les offsets du
        `.lwmap` sont relatifs à la section, pas au fichier), `DirEntry` les
        porte et `SceneChecks` les vérifie contre l'adresse de région — le
        seul endroit qui la connaisse. Message avec fichier:ligne, adresses
        réelles et action à faire. Prouvé de bout en bout : la même unité
        passe à $6100 et échoue à $61C0, plus deux tests unitaires.
  - [ ] M4 (suite) — banc runtime vs runtime « plein » : même scène buildée
        par les deux chaînes et VRAM comparée sous toje (nécessite un projet
        de jeu v1 minimal) ; palette du banc (couleurs par défaut
        aujourd'hui) ; variantes miroir/décalage.
  - [x] M5 (docs) — [`docs/lang/en/sprites.md`](docs/lang/en/sprites.md) écrit
        (pipeline, élément `<gfxcomp>`, format d'index et contrat `$PAGE`,
        ordre de frame, ce qu'un game mode doit fournir, repère de
        coordonnées, parité v1 et ses deux régimes) ; CLAUDE.md à jour ;
        liens de `docs/lang/en/readme.md` réparés (ils pointaient encore sur
        l'ancien layout `docs/`).
  - [ ] M5 (suite) — renommage = phase finale post-migration des jeux
        (table docs/engine-naming.csv)

## Backlog builder (inventaire du 31/07/2026, ordre conseillé)

Fonctionnel :

- [x] **Tri alphabétique des ids de symboles de link** (31/07/2026) — passe de
      découverte par target puis réémission avec ids préseedés triés : les ids
      ne dépendent plus que des NOMS. Renumérotation unique effectuée, validée
      par exécution (loader-ut 16/16, sound RAM + swap). Prérequis des
      « interfaces de groups » désormais en place.
- [x] **storage.xml sur XmlLoader** (31/07/2026) — plus aucun consommateur
      XMLConfiguration ; erreurs fichier:ligne sur les géométries ; bug
      dormant `sectorperblock` corrigé (clé cassée → 0 silencieux, champ non
      consommé). Identité binaire prouvée.
- [x] **Imageset multi-pages** (03/08/2026) — `<gfxcomp genindex>` refusait
      d'être rangé en pages (« an imageset index reads one page from
      `<file>$PAGE` for the whole set »), or l'explosion de R-Type pèse
      17 881 o : 13 sprites dont cinq de 24x48. La v1 n'avait pas le problème,
      son descripteur porte **un octet de page par image**. Le chemin existait
      déjà, et sert au tilemap : `<pageset>` range, `StaticLink.pageOf` rend la
      page réelle d'un symbole — sa javadoc citait déjà « an object index »
      comme consommateur. Compiler et indexer deviennent **deux éléments** :
      `<gfxcomp imageset="…">` cède la géométrie mesurée, `<imageset>` écrit
      l'index en demandant la page image par image, en `code.static` (adresses
      cuites, zéro donnée de lien). Les descripteurs restent groupés, contrainte
      de `Img_Page_Index[id]`. Validé : explosion 24 parts sur `$15` + 2 sur
      `$16`, 26 références cuites, 12 configs d'exemples **identiques à
      l'octet**, JUnit 103/103, explosion dessinée sous toje.
      Cas : [imageset-pages.md](docs/lang/en/migration/imageset-pages.md)
- [x] **Carte d'occupation RAM** (03/08/2026) — `dist/ram-map-<cible>.txt`,
      **une carte par scène** : c'est la composition qu'on optimise, pas
      l'enchaînement, donc aucune syntaxe nouvelle — le rapport se produit pour
      chaque `<scene>` déjà déclarée. Chaque carte montre le layout ENTIER page
      par page (régions, zones réservées, trous mesurés), annoté du budget face
      à l'occupation réelle de ce que CETTE scène charge. Une région qu'elle ne
      charge pas est marquée telle quelle, jamais « libre » : son contenu vient
      d'une scène antérieure, ce que le builder ignore. Régions multi-pages
      comptées page par page (sinon un tileset de 5 pages se rapportait à 413 %).
      Un graphe de scènes déclaré a été envisagé puis écarté — il aurait permis
      des contrôles inter-scènes (pool de liens au pire cas, recouvrement
      partiel, symboles sans fournisseur) au prix d'une déclaration à tenir à
      jour à la main. À rouvrir si ces contrôles deviennent nécessaires.
      Doc : [`scenes.md`](docs/lang/en/scenes.md) § The occupancy map
- [ ] **Page résidente : retrouver le pool d'objets de la v1** — la v1 a
      50 slots (5 850 o), nous 16 (1 872). Constat mesuré le 04/08 : notre
      contenu tient dans **244 octets de plus** que celui de la v1 ; le pool
      est petit parce que les budgets ont été déclarés larges, pas parce que
      le code a grossi. Analyse complète, méthode et chiffres :
      [`analyse-residente-2026-08.md`](docs/lang/fr/analyse-residente-2026-08.md).
      **Axes à traiter au fil de l'eau**, chacun indépendant des autres :
  - [x] Rééquilibrer `common`/`stage` et reprendre le trou de 176 o (04/08) —
        la frontière avait été posée avant qu'on connaisse les tailles :
        93 % / 46 %, recalée à 81 % / 69 %. `loader.DEFAULT_SCENE_EXEC_ADDR`
        lit désormais l'équate `stage.address` au lieu d'un littéral $8300.
  - [x] **`fade` en objet monté — 279 o** (04/08). La v1 le monte déjà
        (`object.fade=…`) : il a un OST et un index de routine, donc rien ne
        le distingue de l'explosion.
  - [ ] **Resserrer les budgets déclarés sur le contenu + une marge énoncée —
        2 538 o.** À faire en dernier : chaque autre axe change les nombres.
  - [x] **Témoins du banc mutualisés + trou récupéré — 1 547 o d'un tenant**
        (04/08). `bench.wit` déclarait 644 octets pour seize écrits ; les
        témoins sont devenus des équates du bloc `globals`
        (`GLOBAL_VARIABLES+13`), la région a disparu, et le trou `$9875-$9BFF`
        a fusionné avec elle. L'ancre du bloc passe de `$9E84` — valeur dérivée
        de la v1 — à `$9E80`, qui donne `$80` pile ; marge de pile 111 → 99 o,
        sans risque (l'IRQ bascule sur `Irq_sys_stack` dès sa 2e instruction).
        Le bloc est en outre remis à zéro au démarrage : la zone n'étant
        chargée par personne, un témoin non posé lisait `$FF`.
  - [ ] **Reste à prendre : le bloc libre `$9875-$9E7F` (1 547 o)** — il n'a de
        preneur que le pool d'objets, donc il se prendra en même temps que son
        agrandissement.
  - [ ] **Passe de collision en unité montée — 184 o.** `Collision_Do` + les
        expansions `_Collision_Do` : calcul pur, page-neutre, appelé par la
        seule boucle. C'est exactement ce que la v1 met dans `obj_mainext`.
  - [ ] **Talon zx0 — 200 o.** Aucune image de R-Type n'est encodée `rle`/`zx0`
        (que du `bdraw`/`draw`), mais `DrawSpritesExtEnc` garde ses deux `jsr` :
        il faut un talon, pas une suppression.
  - [ ] **`gfxlock` en routines plutôt qu'en macros — 151 o** (dans `stage`).
        Trois enveloppes de 95 o + un `jsr` par site remplacent 276 o
        d'expansions ; placées dans le moteur, elles sortent en plus **huit
        variables de l'interface**, mais coûtent alors 92 o à `common`.
  - [ ] **`ClearInterlacedDataMemory` en `paged.call` — 100 o.** Deux sites
        d'appel : ouverture de stage et checkpoint.
  - [ ] **Dépense obligatoire** quand le pool grandira :
        `nb_graphical_objects` 32 → 64 = **−256 o** (tables sous-objets et
        listes « unset » des buffers de priorité). 50 objets dont 32
        dessinables n'aurait pas de sens.
  - [ ] Vérifié **non sortable**, ne pas y revenir : `setDirectionTo` (5 sites
        d'appel dans 4 pages), `tryFoeFire` / `moveXPos-YPos8.8` / `AwardScore`
        (appelés depuis les pages montées), toute la chaîne sprites (elle porte
        les tables de RAM), `object_rsvd_size` (état de rendu du double
        buffering — la v1 paie les mêmes 117 o/objet), le pool hors page 1 (un
        OST est adressé par `U` depuis la page cartouche), `$4000-$5FFF` (déjà
        découpé en 128 cellules de 64 o).

- [ ] **Localisation automatique des destinations** — la carte d'occupation en
      est le préalable, posé. À reprendre quand la vision du jeu porté sera
      complète (l'auteur, 03/08/2026).
- [x] **Encodeur `draw` : convention d'adressage des plans** (04/08/2026) —
      `<encoder planes="pointer|offset">` ; `offset` atteint le second plan à
      `planedistance` de `U` (attribut `<gfxcomp>`, 8192 par défaut) et **rend
      `U` intact**, ce qu'exige un appelant qui pose une RANGÉE de sprites.
      C'est ce qui manquait à la v1 et qui l'obligeait à coller le code généré
      de son HUD. Validé : 12 sprites recompilés, 8 identiques à l'octet et 4 à
      l'ordre près, écran **pixel pour pixel** identique, 12 configs d'exemples
      inchangées, JUnit 112/112. Piège consigné : les tests appellent
      l'encodeur en direct, donc ils ne couvrent PAS le branchement de
      l'attribut — le premier build a silencieusement utilisé le défaut, et
      c'est la lecture du fichier généré qui l'a montré.
      Cas : [pasted-generated-code.md](docs/lang/en/migration/pasted-generated-code.md)
- [ ] **Placement : membres de pageset = résultat du rangement + retrait des
      mécanismes morts** — analyse faite le 08/08, rien d'implémenté :
      [`analyse-placement-2026-08.md`](docs/lang/fr/analyse-placement-2026-08.md).
      Un pageset émet un membre par zone déclarée (dernier héritage v1 : les
      ids sont réservés sur la déclaration) ; la voie recommandée est de
      mesurer/ranger au moment de la réservation dans `DirectoryPlugin`.
      Inventaire associé : souches du placement auto dans `LayoutResolver`,
      tuyauterie `pages="auto"` sans usage, `range=` gfxcomp supplanté par
      `<pageset>`, marche de destination %10/%11 morte en pratique côté
      loader, adresse de membre lue du scalaire `region.address` au lieu de
      la zone. (M)
- [ ] **Migration vers le modèle cible « file maître »** — plan complet en
      neuf phases écrit le 09/08 :
      [`plan-migration-cible-2026-08.md`](docs/lang/fr/plan-migration-cible-2026-08.md)
      (0 retraits sans risque, 1 émetteur d'index + contributions —
      remplace gen_objid.py byte à byte, 2 membres de pageset dérivés,
      3 bake par défaut + link dérivé, 4 place attitrée — région absorbée,
      5 collections fluides, 6 média dérivé des scènes, 7 contrats
      générés, 8 campagne loader unique, 9 passe documentaire). Modèle :
      manuel-cible + workflow + analyse-placement §12-§23. Phases 0-3
      additives (portage r-type continue en parallèle), 4-5 basculent la
      syntaxe. (XL) **État des lieux chiffré du reste (10/08, post-5/5) :**
      [`analyse-reste-cible-2026-08.md`](docs/lang/fr/analyse-reste-cible-2026-08.md)
      — 3a/4a plus avancées que le plan ne le créditait (aiguillage bake
      et arènes déjà en place), chemin critique = migration du corpus
      (recommandation : 3b+4b fusionnées, un config par commit), un
      arbitrage à re-valider avant la phase 5 (inversion `index=`).
  - [x] Phase 0 (09/08) — code mort retiré (souches LayoutResolver,
        tuyauterie pages="auto" dans Regions/Target/PageSetPlugin,
        member(), range= de gfxcomp + spec + scenes.md) ; PREUVE : 15
        configs, 59 images identiques à l'octet, JUnit 61/61, banc
        reproductible vérifié. Préalables : lwtools 4.25 Linux compilé
        depuis les sources versionnées, include fantôme cast-pages.asm
        (clone frais cassé), log manquant de stacked-overflow.
  - [x] Phase 1 (09/08) — élément `<objectindex>` (équates ObjID_* +
        5 tables parallèles Obj/Ani/Img, entrées = déclarations
        explicites dans l'ordre des ids — option b arbitrée) ; r-type
        basculé (77 entrées dans le config, relais d'include,
        gen_objid.py supprimé). PREUVE : 59 images identiques à
        l'octet, JUnit 61/61. Banc toje 5/5 à rejouer par l'auteur ;
        délégation imageset différée en phase 3 (sa link data fondra).
  - [x] Phase 2 (09/08) — le membre par zone tombe : le répertoire mesure
        et range le pageset à la réservation des ids (PageSetPlugin
        scindé pack/run, defaults du répertoire rejoués, adresse de
        membre lue de la zone), n'émet que les pages remplies.
        stage2.tiles.odd.4 disparaît (répertoire −3 blocs, table de
        scène −5 octets). PREUVE : seules les 4 images r-type changent,
        55 images identiques, JUnit 61/61. **Banc toje 5/5 À REJOUER
        par l'auteur — l'image r-type change réellement.**
  - [x] Phase 3a-voix (10/08) — le rapport « résolu au chargement, avec
        cause » : l'aiguillage bake=auto n'avale plus sa cause, chaque
        décision (classée OU déclarée bake=none) est enregistrée et
        rapportée dans `linked-refs-<target>.csv` + au log. Sur r-type la
        liste montre la frontière moteur→stage attendue, ligne par ligne.
        Doc : symbols.md § The caused list. PREUVE : 59 images identiques
        à l'octet, JUnit 64/64 (3 tests ajoutés). Restes 3a : arbitrage
        interface/« même destination » (rapport d'abord, acté), imageset
        délégué (images r-type changeront).
  - [x] Phase 4a-syntaxe (10/08) — la place attitrée : `<file>` déclare
        `arena=`/`region=`/`page=`+`address=` (une forme au plus), un
        `<load>` nu résout contre elle (ScenePlugin + PlacementScan +
        ArenaPacker), le `<pageset>` nommé nu (son region= déclaré EST sa
        place). Répétition cohérente tolérée (transition), contradiction
        = erreur, double place = erreur : l'unicité devient structurelle.
        Mesuré au passage : les 85 loads r-type n'ont aucune incohérence
        de destination. Doc : scenes.md § The attributed place ; XSD
        régénéré (il avait dérivé depuis P1). PREUVE : 59 images
        identiques à l'octet, JUnit 70/70 (6 tests ajoutés). Reste 4a :
        vérification globale des places fixes hors arène (avec 4b).
  - [x] Phase 4b-pilote (10/08) — r-type migré vers la place attitrée :
        75 fichiers annotés (64 arena, 11 region), 4 pagesets nommés
        nus, 84 loads réduits au nom. PREUVE : 59 images identiques à
        l'octet (le déplacement d'attribut à places égales se prouve par
        identité, pas besoin du banc). Restent : les 12 configs
        d'exemples (region= sur loads), puis la dissolution des régions.
  - [x] Phase 4b-exemples (10/08) — les 13 configs d'exemples migrés au
        même mouvement (71 fichiers annotés, 71 loads réduits au nom),
        MO6 compris — l'identité binaire vaut preuve là où l'émulateur
        manque. loader-ut est EXCLU à dessein : il reste le gardien de
        la forme par-load tant que 4c ne l'a pas retirée. PREUVE : 59
        images identiques à l'octet. Reste 4b : la dissolution des
        régions elle-mêmes (places bougent, preuve par exécution).
  - [x] Phase 6-rapport (10/08) — le rapport de seeks par scène
        (`report/SeekReport`, `seek-report-<target>.txt`) : lecture
        seule du journal média + RAM map, retours de tête marqués avec
        provenance, critère imprimé en tête. Première lecture r-type :
        scenes.boot paie 4 retours. PREUVE : 59 images identiques,
        JUnit 70/70. Restent en 6 : l'ordre d'écriture par première
        utilisation, le silence du codec.
- [ ] **Charge manuelle r-type** — inventaire fait le 09/08 :
      [`analyse-charge-manuelle-2026-08.md`](docs/lang/fr/analyse-charge-manuelle-2026-08.md).
      Cinq scripts Python de glue (gen_objid, gen_enemy_unit, crop_stage,
      leanscroll non orchestré), api.asm/stage-tables.asm au clavier,
      2 568 lignes de config dont 52 blocs gfxcomp répétitifs. Priorités :
      index+équates (quotidien, couvert par le modèle cible §23),
      déclaration d'images compacte, .external.asm générés, orchestration
      leanscroll. Critère de fin : tools/ ne contient plus que des outils
      de contenu. (L)
- [ ] **Média cartouche** — CLAUDE.md annonce `rom t2` mais aucun handler
      cartouche n'existe dans le registre : la v2 ne produit que de la
      disquette (fd/sd/sap/hfe). À décider : porter le média ROM (utile
      MegaROM/MO5 à terme) ou corriger la doc en attendant. (M–L)
- [ ] **Packaging zip distribuable** — assembly Maven : `repo/` + lanceurs
      `bin/` + third-party par OS + XSD. Seulement si distribution visée. (M)

Robustesse / outillage :

- [ ] **`lwasm.exe` codé en dur** (`LwAssembler.java:80`) — pas de détection
      d'OS, et les binaires macOS embarqués (lwtools 4.18) sont trop vieux
      (>= 4.22 requis). Piste : défaut par OS + attribut `processor` déjà
      existant, et rafraîchir les binaires third-party. (S)
- [ ] **Build d'image en CI** — débloqué le 09/08 : lwtools 4.25 Linux est
      dans le dépôt et `ci/build-corpus.sh` construit les 15 configs et
      empreinte les 59 images (le banc de la phase 0). Reste à brancher le
      script dans le workflow GitHub Actions avec une empreinte de
      référence commitée. (S)
- [ ] **Parallélisation lwasm** — débloquée par BuildContext (état réentrant),
      jamais exploitée ; gain de temps de build sur les configs à dizaines de
      direntries. (M)
- [ ] Warning « Duplicate filename » de LwAssembler (defines de taille par
      basename de gensource) : mineur, à nettoyer à l'occasion. (S)

Hygiène repo (hors Java mais vite fait) :

- [ ] `data.asm` et `mub.o` orphelins à la racine ; liens cassés des readme
      (cf. Dettes de CLAUDE.md). (S)

En veille sur décision (31/07/2026) :

- [ ] **Adresses de régions calculées façon overlay** (modele-regions §7) —
      reprendre au portage R-Type.

## Différés loader (ne rouvrir que sur besoin réel)

- [ ] Suivi des tailles dans l'index (recouvrement partiel → slot périmé ;
      discipline actuelle : `linkData.unload` explicite)
- [ ] Paginated groups + outils de découpage
- [ ] `linkData.unloadAll` (ou unload par plage de pages) — sécuriser en un
      appel les transitions de phase à cartes mémoire différentes (overlays,
      cf. plan scènes déclaratives §11)

## Runtime engine — roadmap R-Type (détail dans CLAUDE.md)

- [ ] 1. Sprites compilés runtime (`DrawSprites`/`EraseSprites`/`BgBufferAlloc`
      sur sorties gfxcomp) + banc `examples/sprites`
- [ ] 2. Object manager (`RunObjects`, slots, montage de page par objet)
- [ ] 3. Animation (`AnimateSpriteSync`, `moveByScript`)
- [ ] 4. Scroll horizontal + tilemap (décision : port v1 vs nouvelle génération
      `hscroll`)
- [x] 5. Collisions AABB + terrain (03/08/2026) — la passe de détection vit
      dans le moteur résident, à côté des listes (la v1 la déportait dans
      `obj_mainext` faute de place, raison disparue en v2 : le stage EST dans
      la page résidente). Le vaisseau meurt au contact, pata-pata meurt sous le
      tir et fait naître son explosion. Manquent les listes `foefire` et
      `forcepod` et `WeaponContactTick`, faute des objets qui les peuplent.
      Cas : [main-private-object.md](docs/lang/en/migration/main-private-object.md)
- [ ] 6. ObjectWave + caméra/AutoScroll
- [ ] 7. Pipeline builder « jeu » (équivalent v2 des `.properties` v1)
- [ ] 8. Portage du projet R-Type (game modes, ~60 objets, assets)

## Fait (juillet 2026)

- [x] **Scènes/régions déclaratives** — campagne complète (31/07/2026).
      Docs : doctrine [`modele-regions-2026-07.md`](docs/lang/fr/modele-regions-2026-07.md),
      plan [`scenes-declaratives-2026-07.md`](docs/lang/fr/scenes-declaratives-2026-07.md),
      référence [`docs/lang/en/scenes.md`](docs/lang/en/scenes.md).
  - [x] Phase A — éléments `<layout>`/`<region>`/`<scene>`/`<load>` +
        générateur de tables (pilote sound TO8, identité binaire, toje)
  - [x] Phase C — 17/17 tables du corpus migrées (loader-ut ×10, sound ×4,
        tlsf-ut ×2, mplus ×3), identité binaire, tables manuscrites supprimées
  - [x] Phase B — vérifications locales à une scène (budgets, écritures
        disjointes, export-only, somme `bulk`) ; doctrine « le builder vérifie
        une composition, pas les enchaînements » ; `permanent` retiré ;
        régions `bulk` (listes empilées, remplacées en bloc)
  - [x] Encodage `%11` automatique quand les ids se suivent (pad 37→7 octets,
        iface 17→7 ; repli silencieux `%10` si la chaîne se brise) — validé
        par exécution : loader-ut 16/16, sound RAM + swap à chaud
  - [x] Equates de layout (`<layout gensymbols>` → `<région>.page/.address`)
  - [x] Phase D — groups.md aligné, scenes.md écrit, XSD/CLAUDE.md à jour.
      Différé (en veille jusqu'au portage R-Type) : adresses de régions
      calculées façon overlay (modele-regions §7).
- [x] CLAUDE.md initial : état des lieux v1/v2 + roadmap R-Type
- [x] Cycle de vie loader complet (unload, dédup, implicite, count, isLoaded)
      + stress test 16/16 sous toje (multi-secteurs, multi-disquette, ids
      globaux) — 6 bugs corrigés dont 2 dormants depuis l'origine
- [x] Revue Java (`docs/lang/fr/revue-java-2026-07.md`) + phases 0/1/3/2
- [x] 6 PR Dependabot sûres appliquées
- [x] Packer VGC porté en Java, Jython supprimé (validation bit à bit)
- [x] BuildContext : état de build réentrant (fin des statiques)
- [x] Mécanisme de plugins supprimé → registre explicite `Handlers` (−2 400 l.)
- [x] Contrat d'attributs : analyses (XML vs YAML, DSL), loader StAX +
      positions source, specs typées + Validator, XSD généré (option `-x`)
