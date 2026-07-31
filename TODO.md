# TODO — suivi d'avancement

Fichier de travail : on coche ici, le détail vit dans `CLAUDE.md` et `docs/`.

Méthode standard pour tout changement builder/loader : images des 8 configs
d'exemples comparées **octet par octet** avec la référence, `loader-ut` rejoué
sous toje (16/16), tests JUnit verts, CI master verte.

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
  - [ ] M4 (suite) — banc runtime vs runtime : même scène buildée par les deux
        chaînes, VRAM comparée sous toje ; palette du banc (couleurs par
        défaut aujourd'hui) ; variantes miroir/décalage.
  - [ ] M5 — docs (sprites.md, CLAUDE.md) ; renommage = phase finale
        post-migration des jeux (table docs/engine-naming.csv)

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
- [ ] **Build d'image en CI** — la CI ne joue que les tests unitaires ;
      installer lwtools sur le runner et builder une mini-config avec hash de
      l'image mettrait la méthode d'identité binaire sous CI. (M)
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
- [ ] 5. Collisions AABB + terrain
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
