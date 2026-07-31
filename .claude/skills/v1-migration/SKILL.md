---
name: v1-migration
description: Mode opératoire de la migration de l'engine ASM v1 (thomson-to8-game-engine) vers la v2 (ce repo) — import 1:1, manifest, politique d'écarts, drift-check, double banc. À suivre pour tout import de fichier v1 ou adaptation d'exemple.
---

# Migration engine v1 → v2 — mode opératoire

## Décisions cadres (31/07/2026, validées par l'auteur)

1. **La v1 est la référence opérationnelle** (R-Type y tourne). Elle ne peut
   pas être gelée : elle continue d'évoluer. La bascule vers la v2 n'aura lieu
   que lorsque les jeux désignés par l'auteur auront tous migré.
2. **L'ASM v1 est repris en 1:1** (iso-syntaxe, mêmes noms, mêmes chemins de
   fichiers) — c'est ce qui rend le `diff` contre la v1 trivial pour toujours
   et la resynchronisation mécanique. La v2 peut apporter des spécificités ou
   optimisations propres, tracées comme écarts.
3. **Le renommage** (table `docs/engine-naming.csv`) et les évolutions non
   essentielles sont **différés en phase finale**, après la migration des
   jeux. Jusque-là, le dialecte v1 fait foi pour tout code importé.
4. **Ce qu'on remplace est parqué, jamais supprimé** : l'engine v2 actuel et
   les exemples actuels vivent dans `parked/` comme référence. Les exemples
   migrés (re)prennent leur place dans `examples/`.
5. **Périmètre** : le builder migre en **capacité** (idiome v2 : config.xml,
   scènes, linker — pas de portage du code BuildDisk) ; l'ASM migre en
   **iso-syntaxe** + nouvelles fonctionnalités v2.

## La partition de l'engine

- **Importé de v1 (1:1, chemins v1)** : tout ce qui a un original v1 —
  constants, macros, gfxlock, irq, palette, contrôleurs, sprites, objets,
  scroll, collisions, sons v1…
- **Conservé v2 (requis par le builder ou sans équivalent v1)** : bootloader
  + loader + scènes, TLSF (+ UT), décompresseurs ZX0, storage.xml, support
  MO6, MPLUS/MEA8000. Ces fichiers gardent leurs chemins et noms v2.
- **Parqué** (`parked/`) : les doublons v2 d'un fichier v1 (gfxlock v2,
  irq/palette/joypad renommés, glb.const/glb.init, ymm/vgc si divergents) et
  les exemples pré-migration.

## Procédure d'import d'un fichier v1

1. Repo v1 : `/Users/benoitrousseau/Documents/Claude/Projects/thomson-to8-game-engine`
   (chemin relatif depuis ce repo : `../thomson-to8-game-engine`).
2. Copier le fichier **à l'identique**, au **même chemin relatif** sous
   `engine/` (ex. v1 `engine/graphics/buffer/gfxlock.asm` → v2
   `engine/graphics/buffer/gfxlock.asm`).
3. Enregistrer la ligne dans **`engine/v1-manifest.csv`** :
   `v2_path,v1_path,v1_commit,imported_on,deviations`
   avec `v1_commit` = `git -C ../thomson-to8-game-engine log -1 --format=%H -- <v1_path>`.
4. **Écart au 1:1 = exception tracée.** Tout écart volontaire (bugfix,
   adaptation au contrat v2, optimisation) est noté dans la colonne
   `deviations` (motif court) ET signalé par un commentaire `; V2-DEVIATION:`
   dans le fichier. Écart connu et acté : marge de cellule sprites 16 → 12
   (`subd #16` → `subd #12` dans EraseSprites — l'IRQ v2 bascule S en
   première instruction, seul le push matériel touche la pile utilisateur).
5. Ne jamais renommer, ré-indenter ou « améliorer » au passage — la valeur du
   1:1 est le diff propre.

## Drift-check (pas de gel v1)

`./.claude/skills/v1-migration/drift-check.sh` compare, pour chaque ligne du
manifest, le commit v1 enregistré au dernier commit v1 touchant ce fichier.
Sortie : la liste des fichiers dont l'original a bougé depuis l'import.
À lancer avant toute campagne, et après chaque `git pull` du repo v1.
Rattrapage : re-diff fichier par fichier, ré-import, mise à jour du manifest.

## Validation — le double banc

- **Méthode standard du repo** (toujours) : les 8 configs d'exemples
  buildent, comparaison octet par octet quand le changement doit être neutre,
  `loader-ut` 16/16 sous toje, tests JUnit, CI verte.
- **Générateur vs générateur** : les mêmes PNG passés dans le générateur v1
  (`java-generator`) et dans gfxcomp doivent produire des binaires
  identiques (diff des `.bin` assemblés) ; tout écart est expliqué ou corrigé.
- **Runtime vs runtime** : le même code généré (sprites…) + le même scénario
  de test, buildés par chaque chaîne, exécutés chacun sur son engine sous
  toje (les deux sont du TO8) ; les deux écrivent des checksums (VRAM,
  cellules, compteurs) à adresse fixe → comparaison. La parité se prouve
  pendant la migration, pas après.

## Exemples

- Un exemple migré appelle le **dialecte v1** (`IrqInit`, `PalUpdateNow`,
  gfxlock v1…) et vit dans `examples/` ; sa version pré-migration reste dans
  `parked/examples/`.
- Exception MO6 : le support MO6 est v2-only ; les parties MO6 d'un exemple
  restent en dialecte v2 (documenté, pas un écart).

## Interdits

- Modifier un fichier sous `parked/` (référence figée).
- Importer un fichier v1 sans ligne de manifest.
- Appliquer le renommage `docs/engine-naming.csv` avant la phase finale.
