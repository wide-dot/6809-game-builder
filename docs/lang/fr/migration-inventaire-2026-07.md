# Migration v1 → v2 — inventaire de dérive (31/07/2026)

Généré par comparaison des fichiers suivis (`engine/`, extensions
asm/equ/inc/xml) des deux dépôts. Données brutes :
[`docs/migration-inventaire.csv`](../../migration-inventaire.csv).
Mode opératoire : `.claude/skills/v1-migration/SKILL.md`.

## Chiffres

| | |
|---|---|
| fichiers engine v1 | **478** |
| fichiers engine v2 | **131** |
| homonymes (même nom de fichier) | **30 paires — toutes divergentes, zéro identique** |
| v1 seul (la masse à importer au fil du besoin) | 459 |
| v2 seul (candidats « conservé » : loader, TLSF, MO6, MPLUS…) | 107 |

## Découverte : la pollinisation a eu lieu dans les deux sens

La v1 n'est pas restée sur son ancien layout — elle a **déjà absorbé une
partie de la structure v2** :

- `engine/system/to8/map.const.asm` existe **dans les deux repos** (contenus
  divergents) ; idem `engine/system/to8/macros.asm` ;
- le player YMM vit en v1 sous `engine/objects/sound/ymm/ymm.asm` avec ses
  `ymm.const.asm` / `ymm.macro.asm` — le **nommage v2** est déjà en v1 ;
- `engine/joypad/joypad.const.asm` (v1) porte aussi le nommage pointé.

Conséquence heureuse : le « dialecte v1 » actuel est plus proche du dialecte
v2 que l'Excel de nommage le laissait penser — une partie du renommage est
déjà faite côté v1. L'import 1:1 reprend simplement **l'état v1 courant**,
quel que soit son style.

## Les 30 paires divergentes (à arbitrer une à une au moment de l'import)

Familles :

- **gfxlock** (`graphics/buffer/gfxlock.asm` + `.macro`) : v1 et v2 ont
  chacun fait évoluer leur copie. Import = état v1, puis re-greffe des
  spécificités v2 utiles (backProcess, memset, halfPage) comme écarts tracés
  ou re-proposées à la v1.
- **irq** : v1 `engine/irq/Irq.asm` (+ une variante `sound/vgc/lib/irq.asm`)
  vs v2 `system/{to8,mo6}/irq/irq.asm`. Le MO6 est v2-only → conservé.
- **joypad** : `joypad.const.asm`, `joypad.md6.asm` — proches, divergents.
- **macros** : v1 en a trois (racine, collision, system/to8) vs v2
  `engine/6809/macros.asm`.
- **map.const to8**, **sn76489**, **ym2413**, **ymm**/**vgc** (player +
  const + macro), **zx0** (3 décompresseurs) : divergences à differ au cas
  par cas — pour zx0, la v2 est probablement en avance (travaux loader).

## Partition appliquée (règles du skill)

- **Conservé v2** (107 fichiers v2-only, dont) : `system/thomson/bootloader/`
  (loader + scènes), `memory/` (TLSF + UT), `config/storage.xml`, tout
  `system/mo6/`, MPLUS/MEA8000, `global/types.const.asm`.
- **Parqué** (`parked/engine/`, `parked/examples/`) : snapshot intégral de
  l'engine v2 et des exemples au 31/07/2026, avant toute migration.
- **À importer de v1** : tout le reste, au fil du besoin, via le manifest
  (`engine/v1-manifest.csv`) — base commune d'abord (constants, macros,
  gfxlock, irq, palette), puis sprites (la campagne en cours), puis le reste
  de la roadmap R-Type.
