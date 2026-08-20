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
- [x] **examples/sound TO8 ne joue plus** — RÉSOLU (10/08). La bissection
      vers `f7d4474` était un leurre de phase : le vrai coupable est la
      **passerelle `irq.off equ IrqOff`** du gm title (l'anti-pattern que
      `irq-bridge.md` recommandait !). Le IrqOff v1 écrase A ; or
      `ymm.obj.play` appelle `irq.off` juste avant `sta ymm.data.page` —
      la page stockée devenait le résidu STATUS ($00), et chaque
      `frame.play` remontait la fenêtre cartouche sur la page 0 EN
      S'EXÉCUTANT DEPUIS LA FENÊTRE. Le verdict dépendait de la phase de
      la première IRQ musicale, donc tout changement de taille déplaçait
      le vert/rouge — d'où la fausse bissection. Correctif : wrappers
      préservants APRÈS mainLoop (la scène saute sur le premier octet de
      l'unité), `irq-bridge.md` amendé (l'equ nu est banni, deuxième
      morsure après r-type). Validé sous toje : mainLoop en 4069
      instructions, data.page=$66, bascule title→level1 par le hook $9C00
      avec les deux flux remplacés en RAM, 1500 trames de vie libre.
      Migration 3b+4b de sound DÉBLOQUÉE, dépendance de 3c levée.
      (Diagnostic initial, conservé pour l'histoire : « depuis `f7d4474` (05/08)** — trouvé
      le 10/08 en préparant sa migration 3b+4b : le mainLoop du title n'est
      jamais atteint, le premier userIRQ qui streame finit en sous-débord de
      la pile d'IRQ privée et la machine erre en VRAM. Bissecté (worktree +
      `git bisect run`, prédicat mainLoop-sous-toje) : le bloc
      `ymm.stop`/`ymm.restart` est la condition nécessaire (padding
      innocent, builder disculpé — mêmes commits, seul `ymm.asm` échangé).
      Rien dans `sound` ne les appelle : l'effet passe par le décalage ou
      les exports, pas par un appel. r-type non affecté (player à `$1C9B` ;
      `sound` est le seul à placer le sien à `$0000`). Même zone que le
      dossier YMM : à instruire ensemble. **Migration 3b+4b de sound
      SUSPENDUE jusqu'au vert.** Détail : `ci/toje-bench/readme.md`.
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

- [ ] **N'émettre les blocs compression/linker d'une entrée de répertoire que
      s'ils servent** (relevé 14/08/2026, r-type). Une entrée = des slots de
      8 octets (principal + compression si comprimé + linker si linkdata) ;
      **85 fichiers du disque r-type paient un slot linker pour ZÉRO octet de
      lien** — ~680 octets de répertoire gaspillés, et le répertoire vit À
      DEMEURE dans le pool du loader (4060 octets) : son passage de 10 à 11
      secteurs a gelé l'échange de scène (tlsf.err=3, bissection au worktree).
      Le format est déjà à blocs variables (bits dans sizeu, ids = index de
      slot), l'assertion « ids réservés == blocs émis » verrouille — mais
      TOUTES les images changent : méthode standard complète. Détail :
      plan-portage-rtype §chantier 3. Alternative loader (plus lourde) :
      sortir le répertoire du pool (buffer fixe sur la moitié arène de la
      page 4).

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
- [x] **Migration vers le modèle cible « file maître » — CAMPAGNE CLOSE
      (13/08/2026)**. Les neuf phases sont réalisées et prouvées (le plan
      porte une annotation de preuve par phase) ; le manuel cible est
      normatif, master est à jour. Restent OUVERTES, hors campagne, les
      trois études adjacentes listées plus bas (5-normalisation,
      5-nomenclature, 5-arbitrage du modèle de numérotation) — à reprendre
      sur besoin, au portage des ennemis. Plan d'origine en neuf phases
      écrit le 09/08 :
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
        interface/« même destination » (rapport d'abord, acté).
  - [x] Imageset délégué — CLOS PAR MESURE (10/08) : la fonte avait déjà
        eu lieu à 4576b95 (05/08, bake=auto sur les porteurs d'index,
        images changées et validées alors) ; externPg = 0 sur tout le
        corpus hors mplus (hors imageset), listes causées sans symbole
        d'imageset, contre-preuve par cassage volontaire (bake=none →
        1 externPg de retour), bancs verts en tête de branche. Les deux
        formes consomment le même service (pageOf direct / resolvePage à
        la cuisson). Détail : annotation 3a du plan.
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
  - [x] Phase 6-codec (10/08) — le silence du codec : défaut zx0
        (effectiveCodec aux trois lecteurs), codec="none" opt-out sans
        bloc de compression, table de scène épinglée brute (le loader ne
        la décompresse jamais), pageset écrit sa décision effective sur
        chaque membre. Bug latent corrigé : la réservation du répertoire
        ne voyait pas les <default> rejoués (attrapé par réservé==émis).
        loader-ut opte out par défaut de répertoire ; codec="zx0"
        redondant retiré des 12 autres configs (identité 59/59). PREUVE :
        46/59 images changent (annoncé), JUnit 116/116, banc toje complet
        vert (r-type 5/5, loader-ut $0D+T18, hscroll k=−16 aligné, mplus
        séquences identiques). Mesure : mplus-test −24 % média. Reste en
        6 : l'ordre d'écriture par première utilisation.
  - [x] Phase 5-creux (10/08) — la coupe par les creux : ArenaPacker
        enregistre les creux résiduels, <pageset arena=…> y coule ses
        éléments (morceau par creux, gapmin 256, erreurs nommées, restes
        disponibles pour la collection suivante), <unit> marche dans un
        <file>. r-type re-rangé : 2 arènes alternatives sur les 8 pages
        de tuiles, cartes+vagues rigides posées par le packer, adresses
        mesurées à la main disparues ($1C9B, $09C7), fenêtre musiques
        déclarée. PREUVE : identité 59/59 (mécanisme), JUnit 125/125,
        banc r-type 5/5 + niveau 1 traversé, zéro retour conservé,
        4 images r-type changent (annoncé). Mesure honnête : 10 morceaux
        vs 8 (espace quasi plein — le gain est la fin du câblage manuel,
        pas le compte d'entrées).
  - [x] Phase 5-objets (11/08) — TEST CONCLUANT : les objets sortent du
        XML. Les 2 <objectindex> de r-type remplacés par de l'asm de dev
        (objid-common.const.asm : préfixe de 29 ids partagé par include,
        l'invariant devient structurel ; tables manuscrites par stage,
        pages par équates du layout, adresses EXTERNAL cuites ou liées).
        PREUVE : 59 images identiques à l'octet — même exécution, coût
        de lien inchangé par construction. Verdict au §24. Reste si
        adopté : retirer l'élément <objectindex> et son plugin (plus de
        consommateur) ; l'inversion §23 ne porte plus que sur le généré.
  - [x] Phase 5b — symbole$PAGE (11/08) : X$PAGE accepte un symbole OU un
        nom de fichier (StaticLink.pageOfName, collision refusée en
        nommant les deux, jamais de repli silencieux) ; les générateurs
        (<tilemap>, imageset réparti) émettent <expr machine><sym>$PAGE
        au lieu d'un littéral Java. Préalable fait dans la foulée
        (décision auteur) : la machine se déclare —
        engine/config/machine.xml sur le modèle storage.xml (pages de
        RAM, expression de bits cartouche + include), sélectionnée par
        <machine name=…/>. Le builder répond le numéro de page, jamais
        les bits $60. PREUVE : 59 images identiques à l'octet, JUnit
        142/142, banc r-type 5/5, les deux garde-fous cassés et LUS.
  - [x] Phase 5c — un seul tri, le flux par élément sur tout fichier
        (12/08, option (i) tranchée par l'auteur) : les 4 <pageset>
        deviennent des <file> ordinaires (attrs name/arena/linkdata/
        gendir) ; le packer trie TOUT plus-gros-d'abord, pose entier ce
        qui rentre (le fichier garde son nom), coule en <fichier>.N ce
        qui ne rentre pas — la coupe est un repli, pas une politique.
        Mécanique : Cuts (registre des découpes), CollectionPlugin
        (mesure par offsets d'export + émission par morceau),
        collectDivisibles dans PlacementScan (defaults rejoués),
        réservation par membres dans DirectoryPlugin. La prémisse « les
        48 fichiers ennemis changent » était fausse : leur gfxcomp est
        imbriqué dans lwasm → un seul élément → tri inchangé. Gain : les
        tilesets even/odd d'un stage partagent les queues de pages.
        PREUVE : 4 images r-type changent (annoncé), 55 identiques,
        JUnit vert, banc r-type 5/5 sous toje, reproductibilité 59/59.
        Piège Java consigné : ternaire int/Integer qui déboxe un null.
        Commit B FAIT dans la foulée : PageSetPlugin (685 l.) supprimé,
        <unit> relogé dans plugin/unit/UnitPlugin, spec <pageset> +
        branches directory/scan + arenaGaps + memberNames retirés,
        PageSetFlowTest retargeté en ArenaPackerCutTest (les 6 scénarios
        de flux, sur ArenaPacker.cut), XSD −132 lignes, docs alignées
        (scenes.md, sprites.md, symbols.md ; note de mise à jour dans le
        cas imageset-pages.md). PREUVE : 59 images identiques à l'octet,
        JUnit vert, reproductibilité.
  - [x] Phase 5e — retrait de <objectindex> (12/08) : l'élément, son
        plugin (les 5 derniers map.RAM_OVER_CART codés en dur) et les
        specs <objectindex>/<entry>, XSD −219 lignes. Plus aucune
        constante machine hors machine.xml. PREUVE : 59 images
        identiques à l'octet, JUnit vert.
  - [x] Phase 7a — les contrats d'interface : rien à générer (13/08) :
        l'idiome du contrat à liste unique au manuel (symbols.md § The
        single-list contract), le générateur .external.asm REJETÉ et
        consigné (circularité : la liste des exports EST le contrat
        authoré) ; gen_enemy_unit.py retiré (moule XML fondu avec 7b,
        geste de portage documenté dans games/r-type/readme.md).
        CRITÈRE DE FIN DE LA PHASE 7 ATTEINT : tools/ ne contient plus
        que des outils de contenu.
  - [x] Phase 7c — leanscroll + crop orchestrés (13/08) : élément
        <leanscroll> (module en JVM, cache, crop absorbé, géométrie en
        équates), rejoué par la passe de placement ; stages 01-02 câblés,
        crop_stage.py + leanscroll-01.txt + intro/ + plans committés des
        stages câblés supprimés. Le résidu de 6 octets du stage 1 (3
        cellules à 0 là où la carte v1 lit 1) a été RENDU À L'AUTEUR
        (rendu PNG de la zone) et adjugé : c'est une retouche manuelle
        NÉCESSAIRE — la bande centrale n'est pas rafraîchie par le scroll
        depuis les mêmes blocs qu'au début du stage, le checkpoint
        repeint depuis la carte. Devenue donnée déclarée :
        `refresh="48:6-8"` sur le <leanscroll> (cellules forcées à la
        première tuile du set). Cas :
        docs/lang/en/migration/checkpoint-refresh-cells.md.
        PREUVE FINALE : **IDENTITÉ TOTALE 63/63** — toutes les images au
        hash exact d'avant 7c (la chaîne reproduit les octets livrés,
        banc r-type 5/5 déjà acquis sur ces octets), JUnit vert,
        reproductibilité avec cache exercé. Pièges : drawImage remappe
        les couleurs d'une image indexée (copie de raster brute), un
        cache survit aux correctifs (version bumpée), un résidu
        inexpliqué entre généré committé et régénération peut être une
        décision authorée NON DÉCLARÉE — la faire adjuger avant
        d'adopter un côté.
  - [x] Phase 7b — la déclaration d'images compacte (12/08, décisions
        auteur : « tout le stock d'un coup », défaut = décalages seuls,
        names= déduit du répertoire de série) : élément <images> (une
        ligne = une série, ordre = préfixe NN, index continus, un
        encodeur par décalage, images.shifts par target, index="none"
        pour l'adressé-par-nom) ; 355 fichiers renommés (autorité :
        config v2 puis properties d7, familles en sous-répertoires,
        v1-map suivi) ; 17 gfxcomp compactés vérifiés par expansion,
        31 littéraux conservés, config −375 lignes ; check_variants au
        hash de contenu → 14 divergences v1↔v2 PRÉEXISTANTES enfin
        visibles (consignées, à arbitrer au portage). PREUVE : 63
        images identiques à l'octet, JUnit vert, banc r-type 5/5.
        Piège attrapé par l'identité : l'index inventé sur les séries
        adressées par nom (+38 octets sur dobkeratops).
  - [x] Phase 5d — <unit> sur son vrai rôle (12/08, décision auteur :
        « b tout de suite, builder générique ») : unit au registre PARTS
        (UN élément, jamais coupé en son intérieur), mesuré et assemblé
        SEUL, membre mixte = concaténation de binaires en ordre de
        déclaration, genindex imbriqué repointé sur le membre réel ;
        les 2 vagues basculent sur la voie collection. Doc scenes.md.
        PREUVE : 59 images identiques (vagues comprises), JUnit vert,
        et le NOUVEAU banc examples/collection — 40 tuiles + un unit
        coupés en 4 membres, 4/4 sous toje (contenu du unit via son
        membre, pages distinctes, pointeur inter-membres dans le unit),
        erreur « does not fit » lue en vrai.
  - [x] Phase 9 passe 2 — documentation FAITE (13/08) : manuel anglais mis
        au vrai (bandeau « not yet implemented » de scenes.md, validation
        au corpus courant, mention interface= de project-build) ; manuel
        cible + workflow rehomés NORMATIFS avec la divergence d'index
        résolue dans le corps (§3.5/§5/§6 réécrits au modèle implémenté :
        tables de jeu en asm, symboles cuits + $PAGE, équates d'ids
        partagées) ; statuts des études remis au vrai (analyse-placement
        close, plan RÉALISÉ, reste-cible photographie, modele-zones) ;
        CLAUDE.md réaligné (convertisseurs sans ServiceLoader, validation
        13/08, encart « état courant » sur la section loader, rom t2
        retiré) ; readme racine : liens remplis, lien FR mort retiré.
        LA CAMPAGNE EST CLOSE.
  - [x] Phase 9 passe 1 — code mort FAIT (13/08, 4 commits, chacun
        prouvé identité 63/63 + JUnit 84/84) : équates de layout
        `.size`/`.pages`/`.page.last` (zéro consommateur) ; 4c exécuté
        (loader-ut migré aux places attitrées — T18 intact, la
        re-mesure ayant montré que chaque fichier n'a qu'UNE
        destination —, forme par-load retirée des 3 lecteurs + spec +
        XSD, section pédagogique « who/where » au manuel) ; PageSets
        fusionné dans Cuts (le nom du <pageset> disparu quitte le
        code) ; orphelins supprimés (data.asm, mub.o, gfx.memset..,
        examples/timing + timing.md — validé auteur) ; grep de clôture
        des mécanismes disparus : zéro hors historique. Restent :
        passe 2 (documentation).
  - [x] Phase 8 — campagne loader FAITE (13/08, décisions auteur : pas
        de piège loader, rien d'autre à embarquer). Pas A par identité
        (63/63) : le verrou « séquentiel = export-only » EXISTAIT déjà
        (SceneChecks + test — message reformulé), 3 sizeof{} d'une autre
        struct corrigés, et le dépoussiérage éviction/$ff00 débordait
        sur deux docs normatives (scenes.md, groups.md) qui racontaient
        l'éviction au présent. Pas B : la marche mémoire des handlers
        %10/%11 est retirée (~50 lignes), destination constante,
        dérivation d'ids par flags conservée, format de scène inchangé
        (24 tables identiques à l'octet) — plus AUCUNE décision de
        placement à l'exécution. PREUVE : 62 images changent (annoncé),
        to8-disk1.fd intacte, reproductibilité, JUnit 84/84, et la lane
        toje entière verte (loader-ut 17/17+T18 avec disquettes, r-type
        5/5 — le %10 du boot —, collection 4/4, objects 18/18, sprites,
        tilescroll, hscroll k=−13, tlsf 10k trames, stacked 10/10,
        sound title→level1 à chaud, mplus-test séquence identique
        pré/post, mplus-pcm vivant). Pièges consignés au plan : image
        pas toujours nommée to8.fd (écran « No Disk » = faux échec
        total), contre-épreuve invalide si le build n'est pas exit=0.
  - [ ] Phase 5-normalisation (11/08) — ÉTUDE ÉCRITE (§26), suite du §25 :
        inventaire exhaustif (4 orthographes de page vivantes, 3 conventions
        pour les bits cartouche) et fait dur mesuré — `.` est l'espace de
        noms du JEU (`terrainCollision.main.address`, 34 `*.size` de
        structures) et le builder y écrit, collision déjà vécue
        (`Multiply defined symbol (common.anim.page)`). PROPOSITION :
        `<nom>$<ATTRIBUT>` — `$` = question résolue par le builder, hors de
        l'espace de noms du jeu ; `X$PAGE` remplace les 4 formes, `X$ADDR`
        pour les binaires sans symbole, rien d'autre ; collision
        fichier/symbole REFUSÉE en nommant les deux (corrige §25(a)) ; le
        builder répond la page, jamais les bits `$60` (constante TO8, MO6
        est une cible). Conclusion : PAS de langage d'index à créer —
        l'adresse est le symbole, le numéro est authoré, seule la page
        manque. Migration en 3 pas prouvables par identité. HORS PÉRIMÈTRE :
        les 3 dialectes de labels = le renommage, phase finale.
  - [ ] Phase 5-nomenclature (11/08) — ÉTUDE ÉCRITE (§25) : le nom comme
        interface unique. Mesure : l'ADRESSE d'une entrée d'index est déjà
        unifiée (symbole des deux côtés), la PAGE s'écrit de deux façons
        selon la nature du contenu (symbolique pour le rigide, littéral
        Java `pageOf` pour le fluide) — le même générateur porte les deux
        branches. `pageOf(symbole)` existe et n'est pas exposé à l'asm.
        Cuisson : rien de neuf. Load-time : variante bon marché de
        `linkData.symbol.search` (phase 8) — mais PAS nécessaire d'abord,
        le fluide est toujours placé donc toujours cuisible. Retire
        `ImageSets.PageOf`, la branche à deux formes, et surtout le
        couplage génération↔placement. À trancher : un token (modèle
        cible) ou deux (pas sûr).
  - [ ] Phase 5-arbitrage (10/08) — le cas objet MESURÉ (§24 de
        l'analyse placement) : réutilisation multi-stages massive et sans
        axe (20/54 objets, sous-ensembles arbitraires), v1 sans contrat
        de numérotation (par game-mode), contrat v2 = les 25 ObjID du
        résident + clusters ennemi/satellites (binaire partagé) +
        présence forcée par source partagée (bouchon shellEraser).
        Constat : l'arbitrage porte sur le MODÈLE DE NUMÉROTATION
        (résident figé / clusters cohérents / local libre), pas sur la
        syntaxe. EN ATTENTE de l'arbitrage auteur ; la coupe par les
        creux est indépendante et peut précéder.
  - [x] Phase 6-ordre (10/08) — PHASE 6 CLOSE. Écritures différées
        (DirEntry.Pending), flush par le répertoire en ordre de première
        utilisation (table de scène puis fichiers en ordre de table),
        descripteurs patchés au flush, garde-fou entrée-hors-répertoire.
        PREUVE : r-type scenes.boot 4 retours/75 pistes → 0/25, ZÉRO
        retour sur tout le corpus, 24/59 images changent (annoncé),
        reproductible, JUnit 119/119, bancs des images changées verts
        (loader-ut $0D+T18, r-type 5/5, tilescroll, hscroll k=−13,
        mplus-test séquence identique).
  - [x] Publication des places attitrées littérales (10/08) — le
        `gensymbols` du répertoire publie `<name>.page`/`.address` à côté
        de l'id de fichier pour tout fichier à place `page=`+`address=`
        (le remplaçant du gensymbols de layout, idiome du pageset).
        PREUVE : identité (les équates n'émettent rien), JUnit 70/70.
  - [x] 3b+4b-dissolution, 6 configs sur l'ordre acté (10/08) : tlsf-ut
        (TO8+MO6, identité), hscroll (déphasage de 4 trames prouvé par
        alignement d'écrans déterministes), objects (banc 18/18 `$0D`),
        sprites (7 verdicts `$9C00`, tête de liste libre inchangée),
        tilescroll (caméra + 3 verdicts terrain), stacked-overflow
        (TO8+MO6, 10 marqueurs relus en pages 5/6). Chaque commit :
        images changées annoncées, reste du corpus identique, exécution
        rejouée sous la lane toje. **sound SUSPENDU** (régression
        `f7d4474`, voir « À corriger »).
  - [x] Arbitrage interface/alternatives TRANCHÉ (10/08, décision auteur) :
        zéro logique d'interchangeabilité/co-location. Labels générés
        uniques au générateur (adr_<hôte>_<id>_<variante>, tiles= nomme
        l'hôte), comptage nu des fournisseurs (l'élection meurt), doublons
        d'exports = un fait (premier-chargé gagne, liste causée = témoin),
        interface= retiré, régions stage/maps dissoutes, le moteur saute
        sur stage.main par le lien. Coût mesuré : 512→634 octets (+122,
        les entrées principales voulues au lien) — contre les ~12 Ko
        qu'aurait coûté la règle nue sans l'uniquification (mesure faite
        d'abord, elle a réfuté la proposition naïve). Bancs 5/5 + 17/17,
        JUnit 70/70, détail dans l'annotation 3c du plan.
  - [x] 3b clos et 3c FAIT (10/08) : sound migré (TO8 dissous entier,
        MO6 garde ses régions mesurées — témoin complet rejoué, identique
        au témoin du correctif), loader-ut arbitré hors 3b (décor vide,
        exempté par un default par répertoire), défaut bake NONE→AUTO
        prouvé par identité parfaite aux deux pas (bascule + retrait des
        93 attributs redondants). **La phase 3 est close.** Restent de la
        campagne : l'arbitrage interface/alternatives (matière prête),
        les régions interface de r-type après lui, 4c.
  - [x] 3b+4b-dissolution, suite (10/08) : mplus ×3 (les scènes
        « manuscrites » de la note CLAUDE.md n'existaient plus — l'arène
        les avait résorbées ; séquence d'écrans décalée d'un cran, pcm
        statique identique, MO6 sur la foi du jumeau) ; r-type mécanique
        (common, ymm.player, ymm.data → places littérales,
        `engine.sound.ymm.page` publié — PREUVE PAR IDENTITÉ, 59 images,
        banc 5/5 rejoué par surcroît). Observation de l'arbitrage
        interface consignée dans le plan (listes causées du corpus
        migré : vides sauf la frontière r-type). Restent : **loader-ut à
        scinder** (ce qui teste le linker garde bake=none et la forme
        par-load, le décor migre), **l'arbitrage interface/alternatives**
        (la matière est prête : dérivation depuis FilePlaces), les
        régions interface de r-type après lui, et sound après le vert.
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
  - [x] Garde `<reserved>` (19/08) : un load dont l'étendue RÉELLE croise une
        plage réservée est REFUSÉ (SceneChecks, toutes formes de destination —
        brute, région, arène ; passe réelle seulement, et un refus vide
        désormais `dist/` des images des passes de découverte aussi). Trouvé
        par l'incident palette : `title.main` ($0767 octets à $8000) posait
        son dernier octet SUR `bench.magic` $8766 → entrée 15 bleue à l'écran
        LOADING, en silence. Corpus revalidé : 59 images inchangées octet
        pour octet. Débordement résolu (décision auteur, même jour) : pool
        44 -> 43 (ram.const.asm), base $87DB -> $8850, bench $87DB, cast
        $87EB — les unités title/stage disposent de $8000-$87DA (+117).
        Validé sous toje : entrée 15 NOIRE à l'écran LOADING, stage 1 joue,
        témoins du banc vivants à la nouvelle adresse.
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

- [x] r-type : couleurs de l'ecran STAGE n CLEARED (15/08/2026) — tranche
      par l'auteur : le fond des glyphes peint l'INDEX 0 (noir dans toutes
      les palettes), jamais le 15 (saumon dans celles des stages). La copie
      v1 de la police du title posait $F ; transformation F->0 sur les 104
      glyphes, ecrans 1 et 2 photographies identiques, lane 7/7. Le stage 1
      n'avait l'air juste que parce que sa sequence de boss noircissait
      l'index 15 au moment du releve.

- r-type : **trois index de palette gelés par le commun changent de couleur
  selon le stage** (15/08/2026) — relevé par `tools/palette_usage.py`, qui
  lit le config, expanse les images comme le builder et couvre AUSSI le
  dessin écrit à la main (`LDA #$xy` + `STA n,U`, la police du relevé).
  Le commun consomme 15 des 16 index ; seul le **15 est libre** depuis le
  correctif de la police. Les défauts : **index 6** (le cyan du vaisseau,
  des armes et du starfield — 12 unités communes) devient kaki au stage 3
  et vert sombre au stage 6 ; **index 14** (explosions, missiles, tir
  ennemi) varie sur six stages ; **index 4** ne bouge que d'un cran de bleu
  entre le stage 1 et les autres. Cause : les palettes des stages 2-8 sont
  DÉRIVÉES du PNG de tileset (`gen/stages/NN/map/even.png`), personne ne
  leur impose les index du commun. Deux issues, à trancher : accorder les
  palettes de stage sur les index gelés (authorer un vrai `pal.png` par
  stage, comme le stage 1), ou réserver au décor les index que le commun
  n'utilise pas. À faire avant le portage des gfx d'ennemis, qui va élargir
  la contrainte.
  **Suite (15/08) : l'auteur propose une palette 12 communs + 4 par stage, et
  l'étude est chiffrée dans `docs/lang/fr/analyse-palette-migration-2026-08.md`
  (palette proposée dans le dépôt, `games/r-type/tools/palette-reference/nouvelle.png`, non
  branchée). Quatre arbitrages pris : vert du scant accordé, index 15 abandonné
  pour le fond du stage 1, étoiles tolérées sur les noirs des tuiles, et
  migration par objet avec planche de prévisualisation et validation manuelle.
  RIEN N'EST IMPLÉMENTÉ — le protocole du §7 gouverne le jour où ça démarre.**

- r-type : la musique du stage 6 est un CHOIX EN ATTENTE de l'auteur —
  aucun asset ni en v1 ni en v2 (pas de dossier music dans le niveau 06),
  le direntry `stage6.music.ymm` rejoue l'unité du stage 1 en attendant.
  Candidats si un jour : le `theme.ymm` partagé des dossiers 04/07, ou une
  conversion vgm2ymm dédiée.

- [x] Loader : tampon de répertoire STATIQUE hors pool (15/08/2026) — le
      builder émet `loader.dir.buffer.SECTORS` (max des répertoires du
      target) dans gen/directories/locations.asm, le loader taille le
      tampon en tête de la zone mémoire et démarre le pool juste après ;
      `dir.load` n'alloue plus rien. Le game over de r-type était passé à
      83 octets du gel par simple fragmentation (le tampon exigeait
      jusqu'à 1540 octets CONTIGUS à chaque échange), et le chantier
      musique l'a fait franchir une fois — plus possible par construction.

## mscroll — scroll multidirectionnel par buffer de code (étude 20/08)

- [ ] `engine/graphics/tilemap/mscroll/` + démonstrateur `examples/mscroll`,
      étapes M1..M4 et critères dans `docs/lang/fr/etude-mscroll-2026-08.md`.
      Cible : la couche battleship du stage 3 r-type (le rendu tilemap actuel
      reste la seconde couche par-dessus, sol/plafond) ; bandes de masquage
      8 px gauche/droite comme le masque playfield existant. L'adaptation
      r-type est hors périmètre de l'étude.
  - [x] **M1 (20/08)** : clone vscroll v1 intact, exemple en scroll vertical
        sur l'art réel du cuirassé (échelle TO8, palette stage 3), validé
        sous toje dans les deux sens — lignes alimentées relues identiques à
        la map, capture = rendu TO8-vrai. Pièges corrigés : `jmp` de
        bouclage en mode direct (lwasm), padding tileset par bloc-ligne.
  - [x] **vscroll migré 1:1 (20/08)** : import verbatim dans
        `engine/graphics/tilemap/vscroll/` (manifest, zéro écart) +
        `examples/vscroll` (l'exemple M1 renommé) — image octet pour octet
        identique à celle validée sous toje : migration validée par identité.
  - [x] **M2 (20/08)** : ruban horizontal (h/b/w, chunks 16 px, entrée et
        sortie décalées de h — pas de ligne de garde nécessaire, la sortie
        patchée couvre juste). Validé sous toje : rotation 160/160 px,
        +2 px caméra = −2 px écran linéaire sur toutes les phases, feed
        vertical octet-parfait en diagonale, couture confinée aux bandes.
        Piège lwasm consigné : une ligne VIDE termine la portée des labels
        locaux `@`.
  - [x] **M3 (20/08)** : feed colonne + map 2D (ids 16 bits prémultipliés,
        stride en puissance de 2, ≤ 2048 px de large), camera.x entier 16
        bits + accumulateur de fraction, clamp aux bords. Conventions
        tranchées à la mesure : h = −window mod 10 (slots inversés, héritage
        v1) et termes fins en signe opposé à hscroll (bo négué, phase w
        miroir avec −1 octet côté plan 0). Validé sous toje : D(x) = x
        pixel-exact à toutes les phases, aller-retour complet 0↔352 avec
        les deux chemins de feed, 160/160 aux deux butées. Démonstrateur
        sur map 512×640 avec le vaisseau entier.
  - [x] **M3-opt (20/08)** : tileset tile-major (ids ×32, `ldd ,y++`),
        feed par tuile de 8 px cadencé sur les masques — 37 cy/ligne/plan
        (mesuré 117 avant), plus aucune boucle à 6 trames (min 9,8→10,8 fps
        à 200 lignes, moyenne bornée par la quantification). Bug grave
        corrigé : wrap de marche descendante comparé en non signé → la
        queue du feed arrosait $FFxx puis les E/S $E7xx (gels d'IRQ) ; la
        v1 borne ses marches en SIGNÉ (`bge`), règle retenue.
  - [x] **Campagne diagonale + couture supprimée (20/08)** — détail §9 de
        l'étude. Bug signalé par l'auteur (décalages de tuiles en diagonale)
        : garde signée `deca/bpl` de l'ancre du tile-feed, fausse pour
        cursor ∈ [129..200] — deuxième piège signé du module, règle : écrire
        le cas 0 explicitement. Aussi : buffer de départ passé à 201 lignes
        ancrées (`setCameraPos` cale le cursor), row-feed montant recalé de
        +1 (V2-DEVIATION, probablement latent en v1 — jamais contrôlé à
        l'octet). Puis suppression de la couture par cisaillement map-fixe
        (proposition auteur : la coupure est FIXE dans la map, tous les
        160 px) : écritures décalées d'une ligne par couture franchie, cache
        cuit à id×32−2, rattrapage 1 ligne/16 depuis un cache de la rangée
        du dessus, cursor±1 au franchissement caméra — zéro re-feed, coût
        mesuré nul (12,50 vs 12,55 fps). Outils : mire VISUELLE par défaut
        (règles continues, une marche d'un pixel se voit ; `--coded` garde
        le motif forensique), `mire.pix` + `diag_check.py` au modèle uniforme
        — 4 diagonales × 8 000 contrôles octet-exacts, 0 défaut. Élément
        builder `<mscroll>` (map/tiles/start + .equ) enregistré au cœur.
        Note d'exemple : débordement de la ligne du haut (36 octets avant la
        zone, plan B dans la page résidente — réglages viewport + trash,
        commenté dans main.asm).
  - [ ] M4 : masque 8 px + DrawTiles par-dessus + banc de cycles
        (48/96/180) ; arbitrage 8 px/16 px du feed selon la hauteur retenue
        (5 lignes dans move). Différé : contrôle byte-exact du vscroll v1
        (le +1 des montées y est probablement latent).

## Stage 3 — battleship sur mscroll (campagne ouverte le 20/08)

- [x] **Analyse arcade** (`docs/lang/fr/analyse-warship-camera-2026-08.md`) :
      le vaisseau est un objet de wave (priorité 0xff00) qui confisque les
      deux axes de scroll de la couche background par un script de consignes
      (vy, vx, trames) de 295 segments — jumeau du couple
      mscroll.camera.speed*/move. Plates Ghidra corrigées (axes inversés,
      prouvé par le code). Spawn script positionnel 68 entrées (seuil sur le
      scroll accumulé). Excursion v2 : x [0..285], y [−66..38] px.
- [x] **Outils re.arcade.r-type** : `--extract-warship`
      (`extractor/Warship.java`) → `out/warship/warship-camera-script.asm`
      (8.8 convertis ×6/−12, durées gardées), spawn skeleton + CSV.
      `level3_b.png`/`level3_f.png` (3072×240) déjà exportés.
- [x] **Demi-page 0 récupérée** (décision auteur) : PRC bit 0 épinglé sous
      `OverlayMode` — dans `InitGlobals` (premier geste, AVANT les inits
      objets : vécu, le title effaçait une moitié et lisait l'autre) et dans
      `_gfxlock.init` (écarts au manifest). `background.save` retiré du
      config.
- [x] **Pool d'objets déménagé à $4000** : 60 slots dynamiques + fondu +
      3 slots d'armement (64×117=$1D40, 704 o de marge), ancre
      `Dynamic_Object_RAM equ $4000` (ram.const.asm), `<reserved>` en page
      $00. La page 1 rend $8850-$9DCA (~5,5 Ko). Banc : C1 vert, C2 = la
      signature rouge documentée de master (différentiel propre,
      code=4001 pc=84FD identique avant/après).
- [x] **mscroll RÉSIDENT (20/08)** : unité `common.mscroll` à $8850 (2562 o,
      ~3,4 Ko restent de la zone rendue), BUFFER_LINES=181. Frontière en
      SEPT noms (discipline api) : setup (façade à bloc de paramètres, les
      macros restent la source de vérité), do, move, camera.speed/speedx/x/y.
      Branchement stage-main sous `STAGE_MSCROLL` : do+move remplacent
      clearblast/clearWindow (le blast mscroll est l'effaceur — décision
      auteur), avant étoiles/frameBlit/DrawTiles. Inerte ailleurs (aucun
      appel). Banc différentiel : C1 vert, C2 = la signature rouge
      documentée de master (code=4001 pc=84FD, identique aux runs de
      référence) — aucun effet du module inerte.
- [x] **Assets stage 3 (20/08)** : `tools/arcade_to_mscroll.py` →
      `map/battleship.png` 640×384 (90,7 % de couleurs exactes sur la
      palette du stage) ; 5 direntries `<mscroll>` posés en dur $1C-$1F
      (tilesets format court ≤256 tuiles chargés à l'offset $2000 — la
      moitié montrée en $A000, optimisation Mscroll.java ; carte 158
      tuiles avec le tileset A ; buffers pleine page), arène stage3.gfx
      retaillée en conséquence ; `sky_transparent.py 03` rejoué (9904
      blocs — il n'avait jamais tourné sur ce stage, la tilemap noire
      recouvrait la couche).
- [x] **Pilote `warship_core` (20/08)** : `warship/pilot.asm` dans l'unité
      stage3 (ObjID 35 + 5 objids d'assets, index 6 tables), script caméra
      = unité `stage3.camscript` (export re.arcade copié, référence CUITE
      par le builder), wave décommentée, `mscroll.setup` appelé par
      stage.setup (bloc de paramètres, viewport 11/180). Deux bugs tués au
      banc : _SetCartPageA écrasait l'octet fort du reliquat de compteur
      (pilote muet après son 1er segment) ; les accumulateurs 8.8 partaient
      en RAM froide (bond caméra +375 px — setup efface tout l'état du
      module désormais). Outil `tools/warship_traj.py` : trajectoire
      mesurée vs intégrale du script ROM.
- [x] **Trajectoire VALIDÉE (20/08, warship_traj.py)** : forme et pentes
      exactes sur 3 minutes (dx constant ≈ −31 px = la phase de spawn wave
      ~170 trames ; dy ≤ 15 px, la danse verticale suit, wrap 384 compris).
      Gel à t≈7400 : le pilote s'éteint avec la fin de vie du stage
      placeholder (purge/endstage), pas un bug — la timeline réelle du
      combat viendra avec le portage des parties.
- [x] **Amorce autoscroll du checkpoint (20/08)** : l'auteur mesure
      « vaisseau à 6 s en arcade, 24 s chez nous » — la cause n'était ni le
      crop (curseur bg cp6 0x0528 + base 0x10D68F = pile le début de
      level3_b.png, enregistrement identité PROUVÉ) ni l'horloge : la table
      de checkpoint arcade (0x1000:87FA) sème `v_bg=$0080` dès l'entrée du
      stage, et le script du master (spawn ts $2000 = wave `$01,$00`
      correcte) PROLONGE cette vitesse (1er segment 8/16 = 0.5 px/trame).
      Correctif : `mscroll.camera.speedx = $0030` posé par stage.setup après
      mscroll.setup ; banc warship_traj réécrit (autoscroll avant spawn).
      Analyse : §5ter de analyse-warship-camera-2026-08.md.
- [x] **Pilote à la trame près (20/08, décision auteur)** : le mode vitesse
      intégrait tout un frame-drop à la vitesse de l'ancien segment quand
      une frontière tombait au milieu — dérive refusée par l'auteur. Le
      pilote dépile désormais les trames écoulées UNE PAR UNE (chaque trame
      porte la vitesse de son segment, comme tick_warship_master) et pousse
      la somme exacte par la nouvelle façade `mscroll.camera.impulse`
      (X=dx, D=dy 8.8, cumulés dans les reliquats du module — frontière à
      8 noms). Vitesses module à zéro dès pilotInit ; l'autoscroll du
      checkpoint reste en mode vitesse avant le spawn. Banc warship_traj :
      **dx ≤ 2 px, dy ≤ 5 px** sur toute la vie du pilote (avant : jusqu'à
      48 px — c'était bien la dérive de frontière, pas du jitter de banc).
      Deux pièges au passage : ldd écrase B (décompte empilé), ligne vide
      qui ferme la portée des labels @.
- [ ] Stage 3 restants : jugement visuel auteur (signe Y de la danse à
      confirmer à l'écran), chemin mort/checkpoint sur stage à mscroll
      (le rouge connu du chantier checkpoint + la question « le checkpoint
      re-seme-t-il l'autoscroll ? » — stage.setup le couvre déjà), jalons
      musique de boss (0x1180/0x12c0), spawn script des 27 parties +
      ennemis externes (campagne enemy-port), séquence de fin (0xc55d).
