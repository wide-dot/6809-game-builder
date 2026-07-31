# TODO — suivi d'avancement

Fichier de travail : on coche ici, le détail vit dans `CLAUDE.md` et `docs/`.

Méthode standard pour tout changement builder/loader : images des 8 configs
d'exemples comparées **octet par octet** avec la référence, `loader-ut` rejoué
sous toje (16/16), tests JUnit verts, CI master verte.

## En cours

- [ ] **Scènes/régions déclaratives** — plan détaillé et syntaxe :
      [`docs/lang/fr/scenes-declaratives-2026-07.md`](docs/lang/fr/scenes-declaratives-2026-07.md)
  - [ ] Phase A — éléments `<layout>`/`<region>`/`<scene>`/`<file>` + générateur
        de tables (pilote : `examples/sound` TO8, identité binaire)
  - [ ] Phase B — vérifications au build (existence, tailles, chevauchements,
        export-only, multi-disquette)
  - [ ] Phase C — migration complète (loader-ut ×10 scènes, sound MO6),
        suppression des tables manuscrites, toje 16/16
  - [ ] Phase D — docs (groups.md, scenes.md, XSD régénéré, CLAUDE.md)

## Backlog builder (ordre conseillé)

- [ ] **Tri alphabétique des ids de symboles de link** — les ids suivent l'ordre
      de rencontre : réordonner un `<asm>` change toute l'image. Trier avant de
      numéroter rend « image différente » = signal fiable. À faire *entre* deux
      campagnes (renumérotation unique).
- [ ] **storage.xml sur XmlLoader + specs** — `Storages.java` est le dernier
      consommateur de XMLConfiguration ; migration = erreurs fichier:ligne sur
      les géométries disquette, un seul chemin de parsing.
- [ ] **Packaging zip distribuable** — assembly Maven : `repo/` + lanceurs
      `bin/` + third-party par OS + XSD. À faire seulement si distribution à des
      tiers visée.

## Différés loader (ne rouvrir que sur besoin réel)

- [ ] Suivi des tailles dans l'index (recouvrement partiel → slot périmé ;
      discipline actuelle : `linkData.unload` explicite)
- [ ] Paginated groups + outils de découpage

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
